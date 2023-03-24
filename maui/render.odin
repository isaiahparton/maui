package maui
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import "core:runtime"
import "core:path/filepath"
import "core:unicode/utf8"
import rl "vendor:raylib"

TEXTURE_WIDTH :: 2048
TEXTURE_HEIGHT :: 256

TRIANGLE_STEP :: math.TAU / 3

// up to how small/big should circles be pre-rendered?
MIN_CIRCLE_SIZE :: 2
MAX_CIRCLE_SIZE :: 29
CIRCLE_SIZES :: MAX_CIRCLE_SIZE - MIN_CIRCLE_SIZE

MAX_CIRCLE_STROKE_SIZE :: 2
CIRCLE_ROWS :: MAX_CIRCLE_STROKE_SIZE + 1

CIRCLE_SMOOTHING :: 1

PixelFormat :: rl.PixelFormat
Image :: rl.Image

/*
	How this is going to work:

	REBUILD_ATLAS :: ODIN_DEBUG
	OnStart :: proc() {
		when REBUILD_ATLAS {
			RebuildAndExportAtlas()
		} else {
			LoadAtlasData()
		}
	}
*/


/*
	NPatch dealings
*/
PatchIndex :: enum {
	widgetFill,
	widgetStroke,
	widgetStrokeThin,
	windowFill,
}
PatchData :: struct {
	source: Rect,
	amount: i32,
}

/*
	Font dealings
*/
FontIndex :: enum {
	default,
	header,
	monospace,
}
FontLoadData :: struct {
	size: i32,
	file: string,
}

FONT_LOAD_DATA :: [FontIndex]FontLoadData {
	.default = {
		size = 24,
		file = "Muli-SemiBold.ttf",
	},
	.header = {
		size = 28,
		file = "Muli-SemiBold.ttf",
	},
	.monospace = {
		size = 20,
		file = "Inconsolata_Condensed-SemiBold.ttf",
	},
}

GLYPH_SPACING :: 1
GlyphData :: struct {
	source: Rect,
	offset: Vec2,
	advance: f32,
}
FontData :: struct {
	size: f32,
	image: rl.Image,
	glyphs: []GlyphData,
	firstGlyph: rune,
}

GenSmoothCircle :: proc(image: ^rl.Image, center: Vec2, radius, smooth: f32) {
	size := radius * 2
	topLeft := center - radius

	for x in i32(topLeft.x) ..= i32(topLeft.x + size) {
		for y in i32(topLeft.y) ..= i32(topLeft.y + size) {
			point := Vec2{f32(x), f32(y)}
			diff := point - center
			dist := math.sqrt((diff.x * diff.x) + (diff.y * diff.y))
			if dist > radius + smooth {
				continue
			}
			alpha := 1 - max(0, dist - radius) / smooth
			rl.ImageDrawPixel(image, x, y, rl.Fade(rl.WHITE, alpha)) 
		}
	}
}
GenSmoothRing :: proc(image: ^rl.Image, center: Vec2, inner, outer, smooth: f32) {
	size := outer * 2
	topLeft := center - outer

	for x in i32(topLeft.x) ..= i32(topLeft.x + size) {
		for y in i32(topLeft.y) ..= i32(topLeft.y + size) {
			point := Vec2{f32(x), f32(y)}
			diff := point - center
			dist := math.sqrt((diff.x * diff.x) + (diff.y * diff.y))
			if dist < inner - smooth || dist > outer + smooth {
				continue
			}
			alpha := min(1, dist - inner) / smooth - max(0, dist - outer) / smooth
			rl.ImageDrawPixel(image, x, y, rl.Fade(rl.WHITE, alpha)) 
		}
	}
}
GenCircles :: proc(painter: ^Painter, origin: Vec2) -> Vec2 {

	// Spacing is needed to prevent artifacts with texture filtering
	SPACING :: 1

	// The number of stroke sizes plus one for filled
	rows := MAX_CIRCLE_STROKE_SIZE + 1

	// Starting offset
	offset :Vec2= {SPACING, SPACING}

	// Keep track of the total row size
	maxSize :f32= 0
	for rowIndex in 0 ..< rows {
		offset.x = 0
		for sizeIndex in 0 ..< CIRCLE_SIZES {
			size := f32(MIN_CIRCLE_SIZE + sizeIndex)
			radius := size / 2
			
			totalSize := size + CIRCLE_SMOOTHING * 2
			rect :Rect= {origin.x + offset.x, origin.y + offset.y, size + 1, size + 1}

			painter.circles[sizeIndex + rowIndex * CIRCLE_SIZES] = {
				source = rect,
				amount = i32(radius),
			}

			if rowIndex == 0 {
				// First row is filled
				GenSmoothCircle(&painter.image, {rect.x + radius, rect.y + radius}, radius, CIRCLE_SMOOTHING)
			} else {
				GenSmoothRing(&painter.image, {rect.x + radius, rect.y + radius}, radius - f32(rowIndex) - 0.2, radius, CIRCLE_SMOOTHING)
			}

			// Space taken by this circle
			space := totalSize + SPACING
			offset.x += space
			maxSize = max(maxSize, space)
		}
		offset.y += maxSize
	}
	return offset
}
GenIcons :: proc(painter: ^Painter, rect: Rect) {
	offset :Vec2= {}
	maxHeight :f32= 0
	for index in IconIndex {
		if index == .none {
			continue
		}

		path := fmt.caprintf("icons/%v.png", index)
		defer delete(path)

		iconImage := rl.LoadImage(path)
		rl.ImageColorBrightness(&iconImage, 255)
		if iconImage.data == nil {
			fmt.println("failed to load", path)
			continue
		}
		size :Vec2= {f32(iconImage.width), f32(iconImage.height)}

		if offset.x + size.x > rect.w {
			offset.x = 0
			offset.y += maxHeight
			if offset.y + maxHeight > rect.h {
				break
			}
		}

		source := Rect{rect.x + offset.x, rect.y + offset.y, size.x, size.y}
		rl.ImageDraw(&painter.image, iconImage, {0, 0, f32(size.x), f32(size.y)}, transmute(rl.Rectangle)source, rl.WHITE)
		painter.icons[index] = source

		offset.x += size.x
		maxHeight = max(maxHeight, size.y)
	}
}
GenFont :: proc(origin: Vec2, path: string, size, glyphCount: i32) -> (font: FontData, success: bool) {
	/*
		Pass each glyph to a packer	
	*/
	extension := filepath.ext(path)
    if extension == ".ttf" || extension == ".otf" {
    	fileData, ok := os.read_entire_file(path)
    	if !ok {
    		return
    	}

        glyphCount := glyphCount if glyphCount > 0 else 95
        glyphPadding := i32(1)
        glyphInfo := rl.LoadFontData((transmute(runtime.Raw_Slice)fileData).data, i32(len(fileData)), size, nil, glyphCount, .DEFAULT)

        if glyphInfo != nil {
        	rects := make([^]rl.Rectangle, glyphCount)
            font.image = rl.GenImageFontAtlas(glyphInfo, &rects, glyphCount, size, glyphPadding, 0);

            font.glyphs = make([]GlyphData, glyphCount)
            font.firstGlyph = glyphInfo[0].value
            for index in 0..<glyphCount {
            	rect := rects[index]
            	font.glyphs[index] = {
            		source = {origin.x + rect.x, origin.y + rect.y, rect.width, rect.height},
            		offset = {f32(glyphInfo[index].offsetX), f32(glyphInfo[index].offsetY)},
            		advance = f32(glyphInfo[index].advanceX),
            	}
            }

            font.size = f32(size)
        }
        rl.UnloadFontData(glyphInfo, glyphCount)
        success = true
    }
    return
}
GetGlyphData :: proc(font: FontData, codepoint: rune) -> GlyphData {
	index := int(codepoint) - int(font.firstGlyph)
	if len(font.glyphs) <= index {
		return {}
	}
	return font.glyphs[index]
}
GetFontData :: proc(index: FontIndex) -> FontData {
	return painter.fonts[index]
}

/*
	Exists for the lifetime of the program

	Loads or creates the texture, keeps track of every AtlasSource to which icons, patches or font glyphs can refer

	When the atlas is built, fonts, patches and icons will each pass their image and 
	an ^AtlasSource to the packer which will arrange them on the atlas and set the 
	^AtlasSource to their fragment index
		
		The atlas data along with every fragment will be compressed and saved to atlas/data.odin
			
			* Image will be trimmed and written as a slice of bytes
			* Sources will be put into an array

	when !REBUILD_ATLAS {
		import "atlas"
	}
*/
Painter :: struct {
	circles: [CIRCLE_SIZES * CIRCLE_ROWS]PatchData,
	fonts: [FontIndex]FontData,
	icons: [IconIndex]Rect,

	// atlas
	image: Image,
}
painter: ^Painter

DoneWithAtlasImage :: proc() {
	rl.UnloadImage(painter.image)
}

GenAtlas :: proc(using painter: ^Painter) {
	image = rl.GenImageColor(TEXTURE_WIDTH, TEXTURE_HEIGHT, {})
	image.format = .UNCOMPRESSED_GRAY_ALPHA

	rl.ImageDrawPixel(&image, 0, 0, rl.WHITE)
	circleSpace := GenCircles(painter, {1, 0})
	GenIcons(painter, {0, circleSpace.y, 512, 512 - circleSpace.y})

	offset :f32= 0
	for data, index in FONT_LOAD_DATA {
		font, success := GenFont({512 + offset, 0}, StringFormat("fonts/%s", data.file), data.size, 0)
		if !success {
			fmt.printf("Failed to load font %v\n", index)
			continue
		}
		fonts[index] = font
		offset += f32(font.image.width)
	}

	offset = 0
	for font in fonts {
		rl.ImageDraw(&image, font.image, {0, 0, f32(font.image.width), f32(font.image.height)}, {512 + offset, 0, f32(font.image.width), f32(font.image.height)}, rl.WHITE)
		offset += f32(font.image.width)
		rl.UnloadImage(font.image)
	}
}

/*
	Draw commands
*/
CommandTexture :: struct {
	using command: Command,
	uvMin, 
	uvMax,
	min, 
	max: Vec2,
	color: Color,
}
CommandTriangle :: struct {
	using command: Command,
	vertices: [3]Vec2,
	color: Color,
}
CommandClip :: struct {
	using command: Command,
	rect: Rect,
}
CommandVariant :: union {
	^CommandTexture,
	^CommandTriangle,
	^CommandClip,
}
Command :: struct {
	variant: CommandVariant,
	size: i32,
}

/*
	Push a command to the current layer's buffer
*/
PushCommand :: proc($Type: typeid, extra_size := 0) -> ^Type {
	assert(ctx.layerDepth > 0, "PushCommand() There is no layer on which to draw!")
	layer := GetCurrentLayer()
	
	size := i32(size_of(Type) + extra_size)
	cmd := transmute(^Type)&layer.commands[layer.commandOffset]
	assert(layer.commandOffset + size < COMMAND_BUFFER_SIZE, "PushCommand() Insufficient space in command buffer!")
	layer.commandOffset += size
	cmd.variant = cmd
	cmd.size = size
	return cmd
}
/*
	Get the next command in the current layer
*/
NextCommand :: proc(pcmd: ^^Command) -> bool {
	using ctx
	if hotLayer >= i32(len(layerList)) {
		return false
	}
	using layer := &layers[layerList[hotLayer]]

	cmd := pcmd^
	defer pcmd^ = cmd
	if cmd != nil { 
		cmd = (^Command)(uintptr(cmd) + uintptr(cmd.size)) 
	} else {
		cmd = (^Command)(&commands[0])
	}
	InvalidCommand :: #force_inline proc(using layer: ^LayerData) -> ^Command {
		return (^Command)(&commands[commandOffset])
	}
	if cmd == InvalidCommand(layer) {
		// At end of command buffer so reset `cmd` and go to next layer
		hotLayer += 1
		cmd = nil
		return NextCommand(&cmd)
	}
	return true
}
NextCommandIterator :: proc(pcm: ^^Command) -> (CommandVariant, bool) {
	if NextCommand(pcm) {
		return pcm^.variant, true
	}
	return nil, false
}

/*
	Drawing procedures
*/
BeginClip :: proc(rect: Rect) {
	cmd := PushCommand(CommandClip)
	cmd.rect = rect
}
EndClip :: proc() {
	cmd := PushCommand(CommandClip)
	cmd.rect = {0, 0, ctx.size.x, ctx.size.y}
}
DrawQuad :: proc(p1, p2, p3, p4: Vec2, c: Color) {
	PaintTriangle(p1, p2, p4, c)
	PaintTriangle(p4, p2, p3, c)
}
PaintTriangle :: proc(p1, p2, p3: Vec2, color: Color) {
	cmd := PushCommand(CommandTriangle)
	cmd.color = color
	cmd.vertices = {p1, p2, p3}
}
DrawRect :: proc(rect: Rect, color: Color) {
	DrawQuad(
		{f32(rect.x), f32(rect.y)},
		{f32(rect.x), f32(rect.y + rect.h)},
		{f32(rect.x + rect.w), f32(rect.y + rect.h)},
		{f32(rect.x + rect.w), f32(rect.y)},
		color,
	)
}
PaintTriangleStrip :: proc(points: []Vec2, color: Color) {
    if len(points) < 4 {
    	return
    }
    for i in 2 ..< len(points) {
        if i % 2 == 0 {
            PaintTriangle(
            	{points[i].x, points[i].y},
            	{points[i - 2].x, points[i - 2].y},
            	{points[i - 1].x, points[i - 1].y},
            	color,
            )
        } else {
        	PaintTriangle(
           	 	{points[i].x, points[i].y},
            	{points[i - 1].x, points[i - 1].y},
            	{points[i - 2].x, points[i - 2].y},
            	color,
            )
        }
    }
}
DrawLine :: proc(start, end: Vec2, thickness: f32, color: Color) {
	delta := end - start
    length := math.sqrt(f32(delta.x * delta.x + delta.y * delta.y))
    if length > 0 && thickness > 0 {
        scale := thickness / (2 * length)
        radius := Vec2{ -scale * delta.y, scale * delta.x }
        PaintTriangleStrip({
            { start.x - radius.x, start.y - radius.y },
            { start.x + radius.x, start.y + radius.y },
            { end.x - radius.x, end.y - radius.y },
            { end.x + radius.x, end.y + radius.y },
        }, color)
    }
}
DrawRectLines :: proc(rect: Rect, thickness: f32, color: Color) {
	DrawRect({rect.x, rect.y, rect.w, thickness}, color)
	DrawRect({rect.x, rect.y + rect.h - thickness, rect.w, thickness}, color)
	DrawRect({rect.x, rect.y, thickness, rect.h}, color)
	DrawRect({rect.x + rect.w - thickness, rect.y, thickness, rect.h}, color)
}
DrawCircle :: proc(center: Vec2, radius: f32, segments: i32, color: Color) {
	DrawCircleSector(center, radius, 0, math.TAU, segments, color)
}
DrawCircleSector :: proc(center: Vec2, radius, start, end: f32, segments: i32, color: Color) {
	step := (end - start) / f32(segments)
	angle := start
	for i in 0..<segments {
        PaintTriangle(
        	center, 
        	center + {math.cos(angle + step) * radius, math.sin(angle + step) * radius}, 
        	center + {math.cos(angle) * radius, math.sin(angle) * radius}, 
        	color,
        	)
        angle += step;
    }
}
DrawRing :: proc(center: Vec2, inner, outer: f32, segments: i32, color: Color) {
	DrawRingSector(center, inner, outer, 0, math.TAU, segments, color)
}
DrawRingSector :: proc(center: Vec2, inner, outer, start, end: f32, segments: i32, color: Color) {
	step := (end - start) / f32(segments)
	angle := start
	for i in 0..<segments {
        DrawQuad(
        	center + {math.cos(angle) * outer, math.sin(angle) * outer},
        	center + {math.cos(angle) * inner, math.sin(angle) * inner},
        	center + {math.cos(angle + step) * inner, math.sin(angle + step) * inner},
        	center + {math.cos(angle + step) * outer, math.sin(angle + step) * outer},
        	color,
        	)
        angle += step;
    }
}
DrawRectSweep :: proc(r: Rect, t: f32, c: Color) {
	if t >= 1 {
		DrawRect(r, c)
		return
	}
	a := (r.w + r.h) * t - r.h
	DrawRect({r.x, r.y, a, r.h}, c)
	DrawQuad(
		{r.x + max(a, 0), r.y}, 
		{r.x + max(a, 0), r.y + clamp(a + r.h, 0, r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y + max(0, a - r.w + r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y}, 
		c,
	)
}
PaintTexture :: proc(src, dst: Rect, color: Color) {
	cmd := PushCommand(CommandTexture)
	cmd.uvMin = {src.x / TEXTURE_WIDTH, src.y / TEXTURE_HEIGHT}
	cmd.uvMax = {(src.x + src.w) / TEXTURE_WIDTH, (src.y + src.h) / TEXTURE_HEIGHT}
	cmd.min = {dst.x, dst.y}
	cmd.max = {dst.x + dst.w, dst.y + dst.h}
	cmd.color = color
}
PaintTextureEx :: proc(src, dst: Rect, angle: f32, color: Color) {
	cmd := PushCommand(CommandTexture)
	cmd.uvMin = {src.x / TEXTURE_WIDTH, src.y / TEXTURE_HEIGHT}
	cmd.uvMax = {(src.x + src.w) / TEXTURE_WIDTH, (src.y + src.h) / TEXTURE_HEIGHT}
	cmd.min = {dst.x, dst.y}
	cmd.max = {dst.x + dst.w, dst.y + dst.h}
	cmd.color = color
}
PaintCircle :: proc(center: Vec2, radius: f32, color: Color) {
	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index].source
	PaintTexture(source, {center.x - source.w / 2, center.y - source.h / 2, source.w, source.h}, color)
}

Corner :: enum {
	topLeft,
	topRight,
	bottomRight,
	bottomLeft,
}
Corners :: bit_set[Corner;u8]
PaintRoundedRectEx :: proc(rect: Rect, radius: f32, corners: Corners, color: Color) {
	if corners == {} {
		DrawRect(rect, color)
		return
	}
	if rect.h == 0 || rect.w == 0 {
		return
	}

	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index].source
	halfSize := math.trunc(source.w / 2)

	if .topLeft in corners {
		sourceTopLeft: Rect = {source.x, source.y, halfSize, halfSize}
		PaintTexture(sourceTopLeft, {rect.x, rect.y, halfSize, halfSize}, color)
	}
	if .topRight in corners {
		sourceTopRight: Rect = {source.x + source.w - halfSize, source.y, halfSize, halfSize}
		PaintTexture(sourceTopRight, {rect.x + rect.w - radius, rect.y, halfSize, halfSize}, color)
	}
	if .bottomRight in corners {
		sourceBottomRight: Rect = {source.x + source.w - halfSize, source.y + source.h - halfSize, halfSize, halfSize}
		PaintTexture(sourceBottomRight, {rect.x + rect.w - halfSize, rect.y + rect.h - halfSize, halfSize, halfSize}, color)
	}
	if .bottomLeft in corners {
		sourceBottomLeft: Rect = {source.x, source.y + source.h - halfSize, halfSize, halfSize}
		PaintTexture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfSize, halfSize, halfSize}, color)
	}

	if rect.w > radius * 2 {
		DrawRect({rect.x + radius, rect.y, rect.w - radius * 2, rect.h}, color)
	}
	if rect.h > radius * 2 {
		topLeft := radius if .topLeft in corners else 0
		topRight := radius if .topRight in corners else 0
		bottomRight := radius if .bottomRight in corners else 0
		bottomLeft := radius if .bottomLeft in corners else 0
		DrawRect({rect.x, rect.y + topLeft, radius, rect.h - (topLeft + bottomLeft)}, color)
		DrawRect({rect.x + rect.w - radius, rect.y + topRight, radius, rect.h - (topRight + bottomRight)}, color)
	}
}
PaintRoundedRect :: proc(rect: Rect, radius: f32, color: Color) {
	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index].source
	halfSize := math.trunc(source.w / 2)

	sourceTopLeft: Rect = {source.x, source.y, halfSize, halfSize}
	sourceTopRight: Rect = {source.x + source.w - halfSize, source.y, halfSize, halfSize}
	sourceBottomRight: Rect = {source.x + source.w - halfSize, source.y + source.h - halfSize, halfSize, halfSize}
	sourceBottomLeft: Rect = {source.x, source.y + source.h - halfSize, halfSize, halfSize}

	PaintTexture(sourceTopLeft, {rect.x, rect.y, halfSize, halfSize}, color)
	PaintTexture(sourceTopRight, {rect.x + rect.w - radius, rect.y, halfSize, halfSize}, color)
	PaintTexture(sourceBottomRight, {rect.x + rect.w - halfSize, rect.y + rect.h - halfSize, halfSize, halfSize}, color)
	PaintTexture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfSize, halfSize, halfSize}, color)

	if rect.w > radius * 2 {
		DrawRect({rect.x + radius, rect.y, rect.w - radius * 2, rect.h}, color)
	}
	if rect.h > radius * 2 {
		DrawRect({rect.x, rect.y + radius, radius, rect.h - radius * 2}, color)
		DrawRect({rect.x + rect.w - radius, rect.y + radius, radius, rect.h - radius * 2}, color)
	}
}
PaintRoundedRectOutline :: proc(rect: Rect, radius: f32, color: Color) {
	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index + CIRCLE_SIZES * 2].source
	halfSize := math.trunc(source.w / 2)

	sourceTopLeft: Rect = {source.x, source.y, halfSize, halfSize}
	sourceTopRight: Rect = {source.x + source.w - halfSize, source.y, halfSize, halfSize}
	sourceBottomRight: Rect = {source.x + source.w - halfSize, source.y + source.h - halfSize, halfSize, halfSize}
	sourceBottomLeft: Rect = {source.x, source.y + source.h - halfSize, halfSize, halfSize}

	PaintTexture(sourceTopLeft, {rect.x, rect.y, halfSize, halfSize}, color)
	PaintTexture(sourceTopRight, {rect.x + rect.w - radius, rect.y, halfSize, halfSize}, color)
	PaintTexture(sourceBottomRight, {rect.x + rect.w - halfSize, rect.y + rect.h - halfSize, halfSize, halfSize}, color)
	PaintTexture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfSize, halfSize, halfSize}, color)

	if rect.w > radius * 2 {
		DrawRect({rect.x + radius, rect.y, rect.w - radius * 2, 2}, color)
		DrawRect({rect.x + radius, rect.y + rect.h - 2, rect.w - radius * 2, 2}, color)
	}
	if rect.h > radius * 2 {
		DrawRect({rect.x, rect.y + radius, 2, rect.h - radius * 2}, color)
		DrawRect({rect.x + rect.w - 2, rect.y + radius, 2, rect.h - radius * 2}, color)
	}
}
PaintCollapseArrow :: proc(center: Vec2, size, time: f32, color: Color) {
	angle := (1 - time) * math.PI * 0.5
	norm: Vec2 = {math.cos(angle), math.sin(angle)}
	PaintTriangle(
		center + {math.cos(angle - TRIANGLE_STEP), math.sin(angle - TRIANGLE_STEP)} * size,
		center + {math.cos(angle + TRIANGLE_STEP), math.sin(angle + TRIANGLE_STEP)} * size,
		center + {math.cos(angle), math.sin(angle)} * size, 
		color,
		)
}

/*
	Text rendering
*/
Alignment :: enum {
	near,
	middle,
	far,
}
MeasureString :: proc(font: FontData, text: string) -> Vec2 {
	size := Vec2{}
	for codepoint in text {
		glyph := GetGlyphData(font, codepoint)
		size.x += glyph.advance
	}
	size.y = font.size
	return size
}
DrawString :: proc(font: FontData, text: string, origin: Vec2, color: Color) {
	origin := origin
	for codepoint in text {
		glyph := GetGlyphData(font, codepoint)
		PaintTexture(glyph.source, {math.trunc(origin.x + glyph.offset.x), origin.y + glyph.offset.y, glyph.source.w, glyph.source.h}, color)
		origin.x += glyph.advance
	}
}
DrawAlignedString :: proc(font: FontData, text: string, origin: Vec2, color: Color, alignX, alignY: Alignment) {
	origin := origin
	if alignX == .middle {
		origin.x -= math.trunc(MeasureString(font, text).x / 2)
	} else if alignX == .far {
		origin.x -= MeasureString(font, text).x
	}
	if alignY == .middle {
		origin.y -= MeasureString(font, text).y / 2
	} else if alignY == .far {
		origin.y -= MeasureString(font, text).y
	}
	DrawString(font, text, origin, color)
}
/*
/*
	Draw a clipped glyphs with math instead of GPU commands
*/
DrawClippedGlyph :: proc(glyph: GlyphData, origin: Vec2, clipRect: Rect, color: Color) {
	
}
*/

/*
	Icons in the order they appear on the atlas (left to right, descending)
*/
IconIndex :: enum {
	none = -1,
	plus,
	archive,
	arrowUp,
	arrowDown,
	arrowLeft,
	arrowRight,
	undo,
	redo,
	barChart,
	calendar,
	check,
	close,
	delete,
	download,
	eyeOff,
	eye,
	file,
	folder,
	heart,
	history,
	home,
	keyboard,
	list,
	menu,
	palette,
	pencil,
	pieChart,
	pushPin,
	search,
	cog,
	shoppingBasket,
	star,
	minus,
	upload,
}
ICON_SIZE :: 24
DrawIcon :: proc(icon: IconIndex, origin: Vec2, color: Color) {
	DrawIconEx(icon, origin, 1, .near, .near, color)
}
DrawIconEx :: proc(icon: IconIndex, origin: Vec2, scale: f32, alignX, alignY: Alignment, color: Color) {
	offset := Vec2{}
	if alignX == .middle {
		offset.x -= ICON_SIZE / 2
	} else if alignX == .far {
		offset.x -= ICON_SIZE
	}
	if alignY == .middle {
		offset.y -= ICON_SIZE / 2
	} else if alignY == .far {
		offset.y -= ICON_SIZE
	}
	dst := Rect{0, 0, f32(ICON_SIZE * scale), f32(ICON_SIZE * scale)}
	dst.x = origin.x - dst.w / 2
	dst.y = origin.y - dst.h / 2
	PaintTexture(painter.icons[icon], dst, color)
}

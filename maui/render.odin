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

// up to how small/big should circles be pre-rendered?
MIN_CIRCLE_SIZE :: 2
MAX_CIRCLE_SIZE :: 29
CIRCLE_SIZES :: MAX_CIRCLE_SIZE - MIN_CIRCLE_SIZE

MAX_CIRCLE_STROKE_SIZE :: 2
CIRCLE_ROWS :: MAX_CIRCLE_STROKE_SIZE + 1

CIRCLE_SMOOTHING :: 1.1

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
		file = "IBMPlexSans-Regular.ttf",
	},
	.header = {
		size = 36,
		file = "IBMPlexSans-Regular.ttf",
	},
	.monospace = {
		size = 24,
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
	size := radius * 2 + math.ceil(smooth) + 1
	topLeft := center - size / 2

	for x in i32(topLeft.x) ..< i32(topLeft.x + size) {
		for y in i32(topLeft.y) ..< i32(topLeft.y + size) {
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
	size := outer * 2 + math.ceil(smooth) + 1
	topLeft := center - size / 2

	for x in i32(topLeft.x) ..< i32(topLeft.x + size) {
		for y in i32(topLeft.y) ..< i32(topLeft.y + size) {
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
			rect :Rect= {origin.x + offset.x, origin.y + offset.y, totalSize, totalSize}

			painter.circles[sizeIndex + rowIndex * CIRCLE_SIZES] = {
				source = rect,
				amount = i32(radius),
			}

			if rowIndex == 0 {
				// First row is filled
				GenSmoothCircle(&painter.image, {rect.x + rect.w / 2, rect.y + rect.h / 2}, radius, CIRCLE_SMOOTHING)
			} else {
				GenSmoothRing(&painter.image, {rect.x + rect.w / 2, rect.y + rect.h / 2}, radius - f32(rowIndex), radius, CIRCLE_SMOOTHING)
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
            font.firstGlyph = 0xffff
            for index in 0..<glyphCount {
            	font.firstGlyph = rune(min(int(font.firstGlyph), int(glyphInfo[index].value)))
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

LoadResources :: proc(using painter: ^Painter) {
	image = rl.GenImageColor(2048, 256, {})
	image.format = .UNCOMPRESSED_GRAY_ALPHA

	circleSpace := GenCircles(painter, {})
	GenIcons(painter, {0, circleSpace.y, 512, 512 - circleSpace.y})
	atlasHeight := i32(0)
	for data, index in FONT_LOAD_DATA {
		font, success := GenFont({512 + f32(index) * 256, 0}, StringFormat("fonts/%s", data.file), data.size, 0)
		if !success {
			fmt.printf("Failed to load font %v\n", index)
			continue
		}
		fonts[index] = font
		atlasHeight = max(atlasHeight, font.image.height)
	}

	for fontIndex, index in FontIndex {
		rl.ImageDraw(&image, fonts[fontIndex].image, {0, 0, 256, 256}, {512 + f32(index) * 256, 0, 256, 256}, rl.WHITE)
		rl.UnloadImage(fonts[fontIndex].image)
	}
}

/*
	Draw commands
*/
CommandTexture :: struct {
	using command: Command,
	texture: i32,
	src, dst: Rect,
	color: Color,
}
CommandTriangle :: struct {
	using command: Command,
	points: [3]Vec2,
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
	DrawTriangle(p1, p2, p4, c)
	DrawTriangle(p4, p2, p3, c)
}
DrawTriangle :: proc(p1, p2, p3: Vec2, c: Color) {
	cmd := PushCommand(CommandTriangle)
	cmd.points = {p1, p2, p3}
	cmd.color = c
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
DrawTriangleStrip :: proc(points: []Vec2, color: Color) {
    if len(points) < 4 {
    	return
    }
    for i in 2 ..< len(points) {
        if i % 2 == 0 {
            DrawTriangle(
            	{points[i].x, points[i].y},
            	{points[i - 2].x, points[i - 2].y},
            	{points[i - 1].x, points[i - 1].y},
            	color,
            )
        } else {
        	DrawTriangle(
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
        DrawTriangleStrip({
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
        DrawTriangle(
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
TextureIndex :: enum {
	font,
	icons,
}
DrawTexture :: proc(texture: TextureIndex, src, dst: Rect, color: Color) {
	cmd := PushCommand(CommandTexture)
	cmd.texture = i32(texture)
	cmd.color = color
	cmd.src = src
	cmd.dst = dst
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
		glyph := GetGlyphData(ctx.font, codepoint)
		DrawTexture(.font, glyph.source, {origin.x + glyph.offset.x, origin.y + glyph.offset.y, glyph.source.w, glyph.source.h}, color)
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
	lineChart,
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
	DrawTexture(.icons, {(f32(i32(icon) % 10)) * ICON_SIZE, (f32(i32(icon) / 10)) * ICON_SIZE, ICON_SIZE, ICON_SIZE}, dst, color)
}
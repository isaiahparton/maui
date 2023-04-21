package maui
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import "core:runtime"
import "core:path/filepath"
import "core:unicode"
import "core:unicode/utf8"

import stb "vendor:stb/truetype"
import rl "vendor:raylib"

TEXTURE_WIDTH :: 4096
TEXTURE_HEIGHT :: 256

TRIANGLE_STEP :: math.TAU / 3

// up to how small/big should circles be pre-rendered?
MIN_CIRCLE_SIZE :: 2
MAX_CIRCLE_SIZE :: 48
CIRCLE_SIZES :: MAX_CIRCLE_SIZE - MIN_CIRCLE_SIZE

MAX_CIRCLE_STROKE_SIZE :: 2
CIRCLE_ROWS :: MAX_CIRCLE_STROKE_SIZE + 1

CIRCLE_SMOOTHING :: 1

PixelFormat :: rl.PixelFormat
Image :: rl.Image

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
	label,
}
FontLoadData :: struct {
	size: i32,
	file: string,
}

FONT_LOAD_DATA :: [FontIndex]FontLoadData {
	.default = {
		size = 20,
		file = "merged.ttf",
	},
	.header = {
		size = 28,
		file = "IBMPlexSans-Medium.ttf",
	},
	.monospace = {
		size = 20,
		file = "Inconsolata_Condensed-SemiBold.ttf",
	},
	.label = {
		size = 16,
		file = "IBMPlexSans-Medium.ttf",
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
	glyphMap: map[rune]i32,
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
				GenSmoothRing(&painter.image, {rect.x + radius, rect.y + radius}, radius - f32(rowIndex), radius, CIRCLE_SMOOTHING)
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
	return
}
GenFont :: proc(painter: ^Painter, origin: Vec2, path: string, size, glyphCount: i32) -> (font: FontData, success: bool) {
	fontGlyphs := make([dynamic]rune)
	defer delete(fontGlyphs)

	for i in 0 ..< 255 {
		if !unicode.is_letter(rune(i)) && !unicode.is_number(rune(i)) && !unicode.is_symbol(rune(i)) {
			continue
		}
		append(&fontGlyphs, rune(i))
	}
	append(&fontGlyphs, '')
	/*
		Pass each glyph to a packer	
	*/
	extension := filepath.ext(path)
    if extension == ".ttf" || extension == ".otf" {
    	fileData, ok := os.read_entire_file(path)
    	if !ok {
    		return
    	}

        fontInfo: stb.fontinfo
        if !stb.InitFont(&fontInfo, transmute([^]u8)(&fileData), 0) {
        	fmt.println("stb_truetype failed to initialize font")
        	return
        }

        scaleFactor := stb.ScaleForPixelHeight(&fontInfo, f32(size))

        ascent, descent, lineGap: i32
        stb.GetFontVMetrics(&fontInfo, &ascent, &descent, &lineGap)

        offset: Vec2
        font.glyphs = make([]GlyphData, glyphCount)
        for glyph, index in fontGlyphs {
        	glyphWidth, glyphHeight: i32
        	offsetX, offsetY: i32

        	imageData := stb.GetCodepointBitmap(&fontInfo, scaleFactor, scaleFactor, glyph, &glyphWidth, &glyphHeight, &offsetX, &offsetY)
        	glyphAdvance: i32
        	stb.GetGlyphHMetrics(&fontInfo, i32(glyph), &glyphAdvance, nil)

        	// Copy bitmap to atlas
        	image: Image = {
        		data = imageData,
        		mipmaps = 1,
        		width = glyphWidth,
        		height = glyphHeight,
        		format = .UNCOMPRESSED_GRAY_ALPHA,
        	}
        	rect: Rect = {origin.x + offset.x, origin.y + offset.y, f32(glyphWidth), f32(glyphHeight)}
        	rl.ImageDraw(&painter.image, image, {0, 0, rect.w, rect.h}, transmute(rl.Rectangle)rect, rl.WHITE)
        	rl.UnloadImage(image)

        	font.glyphs[index] = {
        		offset = {f32(offsetX), f32(offsetY)},
        		source = rect,
        		advance = f32(glyphAdvance),
        	}
        	font.glyphMap[glyph] = i32(index)
        }
        success = true
    }
    return
}
GetGlyphData :: proc(font: FontData, codepoint: rune) -> GlyphData {
	index, ok := font.glyphMap[codepoint]
	if ok {
		return font.glyphs[index]
	}
	return {}
}
GetFontData :: proc(index: FontIndex) -> FontData {
	return painter.fonts[index]
}

/*
	Exists for the lifetime of the program

	Loads or creates the texture, keeps track of every AtlasSource to which icons, patches or font glyphs can refer
*/
Painter :: struct {
	circles: [CIRCLE_SIZES * CIRCLE_ROWS]PatchData,
	fonts: [FontIndex]FontData,

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
		font, success := GenFont(painter, {circleSpace.x + offset, 0}, StringFormat("fonts/%s", data.file), data.size, 256)
		if !success {
			fmt.printf("Failed to load font %v\n", index)
			continue
		}
		fonts[index] = font
		offset += f32(font.image.width)
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
	layer := &layers[layerList[hotLayer]]

	cmd := pcmd^
	defer pcmd^ = cmd
	if cmd != nil { 
		cmd = (^Command)(uintptr(cmd) + uintptr(cmd.size)) 
	} else {
		cmd = (^Command)(&layer.commands[0])
	}
	InvalidCommand :: #force_inline proc(using layer: ^LayerData) -> ^Command {
		return (^Command)(&layer.commands[commandOffset])
	}
	clip, ok := cmd.variant.(^CommandClip)
	if ok {
		if clip.rect == clipRect {
			return NextCommand(&cmd)
		} else {
			clipRect = clip.rect
		}
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
	if !ctx.shouldRender {
		return
	}

	cmd := PushCommand(CommandClip)
	cmd.rect = rect
}
EndClip :: proc() {
	if !ctx.shouldRender {
		return
	}

	cmd := PushCommand(CommandClip)
	cmd.rect = ctx.fullscreenRect
}
PaintQuad :: proc(p1, p2, p3, p4: Vec2, c: Color) {
	if !ctx.shouldRender {
		return
	}

	PaintTriangle(p1, p2, p4, c)
	PaintTriangle(p4, p2, p3, c)
}
PaintTriangle :: proc(p1, p2, p3: Vec2, color: Color) {
	if !ctx.shouldRender {
		return
	}

	cmd := PushCommand(CommandTriangle)
	cmd.color = color
	cmd.vertices = {p1, p2, p3}
}
PaintRect :: proc(rect: Rect, color: Color) {
	if !ctx.shouldRender {
		return
	}

	PaintQuad(
		{f32(rect.x), f32(rect.y)},
		{f32(rect.x), f32(rect.y + rect.h)},
		{f32(rect.x + rect.w), f32(rect.y + rect.h)},
		{f32(rect.x + rect.w), f32(rect.y)},
		color,
	)
}
PaintTriangleStrip :: proc(points: []Vec2, color: Color) {
	if !ctx.shouldRender {
		return
	}

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
PaintLine :: proc(start, end: Vec2, thickness: f32, color: Color) {
	if !ctx.shouldRender {
		return
	}

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
PaintRectLines :: proc(rect: Rect, thickness: f32, color: Color) {
	if !ctx.shouldRender {
		return
	}

	PaintRect({rect.x, rect.y, rect.w, thickness}, color)
	PaintRect({rect.x, rect.y + rect.h - thickness, rect.w, thickness}, color)
	PaintRect({rect.x, rect.y, thickness, rect.h}, color)
	PaintRect({rect.x + rect.w - thickness, rect.y, thickness, rect.h}, color)
}
PaintCircleUh :: proc(center: Vec2, radius: f32, segments: i32, color: Color) {
	if !ctx.shouldRender {
		return
	}

	PaintCircleSector(center, radius, 0, math.TAU, segments, color)
}
PaintCircleSector :: proc(center: Vec2, radius, start, end: f32, segments: i32, color: Color) {
	if !ctx.shouldRender {
		return
	}

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
PaintRing :: proc(center: Vec2, inner, outer: f32, segments: i32, color: Color) {
	if !ctx.shouldRender {
		return
	}

	PaintRingSector(center, inner, outer, 0, math.TAU, segments, color)
}
PaintRingSector :: proc(center: Vec2, inner, outer, start, end: f32, segments: i32, color: Color) {
	if !ctx.shouldRender {
		return
	}

	step := (end - start) / f32(segments)
	angle := start
	for i in 0..<segments {
        PaintQuad(
        	center + {math.cos(angle) * outer, math.sin(angle) * outer},
        	center + {math.cos(angle) * inner, math.sin(angle) * inner},
        	center + {math.cos(angle + step) * inner, math.sin(angle + step) * inner},
        	center + {math.cos(angle + step) * outer, math.sin(angle + step) * outer},
        	color,
    	)
        angle += step;
    }
}
PaintRectSweep :: proc(r: Rect, t: f32, c: Color) {
	if !ctx.shouldRender {
		return
	}

	if t >= 1 {
		PaintRect(r, c)
		return
	}
	a := (r.w + r.h) * t - r.h
	PaintRect({r.x, r.y, a, r.h}, c)
	PaintQuad(
		{r.x + max(a, 0), r.y}, 
		{r.x + max(a, 0), r.y + clamp(a + r.h, 0, r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y + max(0, a - r.w + r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y}, 
		c,
	)
}
PaintTexture :: proc(src, dst: Rect, color: Color) {
	if !ctx.shouldRender {
		return
	}

	cmd := PushCommand(CommandTexture)
	cmd.uvMin = {src.x / TEXTURE_WIDTH, src.y / TEXTURE_HEIGHT}
	cmd.uvMax = {(src.x + src.w) / TEXTURE_WIDTH, (src.y + src.h) / TEXTURE_HEIGHT}
	cmd.min = {dst.x, dst.y}
	cmd.max = {dst.x + dst.w, dst.y + dst.h}
	cmd.color = color
}
PaintTextureEx :: proc(src, dst: Rect, angle: f32, color: Color) {
	if !ctx.shouldRender {
		return
	}

	cmd := PushCommand(CommandTexture)
	cmd.uvMin = {src.x / TEXTURE_WIDTH, src.y / TEXTURE_HEIGHT}
	cmd.uvMax = {(src.x + src.w) / TEXTURE_WIDTH, (src.y + src.h) / TEXTURE_HEIGHT}
	cmd.min = {dst.x, dst.y}
	cmd.max = {dst.x + dst.w, dst.y + dst.h}
	cmd.color = color
}
PaintCircle :: proc(center: Vec2, radius: f32, color: Color) {
	if !ctx.shouldRender {
		return
	}

	index := int(radius) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := ExpandRect(painter.circles[index].source, 1)
	PaintTexture(source, {center.x - source.w / 2, center.y - source.h / 2, source.w, source.h}, color)
}
PaintCircleOutline :: proc(center: Vec2, radius: f32, thin: bool, color: Color) {
	if !ctx.shouldRender {
		return
	}

	index := CIRCLE_SIZES + int(radius) - MIN_CIRCLE_SIZE
	if !thin {
		index += CIRCLE_SIZES
	}
	if index < 0 {
		return
	}
	source := ExpandRect(painter.circles[index].source, 1)
	PaintTexture(source, {center.x - source.w / 2, center.y - source.h / 2, source.w, source.h}, color)
}

PaintRoundedRectEx :: proc(rect: Rect, radius: f32, corners: RectCorners, color: Color) {
	if !ctx.shouldRender {
		return
	}

	if rect.h == 0 || rect.w == 0 {
		return
	}
	if radius == 0 || corners == {} {
		PaintRect(rect, color)
		return
	}

	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index].source
	halfSize := math.trunc(source.w / 2)

	halfWidth := min(halfSize, rect.w / 2)
	halfHeight := min(halfSize, rect.h / 2)

	if .topLeft in corners {
		sourceTopLeft: Rect = {source.x, source.y, halfWidth, halfHeight}
		PaintTexture(sourceTopLeft, {rect.x, rect.y, halfSize, halfSize}, color)
	}
	if .topRight in corners {
		sourceTopRight: Rect = {source.x + source.w - halfWidth, source.y, halfWidth, halfHeight}
		PaintTexture(sourceTopRight, {rect.x + rect.w - halfWidth, rect.y, halfSize, halfSize}, color)
	}
	if .bottomRight in corners {
		sourceBottomRight: Rect = {source.x + source.w - halfWidth, source.y + source.h - halfHeight, halfWidth, halfHeight}
		PaintTexture(sourceBottomRight, {rect.x + rect.w - halfSize, rect.y + rect.h - halfSize, halfSize, halfSize}, color)
	}
	if .bottomLeft in corners {
		sourceBottomLeft: Rect = {source.x, source.y + source.h - halfHeight, halfWidth, halfHeight}
		PaintTexture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfHeight, halfSize, halfSize}, color)
	}

	if rect.w > radius * 2 {
		PaintRect({rect.x + radius, rect.y, rect.w - radius * 2, rect.h}, color)
	}
	if rect.h > radius * 2 {
		topLeft := radius if .topLeft in corners else 0
		topRight := radius if .topRight in corners else 0
		bottomRight := radius if .bottomRight in corners else 0
		bottomLeft := radius if .bottomLeft in corners else 0
		PaintRect({rect.x, rect.y + topLeft, radius, rect.h - (topLeft + bottomLeft)}, color)
		PaintRect({rect.x + rect.w - radius, rect.y + topRight, radius, rect.h - (topRight + bottomRight)}, color)
	}
}
PaintRoundedRect :: proc(rect: Rect, radius: f32, color: Color) {
	if !ctx.shouldRender {
		return
	}

	if radius == 0 {
		PaintRect(rect, color)
		return
	}

	if rect.w == 0 || rect.h == 0 {
		return
	}
	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index].source
	halfSize := math.trunc(source.w / 2)

	halfWidth := min(halfSize, rect.w / 2)
	halfHeight := min(halfSize, rect.h / 2)

	sourceTopLeft: Rect = {source.x, source.y, halfWidth, halfHeight}
	sourceTopRight: Rect = {source.x + source.w - halfWidth, source.y, halfWidth, halfHeight}
	sourceBottomRight: Rect = {source.x + source.w - halfWidth, source.y + source.h - halfHeight, halfWidth, halfHeight}
	sourceBottomLeft: Rect = {source.x, source.y + source.h - halfHeight, halfWidth, halfHeight}

	PaintTexture(sourceTopLeft, {rect.x, rect.y, halfWidth, halfHeight}, color)
	PaintTexture(sourceTopRight, {rect.x + rect.w - halfWidth, rect.y, halfWidth, halfHeight}, color)
	PaintTexture(sourceBottomRight, {rect.x + rect.w - halfWidth, rect.y + rect.h - halfHeight, halfWidth, halfHeight}, color)
	PaintTexture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfHeight, halfWidth, halfHeight}, color)

	if rect.w > radius * 2 {
		PaintRect({rect.x + radius, rect.y, rect.w - radius * 2, rect.h}, color)
	}
	if rect.h > radius * 2 {
		halfWidth := min(radius, rect.w / 2)
		PaintRect({rect.x, rect.y + radius, halfWidth, rect.h - radius * 2}, color)
		PaintRect({rect.x + rect.w - halfWidth, rect.y + radius, halfWidth, rect.h - radius * 2}, color)
	}
}

PaintRoundedRectOutline :: proc(rect: Rect, radius: f32, thin: bool, color: Color) {
	if !ctx.shouldRender {
		return
	}

	thickness: f32 = 1 if thin else 2
	if radius == 0 {
		PaintRectLines(rect, thickness, color)
		return
	}

	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if color.a == 0 || index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index + (CIRCLE_SIZES if thin else (CIRCLE_SIZES * 2))].source
	halfSize := math.trunc(source.w / 2)

	halfWidth := min(halfSize, rect.w / 2)
	halfHeight := min(halfSize, rect.h / 2)

	sourceTopLeft: Rect = {source.x, source.y, halfWidth, halfHeight}
	sourceTopRight: Rect = {source.x + source.w - halfWidth, source.y, halfWidth, halfHeight}
	sourceBottomRight: Rect = {source.x + source.w - halfWidth, source.y + source.h - halfHeight, halfWidth, halfHeight}
	sourceBottomLeft: Rect = {source.x, source.y + source.h - halfHeight, halfWidth, halfHeight}

	PaintTexture(sourceTopLeft, {rect.x, rect.y, sourceTopLeft.w, sourceTopLeft.h}, color)
	PaintTexture(sourceTopRight, {rect.x + rect.w - halfWidth, rect.y, sourceTopRight.w, sourceTopRight.h}, color)
	PaintTexture(sourceBottomRight, {rect.x + rect.w - halfWidth, rect.y + rect.h - halfHeight, sourceBottomRight.w, sourceBottomRight.h}, color)
	PaintTexture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfHeight, sourceBottomLeft.w, sourceBottomLeft.h}, color)

	if rect.w > radius * 2 {
		PaintRect({rect.x + radius, rect.y, rect.w - radius * 2, thickness}, color)
		PaintRect({rect.x + radius, rect.y + rect.h - thickness, rect.w - radius * 2, thickness}, color)
	}
	if rect.h > radius * 2 {
		PaintRect({rect.x, rect.y + radius, thickness, rect.h - radius * 2}, color)
		PaintRect({rect.x + rect.w - thickness, rect.y + radius, thickness, rect.h - radius * 2}, color)
	}
}
PaintRoundedRectOutlineEx :: proc(rect: Rect, radius: f32, thin: bool, corners: RectCorners, color: Color) {
	if !ctx.shouldRender {
		return
	}

	thickness: f32 = 1 if thin else 2
	if radius == 0 || corners == {} {
		PaintRectLines(rect, thickness, color)
		return
	}

	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if color.a == 0 || index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index + (CIRCLE_SIZES if thin else (CIRCLE_SIZES * 2))].source
	halfSize := math.trunc(source.w / 2)

	halfWidth := min(halfSize, rect.w / 2)
	halfHeight := min(halfSize, rect.h / 2)

	if .topLeft in corners {
		sourceTopLeft: Rect = {source.x, source.y, halfWidth, halfHeight}
		PaintTexture(sourceTopLeft, {rect.x, rect.y, halfSize, halfSize}, color)
	}
	if .topRight in corners {
		sourceTopRight: Rect = {source.x + source.w - halfWidth, source.y, halfWidth, halfHeight}
		PaintTexture(sourceTopRight, {rect.x + rect.w - halfWidth, rect.y, halfSize, halfSize}, color)
	}
	if .bottomRight in corners {
		sourceBottomRight: Rect = {source.x + source.w - halfWidth, source.y + source.h - halfHeight, halfWidth, halfHeight}
		PaintTexture(sourceBottomRight, {rect.x + rect.w - halfSize, rect.y + rect.h - halfSize, halfSize, halfSize}, color)
	}
	if .bottomLeft in corners {
		sourceBottomLeft: Rect = {source.x, source.y + source.h - halfHeight, halfWidth, halfHeight}
		PaintTexture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfHeight, halfSize, halfSize}, color)
	}

	if rect.w > radius * 2 {
		topLeft := radius if .topLeft in corners else 0
		topRight := radius if .topRight in corners else 0
		bottomRight := radius if .bottomRight in corners else 0
		bottomLeft := radius if .bottomLeft in corners else 0
		PaintRect({rect.x + topLeft, rect.y, rect.w - (topLeft + topRight), thickness}, color)
		PaintRect({rect.x + bottomLeft, rect.y + rect.h - thickness, rect.w - (bottomLeft + bottomRight), thickness}, color)
	}
	if rect.h > radius * 2 {
		topLeft := radius if .topLeft in corners else 0
		topRight := radius if .topRight in corners else 0
		bottomRight := radius if .bottomRight in corners else 0
		bottomLeft := radius if .bottomLeft in corners else 0
		PaintRect({rect.x, rect.y + topLeft, thickness, rect.h - (topLeft + bottomLeft)}, color)
		PaintRect({rect.x + rect.w - thickness, rect.y + topRight, thickness, rect.h - (topRight + bottomRight)}, color)
	}
}
PaintCollapseArrow :: proc(center: Vec2, size, time: f32, color: Color) {
	if !ctx.shouldRender {
		return
	}

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
DrawIcon :: proc(icon: IconIndex, origin: Vec2, color: Color) {
	if !ctx.shouldRender {
		return
	}

	DrawIconEx(icon, origin, 1, .near, .near, color)
}
DrawIconEx :: proc(icon: IconIndex, origin: Vec2, scale: f32, alignX, alignY: Alignment, color: Color) {
	if !ctx.shouldRender {
		return
	}

	return
}

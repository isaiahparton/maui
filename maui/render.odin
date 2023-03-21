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

PatchIndex :: enum {
	widgetFill,
	widgetStroke,
	widgetStrokeThin,
	panelFill,
}
PatchData :: struct {
	source: Rect,
	amount: i32,
}

Painter :: struct {
	patches: [PatchIndex]PatchData,
	fonts: [FontIndex]FontData,
}
@static painter :: ^Painter

/*
	Font and patch loading/usage
	uses raylib to load fonts
*/
GLYPH_SPACING :: 1
GlyphData :: struct {
	source: Rect,
	offset: Vector,
	advance: f32,
}

FontData :: struct {
	size: f32,
	imageData: rawptr,
	imageWidth, imageHeight: i32,
	glyphs: []GlyphData,
	glyphMap: map[rune]i32,
}

LoadPatch :: proc(index: PatchIndex, amount: i32) {

}
LoadResources :: proc(using painter: ^Painter) {
	LoadPatch(.panelFill, 12)
	LoadPatch(.widgetFill, 6)
	LoadPatch(.widgetStroke, 6)
	LoadPatch(.widgetStrokeThin, 6)

	atlasHeight := i32(0)
	for data, index in FONT_LOAD_DATA {
		font, success := LoadFont(StringFormat("fonts/%s", data.file), data.size, 0)
		if !success {
			fmt.printf("Failed to load font %v\n", index)
			continue
		}
		fonts[index] = font
		atlasHeight = max(atlasHeight, font.imageHeight)
	}
}

LoadFont :: proc(path: string, size, glyphCount: i32) -> (font: FontData, success: bool) {
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
            atlas := rl.GenImageFontAtlas(glyphInfo, &rects, glyphCount, size, glyphPadding, 0);

            font.glyphs = make([]GlyphData, glyphCount)
            for index in 0..<glyphCount {
            	font.glyphMap[glyphInfo[index].value] = index
            	font.glyphs[index] = {
            		source = transmute(Rect)rects[index],
            		offset = {f32(glyphInfo[index].offsetX), f32(glyphInfo[index].offsetY)},
            		advance = f32(glyphInfo[index].advanceX),
            	}
            }

            font.size = f32(size)
            font.imageData = atlas.data
            font.imageWidth = atlas.width
            font.imageHeight = atlas.height
        }
        rl.UnloadFontData(glyphInfo, glyphCount)
        success = true
    }
    return
}
GetGlyphData :: proc(font: FontData, codepoint: rune) -> GlyphData {
	index, ok := font.glyphMap[codepoint]
	if !ok || i32(len(font.glyphs)) <= index {
		return {}
	}
	return font.glyphs[index]
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
	points: [3]Vector,
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
DrawQuad :: proc(p1, p2, p3, p4: Vector, c: Color) {
	DrawTriangle(p1, p2, p4, c)
	DrawTriangle(p4, p2, p3, c)
}
DrawTriangle :: proc(p1, p2, p3: Vector, c: Color) {
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
DrawTriangleStrip :: proc(points: []Vector, color: Color) {
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
DrawLine :: proc(start, end: Vector, thickness: f32, color: Color) {
	delta := end - start
    length := math.sqrt(f32(delta.x * delta.x + delta.y * delta.y))
    if length > 0 && thickness > 0 {
        scale := thickness / (2 * length)
        radius := Vector{ -scale * delta.y, scale * delta.x }
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
DrawCircle :: proc(center: Vector, radius: f32, segments: i32, color: Color) {
	DrawCircleSector(center, radius, 0, math.TAU, segments, color)
}
DrawCircleSector :: proc(center: Vector, radius, start, end: f32, segments: i32, color: Color) {
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
DrawRing :: proc(center: Vector, inner, outer: f32, segments: i32, color: Color) {
	DrawRingSector(center, inner, outer, 0, math.TAU, segments, color)
}
DrawRingSector :: proc(center: Vector, inner, outer, start, end: f32, segments: i32, color: Color) {
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
MeasureString :: proc(font: FontData, text: string) -> Vector {
	size := Vector{}
	for codepoint in text {
		glyph := GetGlyphData(font, codepoint)
		size.x += glyph.advance
	}
	size.y = font.size
	return size
}
DrawString :: proc(font: FontData, text: string, origin: Vector, color: Color) {
	origin := origin
	for codepoint in text {
		glyph := GetGlyphData(ctx.font, codepoint)
		DrawTexture(.font, glyph.source, {origin.x + glyph.offset.x, origin.y + glyph.offset.y, glyph.source.w, glyph.source.h}, color)
		origin.x += glyph.advance
	}
}
DrawAlignedString :: proc(font: FontData, text: string, origin: Vector, color: Color, alignX, alignY: Alignment) {
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
DrawClippedGlyph :: proc(glyph: GlyphData, origin: Vector, clipRect: Rect, color: Color) {
	
}
*/

/*
	Icons in the order they appear on the atlas (left to right, descending)
*/
IconIndex :: enum {
	none = -1,
	plus,
	archive,
	down,
	undo,
	redo,
	left,
	right,
	up,
	chart,
	calendar,
	check,
	close,
	delete,
	download,
	eyeWithLine,
	eye,
	file,
	flder,
	heart,
	history,
	home,
	keyboard,
	list,
	menu,
	palette,
	edit,
	pieChart,
	pin,
	search,
	cog,
	basket,
	star,
	minus,
	upload,
}
ICON_SIZE :: 24
DrawIcon :: proc(icon: IconIndex, origin: Vector, color: Color) {
	DrawIconEx(icon, origin, 1, .near, .near, color)
}
DrawIconEx :: proc(icon: IconIndex, origin: Vector, scale: f32, alignX, alignY: Alignment, color: Color) {
	offset := Vector{}
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
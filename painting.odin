package maui
// Core dependencies
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:runtime"
import "core:path/filepath"
import "core:unicode"
import "core:unicode/utf8"
// For image/font processing
import rl "vendor:raylib"

// Path to resources folder
RESOURCES_PATH :: #config(MAUI_RESOURCES_PATH, ".")
// Main texture size
TEXTURE_WIDTH :: 4096
TEXTURE_HEIGHT :: 256
// Triangle helper
TRIANGLE_STEP :: math.TAU / 3
// What sizes of circles to pre-render
MIN_CIRCLE_SIZE :: 2
MAX_CIRCLE_SIZE :: 60
MAX_CIRCLE_STROKE_SIZE :: 2
CIRCLE_SIZES :: MAX_CIRCLE_SIZE - MIN_CIRCLE_SIZE
CIRCLE_ROWS :: MAX_CIRCLE_STROKE_SIZE + 1
// Smoothing level for pre-rasterized circles
CIRCLE_SMOOTHING :: 1
// Font class files
MONOSPACE_FONT :: "Inconsolata_Condensed-SemiBold.ttf"
DEFAULT_FONT :: "IBMPlexSans-Medium_Remixicon.ttf"
// Default horizontal spacing between glyphs
GLYPH_SPACING :: 1

Pixel_Format 	:: rl.PixelFormat
Image 			:: rl.Image

// Builtin text styles
Font_Index :: enum {
	default,
	header,
	monospace,
	label,
}
Font_Data :: struct {
	size: f32,
	image: rl.Image,
	glyphs: []GlyphData,
	glyph_map: map[rune]i32,
}
Glyph_Data :: struct {
	source: Box,
	offset: [2]f32,
	advance: f32,
}
Patch_Data :: struct {
	source: Box,
	amount: i32,
}

// Context for painting graphics stuff
Painter :: struct {
	circles: 		[CIRCLE_SIZES * CIRCLE_ROWS]Patch_Data,
	fonts: 			[Font_Index]Font_Data,
	// Style
	style: 			Style,
	// Texture atlas source
	image: 			Image,
}
// Global instance pointer
painter: ^Painter

painter_init :: proc() -> bool {
	if painter == nil {
		painter = new(Painter)
		// Default style
		painter.style.colors = DEFAULT_COLORS_LIGHT
		painter.style.fontSizes = {
			.label = 16,
			.default = 18,
			.header = 28,
			.monospace = 18,
		}
		return painter_gen_atlas(painter)
	}
	return false
}
painter_uninit :: proc() {
	if painter != nil {
		rl.UnloadImage(painter.image)

		for font in &painter.fonts {
			delete(font.glyphs)
			delete(font.glyph_map)
		}

		free(painter)
	}
}

// Color manip
normalize_color :: proc(color: Color) -> [4]f32 {
    return {f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255}
}
set_color_brightness :: proc(color: Color, value: f32) -> Color {
	delta := clamp(i32(255.0 * value), -255, 255)
	return {
		cast(u8)clamp(i32(color.r) + delta, 0, 255),
		cast(u8)clamp(i32(color.g) + delta, 0, 255),
		cast(u8)clamp(i32(color.b) + delta, 0, 255),
		color.a,
	}
}
color_to_hsv :: proc(color: Color) -> Vec4 {
	hsva := linalg.vector4_rgb_to_hsl(linalg.Vector4f32{f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0})
	return hsva.xyzw
}
color_from_hsv :: proc(hue, saturation, value: f32) -> Color {
    rgba := linalg.vector4_hsl_to_rgb(hue, saturation, value, 1.0)
    return {u8(rgba.r * 255.0), u8(rgba.g * 255.0), u8(rgba.b * 255.0), u8(rgba.a * 255.0)}
}
fade :: proc(color: Color, alpha: f32) -> Color {
	return {color.r, color.g, color.b, u8(f32(color.a) * alpha)}
}
blend_colors :: proc(bg, fg: Color, amount: f32) -> (result: Color) {
	if amount <= 0 {
		result = bg
	} else if amount >= 1 {
		result = fg
	} else {
		result = bg + {
			u8((f32(fg.r) - f32(bg.r)) * amount),
			u8((f32(fg.g) - f32(bg.g)) * amount),
			u8((f32(fg.b) - f32(bg.b)) * amount),
			u8((f32(fg.a) - f32(bg.a)) * amount),
		}
	}
	return
}
alpha_blend_colors :: proc(bg, fg: Color, amount: f32) -> (result: Color) {
	return transmute(Color)rl.ColorAlphaBlend(transmute(rl.Color)bg, transmute(rl.Color)fg, rl.Fade(rl.WHITE, amount))
}

image_paint_smooth_circle :: proc(image: ^rl.Image, center: [2]f32, radius, smooth: f32) {
	size := radius * 2
	topLeft := center - radius

	for x in i32(topLeft.x) ..= i32(topLeft.x + size) {
		for y in i32(topLeft.y) ..= i32(topLeft.y + size) {
			point := [2]f32{f32(x), f32(y)}
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
image_paint_smooth_ring :: proc(image: ^rl.Image, center: [2]f32, inner, outer, smooth: f32) {
	size := outer * 2
	topLeft := center - outer

	for x in i32(topLeft.x) ..= i32(topLeft.x + size) {
		for y in i32(topLeft.y) ..= i32(topLeft.y + size) {
			point := [2]f32{f32(x), f32(y)}
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
painter_gen_circles :: proc(painter: ^Painter, origin: [2]f32) -> [2]f32 {

	// Spacing is needed to prevent artifacts with texture filtering
	SPACING :: 1

	// The number of stroke sizes plus one for filled
	rows := MAX_CIRCLE_STROKE_SIZE + 1

	// Starting offset
	offset: [2]f32 = {SPACING, SPACING}

	// Keep track of the total row size
	max_size :f32= 0
	for row_index in 0 ..< rows {
		offset.x = 0
		for size_index in 0 ..< CIRCLE_SIZES {
			size := f32(MIN_CIRCLE_SIZE + size_index)
			radius := size / 2
			
			total_size := size + CIRCLE_SMOOTHING * 2
			rect :Box= {origin.x + offset.x, origin.y + offset.y, size + 1, size + 1}

			painter.circles[size_index + row_index * CIRCLE_SIZES] = {
				source = rect,
				amount = i32(radius),
			}

			if row_index == 0 {
				// First row is filled
				GenSmoothCircle(&painter.image, {rect.x + radius, rect.y + radius}, radius, CIRCLE_SMOOTHING)
			} else {
				GenSmoothRing(&painter.image, {rect.x + radius, rect.y + radius}, radius - f32(row_index), radius, CIRCLE_SMOOTHING)
			}

			// Space taken by this circle
			space := total_size + SPACING
			offset.x += space
			max_size = max(max_size, space)
		}
		offset.y += max_size
	}
	return offset
}
make_font :: proc(origin: [2]f32, path: string, size: i32, codepoints: []rune) -> (font: Font_Data, success: bool) {
	// Character set
	rawArray := transmute(runtime.Raw_Slice)codepoints
	// Get the file extension
	extension := filepath.ext(path)
    if extension == ".ttf" || extension == ".otf" {
    	if fileData, ok := os.read_entire_file(path); ok {
    		defer delete(fileData)
	        glyph_count := i32(len(codepoints))
	        glyph_padding := i32(1)
	        glyph_info := rl.LoadFontData((transmute(runtime.Raw_Slice)fileData).data, i32(len(fileData)), size, transmute([^]rune)(rawArray.data), glyph_count, .DEFAULT)

	        if glyph_info != nil {
	        	font.size = f32(size)
	        	// Temporary array
	        	rects: [^]rl.Boxangle
	            // Create FontData from raylib font
	            font.image = rl.GenImageFontAtlas(glyph_info, &rects, glyph_count, size, glyph_padding, 1);
	            font.glyphs = make([]GlyphData, glyph_count)
	            for index in 0 ..< glyph_count {
	            	rect := rects[index]
	            	codepoint := glyph_info[index].value
	            	if codepoint > unicode.MAX_LATIN1 {
	            		glyph_info[index].offsetY = i32(font.size / 2 - rect.height / 2)
	            	}
	            	font.glyphs[index] = {
	            		source = {origin.x + rect.x, origin.y + rect.y, rect.width, rect.height},
	            		offset = {f32(glyph_info[index].offsetX), f32(glyph_info[index].offsetY)},
	            		advance = f32(glyph_info[index].advanceX),
	            	}
	            	font.glyph_map[codepoint] = index
	            }
	            // Free rectangles
	            free(rawptr(rects))
	        }
	        rl.UnloadFontData(glyph_info, glyph_count)
	        success = true
    	}
    }
    return
}
painter_make_atlas :: proc(using painter: ^Painter) -> (result: bool) {
	defaultCodepoints: []rune = {32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 0x2022}
	codepoints := make([]rune, len(defaultCodepoints) + len(Icon))
	defer delete(codepoints)

	copy(codepoints[:], defaultCodepoints[:len(defaultCodepoints)])
	for icon, index in Icon {
		codepoints[len(defaultCodepoints) + index] = rune(icon)
	}
	firstIconIndex: int
	for codepoint, index in codepoints {
		if codepoint > unicode.MAX_LATIN1 {
			firstIconIndex = index
			break
		}
	}

	// Create the image
	image = rl.GenImageColor(TEXTURE_WIDTH, TEXTURE_HEIGHT, {})
	image.format = .UNCOMPRESSED_GRAY_ALPHA
	// Solid white at texture origin for 'untextured' stuff
	rl.ImageDrawPixel(&image, 0, 0, rl.WHITE)
	// Draw some pre-smoothed circles and rings of different sizes
	circleSpace := GenCircles(painter, {1, 0})

	offset: f32 = 0
	for index in FontIndex {
		file := MONOSPACE_FONT if index == .monospace else DEFAULT_FONT
		font, success := GenFont({circleSpace.x + offset, 0}, TextFormat("%s/fonts/%s", RESOURCES_PATH, file), i32(style.fontSizes[index]), codepoints[:firstIconIndex] if index == .monospace else codepoints)
		if !success {
			fmt.printf("Failed to load font %v\n", index)
			result = false
			continue
		}
		fonts[index] = font
		offset += f32(font.image.width)
	}

	offset = 0
	for font in fonts {
		rl.ImageDraw(&image, font.image, {0, 0, f32(font.image.width), f32(font.image.height)}, {circleSpace.x + offset, 0, f32(font.image.width), f32(font.image.height)}, rl.WHITE)
		offset += f32(font.image.width)
		rl.UnloadImage(font.image)
	}

	result = true
	return
}
get_glyph_data :: proc(font: ^FontData, codepoint: rune) -> GlyphData {
	index, ok := font.glyph_map[codepoint]
	if ok {
		return font.glyphs[index]
	}
	return {}
}
get_font_data :: proc(index: FontIndex) -> ^FontData {
	return &painter.fonts[index]
}

// Draw commands
Command_Texture :: struct {
	using command: Command,
	uv_min, 
	uv_max,
	min, 
	max: [2]f32,
	color: Color,
}
Command_Triangle :: struct {
	using command: Command,
	vertices: [3][2]f32,
	color: Color,
}
Command_Clip :: struct {
	using command: Command,
	rect: Box,
}
Command_Variant :: union {
	^Command_Texture,
	^Command_Triangle,
	^Command_Clip,
}
Command :: struct {
	variant: Command_Variant,
	size: u8,
}
// Push a command to a given layer
push_command :: proc(layer: ^Layer, $Type: typeid, extra_size := 0) -> ^Type {
	size := size_of(Type) + extra_size
	cmd := transmute(^Type)&layer.commands[layer.commandOffset]
	assert(layer.commandOffset + size < COMMAND_BUFFER_SIZE, "push_command() Insufficient space in command buffer!")
	layer.commandOffset += size
	cmd.variant = cmd
	cmd.size = u8(size)
	return cmd
}
// Get the next draw command
next_command :: proc(pcmd: ^^Command) -> bool {
	// Loop through layers
	if core.hotLayer >= len(core.layers) {
		return false
	}
	layer := core.layers[core.hotLayer]

	cmd := pcmd^
	defer pcmd^ = cmd
	if cmd != nil { 
		cmd = (^Command)(uintptr(cmd) + uintptr(cmd.size)) 
	} else {
		cmd = (^Command)(&layer.commands[0])
	}

	clip, ok := cmd.variant.(^CommandClip)
	if ok {
		if clip.rect == core.clipBox {
			return next_command(&cmd)
		} else {
			core.clipBox = clip.rect
		}
	}
	if cmd == (^Command)(&layer.commands[layer.commandOffset]) || cmd.size == 0 {
		// At end of command buffer so reset `cmd` and go to next layer
		core.hotLayer += 1
		cmd = nil
		return next_command(&cmd)
	}
	return true
}
next_command_iterator :: proc(pcm: ^^Command) -> (CommandVariant, bool) {
	if next_command(pcm) {
		return pcm^.variant, true
	}
	return nil, false
}

// Painting procs
begin_clip :: proc(rect: Box) {
	if core.paintThisFrame {
		core.clipBox = rect
		cmd := push_command(current_layer(), CommandClip)
		cmd.rect = rect
	}
}
end_clip :: proc() {
	if core.paintThisFrame {
		core.clipBox = core.fullscreenBox
		cmd := push_command(current_layer(), CommandClip)
		cmd.rect = core.clipBox
	}
}
paint_quad_fill :: proc(p1, p2, p3, p4: [2]f32, c: Color) {
	paint_triangle_fill(p1, p2, p4, c)
	paint_triangle_fill(p4, p2, p3, c)
}
paint_triangle_fill :: proc(p1, p2, p3: [2]f32, color: Color) {
	layer := current_layer()
	cmd := push_command(layer, CommandTriangle)
	cmd.color = Color{color.r, color.g, color.b, u8(f32(color.a) * layer.opacity)}
	cmd.vertices = {p1, p2, p3}
}
paint_box_fill :: proc(rect: Box, color: Color) {
	paint_quad_fill(
		{f32(rect.x), f32(rect.y)},
		{f32(rect.x), f32(rect.y + rect.h)},
		{f32(rect.x + rect.w), f32(rect.y + rect.h)},
		{f32(rect.x + rect.w), f32(rect.y)},
		color,
	)
}
paint_triangle_strip_fill :: proc(points: [][2]f32, color: Color) {
    if len(points) < 4 {
    	return
    }
    for i in 2 ..< len(points) {
        if i % 2 == 0 {
            paint_triangle_fill(
            	{points[i].x, points[i].y},
            	{points[i - 2].x, points[i - 2].y},
            	{points[i - 1].x, points[i - 1].y},
            	color,
            )
        } else {
        	paint_triangle_fill(
           	 	{points[i].x, points[i].y},
            	{points[i - 1].x, points[i - 1].y},
            	{points[i - 2].x, points[i - 2].y},
            	color,
            )
        }
    }
}
paint_line :: proc(start, end: [2]f32, thickness: f32, color: Color) {
	delta := end - start
    length := math.sqrt(f32(delta.x * delta.x + delta.y * delta.y))
    if length > 0 && thickness > 0 {
        scale := thickness / (2 * length)
        radius := [2]f32{ -scale * delta.y, scale * delta.x }
        paint_triangle_strip_fill({
            { start.x - radius.x, start.y - radius.y },
            { start.x + radius.x, start.y + radius.y },
            { end.x - radius.x, end.y - radius.y },
            { end.x + radius.x, end.y + radius.y },
        }, color)
    }
}
paint_box_stroke :: proc(rect: Box, thickness: f32, color: Color) {
	paint_box_fill({rect.x + thickness, rect.y, rect.w - thickness * 2, thickness}, color)
	paint_box_fill({rect.x + thickness, rect.y + rect.h - thickness, rect.w - thickness * 2, thickness}, color)
	paint_box_fill({rect.x, rect.y, thickness, rect.h}, color)
	paint_box_fill({rect.x + rect.w - thickness, rect.y, thickness, rect.h}, color)	
}
paint_widget_frame :: proc(rect: Box, gapOffset, gapWidth, thickness: f32, color: Color) {
	paint_box_fill({rect.x, rect.y, gapOffset, thickness}, color)
	paint_box_fill({rect.x + gapOffset + gapWidth, rect.y, rect.w - gapWidth - gapOffset, thickness}, color)
	paint_box_fill({rect.x, rect.y + rect.h - thickness, rect.w, thickness}, color)
	paint_box_fill({rect.x, rect.y, thickness, rect.h}, color)
	paint_box_fill({rect.x + rect.w - thickness, rect.y, thickness, rect.h}, color)
}
paint_circle_fill :: proc(center: [2]f32, radius: f32, segments: i32, color: Color) {
	paint_circle_sector_fill(center, radius, 0, math.TAU, segments, color)
}
paint_circle_sector_fill :: proc(center: [2]f32, radius, start, end: f32, segments: i32, color: Color) {
	step := (end - start) / f32(segments)
	angle := start
	for i in 0..<segments {
        paint_triangle_fill(
        	center, 
        	center + {math.cos(angle + step) * radius, math.sin(angle + step) * radius}, 
        	center + {math.cos(angle) * radius, math.sin(angle) * radius}, 
        	color,
    	)
        angle += step;
    }
}
paint_ring_fill :: proc(center: [2]f32, inner, outer: f32, segments: i32, color: Color) {
	paint_ring_sector_fill(center, inner, outer, 0, math.TAU, segments, color)
}
paint_ring_sector_fill :: proc(center: [2]f32, inner, outer, start, end: f32, segments: i32, color: Color) {
	step := (end - start) / f32(segments)
	angle := start
	for i in 0..<segments {
        paint_quad_fill(
        	center + {math.cos(angle) * outer, math.sin(angle) * outer},
        	center + {math.cos(angle) * inner, math.sin(angle) * inner},
        	center + {math.cos(angle + step) * inner, math.sin(angle + step) * inner},
        	center + {math.cos(angle + step) * outer, math.sin(angle + step) * outer},
        	color,
    	)
        angle += step;
    }
}
paint_box_sweep :: proc(r: Box, t: f32, c: Color) {
	if t >= 1 {
		paint_box_fill(r, c)
		return
	}
	a := (r.w + r.h) * t - r.h
	paint_box_fill({r.x, r.y, a, r.h}, c)
	PaintQuad(
		{r.x + max(a, 0), r.y}, 
		{r.x + max(a, 0), r.y + clamp(a + r.h, 0, r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y + max(0, a - r.w + r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y}, 
		c,
	)
}
paint_texture :: proc(src, dst: Box, color: Color) {
	layer := CurrentLayer()
	cmd := push_command(layer, CommandTexture)
	cmd.uvMin = {src.x / TEXTURE_WIDTH, src.y / TEXTURE_HEIGHT}
	cmd.uvMax = {(src.x + src.w) / TEXTURE_WIDTH, (src.y + src.h) / TEXTURE_HEIGHT}
	cmd.min = {dst.x, dst.y}
	cmd.max = {dst.x + dst.w, dst.y + dst.h}
	cmd.color = Color{color.r, color.g, color.b, u8(f32(color.a) * layer.opacity)}
}
paint_circle_fill_texture :: proc(center: [2]f32, size: f32, color: Color) {
	index := int(size) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := grow_box(painter.circles[index].source, 1)
	paint_texture(source, {center.x - math.floor(source.w / 2), center.y - math.floor(source.h / 2), source.w, source.h}, color)
}
paint_circle_stroke_texture :: proc(center: [2]f32, size: f32, thin: bool, color: Color) {
	index := CIRCLE_SIZES + int(size) - MIN_CIRCLE_SIZE
	if !thin {
		index += CIRCLE_SIZES
	}
	if index < 0 {
		return
	}
	source := grow_box(painter.circles[index].source, 1)
	paint_texture(source, {center.x - math.floor(source.w / 2), center.y - math.floor(source.h / 2), source.w, source.h}, color)
}

paint_pill_fill_h :: proc(rect: Box, color: Color) {
	radius := math.floor(rect.h / 2)

	if rect.w == 0 || rect.h == 0 {
		return
	}
	index := int(rect.h) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index].source
	halfSize := math.trunc(source.w / 2)

	halfWidth := min(halfSize, rect.w / 2)

	sourceLeft: Box = {source.x, source.y, halfWidth, source.h}
	sourceRight: Box = {source.x + source.w - halfWidth, source.y, halfWidth, source.h}

	paint_texture(sourceLeft, {rect.x, rect.y, halfWidth, rect.h}, color)
	paint_texture(sourceRight, {rect.x + rect.w - halfWidth, rect.y, halfWidth, rect.h}, color)

	if rect.w > rect.h {
		paint_box_fill({rect.x + radius, rect.y, rect.w - radius * 2, rect.h}, color)
	}
}
paint_pill_stroke_h :: proc(rect: Box, thin: bool, color: Color) {
	thickness: f32 = 1 if thin else 2
	radius := math.floor(rect.h / 2)

	if rect.w == 0 || rect.h == 0 {
		return
	}
	index := int(rect.h) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	source := painter.circles[index + (CIRCLE_SIZES if thin else (CIRCLE_SIZES * 2))].source
	halfSize := math.trunc(source.w / 2)

	halfWidth := min(halfSize, rect.w / 2)

	sourceLeft: Box = {source.x, source.y, halfWidth, source.h}
	sourceRight: Box = {source.x + source.w - halfWidth, source.y, halfWidth, source.h}

	paint_texture(sourceLeft, {rect.x, rect.y, halfWidth, rect.h}, color)
	paint_texture(sourceRight, {rect.x + rect.w - halfWidth, rect.y, halfWidth, rect.h}, color)

	if rect.w > rect.h {
		paint_box_fill({rect.x + radius, rect.y, rect.w - radius * 2, thickness}, color)
		paint_box_fill({rect.x + radius, rect.y + rect.h - thickness, rect.w - radius * 2, thickness}, color)
	}
}

paint_rounded_box_corners_fill :: proc(rect: Box, radius: f32, corners: BoxCorners, color: Color) {
	if rect.h == 0 || rect.w == 0 {
		return
	}
	if radius == 0 || corners == {} {
		paint_box_fill(rect, color)
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
		sourceTopLeft: Box = {source.x, source.y, halfWidth, halfHeight}
		paint_texture(sourceTopLeft, {rect.x, rect.y, halfSize, halfSize}, color)
	}
	if .topRight in corners {
		sourceTopRight: Box = {source.x + source.w - halfWidth, source.y, halfWidth, halfHeight}
		paint_texture(sourceTopRight, {rect.x + rect.w - halfWidth, rect.y, halfSize, halfSize}, color)
	}
	if .bottomRight in corners {
		sourceBottomRight: Box = {source.x + source.w - halfWidth, source.y + source.h - halfHeight, halfWidth, halfHeight}
		paint_texture(sourceBottomRight, {rect.x + rect.w - halfSize, rect.y + rect.h - halfSize, halfSize, halfSize}, color)
	}
	if .bottomLeft in corners {
		sourceBottomLeft: Box = {source.x, source.y + source.h - halfHeight, halfWidth, halfHeight}
		paint_texture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfHeight, halfSize, halfSize}, color)
	}

	if rect.w > radius * 2 {
		paint_box_fill({rect.x + radius, rect.y, rect.w - radius * 2, rect.h}, color)
	}
	if rect.h > radius * 2 {
		topLeft := radius if .topLeft in corners else 0
		topRight := radius if .topRight in corners else 0
		bottomRight := radius if .bottomRight in corners else 0
		bottomLeft := radius if .bottomLeft in corners else 0
		paint_box_fill({rect.x, rect.y + topLeft, radius, rect.h - (topLeft + bottomLeft)}, color)
		paint_box_fill({rect.x + rect.w - radius, rect.y + topRight, radius, rect.h - (topRight + bottomRight)}, color)
	}
}
paint_rounded_box_fill :: proc(rect: Box, radius: f32, color: Color) {
	if radius == 0 {
		paint_box_fill(rect, color)
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

	sourceTopLeft: Box = {source.x, source.y, halfWidth, halfHeight}
	sourceTopRight: Box = {source.x + source.w - halfWidth, source.y, halfWidth, halfHeight}
	sourceBottomRight: Box = {source.x + source.w - halfWidth, source.y + source.h - halfHeight, halfWidth, halfHeight}
	sourceBottomLeft: Box = {source.x, source.y + source.h - halfHeight, halfWidth, halfHeight}

	paint_texture(sourceTopLeft, {rect.x, rect.y, halfWidth, halfHeight}, color)
	paint_texture(sourceTopRight, {rect.x + rect.w - halfWidth, rect.y, halfWidth, halfHeight}, color)
	paint_texture(sourceBottomRight, {rect.x + rect.w - halfWidth, rect.y + rect.h - halfHeight, halfWidth, halfHeight}, color)
	paint_texture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfHeight, halfWidth, halfHeight}, color)

	if rect.w > radius * 2 {
		paint_box_fill({rect.x + radius, rect.y, rect.w - radius * 2, rect.h}, color)
	}
	if rect.h > radius * 2 {
		halfWidth := min(radius, rect.w / 2)
		paint_box_fill({rect.x, rect.y + radius, halfWidth, rect.h - radius * 2}, color)
		paint_box_fill({rect.x + rect.w - halfWidth, rect.y + radius, halfWidth, rect.h - radius * 2}, color)
	}
}

paint_rounded_box_stroke :: proc(rect: Box, radius: f32, thin: bool, color: Color) {
	thickness: f32 = 1 if thin else 2
	if radius == 0 {
		paint_box_fillLines(rect, thickness, color)
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

	sourceTopLeft: Box = {source.x, source.y, halfWidth, halfHeight}
	sourceTopRight: Box = {source.x + source.w - halfWidth, source.y, halfWidth, halfHeight}
	sourceBottomRight: Box = {source.x + source.w - halfWidth, source.y + source.h - halfHeight, halfWidth, halfHeight}
	sourceBottomLeft: Box = {source.x, source.y + source.h - halfHeight, halfWidth, halfHeight}

	paint_texture(sourceTopLeft, {rect.x, rect.y, sourceTopLeft.w, sourceTopLeft.h}, color)
	paint_texture(sourceTopRight, {rect.x + rect.w - halfWidth, rect.y, sourceTopRight.w, sourceTopRight.h}, color)
	paint_texture(sourceBottomRight, {rect.x + rect.w - halfWidth, rect.y + rect.h - halfHeight, sourceBottomRight.w, sourceBottomRight.h}, color)
	paint_texture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfHeight, sourceBottomLeft.w, sourceBottomLeft.h}, color)

	if rect.w > radius * 2 {
		paint_box_fill({rect.x + radius, rect.y, rect.w - radius * 2, thickness}, color)
		paint_box_fill({rect.x + radius, rect.y + rect.h - thickness, rect.w - radius * 2, thickness}, color)
	}
	if rect.h > radius * 2 {
		paint_box_fill({rect.x, rect.y + radius, thickness, rect.h - radius * 2}, color)
		paint_box_fill({rect.x + rect.w - thickness, rect.y + radius, thickness, rect.h - radius * 2}, color)
	}
}
paint_rounded_box_corners_stroke :: proc(rect: Box, radius: f32, thin: bool, corners: BoxCorners, color: Color) {
	thickness: f32 = 1 if thin else 2
	if radius == 0 || corners == {} {
		paint_box_fillLines(rect, thickness, color)
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
		sourceTopLeft: Box = {source.x, source.y, halfWidth, halfHeight}
		paint_texture(sourceTopLeft, {rect.x, rect.y, halfSize, halfSize}, color)
	}
	if .topRight in corners {
		sourceTopRight: Box = {source.x + source.w - halfWidth, source.y, halfWidth, halfHeight}
		paint_texture(sourceTopRight, {rect.x + rect.w - halfWidth, rect.y, halfSize, halfSize}, color)
	}
	if .bottomRight in corners {
		sourceBottomRight: Box = {source.x + source.w - halfWidth, source.y + source.h - halfHeight, halfWidth, halfHeight}
		paint_texture(sourceBottomRight, {rect.x + rect.w - halfSize, rect.y + rect.h - halfSize, halfSize, halfSize}, color)
	}
	if .bottomLeft in corners {
		sourceBottomLeft: Box = {source.x, source.y + source.h - halfHeight, halfWidth, halfHeight}
		paint_texture(sourceBottomLeft, {rect.x, rect.y + rect.h - halfHeight, halfSize, halfSize}, color)
	}

	if rect.w > radius * 2 {
		topLeft := radius if .topLeft in corners else 0
		topRight := radius if .topRight in corners else 0
		bottomRight := radius if .bottomRight in corners else 0
		bottomLeft := radius if .bottomLeft in corners else 0
		paint_box_fill({rect.x + topLeft, rect.y, rect.w - (topLeft + topRight), thickness}, color)
		paint_box_fill({rect.x + bottomLeft, rect.y + rect.h - thickness, rect.w - (bottomLeft + bottomRight), thickness}, color)
	}
	if rect.h > radius * 2 {
		topLeft := radius if .topLeft in corners else 0
		topRight := radius if .topRight in corners else 0
		bottomRight := radius if .bottomRight in corners else 0
		bottomLeft := radius if .bottomLeft in corners else 0
		paint_box_fill({rect.x, rect.y + topLeft, thickness, rect.h - (topLeft + bottomLeft)}, color)
		paint_box_fill({rect.x + rect.w - thickness, rect.y + topRight, thickness, rect.h - (topRight + bottomRight)}, color)
	}
}

paint_rotating_arrow :: proc(center: [2]f32, size, time: f32, color: Color) {
	angle := (1 - time) * math.PI * 0.5
	norm: [2]f32 = {math.cos(angle), math.sin(angle)}
	paint_triangle_fill(
		center + {math.cos(angle - TRIANGLE_STEP), math.sin(angle - TRIANGLE_STEP)} * size,
		center + {math.cos(angle + TRIANGLE_STEP), math.sin(angle + TRIANGLE_STEP)} * size,
		center + {math.cos(angle), math.sin(angle)} * size, 
		color,
		)
}
paint_flipping_arrow :: proc(center: [2]f32, size, time: f32, color: Color) {
	TRIANGLE_NORMALS: [3][2]f32: {
		{-0.500, -0.866},
		{-0.500, 0.866},
		{1.000, 0.000},
	}
	scale: [2]f32 = {1 - time * 2, 1} * size
	if time > 0.5 {
		paint_triangle_fill(
			center + TRIANGLE_NORMALS[2] * scale,
			center + TRIANGLE_NORMALS[1] * scale,
			center + TRIANGLE_NORMALS[0] * scale,
			color,
		)
	} else {
		paint_triangle_fill(
			center + TRIANGLE_NORMALS[0] * scale,
			center + TRIANGLE_NORMALS[1] * scale,
			center + TRIANGLE_NORMALS[2] * scale,
			color,
		)
	}
}
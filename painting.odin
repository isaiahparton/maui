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

// Path to resrcs folder
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
	glyphs: []Glyph_Data,
	glyph_map: map[rune]i32,
}
Glyph_Data :: struct {
	src: Box,
	offset: [2]f32,
	advance: f32,
}
Patch_Data :: struct {
	src: Box,
	amount: i32,
}

// Context for painting graphics stuff
Painter :: struct {
	circles: 		[CIRCLE_SIZES * CIRCLE_ROWS]Patch_Data,
	fonts: 			[Font_Index]Font_Data,
	// Style
	style: 			Style,
	// Texture atlas src
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
		return painter_make_atlas(painter)
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
color_to_hsv :: proc(color: Color) -> [4]f32 {
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
	top_left := center - radius

	for x in i32(top_left.x) ..= i32(top_left.x + size) {
		for y in i32(top_left.y) ..= i32(top_left.y + size) {
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
	top_left := center - outer

	for x in i32(top_left.x) ..= i32(top_left.x + size) {
		for y in i32(top_left.y) ..= i32(top_left.y + size) {
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
			box :Box= {origin.x + offset.x, origin.y + offset.y, size + 1, size + 1}

			painter.circles[size_index + row_index * CIRCLE_SIZES] = {
				src = box,
				amount = i32(radius),
			}

			if row_index == 0 {
				// First row is filled
				image_paint_smooth_circle(&painter.image, {box.x + radius, box.y + radius}, radius, CIRCLE_SMOOTHING)
			} else {
				image_paint_smooth_ring(&painter.image, {box.x + radius, box.y + radius}, radius - f32(row_index), radius, CIRCLE_SMOOTHING)
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
make_font :: proc(origin: [2]f32, path: string, size: i32, runes: []rune) -> (font: Font_Data, success: bool) {
	// Character set
	raw_array := transmute(runtime.Raw_Slice)runes
	// Get the file extension
	extension := filepath.ext(path)
    if extension == ".ttf" || extension == ".otf" {
    	if file_data, ok := os.read_entire_file(path); ok {
    		defer delete(file_data)
	        glyph_count := i32(len(runes))
	        glyph_padding := i32(1)
	        glyph_info := rl.LoadFontData((transmute(runtime.Raw_Slice)file_data).data, i32(len(file_data)), size, transmute([^]rune)(raw_array.data), glyph_count, .DEFAULT)

	        if glyph_info != nil {
	        	font.size = f32(size)
	        	// Temporary array
	        	boxs: [^]rl.Rectangle
	            // Create FontData from raylib font
	            font.image = rl.GenImageFontAtlas(glyph_info, &boxs, glyph_count, size, glyph_padding, 1);
	            font.glyphs = make([]Glyph_Data, glyph_count)
	            for index in 0 ..< glyph_count {
	            	box := boxs[index]
	            	codepoint := glyph_info[index].value
	            	if codepoint > unicode.MAX_LATIN1 {
	            		glyph_info[index].offsetY = i32(font.size / 2 - box.height / 2)
	            	}
	            	font.glyphs[index] = {
	            		src = {origin.x + box.x, origin.y + box.y, box.width, box.height},
	            		offset = {f32(glyph_info[index].offsetX), f32(glyph_info[index].offsetY)},
	            		advance = f32(glyph_info[index].advanceX),
	            	}
	            	font.glyph_map[codepoint] = index
	            }
	            // Free boxangles
	            //free(rawptr(boxs))
	        }
	        rl.UnloadFontData(glyph_info, glyph_count)
	        success = true
    	}
    }
    return
}
painter_make_atlas :: proc(using painter: ^Painter) -> (result: bool) {
	default_runes: []rune = {32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 0x2022}
	runes := make([]rune, len(default_runes) + len(Icon))
	defer delete(runes)

	copy(runes[:], default_runes[:len(default_runes)])
	for icon, index in Icon {
		runes[len(default_runes) + index] = rune(icon)
	}
	first_icon_index: int
	for codepoint, index in runes {
		if codepoint > unicode.MAX_LATIN1 {
			first_icon_index = index
			break
		}
	}

	// Create the image
	image = rl.GenImageColor(TEXTURE_WIDTH, TEXTURE_HEIGHT, {})
	image.format = .UNCOMPRESSED_GRAY_ALPHA
	// Solid white at texture origin for 'untextured' stuff
	rl.ImageDrawPixel(&image, 0, 0, rl.WHITE)
	// Draw some pre-smoothed circles and rings of different sizes
	circle_space := painter_gen_circles(painter, {1, 0})

	offset: f32 = 0
	for index in Font_Index {
		file := MONOSPACE_FONT if index == .monospace else DEFAULT_FONT
		font, success := make_font({circle_space.x + offset, 0}, text_format("%s/fonts/%s", RESOURCES_PATH, file), i32(style.fontSizes[index]), runes[:first_icon_index] if index == .monospace else runes)
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
		rl.ImageDraw(&image, font.image, {0, 0, f32(font.image.width), f32(font.image.height)}, {circle_space.x + offset, 0, f32(font.image.width), f32(font.image.height)}, rl.WHITE)
		offset += f32(font.image.width)
		rl.UnloadImage(font.image)
	}

	result = true
	return
}
get_glyph_data :: proc(font: ^Font_Data, codepoint: rune) -> Glyph_Data {
	index, ok := font.glyph_map[codepoint]
	if ok {
		return font.glyphs[index]
	}
	return {}
}
get_font_data :: proc(index: Font_Index) -> ^Font_Data {
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
	box: Box,
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
	cmd := transmute(^Type)&layer.commands[layer.command_offset]
	assert(layer.command_offset + size < COMMAND_BUFFER_SIZE, "push_command() Insufficient space in command buffer!")
	layer.command_offset += size
	cmd.variant = cmd
	cmd.size = u8(size)
	return cmd
}
// Get the next draw command
next_command :: proc(pcmd: ^^Command) -> bool {
	// Loop through layers
	if core.hot_layer >= len(core.layers) {
		return false
	}
	layer := core.layers[core.hot_layer]

	cmd := pcmd^
	defer pcmd^ = cmd
	if cmd != nil { 
		cmd = (^Command)(uintptr(cmd) + uintptr(cmd.size)) 
	} else {
		cmd = (^Command)(&layer.commands[0])
	}

	clip, ok := cmd.variant.(^Command_Clip)
	if ok {
		if clip.box == core.clip_box {
			return next_command(&cmd)
		} else {
			core.clip_box = clip.box
		}
	}
	if cmd == (^Command)(&layer.commands[layer.command_offset]) || cmd.size == 0 {
		// At end of command buffer so reset `cmd` and go to next layer
		core.hot_layer += 1
		cmd = nil
		return next_command(&cmd)
	}
	return true
}
next_command_iterator :: proc(pcm: ^^Command) -> (Command_Variant, bool) {
	if next_command(pcm) {
		return pcm^.variant, true
	}
	return nil, false
}

// Painting procs
begin_clip :: proc(box: Box) {
	if core.paint_this_frame {
		core.clip_box = box
		cmd := push_command(current_layer(), Command_Clip)
		cmd.box = box
	}
}
end_clip :: proc() {
	if core.paint_this_frame {
		core.clip_box = core.fullscreen_box
		cmd := push_command(current_layer(), Command_Clip)
		cmd.box = core.clip_box
	}
}
paint_quad_fill :: proc(p1, p2, p3, p4: [2]f32, c: Color) {
	paint_triangle_fill(p1, p2, p4, c)
	paint_triangle_fill(p4, p2, p3, c)
}
paint_triangle_fill :: proc(p1, p2, p3: [2]f32, color: Color) {
	layer := current_layer()
	cmd := push_command(layer, Command_Triangle)
	cmd.color = Color{color.r, color.g, color.b, u8(f32(color.a) * layer.opacity)}
	cmd.vertices = {p1, p2, p3}
}
paint_box_fill :: proc(box: Box, color: Color) {
	paint_quad_fill(
		{f32(box.x), f32(box.y)},
		{f32(box.x), f32(box.y + box.h)},
		{f32(box.x + box.w), f32(box.y + box.h)},
		{f32(box.x + box.w), f32(box.y)},
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
paint_box_stroke :: proc(box: Box, thickness: f32, color: Color) {
	paint_box_fill({box.x + thickness, box.y, box.w - thickness * 2, thickness}, color)
	paint_box_fill({box.x + thickness, box.y + box.h - thickness, box.w - thickness * 2, thickness}, color)
	paint_box_fill({box.x, box.y, thickness, box.h}, color)
	paint_box_fill({box.x + box.w - thickness, box.y, thickness, box.h}, color)	
}
paint_widget_frame :: proc(box: Box, gapOffset, gapWidth, thickness: f32, color: Color) {
	paint_box_fill({box.x, box.y, gapOffset, thickness}, color)
	paint_box_fill({box.x + gapOffset + gapWidth, box.y, box.w - gapWidth - gapOffset, thickness}, color)
	paint_box_fill({box.x, box.y + box.h - thickness, box.w, thickness}, color)
	paint_box_fill({box.x, box.y, thickness, box.h}, color)
	paint_box_fill({box.x + box.w - thickness, box.y, thickness, box.h}, color)
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
	paint_quad_fill(
		{r.x + max(a, 0), r.y}, 
		{r.x + max(a, 0), r.y + clamp(a + r.h, 0, r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y + max(0, a - r.w + r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y}, 
		c,
	)
}
paint_texture :: proc(src, dst: Box, color: Color) {
	layer := current_layer()
	cmd := push_command(layer, Command_Texture)
	cmd.uv_min = {src.x / TEXTURE_WIDTH, src.y / TEXTURE_HEIGHT}
	cmd.uv_max = {(src.x + src.w) / TEXTURE_WIDTH, (src.y + src.h) / TEXTURE_HEIGHT}
	cmd.min = {dst.x, dst.y}
	cmd.max = {dst.x + dst.w, dst.y + dst.h}
	cmd.color = Color{color.r, color.g, color.b, u8(f32(color.a) * layer.opacity)}
}
paint_circle_fill_texture :: proc(center: [2]f32, size: f32, color: Color) {
	index := int(size) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	src := grow_box(painter.circles[index].src, 1)
	paint_texture(src, {center.x - math.floor(src.w / 2), center.y - math.floor(src.h / 2), src.w, src.h}, color)
}
paint_circle_stroke_texture :: proc(center: [2]f32, size: f32, thin: bool, color: Color) {
	index := CIRCLE_SIZES + int(size) - MIN_CIRCLE_SIZE
	if !thin {
		index += CIRCLE_SIZES
	}
	if index < 0 {
		return
	}
	src := grow_box(painter.circles[index].src, 1)
	paint_texture(src, {center.x - math.floor(src.w / 2), center.y - math.floor(src.h / 2), src.w, src.h}, color)
}

paint_pill_fill_h :: proc(box: Box, color: Color) {
	radius := math.floor(box.h / 2)

	if box.w == 0 || box.h == 0 {
		return
	}
	index := int(box.h) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	src := painter.circles[index].src
	half_size := math.trunc(src.w / 2)

	half_width := min(half_size, box.w / 2)

	src_left: Box = {src.x, src.y, half_width, src.h}
	src_right: Box = {src.x + src.w - half_width, src.y, half_width, src.h}

	paint_texture(src_left, {box.x, box.y, half_width, box.h}, color)
	paint_texture(src_right, {box.x + box.w - half_width, box.y, half_width, box.h}, color)

	if box.w > box.h {
		paint_box_fill({box.x + radius, box.y, box.w - radius * 2, box.h}, color)
	}
}
paint_pill_stroke_h :: proc(box: Box, thin: bool, color: Color) {
	thickness: f32 = 1 if thin else 2
	radius := math.floor(box.h / 2)

	if box.w == 0 || box.h == 0 {
		return
	}
	index := int(box.h) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	src := painter.circles[index + (CIRCLE_SIZES if thin else (CIRCLE_SIZES * 2))].src
	half_size := math.trunc(src.w / 2)

	half_width := min(half_size, box.w / 2)

	src_left: Box = {src.x, src.y, half_width, src.h}
	src_right: Box = {src.x + src.w - half_width, src.y, half_width, src.h}

	paint_texture(src_left, {box.x, box.y, half_width, box.h}, color)
	paint_texture(src_right, {box.x + box.w - half_width, box.y, half_width, box.h}, color)

	if box.w > box.h {
		paint_box_fill({box.x + radius, box.y, box.w - radius * 2, thickness}, color)
		paint_box_fill({box.x + radius, box.y + box.h - thickness, box.w - radius * 2, thickness}, color)
	}
}

paint_rounded_box_corners_fill :: proc(box: Box, radius: f32, corners: Box_Corners, color: Color) {
	if box.h == 0 || box.w == 0 {
		return
	}
	if radius == 0 || corners == {} {
		paint_box_fill(box, color)
		return
	}

	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	src := painter.circles[index].src
	half_size := math.trunc(src.w / 2)

	half_width := min(half_size, box.w / 2)
	half_height := min(half_size, box.h / 2)

	if .top_left in corners {
		src_top_left: Box = {src.x, src.y, half_width, half_height}
		paint_texture(src_top_left, {box.x, box.y, half_size, half_size}, color)
	}
	if .top_right in corners {
		src_top_right: Box = {src.x + src.w - half_width, src.y, half_width, half_height}
		paint_texture(src_top_right, {box.x + box.w - half_width, box.y, half_size, half_size}, color)
	}
	if .bottom_right in corners {
		src_bottom_right: Box = {src.x + src.w - half_width, src.y + src.h - half_height, half_width, half_height}
		paint_texture(src_bottom_right, {box.x + box.w - half_size, box.y + box.h - half_size, half_size, half_size}, color)
	}
	if .bottom_left in corners {
		src_bottom_left: Box = {src.x, src.y + src.h - half_height, half_width, half_height}
		paint_texture(src_bottom_left, {box.x, box.y + box.h - half_height, half_size, half_size}, color)
	}

	if box.w > radius * 2 {
		paint_box_fill({box.x + radius, box.y, box.w - radius * 2, box.h}, color)
	}
	if box.h > radius * 2 {
		top_left := radius if .top_left in corners else 0
		top_right := radius if .top_right in corners else 0
		bottom_right := radius if .bottom_right in corners else 0
		bottom_left := radius if .bottom_left in corners else 0
		paint_box_fill({box.x, box.y + top_left, radius, box.h - (top_left + bottom_left)}, color)
		paint_box_fill({box.x + box.w - radius, box.y + top_right, radius, box.h - (top_right + bottom_right)}, color)
	}
}
paint_rounded_box_fill :: proc(box: Box, radius: f32, color: Color) {
	if radius == 0 {
		paint_box_fill(box, color)
		return
	}

	if box.w == 0 || box.h == 0 {
		return
	}
	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	src := painter.circles[index].src
	half_size := math.trunc(src.w / 2)

	half_width := min(half_size, box.w / 2)
	half_height := min(half_size, box.h / 2)

	src_top_left: Box = {src.x, src.y, half_width, half_height}
	src_top_right: Box = {src.x + src.w - half_width, src.y, half_width, half_height}
	src_bottom_right: Box = {src.x + src.w - half_width, src.y + src.h - half_height, half_width, half_height}
	src_bottom_left: Box = {src.x, src.y + src.h - half_height, half_width, half_height}

	paint_texture(src_top_left, {box.x, box.y, half_width, half_height}, color)
	paint_texture(src_top_right, {box.x + box.w - half_width, box.y, half_width, half_height}, color)
	paint_texture(src_bottom_right, {box.x + box.w - half_width, box.y + box.h - half_height, half_width, half_height}, color)
	paint_texture(src_bottom_left, {box.x, box.y + box.h - half_height, half_width, half_height}, color)

	if box.w > radius * 2 {
		paint_box_fill({box.x + radius, box.y, box.w - radius * 2, box.h}, color)
	}
	if box.h > radius * 2 {
		half_width := min(radius, box.w / 2)
		paint_box_fill({box.x, box.y + radius, half_width, box.h - radius * 2}, color)
		paint_box_fill({box.x + box.w - half_width, box.y + radius, half_width, box.h - radius * 2}, color)
	}
}

paint_rounded_box_stroke :: proc(box: Box, radius: f32, thin: bool, color: Color) {
	thickness: f32 = 1 if thin else 2
	if radius == 0 {
		paint_box_stroke(box, thickness, color)
		return
	}

	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if color.a == 0 || index < 0 || index >= CIRCLE_SIZES {
		return
	}
	src := painter.circles[index + (CIRCLE_SIZES if thin else (CIRCLE_SIZES * 2))].src
	half_size := math.trunc(src.w / 2)

	half_width := min(half_size, box.w / 2)
	half_height := min(half_size, box.h / 2)

	src_top_left: Box = {src.x, src.y, half_width, half_height}
	src_top_right: Box = {src.x + src.w - half_width, src.y, half_width, half_height}
	src_bottom_right: Box = {src.x + src.w - half_width, src.y + src.h - half_height, half_width, half_height}
	src_bottom_left: Box = {src.x, src.y + src.h - half_height, half_width, half_height}

	paint_texture(src_top_left, {box.x, box.y, src_top_left.w, src_top_left.h}, color)
	paint_texture(src_top_right, {box.x + box.w - half_width, box.y, src_top_right.w, src_top_right.h}, color)
	paint_texture(src_bottom_right, {box.x + box.w - half_width, box.y + box.h - half_height, src_bottom_right.w, src_bottom_right.h}, color)
	paint_texture(src_bottom_left, {box.x, box.y + box.h - half_height, src_bottom_left.w, src_bottom_left.h}, color)

	if box.w > radius * 2 {
		paint_box_fill({box.x + radius, box.y, box.w - radius * 2, thickness}, color)
		paint_box_fill({box.x + radius, box.y + box.h - thickness, box.w - radius * 2, thickness}, color)
	}
	if box.h > radius * 2 {
		paint_box_fill({box.x, box.y + radius, thickness, box.h - radius * 2}, color)
		paint_box_fill({box.x + box.w - thickness, box.y + radius, thickness, box.h - radius * 2}, color)
	}
}
paint_rounded_box_corners_stroke :: proc(box: Box, radius: f32, thin: bool, corners: Box_Corners, color: Color) {
	thickness: f32 = 1 if thin else 2
	if radius == 0 || corners == {} {
		paint_box_stroke(box, thickness, color)
		return
	}

	index := int(radius * 2) - MIN_CIRCLE_SIZE
	if color.a == 0 || index < 0 || index >= CIRCLE_SIZES {
		return
	}
	src := painter.circles[index + (CIRCLE_SIZES if thin else (CIRCLE_SIZES * 2))].src
	half_size := math.trunc(src.w / 2)

	half_width := min(half_size, box.w / 2)
	half_height := min(half_size, box.h / 2)

	if .top_left in corners {
		src_top_left: Box = {src.x, src.y, half_width, half_height}
		paint_texture(src_top_left, {box.x, box.y, half_size, half_size}, color)
	}
	if .top_right in corners {
		src_top_right: Box = {src.x + src.w - half_width, src.y, half_width, half_height}
		paint_texture(src_top_right, {box.x + box.w - half_width, box.y, half_size, half_size}, color)
	}
	if .bottom_right in corners {
		src_bottom_right: Box = {src.x + src.w - half_width, src.y + src.h - half_height, half_width, half_height}
		paint_texture(src_bottom_right, {box.x + box.w - half_size, box.y + box.h - half_size, half_size, half_size}, color)
	}
	if .bottom_left in corners {
		src_bottom_left: Box = {src.x, src.y + src.h - half_height, half_width, half_height}
		paint_texture(src_bottom_left, {box.x, box.y + box.h - half_height, half_size, half_size}, color)
	}

	if box.w > radius * 2 {
		top_left := radius if .top_left in corners else 0
		top_right := radius if .top_right in corners else 0
		bottom_right := radius if .bottom_right in corners else 0
		bottom_left := radius if .bottom_left in corners else 0
		paint_box_fill({box.x + top_left, box.y, box.w - (top_left + top_right), thickness}, color)
		paint_box_fill({box.x + bottom_left, box.y + box.h - thickness, box.w - (bottom_left + bottom_right), thickness}, color)
	}
	if box.h > radius * 2 {
		top_left := radius if .top_left in corners else 0
		top_right := radius if .top_right in corners else 0
		bottom_right := radius if .bottom_right in corners else 0
		bottom_left := radius if .bottom_left in corners else 0
		paint_box_fill({box.x, box.y + top_left, thickness, box.h - (top_left + bottom_left)}, color)
		paint_box_fill({box.x + box.w - thickness, box.y + top_right, thickness, box.h - (top_right + bottom_right)}, color)
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
/*
	Handles the main texture atlas
		* Newly created fonts are added at the bottom of the existing content
		* When the texture is full, it is repainted entirely
*/

package maui
// Core dependencies
import "core:os"
import "core:mem"
import "core:runtime"
import "core:path/filepath"

import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:unicode"
import "core:unicode/utf8"

import "core:math"
import "core:math/linalg"

import ttf "vendor:stb/truetype"
import img "vendor:stb/image"

// Path to resrcs folder
RESOURCES_PATH :: #config(MAUI_RESOURCES_PATH, ".")
// Main texture size
TEXTURE_WIDTH :: 4096
TEXTURE_HEIGHT :: 4096
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

Patch_Data :: struct {
	src: Box,
	amount: i32,
}

Image ::struct {
	width, height: int,
	data: []u8,
	channels: int,
}

Texture :: struct {
	width, height: int,
	id: u32,
	channels: int,
}

// User imported images
Image_Data :: struct {
	texture_id: u32,
	size: [2]int,
}

MAX_IMAGES :: 64

Image_Index :: int

Vertex :: struct {
	point,
	uv: [2]f32,
	color: [4]u8,
}

DRAW_COMMAND_SIZE :: 1024
// A draw command
Draw_Command :: struct {
	clip: Maybe(Box),
	vertices: [DRAW_COMMAND_SIZE]Vertex,
	vertices_offset: u16,
	indices: [DRAW_COMMAND_SIZE]u16,
	indices_offset: u16,
}
// Push a command to a given layer
paint_vertices :: proc(cmd: ^Draw_Command, vertices: ..Vertex) {
	if int(cmd.vertices_offset) + len(vertices) <= DRAW_COMMAND_SIZE {
		copy(cmd.vertices[cmd.vertices_offset:], vertices[:])
		cmd.vertices_offset += u16(len(vertices))
	}
}
paint_vertices_translated :: proc(cmd: ^Draw_Command, delta: [2]f32, vertices: ..Vertex) {
	if int(cmd.vertices_offset) + len(vertices) <= DRAW_COMMAND_SIZE {
		for v in vertices {
			cmd.vertices[cmd.vertices_offset] = v 
			cmd.vertices[cmd.vertices_offset].point += delta 
			cmd.vertices_offset += 1 
		}
	}
}
paint_indices :: proc(cmd: ^Draw_Command, indices: ..u16) {
	if int(cmd.vertices_offset) + len(indices) <= DRAW_COMMAND_SIZE {
		copy(cmd.indices[cmd.indices_offset:], indices[:])
		cmd.indices_offset += u16(len(indices))
	}
}

// Maximum radius of pre-rasterized circles
MAX_CIRCLE_RADIUS :: 30
/*
	Handles dynamics of the texture atlas, can load new assets at runtime
*/
Atlas_Agent :: struct {
	texture: Texture,
	image: Image,
	cursor: [2]f32,
	row_height: f32,
	// If resetting the atlas would free space
	should_reset: bool,
	// Pre-rasterized circles
	circles: [MAX_CIRCLE_RADIUS]Box,
	rings: []Box,
}
atlas_agent_destroy :: proc(using self: ^Atlas_Agent) {
	delete(image.data)
}
atlas_agent_reset :: proc(using self: ^Atlas_Agent) {

}
atlas_agent_add :: proc(using self: ^Atlas_Agent, content: Image) -> (src: Box, ok: bool) {

	return
}
atlas_agent_get_box :: proc(using self: ^Atlas_Agent, size: [2]f32) -> (box: Box) {
	if cursor.x + size.x > f32(image.width) {
		cursor.y += row_height
	}
	if cursor.y + size.y > f32(image.height) {
		atlas_agent_reset(self)
	}
	box = {
		cursor.x,
		cursor.y,
		size.x,
		size.y,
	}
	cursor.x += size.x
	row_height = max(row_height, size.y)
	return
}
atlas_agent_add_ring :: proc(using self: ^Atlas_Agent, inner, outer: f32) -> (src: Box, ok: bool) {
	box := atlas_agent_get_box(self, outer * 2)
	center: [2]f32 = {box.x, box.y} + outer

	for x in int(box.x)..<int(box.x + box.w) {
		for y in int(box.y)..<int(box.y + box.h) {
			point: [2]f32 = {f32(x), f32(y)}
			diff := point - center
			dist := math.sqrt((diff.x * diff.x) + (diff.y * diff.y))
			if dist < inner || dist > outer {
				continue
			}
			alpha := min(1, dist - inner) - max(0, dist - outer)
			i := x + y * image.width
			image.data[i] = 255
			image.data[i + 1] = 255
			image.data[i + 2] = 255
			image.data[i + 3] = u8(255.0 * alpha)
		}
	}
	return
}

MAX_FONTS :: 32
MAX_DRAW_COMMANDS :: 32

// Context for painting graphics stuff
Painter :: struct {
	circles: 			[CIRCLE_SIZES * CIRCLE_ROWS]Patch_Data,
	font_exists: 	[MAX_FONTS]bool,
	fonts: 				[MAX_FONTS]Font,
	// Style
	style: 				Style,
	// User Images
	image_exists: [MAX_IMAGES]bool,
	images:  			[MAX_IMAGES]Image_Data,
	// Main texture atlas
	atlas_agent: Atlas_Agent,
	// Draw commands
	commands: [MAX_DRAW_COMMANDS]Draw_Command,
	commands_offset: u16,
}
// Global instance pointer
painter: ^Painter

style_default_fonts :: proc(style: ^Style) -> bool {
	main_font := load_font(painter, "IBMPlexSans-Medium_Remixicon.ttf") or_return
	monospace_font := load_font(painter, "Inconsolata_Condensed-SemiBold") or_return
	style.button_font = main_font
	style.button_font_size = 20
	style.default_font = main_font
	style.default_font_size = 18
	style.title_font = main_font
	style.title_font_size = 12
	style.monospace_font = monospace_font
	style.monospace_font_size = 18
	return true
}
painter_init :: proc() -> bool {
	if painter == nil {
		painter = new(Painter)
		// Default style
		painter.style.colors = DEFAULT_COLORS_LIGHT
		style_default_fonts(&painter.style)
		atlas_agent_reset(&painter.atlas_agent)
		painter.default_texture_id, _ = load_texture(painter.atlas_agent.image)
		return true
	}
	return false
}
painter_destroy :: proc() {
	if painter != nil {
		atlas_agent_destroy(&painter.atlas_agent)
		unload_texture(painter.default_texture_id)

		for font in &painter.fonts {
			for _, size in font.sizes {
				for _, glyph in size.glyphs {
					delete(glyph.image.data)
				}
				delete(size.glyphs)
			}
			delete(font.sizes)
		}

		free(painter)
	}
}

_load_texture: proc(image: Image) -> (id: u32, ok: bool)
_unload_texture: proc(id: u32)

load_texture :: proc(image: Image) -> (id: u32, ok: bool) {
	assert(_load_texture != nil)
	return _load_texture(image)
}
unload_texture :: proc(id: u32) {
	assert(_unload_texture != nil)
	_unload_texture(id)
}


unload_image :: proc(index: Image_Index) {
	painter.image_exists[index] = false 
	unload_texture(painter.images[index].texture_id)
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
alpha_blend_colors :: proc(dst, src, tint: Color) -> (out: Color) {
	out = 255

	src := src
	src.r = u8((u32(src.r) * (u32(tint.r) + 1)) >> 8)
	src.g = u8((u32(src.g) * (u32(tint.g) + 1)) >> 8)
	src.b = u8((u32(src.b) * (u32(tint.b) + 1)) >> 8)
	src.a = u8((u32(src.a) * (u32(tint.a) + 1)) >> 8)

	if (src.a == 0) {
		out = dst
	} else if src.a == 255 {
		out = src
	} else {
		alpha := u32(src.a) + 1
		out.a = u8((u32(alpha) * 256 + u32(dst.a) * (256 - alpha)) >> 8)

		if out.a > 0 {
			out.r = u8(((u32(src.r) * alpha * 256 + u32(dst.r) * u32(dst.a) * (256 - alpha)) / u32(out.a)) >> 8)
			out.g = u8(((u32(src.g) * alpha * 256 + u32(dst.g) * u32(dst.a) * (256 - alpha)) / u32(out.a)) >> 8)
			out.b = u8(((u32(src.b) * alpha * 256 + u32(dst.b) * u32(dst.a) * (256 - alpha)) / u32(out.a)) >> 8)
		}
	}
	return
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
paint_labeled_widget_frame :: proc(box: Box, text: Maybe(string), offset, thickness: f32, color: Color) {
	if text != nil {
		label_font := get_font_data(.Label)
		text_size := measure_string(label_font, text.?)
		paint_widget_frame(box, offset - 2, text_size.x + 4, thickness, color)
		paint_string(label_font, text.?, {box.x + offset, box.y - text_size.y / 2}, get_color(.Text))
	} else {
		paint_box_stroke(box, thickness, color)
	}
}
paint_quad_fill :: proc(p1, p2, p3, p4: [2]f32, c: Color) {
	paint_triangle_fill(p1, p2, p4, c)
	paint_triangle_fill(p4, p2, p3, c)
}
paint_triangle_fill :: proc(a, b, c: [2]f32, color: Color) {
	layer := current_layer()
	paint_indices(&layer.command, {
		layer.command.vertices_offset,
		layer.command.vertices_offset + 1,
		layer.command.vertices_offset + 2,
	})
	paint_vertices(&layer.command, {
		{point = a, color = color},
		{point = b, color = color},
		{point = c, color = color},
	})
}
paint_box_fill :: proc(box: Box, color: Color) {
	paint_quad_fill(
		{box.x, box.y},
		{box.x, box.y + box.h},
		{box.x + box.w, box.y + box.h},
		{box.x + box.w, box.y},
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
paint_texture :: proc(tex: Texture, src, dst: Box, color: Color) {
	layer := current_layer()
	paint_indices(&layer.command, {
		layer.command.vertices_offset,
		layer.command.vertices_offset + 1,
		layer.command.vertices_offset + 2,
		layer.command.vertices_offset,
		layer.command.vertices_offset + 2,
		layer.command.vertices_offset + 3,
	})
	paint_vertices(&layer.command, {
		{
			point = {dst.x, dst.y}, 
			uv = {src.x / f32(tex.width), src.y / f32(tex.height)}, 
			color = color,
		},
		{
			point = {dst.x + dst.w, dst.y}, 
			uv = {(src.x + src.w) / f32(tex.width), src.y / f32(tex.height)}, 
			color = color,
		},
		{
			point = {dst.x + dst.w, dst.y + dst.h}, 
			uv = {(src.x + src.w) / f32(tex.width), (src.y + src.h) / f32(tex.height)}, 
			color = color,
		},
		{
			point = {dst.x, dst.y + dst.h}, 
			uv = {src.x / f32(tex.width), (src.y + src.h) / f32(tex.height)}, 
			color = color,
		},
	})
}
paint_image :: proc(image: Image_Index, src, dst: Box, color: Color) {
	layer := core.layer_agent.current_layer
	cmd := push_command(layer, Command_Texture)
	cmd.id = painter.images[image].texture_id
	cmd.uv_min = {src.x, src.y}
	cmd.uv_max = {src.x + src.w, src.y + src.h}
	cmd.min = {dst.x, dst.y}
	cmd.max = {dst.x + dst.w, dst.y + dst.h}
	cmd.color = Color{color.r, color.g, color.b, u8(f32(color.a) * layer.opacity)}
}
paint_circle_fill_texture :: proc(center: [2]f32, size: f32, color: Color) {
	index := int(size) - MIN_CIRCLE_SIZE - 1
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	src := painter.circles[index].src
	paint_texture(src, {center.x - src.w / 2, center.y - src.h / 2, src.w, src.h}, color)
}
paint_circle_stroke_texture :: proc(center: [2]f32, size: f32, thin: bool, color: Color) {
	index := CIRCLE_SIZES + int(size) - MIN_CIRCLE_SIZE - 1
	if !thin {
		index += CIRCLE_SIZES
	}
	if index < 0 {
		return
	}
	src := painter.circles[index].src
	paint_texture(src, {center.x - src.w / 2, center.y - src.h / 2, src.w, src.h}, color)
}

clip_dst_src :: proc(dst, src: ^Box, clip: Box) {
	 if dst.x < clip.x {
  	delta := clip.x - dst.x
  	dst.w -= delta
  	dst.x += delta
  	src.x += delta
  }
  if dst.y < clip.y {
  	delta := clip.y - dst.y
  	dst.h -= delta
  	dst.y += delta
  	src.y += delta
  }
  if dst.x + dst.w > clip.x + clip.w {
  	dst.w = (clip.x + clip.w) - dst.x
  }
  if dst.y + dst.h > clip.y + clip.h {
  	dst.h = (clip.y + clip.h) - dst.y
  }
  src.w = dst.w
  src.h = dst.h
}

paint_right_ribbon_fill :: proc(box: Box, color: Color) {
	n := box.h / 2
	paint_box_fill({box.x + n, box.y, box.w - n * 2, box.h}, color)
	paint_triangle_fill({box.x + box.w, box.y}, {box.x + box.w - n, box.y}, {box.x + box.w - n, box.y + n}, color)
	paint_triangle_fill({box.x + box.w - n, box.y + n}, {box.x + box.w - n, box.y + box.h}, {box.x + box.w, box.y + box.h}, color)
	paint_triangle_fill({box.x, box.y + n}, {box.x + n, box.y + box.h}, {box.x + n, box.y}, color)
}
paint_right_ribbon_stroke :: proc(box: Box, color: Color) {
	n := box.h / 2
	paint_box_fill({box.x + n, box.y, box.w - n, 1}, color)
	paint_box_fill({box.x + n, box.y + box.h - 1, box.w - n, 1}, color)
	paint_line({box.x + box.w, box.y}, {box.x + box.w - n, box.y + n}, 1, color)
	paint_line({box.x + box.w, box.y + box.h}, {box.x + box.w - n, box.y + n}, 1, color)
	paint_line({box.x + n, box.y}, {box.x, box.y + n}, 1, color)
	paint_line({box.x + n, box.y + box.h}, {box.x, box.y + n}, 1, color)
}
paint_left_ribbon_fill :: proc(box: Box, color: Color) {
	n := box.h / 2
	paint_box_fill({box.x + n, box.y, box.w - n * 2, box.h}, color)
	paint_triangle_fill({box.x + n, box.y}, {box.x, box.y}, {box.x + n, box.y + n}, color)
	paint_triangle_fill({box.x + n, box.y + n}, {box.x, box.y + box.h}, {box.x + n, box.y + box.h}, color)
	paint_triangle_fill({box.x + box.w, box.y + n}, {box.x + box.w - n, box.y}, {box.x + box.w - n, box.y + box.h}, color)
}
paint_left_ribbon_stroke :: proc(box: Box, color: Color) {
	n := box.h / 2
	paint_box_fill({box.x, box.y, box.w - n, 1}, color)
	paint_box_fill({box.x, box.y + box.h - 1, box.w - n, 1}, color)
	paint_line({box.x, box.y}, {box.x + n, box.y + n}, 1, color)
	paint_line({box.x, box.y + box.h}, {box.x + n, box.y + n}, 1, color)
	paint_line({box.x + box.w - n, box.y}, {box.x + box.w, box.y + n}, 1, color)
	paint_line({box.x + box.w - n, box.y + box.h}, {box.x + box.w, box.y + n}, 1, color)
}

paint_pill_fill_clipped_h :: proc(box, clip: Box, color: Color) {
	radius := math.floor(box.h / 2)

	if box.w == 0 || box.h == 0 {
		return
	}
	index := int(box.h - 1) - MIN_CIRCLE_SIZE
	if index < 0 || index >= CIRCLE_SIZES {
		return
	}
	src := painter.circles[index].src
	half_size := math.trunc(src.w / 2)

	half_width := min(half_size, box.w / 2)

	src_left: Box = {src.x, src.y, half_width, src.h}
	dst_left: Box = {box.x, box.y, half_width, box.h}
	clip_dst_src(&dst_left, &src_left, clip)
	src_right: Box = {src.x + src.w - half_width, src.y, half_width, src.h}
	dst_right: Box = {box.x + box.w - half_width, box.y, half_width, box.h}
	clip_dst_src(&dst_right, &src_right, clip)

	if dst_left.w > 0 {
		paint_texture(src_left, dst_left, color)
	}
	if dst_right.w > 0 {
		paint_texture(src_right, dst_right, color)
	}

	if box.w > box.h {
		paint_box_fill(clip_box({box.x + radius, box.y, box.w - radius * 2, box.h}, clip), color)
	}
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

	if .Top_Left in corners {
		src_top_left: Box = {src.x, src.y, half_width, half_height}
		paint_texture(src_top_left, {box.x, box.y, half_size, half_size}, color)
	}
	if .Top_Right in corners {
		src_top_right: Box = {src.x + src.w - half_width, src.y, half_width, half_height}
		paint_texture(src_top_right, {box.x + box.w - half_width, box.y, half_size, half_size}, color)
	}
	if .Bottom_Right in corners {
		src_bottom_right: Box = {src.x + src.w - half_width, src.y + src.h - half_height, half_width, half_height}
		paint_texture(src_bottom_right, {box.x + box.w - half_size, box.y + box.h - half_size, half_size, half_size}, color)
	}
	if .Bottom_Left in corners {
		src_bottom_left: Box = {src.x, src.y + src.h - half_height, half_width, half_height}
		paint_texture(src_bottom_left, {box.x, box.y + box.h - half_height, half_size, half_size}, color)
	}

	if box.w > radius * 2 {
		paint_box_fill({box.x + radius, box.y, box.w - radius * 2, box.h}, color)
	}
	if box.h > radius * 2 {
		top_left := radius if .Top_Left in corners else 0
		top_right := radius if .Top_Right in corners else 0
		bottom_right := radius if .Bottom_Right in corners else 0
		bottom_left := radius if .Bottom_Left in corners else 0
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
paint_rounded_box_sides_stroke :: proc(box: Box, radius: f32, thin: bool, sides: Box_Sides, color: Color) {
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

	corners: Box_Corners
	if sides >= {.Top, .Left} {
		corners += {.Top_Left}
	}
	if sides >= {.Top, .Right} {
		corners += {.Top_Right}
	}
	if sides >= {.Bottom, .Left} {
		corners += {.Bottom_Left}
	}
	if sides >= {.Bottom, .Right} {
		corners += {.Bottom_Right}
	}

	if .Top_Left in corners {
		src_top_left: Box = {src.x, src.y, half_width, half_height}
		paint_texture(src_top_left, {box.x, box.y, half_size, half_size}, color)
	}
	if .Top_Right in corners {
		src_top_right: Box = {src.x + src.w - half_width, src.y, half_width, half_height}
		paint_texture(src_top_right, {box.x + box.w - half_width, box.y, half_size, half_size}, color)
	}
	if .Bottom_Right in corners {
		src_bottom_right: Box = {src.x + src.w - half_width, src.y + src.h - half_height, half_width, half_height}
		paint_texture(src_bottom_right, {box.x + box.w - half_size, box.y + box.h - half_size, half_size, half_size}, color)
	}
	if .Bottom_Left in corners {
		src_bottom_left: Box = {src.x, src.y + src.h - half_height, half_width, half_height}
		paint_texture(src_bottom_left, {box.x, box.y + box.h - half_height, half_size, half_size}, color)
	}

	if box.w > radius * 2 {
		top_left := radius if .Top_Left in corners else 0
		top_right := radius if .Top_Right in corners else 0
		bottom_right := radius if .Bottom_Right in corners else 0
		bottom_left := radius if .Bottom_Left in corners else 0
		if .Top in sides {
			paint_box_fill({box.x + top_left, box.y, box.w - (top_left + top_right), thickness}, color)
		}
		if .Bottom in sides {
			paint_box_fill({box.x + bottom_left, box.y + box.h - thickness, box.w - (bottom_left + bottom_right), thickness}, color)
		}
	}
	if box.h > radius * 2 {
		top_left := radius if .Top_Left in corners else 0
		top_right := radius if .Top_Right in corners else 0
		bottom_right := radius if .Bottom_Right in corners else 0
		bottom_left := radius if .Bottom_Left in corners else 0
		if .Left in sides {
			paint_box_fill({box.x, box.y + top_left, thickness, box.h - (top_left + bottom_left)}, color)
		}
		if .Right in sides {
			paint_box_fill({box.x + box.w - thickness, box.y + top_right, thickness, box.h - (top_right + bottom_right)}, color)
		}
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
paint_loader :: proc(center: [2]f32, radius, time: f32, color: Color) {
	start := time * math.TAU
	paint_ring_sector_fill(center, radius - 3, radius, start, start + 2.2 + math.sin(time * 4) * 0.8, 24, color)
	core.paint_this_frame = true
	core.paint_next_frame = true
}
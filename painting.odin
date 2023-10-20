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
destroy_image :: proc(using self: ^Image) {
	delete(data)
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

DRAW_SIZE :: 48000
// A draw command
Draw :: struct {
	clip: Maybe(Box),
	texture: u32,
	vertices: [DRAW_SIZE]Vertex,
	vertices_offset: u16,
	indices: [DRAW_SIZE]u16,
	indices_offset: u16,
}

normalize_color :: proc(color: [4]u8) -> [4]f32 {
	return linalg.array_cast(color, f32) / 255.0
}

// Push a command to a given layer
paint_vertices :: proc(draw: ^Draw, vertices: ..Vertex) {
	if int(draw.vertices_offset) + len(vertices) <= DRAW_SIZE {
		draw.vertices_offset += u16(copy(draw.vertices[draw.vertices_offset:], vertices[:]))
	}
}
paint_vertices_translated :: proc(draw: ^Draw, delta: [2]f32, vertices: ..Vertex) {
	if int(draw.vertices_offset) + len(vertices) <= DRAW_SIZE {
		for v in vertices {
			draw.vertices[draw.vertices_offset] = v 
			draw.vertices[draw.vertices_offset].point += delta 
		}
		draw.vertices_offset += u16(len(vertices)) 
	}
}
paint_indices :: proc(draw: ^Draw, indices: ..u16) {
	if int(draw.indices_offset) + len(indices) <= DRAW_SIZE {
		draw.indices_offset += u16(copy(draw.indices[draw.indices_offset:], indices[:]))
	}
}

// Maximum radius of pre-rasterized circles
MAX_RING_RADIUS :: 30
/*
	Handles dynamics of the texture atlas, can load new assets at runtime
*/
Atlas :: struct {
	texture: Texture,
	image: Image,
	cursor: [2]f32,
	row_height: f32,
	// If resetting the atlas would free space
	should_update,
	should_reset: bool,
	// Font data
	font_exists: [MAX_FONTS]bool,
	fonts: [MAX_FONTS]Font,
	// Pre-rasterized ring locations
	rings: [MAX_RING_RADIUS][MAX_RING_RADIUS]Maybe(Box),
}
atlas_get_ring :: proc(using self: ^Atlas, inner, outer: f32) -> (src: Box, ok: bool) {
	_inner := int(inner)
	_outer := int(outer)
	if _inner < 0 || _inner >= MAX_RING_RADIUS || _outer < 0 || _outer >= MAX_RING_RADIUS {
		return {}, false
	}
	ring := &rings[_inner][_outer]
	if ring^ == nil {
		ring^, _ = atlas_add_ring(self, inner, outer)
	}
	return ring^.?
}
atlas_destroy :: proc(using self: ^Atlas) {
	// Free font memory
	for font in &fonts {
		for _, size in font.sizes {
			for _, glyph in size.glyphs {
				//delete(glyph.image.data)
			}
			delete(size.glyphs)
		}
		delete(font.sizes)
	}
	unload_texture(texture.id)
	delete(image.data)
}
atlas_reset :: proc(using self: ^Atlas) -> bool {
	delete(image.data)
	WIDTH :: 4096
	HEIGHT :: 4096
	SIZE :: WIDTH * HEIGHT * 4
	image = {
		data = make([]u8, SIZE),
		width = WIDTH,
		height = HEIGHT,
		channels = 4,
	}
	image.data[0] = 255
	image.data[1] = 255
	image.data[2] = 255
	image.data[3] = 255

	cursor = {1, 1}
	if texture == {} {
		texture = load_texture(image) or_return
	} else {
		update_texture(texture, image, 0, 0, f32(image.width), f32(image.height))
	}
	return true
}
atlas_add :: proc(using self: ^Atlas, content: Image) -> (src: Box, ok: bool) {
	box := atlas_get_box(self, {f32(content.width), f32(content.height)})
	for x in int(box.low.x)..<int(box.high.x) {
		for y in int(box.low.y)..<int(box.high.y) {
			src_x := x - int(box.low.x)
			src_y := y - int(box.low.y)
			src_i := src_x + src_y * content.width
			i := (x + y * image.width) * image.channels
			image.data[i] = 255
			image.data[i + 1] = 255
			image.data[i + 2] = 255
			image.data[i + 3] = content.data[src_i]
		}
	}
	should_update = true
	return box, true
}
atlas_get_box :: proc(using self: ^Atlas, size: [2]f32) -> (box: Box) {
	if cursor.x + size.x > f32(image.width) {
		cursor.x = 0
		cursor.y += row_height + 1
		row_height = 0
	}
	if cursor.y + size.y > f32(image.height) {
		atlas_reset(self)
	}
	box = {cursor, cursor + size}
	cursor.x += size.x + 1
	row_height = max(row_height, size.y)
	return
}
atlas_add_ring :: proc(using self: ^Atlas, inner, outer: f32) -> (src: Box, ok: bool) {
	if inner >= outer {
		return
	}
	box := atlas_get_box(self, outer * 2)
	center: [2]f32 = box_center(box) - 0.5
	outer := outer - 0.5
	inner := inner - 0.5
	for y in int(box.low.y)..<int(box.high.y) {
		for x in int(box.low.x)..<int(box.high.x) {
			point: [2]f32 = {f32(x), f32(y)}
			diff := point - center
			dist := math.sqrt((diff.x * diff.x) + (diff.y * diff.y))
			if dist < inner || dist > outer + 1 {
				continue
			}
			alpha := min(1, dist - inner) - max(0, dist - outer)
			i := (x + y * image.width) * image.channels
			image.data[i] = 255
			image.data[i + 1] = 255
			image.data[i + 2] = 255
			image.data[i + 3] = u8(255.0 * alpha)
		}
	}
	should_update = true
	return box, ok
}

MAX_FONTS :: 16
MAX_DRAWS :: 32

// Context for painting graphics stuff
Painter :: struct {
	// Style
	style: Style,
	// Main texture atlas
	atlas: Atlas,
	// Draw options
	opacity: f32,
	// Target index
	target: int,
	// Draw commands
	draws: [MAX_DRAWS]Draw,
	draw_index: int,
}
// Global instance pointer
painter: ^Painter

style_default_fonts :: proc(style: ^Style) -> bool {
	// Load the fonts
	main_font := load_font(&painter.atlas, "fonts/Ubuntu-Regular.ttf") or_return
	monospace_font := load_font(&painter.atlas, "fonts/UbuntuMono-Regular.ttf") or_return
	// Assign their handles and sizes
	style.button_font = main_font
	style.button_font_size = 18
	style.default_font = main_font
	style.default_font_size = 18
	style.title_font = main_font
	style.title_font_size = 14
	style.monospace_font = monospace_font
	style.monospace_font_size = 18
	return true
}
painter_init :: proc() -> bool {
	if painter == nil {
		painter = new(Painter)
		// Default style
		painter.style.colors = DEFAULT_COLORS_LIGHT
		if !style_default_fonts(&painter.style) {
			fmt.println("Failed to load fonts")
		}
		atlas_reset(&painter.atlas)
		return true
	}
	return false
}
painter_destroy :: proc() {
	if painter != nil {
		// Destroy the main atlas
		atlas_destroy(&painter.atlas)
		// Free the global instance
		free(painter)
		painter = nil
	}
}
get_draw_target :: proc() -> int {
	painter.draw_index += 1
	assert(painter.draw_index < MAX_DRAWS)
	painter.draws[painter.draw_index].clip = nil
	painter.draws[painter.draw_index].vertices_offset = 0
	painter.draws[painter.draw_index].indices_offset = 0
	painter.draws[painter.draw_index].texture = painter.atlas.texture.id
	return painter.draw_index
}
// Must be defined by backend
_load_texture: proc(image: Image) -> (id: u32, ok: bool)
_unload_texture: proc(id: u32)
_update_texture: proc(texture: Texture, data: []u8, x, y, w, h: f32)
// Backend interface
load_texture :: proc(image: Image) -> (texture: Texture, ok: bool) {
	assert(_load_texture != nil)
	id := _load_texture(image) or_return
	return Texture{
		id = id,
		width = image.width,
		height = image.height,
		channels = image.channels,
	}, true
}
unload_texture :: proc(id: u32) {
	assert(_unload_texture != nil)
	_unload_texture(id)
}
update_texture :: proc(texture: Texture, image: Image, x, y, w, h: f32) {
	assert(_update_texture != nil)
	_update_texture(texture, image.data, x, y, w, h)
}
// Color processing
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
alpha_blend_colors_tint :: proc(dst, src, tint: Color) -> (out: Color) {
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
alpha_blend_colors_time :: proc(dst, src: Color, time: f32) -> (out: Color) {
	return alpha_blend_colors_tint(dst, src, fade(255, time))
}
alpha_blend_colors :: proc {
	alpha_blend_colors_time,
	alpha_blend_colors_tint,
}

stroke_path :: proc(pts: [][2]f32, closed: bool, thickness: f32, color: Color) {
	draw := &painter.draws[painter.target]
	base_index := draw.vertices_offset
	if len(pts) < 2 {
		return
	}
	for i in 0..<len(pts) {
		a := max(0, i - 1)
		b := i 
		c := min(len(pts) - 1, i + 1)
		d := min(len(pts) - 1, i + 2)
		p0 := pts[a]
		p1 := pts[b]
		p2 := pts[c]
		p3 := pts[d]

		if p1 == p2 {
			continue
		}

		line := linalg.normalize(p2 - p1)
		normal := linalg.normalize([2]f32{-line.y, line.x})
		tangent1 := line if p0 == p1 else linalg.normalize(linalg.normalize(p1 - p0) + line)
		tangent2 := line if p2 == p3 else linalg.normalize(linalg.normalize(p3 - p2) + line)
		miter1: [2]f32 = {-tangent1.y, tangent1.x}
		miter2: [2]f32 = {-tangent2.y, tangent2.x}
		length1 := thickness / linalg.dot(normal, miter1)
		length2 := thickness / linalg.dot(normal, miter2)

		if closed && i == len(pts) - 1 {
			paint_indices(draw, base_index + u16(i * 2))
			paint_indices(draw, base_index + u16(i * 2 + 1))
			paint_indices(draw, base_index)
			paint_indices(draw, base_index + u16(i * 2 + 3))
			paint_indices(draw, base_index)
			paint_indices(draw, base_index + 1)
		} else {
			paint_indices(draw, base_index + u16(i * 2))
			paint_indices(draw, base_index + u16(i * 2 + 1))
			paint_indices(draw, base_index + u16(i * 2 + 2))
			paint_indices(draw, base_index + u16(i * 2 + 3))
			paint_indices(draw, base_index + u16(i * 2 + 1))
			paint_indices(draw, base_index + u16(i * 2 + 2))
		}

		if i == 0 && !closed {
			paint_vertices(draw, 
				{point = p1 - length1 * miter1, color = color},
				{point = p1 + length1 * miter1, color = color},
			)
		}
		paint_vertices(draw, 
			{point = p2 - length2 * miter2, color = color},
			{point = p2 + length2 * miter2, color = color},
		)
	}
}


/*
	Painting procedures
		Most of these eventually call `paint_triangle_fill()`
*/
paint_labeled_widget_frame :: proc(box: Box, text: Maybe(string), offset, thickness: f32, color: Color) {
	if text != nil {
		text_size := measure_text({
			text = text.?,
			font = painter.style.title_font,
			size = painter.style.title_font_size,
		})
		paint_widget_frame(box, offset - 2, text_size.x + 4, thickness, color)
		paint_text(
			{
				box.low.x + offset, 
				box.low.y - text_size.y / 2,
			}, 
			{
				font = painter.style.title_font, 
				size = painter.style.title_font_size,
				text = text.?, 
			},
			{
				align = .Left,
			}, 
			get_color(.Text),
		)
	} else {
		paint_box_stroke(box, thickness, color)
	}
}
paint_quad_fill :: proc(a, b, c, d: [2]f32, color: Color) {
	draw := &painter.draws[painter.target]
	color := color
	color.a = u8(f32(color.a) * painter.opacity)
	paint_indices(draw, 
		draw.vertices_offset,
		draw.vertices_offset + 1,
		draw.vertices_offset + 2,
		draw.vertices_offset,
		draw.vertices_offset + 2,
		draw.vertices_offset + 3,
	)
	paint_vertices(draw, 
		{point = a, color = color},
		{point = b, color = color},
		{point = c, color = color},
		{point = d, color = color},
	)
}
paint_triangle_fill :: proc(a, b, c: [2]f32, color: Color) {
	draw := &painter.draws[painter.target]
	color := color
	color.a = u8(f32(color.a) * painter.opacity)
	paint_indices(draw, 
		draw.vertices_offset,
		draw.vertices_offset + 1,
		draw.vertices_offset + 2,
	)
	paint_vertices(draw, 
		{point = a, color = color},
		{point = b, color = color},
		{point = c, color = color},
	)
}
paint_box_fill :: proc(box: Box, color: Color) {
	paint_quad_fill(
		box.low,
		{box.low.x, box.high.y},
		box.high,
		{box.high.x, box.low.y},
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

// A simple line painting procedure
paint_line :: proc(start, end: [2]f32, thickness: f32, color: Color) {
	delta := end - start
	length := math.sqrt(f32(delta.x * delta.x + delta.y * delta.y))
	if length > 0 && thickness > 0 {
		scale := thickness / (2 * length)
		radius: [2]f32 = {-scale * delta.y, scale * delta.x}
		paint_triangle_strip_fill({
				{ start.x - radius.x, start.y - radius.y },
				{ start.x + radius.x, start.y + radius.y },
				{ end.x - radius.x, end.y - radius.y },
				{ end.x + radius.x, end.y + radius.y },
		}, color)
	}
}

// Paints an inner stroke along a given box
paint_box_stroke :: proc(box: Box, thickness: f32, color: Color) {
	paint_box_fill({box.low, {box.high.x, box.low.y + thickness}}, color)
	paint_box_fill({{box.low.x, box.low.y + thickness}, {box.low.x + thickness, box.high.y - thickness}}, color)
	paint_box_fill({{box.high.x - thickness, box.low.y + thickness}, {box.high.x, box.high.y - thickness}}, color)
	paint_box_fill({{box.low.x, box.high.y - thickness}, box.high}, color)
}

// Paints a box stroke with a gap for text
paint_widget_frame :: proc(box: Box, gap_offset, gap_size, thickness: f32, color: Color) {
	paint_box_fill({box.low, {box.low.x + gap_offset, box.low.y + thickness}}, color)
	paint_box_fill({{box.low.x + gap_offset + gap_size, box.low.y}, {box.high.x, box.low.y + thickness}}, color)
	paint_box_fill({{box.low.x, box.low.y + thickness}, {box.low.x + thickness, box.high.y - thickness}}, color)
	paint_box_fill({{box.high.x - thickness, box.low.y + thickness}, {box.high.x, box.high.y - thickness}}, color)
	paint_box_fill({{box.low.x, box.high.y - thickness}, box.high}, color)
}
// Paint a filled circle
paint_circle_fill :: proc(center: [2]f32, radius: f32, segments: i32, color: Color) {
	paint_circle_sector_fill(center, radius, 0, math.TAU, segments, color)
}
// Paint only a slice of a circle
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
// Paint a filled ring
paint_ring_fill :: proc(center: [2]f32, inner, outer: f32, segments: i32, color: Color) {
	paint_ring_sector_fill(center, inner, outer, 0, math.TAU, segments, color)
}
// Paint only a portion of a filled ring
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
// Paints a sweep effect over a box
/*
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
*/
// Paint a textured box clipped to the `clip` parameter
paint_clipped_textured_box :: proc(texture: Texture, src, dst, clip: Box, tint: Color) {
	src := src
	dst := dst
	if dst.low.x < clip.low.x {
		delta := clip.low.x - dst.low.x
		dst.low.x += delta
		src.low.x += delta
	}
	if dst.low.y < clip.low.y {
		delta := clip.low.y - dst.low.y
		dst.low.y += delta
		src.low.y += delta
	}
	if dst.high.x > clip.high.x {
		delta := clip.high.x - dst.high.x
		dst.high.x += delta
		src.high.x += delta
	}
	if dst.high.y > clip.high.y {
		delta := clip.high.y - dst.high.y
		dst.high.y += delta
		src.high.y += delta
	}
	if src.high.x <= src.low.x || src.high.y <= src.low.y {
		return
	}
	paint_textured_box(texture, src, dst, tint)
}
// Paint a given texture on a box
paint_textured_box :: proc(tex: Texture, src, dst: Box, tint: Color) {
	draw := &painter.draws[painter.target]
	tint := tint
	tint.a = u8(f32(tint.a) * painter.opacity)
	paint_indices(draw, 
		draw.vertices_offset,
		draw.vertices_offset + 1,
		draw.vertices_offset + 2,
		draw.vertices_offset,
		draw.vertices_offset + 2,
		draw.vertices_offset + 3,
	)
	src: Box = {src.low / {f32(tex.width), f32(tex.height)}, src.high / {f32(tex.width), f32(tex.height)}}
	paint_vertices(draw, 
		{
			point = dst.low, 
			uv = src.low, 
			color = tint,
		},
		{
			point = {dst.low.x, dst.high.y}, 
			uv = {src.low.x, src.high.y}, 
			color = tint,
		},
		{
			point = dst.high, 
			uv = src.high,
			color = tint,
		},
		{
			point = {dst.high.x, dst.low.y}, 
			uv = {src.high.x, src.low.y}, 
			color = tint,
		},
	)
}

// Circles
paint_circle_fill_texture :: proc(center: [2]f32, radius: f32, color: Color) {
	if src, ok := atlas_get_ring(&painter.atlas, 0, radius); ok {
		offset := (src.high - src.low) * 0.5
		paint_textured_box(painter.atlas.texture, src, {linalg.round(center - offset), linalg.round(center + offset)}, color)
	}
}
paint_ring_fill_texture :: proc(center: [2]f32, inner, outer: f32, color: Color) {
	if src, ok := atlas_get_ring(&painter.atlas, inner, outer); ok {
		offset := (src.high - src.low) * 0.5
		paint_textured_box(painter.atlas.texture, src, {linalg.round(center - offset), linalg.round(center + offset)}, color)
	}
}

paint_left_ribbon_fill :: proc(box: Box, color: Color) {
	n := height(box) / 2
	paint_box_fill({{box.low.x + n, box.low.y}, {box.high.x - n, box.high.y}}, color)
	paint_triangle_fill({box.high.x, box.low.y}, {box.high.x - n, box.low.y}, {box.high.x - n, box.low.y + n}, color)
	paint_triangle_fill({box.high.x - n, box.low.y + n}, {box.high.x - n, box.high.y}, box.high, color)
	paint_triangle_fill({box.low.x, box.low.y + n}, {box.low.x + n, box.high.y}, {box.low.x + n, box.low.y}, color)
}
paint_left_ribbon_stroke :: proc(box: Box, t: f32, color: Color) {
	n := height(box) / 2
	dt := t * math.SQRT_TWO
	// a
	paint_quad_fill(box.low + {n, 0}, box.low + {n - t, t}, {box.high.x - t, box.low.y + t}, {box.high.x, box.low.y}, color)
	// b
	paint_quad_fill({box.high.x, box.low.y}, {box.high.x - dt, box.low.y}, {box.high.x - (n + dt), box.low.y + n}, {box.high.x - n, box.low.y + n}, color)
	// c
	paint_quad_fill({box.high.x - n, box.low.y + n}, {box.high.x - (n + dt), box.low.y + n}, {box.high.x - dt, box.high.y}, box.high, color)
	// d
	paint_quad_fill({box.low.x + n - t, box.high.y - t}, {box.low.x + n, box.high.y}, box.high, box.high - t, color)
	// e
	paint_quad_fill({box.low.x + n, box.high.y}, {box.low.x + n + dt, box.high.y}, {box.low.x + dt, box.low.y + n}, {box.low.x, box.low.y + n}, color)
	// f 
	paint_quad_fill({box.low.x + n, box.low.y}, {box.low.x + n + dt, box.low.y}, {box.low.x + dt, box.low.y + n}, {box.low.x, box.low.y + n}, color)
}
paint_right_ribbon_fill :: proc(box: Box, color: Color) {
	n := height(box) / 2
	paint_box_fill({{box.low.x + n, box.low.y}, {box.high.x - n, box.high.y}}, color)
	paint_triangle_fill({box.low.x + n, box.low.y}, box.low, box.low + n, color)
	paint_triangle_fill({box.low.x + n, box.low.y + n}, {box.low.x, box.high.y}, {box.low.x + n, box.high.y}, color)
	paint_triangle_fill({box.high.x, box.low.y + n}, {box.high.x - n, box.low.y}, {box.high.x - n, box.high.y}, color)
}
paint_right_ribbon_stroke :: proc(box: Box, t: f32, color: Color) {
	n := height(box) / 2
	dt := t * math.SQRT_TWO
	// a
	paint_quad_fill(box.low, box.low + t, {box.high.x - n + t, box.low.y + t}, {box.high.x - n, box.low.y}, color)
	// b
	paint_quad_fill({box.high.x - (n + dt), box.low.y}, {box.high.x - dt, box.low.y + n}, {box.high.x, box.low.y + n}, {box.high.x - n, box.low.y}, color)
	// c
	paint_quad_fill({box.high.x - (n + dt), box.high.y}, {box.high.x - n, box.high.y}, {box.high.x, box.low.y + n}, {box.high.x - dt, box.low.y + n}, color)
	// d
	paint_quad_fill({box.low.x, box.high.y}, {box.high.x - n, box.high.y}, {box.high.x - n + t, box.high.y - t}, {box.low.x + t, box.high.y - t}, color)
	// e
	paint_quad_fill({box.low.x + dt, box.high.y}, box.low + {n + dt, n}, box.low + n, {box.low.x, box.high.y}, color)
	// f 
	paint_quad_fill(box.low, box.low + n, box.low + {n + dt, n}, {box.low.x + dt, box.low.y}, color)
}

paint_pill_fill_clipped_h :: proc(box, clip: Box, color: Color) {
	/*radius := math.floor(height(box) / 2)
	if src, ok := atlas_get_ring(&painter.atlas, 0, radius); ok {
		half_size := math.trunc(src.w / 2)
		center_x := (box.low.x + box.high.x) * 0.5

		src_left: Box = {src.low, {center_x, src.high.y}}
		dst_left: Box = {box.low, {center_x, src.high.y}}
		clip_dst_src(&dst_left, &src_left, clip)
		src_right: Box = {src.high.x - center_x, src.y, center_x, src.h}
		dst_right: Box = {box.x + box.w - center_x, box.y, center_x, box.h}
		clip_dst_src(&dst_right, &src_right, clip)

		if dst_left.w > 0 {
			paint_textured_box(painter.atlas.texture, src_left, dst_left, color)
		}
		if dst_right.w > 0 {
			paint_textured_box(painter.atlas.texture, src_right, dst_right, color)
		}

		if box.w > box.h {
			paint_box_fill(clip_box({box.x + radius, box.y, box.w - radius * 2, box.h}, clip), color)
		}
	}*/
}
paint_pill_fill_h :: proc(box: Box, color: Color) {
	radius := math.floor(height(box) / 2)
	if src, ok := atlas_get_ring(&painter.atlas, 0, radius); ok {
		half_size := math.trunc(width(src) / 2)
		half_width := min(half_size, width(box) / 2)

		src_left: Box = {src.low, {src.low.x + half_width, src.high.y}}
		src_right: Box = {{src.high.x - half_width, src.low.y}, src.high}

		paint_textured_box(painter.atlas.texture, src_left, {box.low, {box.low.x + half_width, box.high.y}}, color)
		paint_textured_box(painter.atlas.texture, src_right, {{box.high.x - half_width, box.low.y}, box.high}, color)

		paint_box_fill({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.high.y}}, color)
	}
}
paint_pill_stroke_h :: proc(box: Box, thickness: f32, color: Color) {
	radius := math.floor(height(box) / 2)
	if src, ok := atlas_get_ring(&painter.atlas, radius - thickness, radius); ok {
		half_size := math.trunc(width(src) / 2)
		half_width := min(half_size, width(box) / 2)

		src_left: Box = {src.low, {src.low.x + half_width, src.high.y}}
		src_right: Box = {{src.high.x - half_width, src.low.y}, src.high}

		paint_textured_box(painter.atlas.texture, src_left, {box.low, {box.low.x + half_width, box.high.y}}, color)
		paint_textured_box(painter.atlas.texture, src_right, {{box.high.x - half_width, box.low.y}, box.high}, color)

		paint_box_fill({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.low.y + thickness}}, color)
		paint_box_fill({{box.low.x + radius, box.high.y - thickness}, {box.high.x - radius, box.high.y}}, color)
	}
}

paint_rounded_box_corners_fill :: proc(box: Box, radius: f32, corners: Box_Corners, color: Color) {
	/*if box.h == 0 || box.w == 0 {
		return
	}
	if radius == 0 || corners == {} {
		paint_box_fill(box, color)
		return
	}
	if src, ok := atlas_get_ring(&painter.atlas, 0, radius); ok {
		half_size := math.trunc(src.w / 2)
		half_width := min(half_size, box.w / 2)
		half_height := min(half_size, box.h / 2)

		if .Top_Left in corners {
			src_top_left: Box = {src.x, src.y, half_width, half_height}
			paint_textured_box(painter.atlas.texture, src_top_left, {box.x, box.y, half_size, half_size}, color)
		}
		if .Top_Right in corners {
			src_top_right: Box = {src.x + src.w - half_width, src.y, half_width, half_height}
			paint_textured_box(painter.atlas.texture, src_top_right, {box.x + box.w - half_width, box.y, half_size, half_size}, color)
		}
		if .Bottom_Right in corners {
			src_bottom_right: Box = {src.x + src.w - half_width, src.y + src.h - half_height, half_width, half_height}
			paint_textured_box(painter.atlas.texture, src_bottom_right, {box.x + box.w - half_size, box.y + box.h - half_size, half_size, half_size}, color)
		}
		if .Bottom_Left in corners {
			src_bottom_left: Box = {src.x, src.y + src.h - half_height, half_width, half_height}
			paint_textured_box(painter.atlas.texture, src_bottom_left, {box.x, box.y + box.h - half_height, half_size, half_size}, color)
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
	}*/
}
paint_rounded_box_fill :: proc(box: Box, radius: f32, color: Color) {
	if box.high.x <= box.low.x || box.high.y <= box.low.y {
		return
	}
	if radius == 0 {
		paint_box_fill(box, color)
		return
	}
	if src, ok := atlas_get_ring(&painter.atlas, 0, radius); ok {
		src_center := center(src)
		tl_src: Box = {src.low, src_center}
		tr_src: Box = {{src_center.x, src.low.y}, {src.high.x, src_center.y}}
		bl_src: Box = {{src.low.x, src_center.y}, {src_center.x, src.high.y}}
		br_src: Box = {src_center, src.high}

		tl_dst: Box = {box.low, box.low + radius}
		tr_dst: Box = {{box.high.x - radius, box.low.y}, {box.high.x, box.low.y + radius}}
		bl_dst: Box = {{box.low.x, box.high.y - radius}, {box.low.x + radius, box.high.y}}
		br_dst: Box = {box.high - radius, box.high}

		paint_clipped_textured_box(painter.atlas.texture, tl_src, tl_dst, box, color)
		paint_clipped_textured_box(painter.atlas.texture, tr_src, tr_dst, box, color)
		paint_clipped_textured_box(painter.atlas.texture, bl_src, bl_dst, box, color)
		paint_clipped_textured_box(painter.atlas.texture, br_src, br_dst, box, color)

		if box.high.x > box.low.x + radius * 2 {
			paint_box_fill({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.high.y}}, color)
		}
		paint_box_fill({{box.low.x, box.low.y + radius}, {box.low.x + radius, box.high.y - radius}}, color)
		paint_box_fill({{box.high.x - radius, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color)
	}
}

paint_rounded_box_stroke :: proc(box: Box, radius, thickness: f32, color: Color) {
	if box.high.x <= box.low.x || box.high.y <= box.low.y {
		return
	}
	if radius == 0 {
		paint_box_stroke(box, thickness, color)
		return
	}
	if src, ok := atlas_get_ring(&painter.atlas, radius - thickness, radius); ok {
		src_center := center(src)
		tl_src: Box = {src.low, src_center}
		tr_src: Box = {{src_center.x, src.low.y}, {src.high.x, src_center.y}}
		bl_src: Box = {{src.low.x, src_center.y}, {src_center.x, src.high.y}}
		br_src: Box = {src_center, src.high}

		tl_dst: Box = {box.low, box.low + radius}
		tr_dst: Box = {{box.high.x - radius, box.low.y}, {box.high.x, box.low.y + radius}}
		bl_dst: Box = {{box.low.x, box.high.y - radius}, {box.low.x + radius, box.high.y}}
		br_dst: Box = {box.high - radius, box.high}

		paint_textured_box(painter.atlas.texture, tl_src, tl_dst, color)
		paint_textured_box(painter.atlas.texture, tr_src, tr_dst, color)
		paint_textured_box(painter.atlas.texture, bl_src, bl_dst, color)
		paint_textured_box(painter.atlas.texture, br_src, br_dst, color)

		paint_box_fill({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.low.y + thickness}}, color)
		paint_box_fill({{box.low.x, box.low.y + radius}, {box.low.x + thickness, box.high.y - radius}}, color)
		paint_box_fill({{box.high.x - thickness, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color)
		paint_box_fill({{box.low.x + radius, box.high.y - thickness}, {box.high.x - radius, box.high.y}}, color)
	}
}
paint_rounded_box_sides_stroke :: proc(box: Box, radius, thickness: f32, sides: Box_Sides, color: Color) {
	/*if radius == 0 {
		paint_box_stroke(box, thickness, color)
		return
	}
	if src, ok := atlas_get_ring(&painter.atlas, radius - thickness, radius); ok {
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
			paint_textured_box(painter.atlas.texture, src_top_left, {box.x, box.y, half_size, half_size}, color)
		}
		if .Top_Right in corners {
			src_top_right: Box = {src.x + src.w - half_width, src.y, half_width, half_height}
			paint_textured_box(painter.atlas.texture, src_top_right, {box.x + box.w - half_width, box.y, half_size, half_size}, color)
		}
		if .Bottom_Right in corners {
			src_bottom_right: Box = {src.x + src.w - half_width, src.y + src.h - half_height, half_width, half_height}
			paint_textured_box(painter.atlas.texture, src_bottom_right, {box.x + box.w - half_size, box.y + box.h - half_size, half_size, half_size}, color)
		}
		if .Bottom_Left in corners {
			src_bottom_left: Box = {src.x, src.y + src.h - half_height, half_width, half_height}
			paint_textured_box(painter.atlas.texture, src_bottom_left, {box.x, box.y + box.h - half_height, half_size, half_size}, color)
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
	}*/
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
rotate_point :: proc(v: [2]f32, a: f32) -> [2]f32 {
	cosres := math.cos(a);
  sinres := math.sin(a);

  return {
  	v.x * cosres - v.y * sinres,
  	v.x * sinres + v.y * cosres,
  }
}
paint_cross :: proc(center: [2]f32, scale, angle, thickness: f32, color: Color) {
	p0: [2]f32 = center + rotate_point({-1, 0}, angle) * scale
	p1: [2]f32 = center + rotate_point({1, 0}, angle) * scale
	p2: [2]f32 = center + rotate_point({0, -1}, angle) * scale
	p3: [2]f32 = center + rotate_point({0, 1}, angle) * scale
	paint_line(p0, p1, thickness, color)
	paint_line(p2, p3, thickness, color)
}
paint_arrow :: proc(center: [2]f32, scale, angle, thickness: f32, color: Color) {
	p0: [2]f32 = center + rotate_point({-1, -0.5}, angle) * scale
	p1: [2]f32 = center + rotate_point({0, 0.5}, angle) * scale
	p2: [2]f32 = center + rotate_point({1, -0.5}, angle) * scale
	stroke_path({p0, p1, p2}, false, thickness, color)
}
paint_arrow_flip :: proc(center: [2]f32, scale, angle, thickness, time: f32, color: Color) {
	t := (1 - time * 2)
	p0: [2]f32 = center + rotate_point({-1, -0.5 * t}, angle) * scale
	p1: [2]f32 = center + rotate_point({0, 0.5 * t}, angle) * scale
	p2: [2]f32 = center + rotate_point({1, -0.5 * t}, angle) * scale
	stroke_path({p0, p1, p2}, false, thickness, color)
}
paint_loader :: proc(center: [2]f32, radius, time: f32, color: Color) {
	start := time * math.TAU
	paint_ring_sector_fill(center, radius - 3, radius, start, start + 2.2 + math.sin(time * 4) * 0.8, 24, color)
	core.paint_this_frame = true
}
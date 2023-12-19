/*
	Handles the main texture atlas
		* Newly created fonts are added at the bottom of the existing content
		* When the texture is full, it is cleared
*/
package maui
// Core dependencies
import "core:os"
import "core:fmt"
import "core:mem"
import "core:runtime"
import "core:path/filepath"

import "core:strings"
import "core:strconv"

import "core:unicode"
import "core:unicode/utf8"

import "core:math"
import "core:math/linalg"

import ttf "vendor:stb/truetype"
import img "vendor:stb/image"

// Global instance pointer
painter: ^Painter

// Path to resrcs folder
RESOURCES_PATH :: #config(MAUI_RESOURCES_PATH, ".")
// Main texture size
TEXTURE_WIDTH :: 4096
TEXTURE_HEIGHT :: 4096
// Triangle helper
TRIANGLE_STEP :: math.TAU / 3.0
// What sizes of circles to pre-render
MIN_CIRCLE_SIZE :: 2
MAX_CIRCLE_SIZE :: 60
MAX_CIRCLE_STROKE_SIZE :: 2
CIRCLE_SIZES :: MAX_CIRCLE_SIZE - MIN_CIRCLE_SIZE
CIRCLE_ROWS :: MAX_CIRCLE_STROKE_SIZE + 1
// Smoothing level for pre-rasterized circles
CIRCLE_SMOOTHING :: 1
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

Texture_Id :: u32
Material :: union {
	Default_Material,
	Acrylic_Material,
	//Gradient_Material,
}
Default_Material :: struct {
	texture: Texture_Id,
	emissive: bool,
}
Acrylic_Material :: struct {
	amount: int,
}
Gradient_Material :: struct {
	corners: [Box_Corner]Color,
}

MAX_MESH_VERTICES :: 32768
// A draw command
Mesh :: struct {
	clip: Maybe(Box),
	material: Material,
	vertices: [MAX_MESH_VERTICES]Vertex,
	vertices_offset: u16,
	indices: [MAX_MESH_VERTICES]u16,
	indices_offset: u16,
}

normalize_color :: proc(color: [4]u8) -> [4]f32 {
	return linalg.array_cast(color, f32) / 255.0
}

// Push a command to a given layer
paint_vertices :: proc(mesh: ^Mesh, vertices: ..Vertex) {
	if int(mesh.vertices_offset) + len(vertices) <= MAX_MESH_VERTICES {
		mesh.vertices_offset += u16(copy(mesh.vertices[mesh.vertices_offset:], vertices[:]))
	}
}
paint_vertices_translated :: proc(mesh: ^Mesh, delta: [2]f32, vertices: ..Vertex) {
	if int(mesh.vertices_offset) + len(vertices) <= MAX_MESH_VERTICES {
		for v in vertices {
			mesh.vertices[mesh.vertices_offset] = v 
			mesh.vertices[mesh.vertices_offset].point += delta 
		}
		mesh.vertices_offset += u16(len(vertices)) 
	}
}
paint_indices :: proc(mesh: ^Mesh, indices: ..u16) {
	if int(mesh.indices_offset) + len(indices) <= MAX_MESH_VERTICES {
		mesh.indices_offset += u16(copy(mesh.indices[mesh.indices_offset:], indices[:]))
	}
}

MAX_FONTS :: 32
MAX_MESHES :: 512

Paint_Mode :: enum {
	Discrete,
	Continuous,
}

// Context for painting graphics stuff
Painter :: struct {
	mode: Paint_Mode,
	this_frame,
	next_frame: bool,
	// Main texture atlas
	atlas: Atlas,
	// Draw options
	opacity: f32,
	// Target index
	target: int,
	// Draw commands
	meshes: [MAX_MESHES]Mesh,
	mesh_index: int,
}

should_render :: proc() -> bool {
	return painter.mode == .Continuous || painter.this_frame
}

style_default_fonts :: proc() -> bool {
	// Load the fonts
	style.font.label = load_font(&painter.atlas, "fonts/Ubuntu-Regular.ttf") or_return
	style.font.title = load_font(&painter.atlas, "fonts/RobotoSlab-Regular.ttf") or_return
	style.font.monospace = load_font(&painter.atlas, "fonts/AzeretMono-Regular.ttf") or_return
	style.font.icon = load_font(&painter.atlas, "fonts/remixicon.ttf") or_return
	// Assign their handles and sizes
	style.text_size.label = 16
	style.rounding = 5
	style.panel_rounding = 5
	style.tooltip_rounding = 5
	style.text_size.title = 16
	style.text_size.field = 18
	style.layout.title_size = 24
	style.layout.size = 24
	style.layout.gap_size = 5
	style.layout.widget_padding = 7
	return true
}
painter_init :: proc() -> bool {
	if painter == nil {
		painter = new(Painter)
		// Default style
		style.color = DARK_STYLE_COLORS
		if !style_default_fonts() {
			fmt.println("Failed to load fonts")
		}
		reset_atlas(&painter.atlas)
		return true
	}
	return false
}
painter_destroy :: proc() {
	if painter != nil {
		// Destroy the main atlas
		destroy_atlas(&painter.atlas)
		// Free the global instance
		free(painter)
		painter = nil
	}
}
get_draw_target :: proc() -> int {
	assert(painter.mesh_index < MAX_MESHES)
	index := painter.mesh_index
	painter.mesh_index += 1
	painter.meshes[index].clip = nil
	painter.meshes[index].vertices_offset = 0
	painter.meshes[index].indices_offset = 0
	painter.meshes[index].material = Default_Material{
		texture = Texture_Id(painter.atlas.texture.id),
	}
	return index
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

stroke_path :: proc(pts: [][2]f32, closed: bool, thickness: f32, color: Color) {
	draw := &painter.meshes[painter.target]
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
			font = style.font.title,
			size = style.text_size.title,
		})
		paint_widget_frame(box, offset - 2, text_size.x + 4, thickness, color)
		paint_text(
			{
				box.low.x + offset, 
				box.low.y - text_size.y / 2,
			}, 
			{
				font = style.font.title, 
				size = style.text_size.title,
				text = text.?, 
			},
			{
				align = .Left,
			}, 
			style.color.base_text[1],
		)
	} else {
		paint_box_stroke(box, thickness, color)
	}
}
paint_quad_fill :: proc(a, b, c, d: [2]f32, color: Color) {
	draw := &painter.meshes[painter.target]
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
paint_quad_mask :: proc(a, b, c, d: [2]f32, color: Color) {
	draw := &painter.meshes[painter.target]
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
		{point = a, uv = [2]f32{0, 1} + (a / core.size) * {1, -1}, color = color},
		{point = b, uv = [2]f32{0, 1} + (b / core.size) * {1, -1}, color = color},
		{point = c, uv = [2]f32{0, 1} + (c / core.size) * {1, -1}, color = color},
		{point = d, uv = [2]f32{0, 1} + (d / core.size) * {1, -1}, color = color},
	)
}
paint_quad_vertices :: proc(a, b, c, d: Vertex) {
	draw := &painter.meshes[painter.target]
	paint_indices(draw, 
		draw.vertices_offset,
		draw.vertices_offset + 1,
		draw.vertices_offset + 2,
		draw.vertices_offset,
		draw.vertices_offset + 2,
		draw.vertices_offset + 3,
	)
	paint_vertices(draw, a, b, c, d)
}
paint_triangle_fill :: proc(a, b, c: [2]f32, color: Color) {
	draw := &painter.meshes[painter.target]
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
paint_triangle_mask :: proc(a, b, c: [2]f32, color: Color) {
	draw := &painter.meshes[painter.target]
	paint_indices(draw, 
		draw.vertices_offset,
		draw.vertices_offset + 1,
		draw.vertices_offset + 2,
	)
	paint_vertices(draw, 
		{point = a, uv = [2]f32{0, 1} + (a / core.size) * {1, -1}, color = color},
		{point = b, uv = [2]f32{0, 1} + (b / core.size) * {1, -1}, color = color},
		{point = c, uv = [2]f32{0, 1} + (c / core.size) * {1, -1}, color = color},
	)
}
paint_triangle_stroke :: proc(a, b, c: [2]f32, thickness: f32, color: Color) {
	paint_line(a, b, thickness, color)
	paint_line(b, c, thickness, color)
	paint_line(c, a, thickness, color)
}

paint_box_mask :: proc(box: Box, color: Color) {
	paint_quad_mask(
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

/*
	Cubic bezier curve
*/
paint_cubic_bezier_curve :: proc(p0, p1, p2, p3: [2]f32, segments: int, thickness: f32, color: Color) {
	p := p0
	step: f32 = 1.0 / f32(segments)
	for t: f32 = 0; t <= 1; t += step {
		times: matrix[1, 4]f32 = {1, t, t * t, t * t * t}
		weights: matrix[4, 4]f32 = {
			1, 0, 0, 0,
			-3, 3, 0, 0,
			3, -6, 3, 0,
			-1, 3, -3, 1,
		}
		np: [2]f32 = {
			(times * weights * (matrix[4, 1]f32){p0.x, p1.x, p2.x, p3.x})[0][0],
			(times * weights * (matrix[4, 1]f32){p0.y, p1.y, p2.y, p3.y})[0][0],
		}
		paint_line(p, np, thickness, color)
		p = np
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
	draw := &painter.meshes[painter.target]
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

rotate_point :: proc(v: [2]f32, a: f32) -> [2]f32 {
	cosres := math.cos(a);
  sinres := math.sin(a);

  return {
  	v.x * cosres - v.y * sinres,
  	v.x * sinres + v.y * cosres,
  }
}
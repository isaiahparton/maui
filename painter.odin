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
Texture_Id :: u32
load_texture :: proc(painter: ^Painter, image: Image) -> (texture: Texture, ok: bool) {
	assert(painter.load_texture != nil)
	return painter.load_texture(image)
}
unload_texture :: proc(painter: ^Painter, texture: Texture) {
	assert(painter.unload_texture != nil)
	painter.unload_texture(texture)
}
update_texture :: proc(painter: ^Painter, texture: Texture, image: Image, x, y, w, h: f32) {
	assert(painter.update_texture != nil)
	painter.update_texture(texture, image.data, x, y, w, h)
}
Vertex :: struct {
	point,
	uv: [2]f32,
	color: [4]u8,
}
MAX_MESH_VERTICES :: 65536
// A draw command
Mesh :: struct {
	clip: Maybe(Box),
	// Vertices
	vertices: [MAX_MESH_VERTICES]Vertex,
	vertices_offset: u16,
	// Indices
	indices: [MAX_MESH_VERTICES]u16,
	indices_offset: u16,
}

make_mesh :: proc() -> (result: Mesh, ok: bool) {
	result, ok = Mesh{}, true
	return
}

normalize_color :: proc(color: [4]u8) -> [4]f32 {
	return linalg.array_cast(color, f32) / 255.0
}

// Push a command to a given layer
paint_vertices :: proc(mesh: ^Mesh, vertices: ..Vertex) {
	mesh.vertices_offset += u16(copy(mesh.vertices[mesh.vertices_offset:], vertices))
}
paint_indices :: proc(mesh: ^Mesh, indices: ..u16) {
	mesh.indices_offset += u16(copy(mesh.indices[mesh.indices_offset:], indices))
}

MAX_FONTS :: 128
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
	ready: bool,
	texture: Texture,
	image: Image,
	cursor: [2]f32,
	row_height: f32,
	// If resetting the atlas would free space
	should_update,
	should_reset: bool,
	// Font data
	fonts: [MAX_FONTS]Maybe(Font),
	// Pre-rasterized ring locations
	rings: [MAX_RING_RADIUS][MAX_RING_RADIUS]Maybe(Box),
	// Draw options
	opacity: f32,
	// Target index
	target: int,
	// Draw commands
	meshes: []Mesh,
	mesh_index: int,
	// Renderer interface
	load_texture: proc(Image) -> (Texture, bool),
	unload_texture: proc(Texture),
	update_texture: proc(Texture, []u8, f32, f32, f32, f32),
}

should_render :: proc(painter: ^Painter) -> bool {
	return painter.mode == .Continuous || painter.this_frame
}

make_painter :: proc() -> (result: Painter, ok: bool) {
	result, ok = Painter{
		meshes = make([]Mesh, MAX_MESHES),
	}, true
	return
}
destroy_painter :: proc(using self: ^Painter) {
	for i in 0..<MAX_FONTS {
		if font, ok := self.fonts[i].?; ok {
			for _, size in font.sizes {
				for _, glyph in size.glyphs {
					//delete(glyph.image.data)
				}
				delete(size.glyphs)
			}
			delete(font.sizes)
		}
	}
	delete(meshes)
	unload_texture(self.texture)
	delete(self.image.data)
	self^ = {}
}
/*
	Returns a fresh mesh for seshing
*/
get_draw_target :: proc(painter: ^Painter) -> (index: int, ok: bool) {
	ok = painter.mesh_index < MAX_MESHES
	if !ok {
		return
	}

	index = painter.mesh_index
	painter.mesh_index += 1

	painter.meshes[index].clip = nil
	painter.meshes[index].vertices_offset = 0
	painter.meshes[index].indices_offset = 0

	return
}
/*
	Painting procedures
		Most of these eventually call `paint_triangle_fill()`
*/
paint_quad_fill :: proc(painter: ^Painter, a, b, c, d: [2]f32, color: Color) {
	mesh := &painter.meshes[painter.target]
	color := color
	color.a = u8(f32(color.a) * painter.opacity)
	paint_indices(mesh, 
		mesh.vertices_offset,
		mesh.vertices_offset + 1,
		mesh.vertices_offset + 2,
		mesh.vertices_offset,
		mesh.vertices_offset + 2,
		mesh.vertices_offset + 3,
	)
	paint_vertices(mesh, 
		{point = a, color = color},
		{point = b, color = color},
		{point = c, color = color},
		{point = d, color = color},
	)
}
/*
	Paint a quad but define each vertex
*/
paint_quad_vertices :: proc(painter: ^Painter, a, b, c, d: Vertex) {
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
/*
	Triangl
*/
paint_triangle_fill :: proc(painter: ^Painter, a, b, c: [2]f32, color: Color) {
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
paint_triangle_stroke :: proc(painter: ^Painter, a, b, c: [2]f32, thickness: f32, color: Color) {
	paint_path_stroke(painter, {a, b, c}, true, 0, thickness, color)
}
/*
	Triangle strip
*/
paint_triangle_strip_fill :: proc(painter: ^Painter, points: [][2]f32, color: Color) {
	if len(points) < 4 {
		return
	}
	for i in 2 ..< len(points) {
		if i % 2 == 0 {
			paint_triangle_fill(
				painter,
				{points[i].x, points[i].y},
				{points[i - 2].x, points[i - 2].y},
				{points[i - 1].x, points[i - 1].y},
				color,
			)
		} else {
			paint_triangle_fill(
				painter,
				{points[i].x, points[i].y},
				{points[i - 1].x, points[i - 1].y},
				{points[i - 2].x, points[i - 2].y},
				color,
			)
		}
	}
}
/*
	Paint lines
*/
paint_line :: proc(painter: ^Painter, start, end: [2]f32, thickness: f32, color: Color) {
	delta := end - start
	length := math.sqrt(f32(delta.x * delta.x + delta.y * delta.y))
	if length > 0 && thickness > 0 {
		scale := thickness / (2 * length)
		radius: [2]f32 = {-scale * delta.y, scale * delta.x}
		paint_triangle_strip_fill(painter, {
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
paint_cubic_bezier_curve :: proc(painter: ^Painter, p0, p1, p2, p3: [2]f32, segments: int, thickness: f32, color: Color) {
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
		paint_line(painter, p, np, thickness, color)
		p = np
	}
}
// Paints an inner stroke along a given box
paint_box_stroke :: proc(painter: ^Painter, box: Box, thickness: f32, color: Color) {
	paint_box_fill(painter, {box.low, {box.high.x, box.low.y + thickness}}, color)
	paint_box_fill(painter, {{box.low.x, box.low.y + thickness}, {box.low.x + thickness, box.high.y - thickness}}, color)
	paint_box_fill(painter, {{box.high.x - thickness, box.low.y + thickness}, {box.high.x, box.high.y - thickness}}, color)
	paint_box_fill(painter, {{box.low.x, box.high.y - thickness}, box.high}, color)
}
// Paints a box stroke with a gap for text
paint_widget_frame :: proc(painter: ^Painter, box: Box, gap_offset, gap_size, thickness: f32, color: Color) {
	paint_box_fill(painter, {box.low, {box.low.x + gap_offset, box.low.y + thickness}}, color)
	paint_box_fill(painter, {{box.low.x + gap_offset + gap_size, box.low.y}, {box.high.x, box.low.y + thickness}}, color)
	paint_box_fill(painter, {{box.low.x, box.low.y + thickness}, {box.low.x + thickness, box.high.y - thickness}}, color)
	paint_box_fill(painter, {{box.high.x - thickness, box.low.y + thickness}, {box.high.x, box.high.y - thickness}}, color)
	paint_box_fill(painter, {{box.low.x, box.high.y - thickness}, box.high}, color)
}
// Paint a textured box clipped to the `clip` parameter
paint_clipped_textured_box :: proc(painter: ^Painter, texture: Texture, src, dst, clip: Box, tint: Color) {
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
	paint_textured_box(painter, texture, src, dst, tint)
}
// Paint a given texture on a box
paint_textured_box :: proc(painter: ^Painter, tex: Texture, src, dst: Box, tint: Color) {
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
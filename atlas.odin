package maui

import "core:math"
import "core:math/linalg"

MAX_RING_RADIUS :: 30
/*
	Get a pre-rasterized ring from the atlas or create one
*/
get_atlas_ring :: proc(painter: ^Painter, inner, outer: f32) -> (src: Box, ok: bool) {
	_inner := int(inner)
	_outer := int(outer)
	if _inner < 0 || _inner >= MAX_RING_RADIUS || _outer < 0 || _outer >= MAX_RING_RADIUS {
		return {}, false
	}
	ring := &painter.rings[_inner][_outer]
	if ring^ == nil {
		ring^, _ = add_atlas_ring(painter, inner, outer)
	}
	return ring^.?
}
/*
	Clear the atlas
		then add the one white pixel to the corner
		update the texture
*/
reset_atlas :: proc(painter: ^Painter) -> bool {
	destroy_image(&painter.image)

	WIDTH :: 4096
	HEIGHT :: 4096
	SIZE :: WIDTH * HEIGHT * 4
	painter.image = {
		data = make([]u8, SIZE),
		width = WIDTH,
		height = HEIGHT,
		channels = 4,
	}
	painter.image.data[0] = 255
	painter.image.data[1] = 255
	painter.image.data[2] = 255
	painter.image.data[3] = 255
	// Reset resources to nil so they will be rebuilt
	painter.rings = {}
	// Delete font sizes
	for i in 0..<MAX_FONTS {
		if font, ok := &painter.fonts[i].?; ok {
			for _, &size in font.sizes {
				destroy_font_size(&size)
			}
		}
	}
	// Reset cursor location
	painter.cursor = {1, 1}
	if painter.texture == {} {
		painter.texture = load_texture(painter, painter.image) or_return
	} else {
		update_texture(painter, painter.texture, painter.image, 0, 0, f32(painter.image.width), f32(painter.image.height))
	}
	return true
}
/*
	Add an image to the atlas and return it's location
*/
add_atlas_image :: proc(painter: ^Painter, content: Image) -> (src: Box, ok: bool) {
	box := get_atlas_box(painter, {f32(content.width), f32(content.height)})
	for x in int(box.low.x)..<int(box.high.x) {
		for y in int(box.low.y)..<int(box.high.y) {
			src_x := x - int(box.low.x)
			src_y := y - int(box.low.y)
			src_i := src_x + src_y * content.width
			i := (x + y * painter.image.width) * painter.image.channels
			painter.image.data[i] = 255
			painter.image.data[i + 1] = 255
			painter.image.data[i + 2] = 255
			painter.image.data[i + 3] = content.data[src_i]
		}
	}
	painter.should_update = true
	return box, true
}
/*
	Find space for something on the atlas
*/
get_atlas_box :: proc(painter: ^Painter, size: [2]f32) -> (box: Box) {
	if painter.cursor.x + size.x > f32(painter.image.width) {
		painter.cursor.x = 0
		painter.cursor.y += painter.row_height + 1
		painter.row_height = 0
	}
	if painter.cursor.y + size.y > f32(painter.image.height) {
		reset_atlas(painter)
	}
	box = {painter.cursor, painter.cursor + size}
	painter.cursor.x += size.x + 1
	painter.row_height = max(painter.row_height, size.y)
	return
}
/*
	Generate a anti-aliased ring and place in on the atlas
		Returns the location if it was successful
*/
add_atlas_ring :: proc(painter: ^Painter, inner, outer: f32) -> (src: Box, ok: bool) {
	if inner >= outer {
		return
	}
	box := get_atlas_box(painter, outer * 2)
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
			i := (x + y * painter.image.width) * painter.image.channels
			painter.image.data[i] = 255
			painter.image.data[i + 1] = 255
			painter.image.data[i + 2] = 255
			painter.image.data[i + 3] = u8(255.0 * alpha)
		}
	}
	painter.should_update = true
	return box, ok
}
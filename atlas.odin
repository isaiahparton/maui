package maui

import "core:math"
import "core:math/linalg"

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
/*
	Get a pre-rasterized ring from the atlas or create one
*/
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
/*
	Destroy the atlas and all it's fonts
		also unloads textures
*/
destroy_atlas :: proc(using self: ^Atlas) {
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
/*
	Clear the atlas
		then add the one white pixel to the corner
		update the texture
*/
reset_atlas :: proc(using self: ^Atlas) -> bool {
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

	// Reset resources to nil so they will be rebuilt
	rings = {}
	// Delete font sizes
	for i in 0..<MAX_FONTS {
		if font_exists[i] {
			for _, &size in fonts[i].sizes {
				destroy_font_size(&size)
			}
		}
	}

	cursor = {1, 1}

	if texture == {} {
		texture = load_texture(image) or_return
	} else {
		update_texture(texture, image, 0, 0, f32(image.width), f32(image.height))
	}
	return true
}
/*
	Add an image to the atlas and return it's location
*/
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
/*
	Find space for something on the atlas
*/
atlas_get_box :: proc(using self: ^Atlas, size: [2]f32) -> (box: Box) {
	if cursor.x + size.x > f32(image.width) {
		cursor.x = 0
		cursor.y += row_height + 1
		row_height = 0
	}
	if cursor.y + size.y > f32(image.height) {
		reset_atlas(self)
	}
	box = {cursor, cursor + size}
	cursor.x += size.x + 1
	row_height = max(row_height, size.y)
	return
}
/*
	Generate a anti-aliased ring and place in on the atlas
		Returns the location if it was successful
*/
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
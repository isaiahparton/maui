package maui

import "core:math"
import "core:math/linalg"

/*
	Simple boxes
*/
paint_box_fill :: proc(box: Box, color: Color) {
	paint_quad_fill(
		box.low,
		{box.low.x, box.high.y},
		box.high,
		{box.high.x, box.low.y},
		color,
	)
}
/*
	Pre-rasterized circles
*/
paint_circle_fill_texture :: proc(center: [2]f32, radius: f32, color: Color) {
	if src, ok := atlas_get_ring(&ctx.painter.atlas, 0, radius); ok {
		offset := (src.high - src.low) * 0.5
		paint_textured_box(ctx.painter.atlas.texture, src, {linalg.round(center - offset), linalg.round(center + offset)}, color)
	}
}
paint_ring_fill_texture :: proc(center: [2]f32, inner, outer: f32, color: Color) {
	if src, ok := atlas_get_ring(&ctx.painter.atlas, inner, outer); ok {
		offset := (src.high - src.low) * 0.5
		paint_textured_box(ctx.painter.atlas.texture, src, {linalg.round(center - offset), linalg.round(center + offset)}, color)
	}
}
/*
	Geometric circles
*/
paint_circle_fill :: proc(center: [2]f32, radius: f32, segments: int, color: Color) {
	paint_circle_sector_fill(center, radius, 0, math.TAU, segments, color)
}
// Paint only a slice of a circle
paint_circle_sector_fill :: proc(center: [2]f32, radius, start, end: f32, segments: int, color: Color) {
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
paint_circle_sector_mask :: proc(center: [2]f32, radius, start, end: f32, segments: int, color: Color) {
	step := (end - start) / f32(segments)
	angle := start
	for i in 0..<segments {
		paint_triangle_mask(
			center, 
			center + {math.cos(angle + step) * radius, math.sin(angle + step) * radius}, 
			center + {math.cos(angle) * radius, math.sin(angle) * radius}, 
			color,
		)
		angle += step;
	}
}
paint_radial_gradient_sector :: proc(center: [2]f32, radius, start, end: f32, segments: int, inner, outer: Color) {
	step := (end - start) / f32(segments)
	angle := start
	for i in 0..<segments {
		mesh := &ctx.painter.meshes[ctx.painter.target]
		paint_indices(mesh, 
			mesh.vertices_offset,
			mesh.vertices_offset + 1,
			mesh.vertices_offset + 2,
		)
		paint_vertices(mesh, 
			{point = center, color = inner},
			{point = center + {math.cos(angle + step) * radius, math.sin(angle + step) * radius}, color = outer},
			{point = center + {math.cos(angle) * radius, math.sin(angle) * radius}, color = outer},
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
/*
	Symbols
*/
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
	ctx.painter.next_frame = true
}
paint_check :: proc(center: [2]f32, scale: f32, color: Color) {
	a, b, c: [2]f32 = {-1, -0.047} * scale, {-0.333, 0.619} * scale, {1, -0.713} * scale
	stroke_path({center + a, center + b, center + c}, false, 1, color)
}
/*
	Basic gradients
*/
paint_gradient_box_v :: proc(box: Box, top, bottom: Color) {
	paint_quad_vertices(
		{point = box.low, color = top},
		{point = {box.low.x, box.high.y}, color = bottom},
		{point = box.high, color = bottom},
		{point = {box.high.x, box.low.y}, color = top},
	)
}
paint_gradient_box_h :: proc(box: Box, left, right: Color) {
	paint_quad_vertices(
		{point = box.low, color = left},
		{point = {box.low.x, box.high.y}, color = left},
		{point = box.high, color = right},
		{point = {box.high.x, box.low.y}, color = right},
	)
}

/*
	Rounded boxes
*/
paint_rounded_box_fill :: proc(box: Box, radius: f32, color: Color) {
	if box.high.x <= box.low.x || box.high.y <= box.low.y {
		return
	}
	if radius == 0 {
		paint_box_fill(box, color)
		return
	}
	if src, ok := atlas_get_ring(&ctx.painter.atlas, 0, radius); ok {
		src_center := center(src)
		tl_src: Box = {src.low, src_center}
		tr_src: Box = {{src_center.x, src.low.y}, {src.high.x, src_center.y}}
		bl_src: Box = {{src.low.x, src_center.y}, {src_center.x, src.high.y}}
		br_src: Box = {src_center, src.high}

		tl_dst: Box = {box.low, box.low + radius}
		tr_dst: Box = {{box.high.x - radius, box.low.y}, {box.high.x, box.low.y + radius}}
		bl_dst: Box = {{box.low.x, box.high.y - radius}, {box.low.x + radius, box.high.y}}
		br_dst: Box = {box.high - radius, box.high}

		paint_clipped_textured_box(ctx.painter.atlas.texture, tl_src, tl_dst, box, color)
		paint_clipped_textured_box(ctx.painter.atlas.texture, tr_src, tr_dst, box, color)
		paint_clipped_textured_box(ctx.painter.atlas.texture, bl_src, bl_dst, box, color)
		paint_clipped_textured_box(ctx.painter.atlas.texture, br_src, br_dst, box, color)

		if box.high.x > box.low.x + radius * 2 {
			paint_box_fill({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.high.y}}, color)
		}
		if box.high.y > box.low.y + radius * 2 {
			paint_box_fill({{box.low.x, box.low.y + radius}, {box.low.x + radius, box.high.y - radius}}, color)
			paint_box_fill({{box.high.x - radius, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color)
		}
	}
}

paint_rounded_box_stroke :: proc(box: Box, radius, thickness: f32, color: Color) {
	if (box.high.x <= box.low.x) || (box.high.y <= box.low.y) {
		return
	}
	if radius == 0 {
		paint_box_stroke(box, thickness, color)
		return
	}
	if src, ok := atlas_get_ring(&ctx.painter.atlas, radius - thickness, radius); ok {
		src_center := center(src)
		tl_src: Box = {src.low, src_center}
		tr_src: Box = {{src_center.x, src.low.y}, {src.high.x, src_center.y}}
		bl_src: Box = {{src.low.x, src_center.y}, {src_center.x, src.high.y}}
		br_src: Box = {src_center, src.high}

		tl_dst: Box = {box.low, box.low + radius}
		tr_dst: Box = {{box.high.x - radius, box.low.y}, {box.high.x, box.low.y + radius}}
		bl_dst: Box = {{box.low.x, box.high.y - radius}, {box.low.x + radius, box.high.y}}
		br_dst: Box = {box.high - radius, box.high}

		paint_textured_box(ctx.painter.atlas.texture, tl_src, tl_dst, color)
		paint_textured_box(ctx.painter.atlas.texture, tr_src, tr_dst, color)
		paint_textured_box(ctx.painter.atlas.texture, bl_src, bl_dst, color)
		paint_textured_box(ctx.painter.atlas.texture, br_src, br_dst, color)

		paint_box_fill({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.low.y + thickness}}, color)
		paint_box_fill({{box.low.x, box.low.y + radius}, {box.low.x + thickness, box.high.y - radius}}, color)
		paint_box_fill({{box.high.x - thickness, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color)
		paint_box_fill({{box.low.x + radius, box.high.y - thickness}, {box.high.x - radius, box.high.y}}, color)
	}
}
/*
	Draw a rounded box stroke but choose which corners are rounded
*/
paint_rounded_box_corners_stroke :: proc(box: Box, radius, thickness: f32, corners: Box_Corners, color: Color) {
	if radius == 0 || corners == {} {
		paint_box_stroke(box, thickness, color)
		return
	}
	if (box.high.x <= box.low.x) || (box.high.y <= box.low.y) {
		return
	}
	if src, ok := atlas_get_ring(&ctx.painter.atlas, radius - thickness, radius); ok {
		src_center := center(src)

		top_left := box.low.x 
		top_right := box.high.x 
		bottom_left := box.low.x
		bottom_right := box.high.x
		left_top := box.low.y
		left_bottom := box.high.y
		right_top := box.low.y
		right_bottom := box.high.y

		if .Top_Left in corners {
			paint_textured_box(ctx.painter.atlas.texture, {src.low, src_center}, {box.low, box.low + radius}, color)
			top_left += radius
			left_top += radius
		}
		if .Top_Right in corners {
			paint_textured_box(ctx.painter.atlas.texture, {{src_center.x, src.low.y}, {src.high.x, src_center.y}}, {{box.high.x - radius, box.low.y}, {box.high.x, box.low.y + radius}}, color)
			top_right -= radius
			right_top += radius
		}
		if .Bottom_Left in corners {
			paint_textured_box(ctx.painter.atlas.texture, {{src.low.x, src_center.y}, {src_center.x, src.high.y}}, {{box.low.x, box.high.y - radius}, {box.low.x + radius, box.high.y}}, color)
			bottom_left += radius
			left_bottom -= radius
		}
		if .Bottom_Right in corners {
			paint_textured_box(ctx.painter.atlas.texture, {src_center, src.high}, {box.high - radius, box.high}, color)
			bottom_right -= radius
			right_bottom -= radius
		}

		paint_box_fill({{top_left, box.low.y}, {top_right, box.low.y + thickness}}, color)
		paint_box_fill({{box.low.x, left_top}, {box.low.x + thickness, left_bottom}}, color)
		paint_box_fill({{box.high.x - thickness, right_top}, {box.high.x, right_bottom}}, color)
		paint_box_fill({{bottom_left, box.high.y - thickness}, {bottom_right, box.high.y}}, color)
	}
}

paint_rounded_box_corners_fill :: proc(box: Box, radius: f32, corners: Box_Corners, color: Color) {
	if box.high.x <= box.low.x || box.high.y <= box.low.y {
		return
	}
	if radius == 0 || corners == {} {
		paint_box_fill(box, color)
		return
	}
	if src, ok := atlas_get_ring(&ctx.painter.atlas, 0, radius); ok {
		src_center := center(src)

		tl_dst: Box = {box.low, box.low + radius}
		if .Top_Left in corners {
			tl_src: Box = {src.low, src_center}
			paint_clipped_textured_box(ctx.painter.atlas.texture, tl_src, tl_dst, box, color)
		} else {
			paint_box_fill(tl_dst, color)
		}
		tr_dst: Box = {{box.high.x - radius, box.low.y}, {box.high.x, box.low.y + radius}}
		if .Top_Right in corners {
			tr_src: Box = {{src_center.x, src.low.y}, {src.high.x, src_center.y}}
			paint_clipped_textured_box(ctx.painter.atlas.texture, tr_src, tr_dst, box, color)
		} else {
			paint_box_fill(tr_dst, color)
		}
		bl_dst: Box = {{box.low.x, box.high.y - radius}, {box.low.x + radius, box.high.y}}
		if .Bottom_Left in corners {
			bl_src: Box = {{src.low.x, src_center.y}, {src_center.x, src.high.y}}
			paint_clipped_textured_box(ctx.painter.atlas.texture, bl_src, bl_dst, box, color)
		} else {
			paint_box_fill(bl_dst, color)
		}
		br_dst: Box = {box.high - radius, box.high}
		if .Bottom_Right in corners {
			br_src: Box = {src_center, src.high}
			paint_clipped_textured_box(ctx.painter.atlas.texture, br_src, br_dst, box, color)
		} else {
			paint_box_fill(br_dst, color)
		}

		if box.high.x > box.low.x + radius * 2 {
			paint_box_fill({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.high.y}}, color)
		}
		paint_box_fill({{box.low.x, box.low.y + radius}, {box.low.x + radius, box.high.y - radius}}, color)
		paint_box_fill({{box.high.x - radius, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color)
	}
}

paint_rounded_box_shadow :: proc(box: Box, radius: f32, color: Color) {
	paint_gradient_box_v({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.low.y + radius}}, {}, color)
	paint_gradient_box_v({{box.low.x + radius, box.high.y - radius}, {box.high.x - radius, box.high.y}}, color, {})
	paint_gradient_box_h({{box.low.x, box.low.y + radius}, {box.low.x + radius, box.high.y - radius}}, {}, color)
	paint_gradient_box_h({{box.high.x - radius, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color, {})
	paint_box_fill({box.low + radius, box.high - radius}, color)
	segments := int(radius)
	paint_radial_gradient_sector(box.low + radius, radius, -math.PI / 2, -math.PI, segments, color, {})
	paint_radial_gradient_sector({box.low.x + radius, box.high.y - radius}, radius, math.PI, math.PI / 2, segments, color, {})
	paint_radial_gradient_sector({box.high.x - radius, box.low.y + radius}, radius, -math.PI / 2, 0, segments, color, {})
	paint_radial_gradient_sector(box.high - radius, radius, 0, math.PI / 2, segments, color, {})
}

/*
	Horizontal pill (simplified rounded box)
*/
paint_pill_fill_h :: proc(box: Box, color: Color) {
	size := box.high - box.low
	radius := math.floor(size.y / 2)
	if src, ok := atlas_get_ring(&ctx.painter.atlas, 0, radius); ok {
		half_size := math.trunc(width(src) / 2)
		half_width := min(half_size, size.x / 2)

		src_left: Box = {src.low, {src.low.x + half_width, src.high.y}}
		src_right: Box = {{src.high.x - half_width, src.low.y}, src.high}

		paint_textured_box(ctx.painter.atlas.texture, src_left, {box.low, {box.low.x + half_width, box.high.y}}, color)
		paint_textured_box(ctx.painter.atlas.texture, src_right, {{box.high.x - half_width, box.low.y}, box.high}, color)

		if box.high.x > box.low.x + size.y {
			paint_box_fill({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.high.y}}, color)
		}
	}
}
paint_clipped_pill_fill_h :: proc(box: Box, clip: Box, color: Color) {
	size := box.high - box.low
	radius := math.floor(size.y / 2)
	if src, ok := atlas_get_ring(&ctx.painter.atlas, 0, radius); ok {
		half_size := math.trunc(width(src) / 2)
		half_width := min(half_size, size.x / 2)

		src_left: Box = {src.low, {src.low.x + half_width, src.high.y}}
		src_right: Box = {{src.high.x - half_width, src.low.y}, src.high}

		paint_clipped_textured_box(ctx.painter.atlas.texture, src_left, {box.low, {box.low.x + half_width, box.high.y}}, clip, color)
		paint_clipped_textured_box(ctx.painter.atlas.texture, src_right, {{box.high.x - half_width, box.low.y}, box.high}, clip, color)

		if box.high.x > box.low.x + size.y {
			paint_box_fill(clamp_box({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.high.y}}, clip), color)
		}
	}
}
paint_pill_stroke_h :: proc(box: Box, thickness: f32, color: Color) {
	radius := math.floor(height(box) / 2)
	if src, ok := atlas_get_ring(&ctx.painter.atlas, radius - thickness, radius); ok {
		half_size := math.trunc(width(src) / 2)
		half_width := min(half_size, width(box) / 2)

		src_left: Box = {src.low, {src.low.x + half_width, src.high.y}}
		src_right: Box = {{src.high.x - half_width, src.low.y}, src.high}

		paint_textured_box(ctx.painter.atlas.texture, src_left, {box.low, {box.low.x + half_width, box.high.y}}, color)
		paint_textured_box(ctx.painter.atlas.texture, src_right, {{box.high.x - half_width, box.low.y}, box.high}, color)

		paint_box_fill({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.low.y + thickness}}, color)
		paint_box_fill({{box.low.x + radius, box.high.y - thickness}, {box.high.x - radius, box.high.y}}, color)
	}
}
/*
	Vertical pill (simplified rounded box)
*/
paint_pill_fill_v :: proc(box: Box, color: Color) {
	size := box.high - box.low
	radius := math.floor(size.x / 2)
	if src, ok := atlas_get_ring(&ctx.painter.atlas, 0, radius); ok {
		half_size := math.trunc(height(src) / 2)
		half_height := min(half_size, size.y / 2)

		src_top: Box = {src.low, {src.high.x, src.low.y + half_height}}
		src_bottom: Box = {{src.low.x, src.high.y - half_height}, src.high}

		paint_textured_box(ctx.painter.atlas.texture, src_top, {box.low, {box.high.x, box.low.y + half_height}}, color)
		paint_textured_box(ctx.painter.atlas.texture, src_bottom, {{box.low.x, box.high.y - half_height}, box.high}, color)

		if box.high.y > box.low.y + size.x {
			paint_box_fill({{box.low.x, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color)
		}
	}
}
/*
	Ribbons
*/
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
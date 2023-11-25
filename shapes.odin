package maui

import "core:math"
import "core:math/linalg"

paint_rounded_box_mask :: proc(box: Box, radius: f32, color: Color) {
	paint_box_mask({{box.low.x, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color)
	paint_box_mask({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.high.y}}, color)
	segments := int(radius)
	paint_circle_sector_mask(box.low + radius, radius, -math.PI / 2, -math.PI, segments, color)
	paint_circle_sector_mask({box.low.x + radius, box.high.y - radius}, radius, math.PI, math.PI / 2, segments, color)
	paint_circle_sector_mask({box.high.x - radius, box.low.y + radius}, radius, math.PI, -math.PI / 2, segments, color)
	paint_circle_sector_mask(box.high - radius, radius, 0, math.PI / 2, segments, color)
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
		if box.high.y > box.low.y + radius * 2 {
			paint_box_fill({{box.low.x, box.low.y + radius}, {box.low.x + radius, box.high.y - radius}}, color)
			paint_box_fill({{box.high.x - radius, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color)
		}
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

paint_rounded_box_stroke :: proc(box: Box, radius, thickness: f32, color: Color) {
	if (box.high.x <= box.low.x) || (box.high.y <= box.low.y) {
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
	if src, ok := atlas_get_ring(&painter.atlas, radius - thickness, radius); ok {
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
			paint_textured_box(painter.atlas.texture, {src.low, src_center}, {box.low, box.low + radius}, color)
			top_left += radius
			left_top += radius
		}
		if .Top_Right in corners {
			paint_textured_box(painter.atlas.texture, {{src_center.x, src.low.y}, {src.high.x, src_center.y}}, {{box.high.x - radius, box.low.y}, {box.high.x, box.low.y + radius}}, color)
			top_right -= radius
			right_top += radius
		}
		if .Bottom_Left in corners {
			paint_textured_box(painter.atlas.texture, {{src.low.x, src_center.y}, {src_center.x, src.high.y}}, {{box.low.x, box.high.y - radius}, {box.low.x + radius, box.high.y}}, color)
			bottom_left += radius
			left_bottom -= radius
		}
		if .Bottom_Right in corners {
			paint_textured_box(painter.atlas.texture, {src_center, src.high}, {box.high - radius, box.high}, color)
			bottom_right -= radius
			right_bottom -= radius
		}

		paint_box_fill({{top_left, box.low.y}, {top_right, box.low.y + thickness}}, color)
		paint_box_fill({{box.low.x, left_top}, {box.low.x + thickness, left_bottom}}, color)
		paint_box_fill({{box.high.x - thickness, right_top}, {box.high.x, right_bottom}}, color)
		paint_box_fill({{bottom_left, box.high.y - thickness}, {bottom_right, box.high.y}}, color)
	}
}
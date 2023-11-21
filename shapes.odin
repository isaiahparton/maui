package maui

paint_rounded_box_mask :: proc(box: Box, radius: f32, color: Color) {
	paint_box_mask({{box.low.x, box.low.y + radius}, {box.high.x, box.high.y - radius}}, color)
	paint_box_mask({{box.low.x + radius, box.low.y}, {box.high.x - radius, box.high.y}}, color)
	segments := int(radius)
	paint_circle_sector_mask(box.low + radius, radius, -math.PI / 2, -math.PI, segments, color)
	paint_circle_sector_mask({box.low.x + radius, box.high.y - radius}, radius, 0, -math.PI / 2, segments, color)
	paint_circle_sector_mask({box.high.x - radius, box.low.y + radius}, radius, math.PI, math.PI / 2, segments, color)
	paint_circle_sector_mask(box.high - radius, radius, -math.PI / 2, -math.PI, segments, color)
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
	paint_box_fill(box, color)
	paint_quad_vertices(
		{point = {box.low.x, box.low.y}, color = color},
		{point = {box.low.x - radius, box.low.y}},
		{point = {box.low.x - radius, box.high.y}},
		{point = {box.low.x, box.high.y}, color = color},
	)
	paint_quad_vertices(
		{point = {box.high.x + radius, box.low.y}},
		{point = {box.high.x, box.low.y}, color = color},
		{point = {box.high.x, box.high.y}, color = color},
		{point = {box.high.x + radius, box.high.y}},
	)
	paint_quad_vertices(
		{point = {box.low.x, box.low.y}, color = color},
		{point = {box.high.x, box.low.y}, color = color},
		{point = {box.high.x, box.low.y - radius}},
		{point = {box.low.x, box.low.y - radius}},
	)
	paint_quad_vertices(
		{point = {box.low.x, box.high.y}, color = color},
		{point = {box.high.x, box.high.y}, color = color},
		{point = {box.high.x, box.high.y + radius}},
		{point = {box.low.x, box.high.y + radius}},
	)
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
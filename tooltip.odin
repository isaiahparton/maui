package maui

/*
	Tooltips
*/
Tooltip_Info :: struct {
	text: string,
	box_side: Box_Side,
}
Tooltip_Result :: struct {
	layer: Maybe(^Layer),
}
/*
	Deploy a tooltip layer aligned to a given side of the origin
*/
tooltip :: proc(ui: ^UI, id: Id, text: string, origin: [2]f32, align: [2]Alignment, side: Maybe(Box_Side) = nil) -> Tooltip_Result {
	text_size := measure_text(ui.painter, {
		text = text,
		font = ui.style.font.title,
		size = ui.style.text_size.tooltip,
	})
	size := text_size + ui.style.tooltip_padding * 2
	box: Box
	switch align.x {
		case .Near: box.low.x = origin.x
		case .Far: box.low.x = origin.x - size.x
		case .Middle: box.low.x = origin.x - size.x / 2
	}
	switch align.y {
		case .Near: box.low.y = origin.y
		case .Far: box.low.y = origin.y - size.y
		case .Middle: box.low.y = origin.y - size.y / 2
	}
	box.high = box.low + size
	result: Tooltip_Result
	if layer, ok := begin_layer(ui, {
		placement = box, 
		id = id,
		options = {.No_Scroll_X, .No_Scroll_Y},
	}); ok {
		result.layer = layer
		layer.order = .Tooltip
		fill_color: Color = ui.style.color.accent
		paint_rounded_box_fill(ui.painter, layer.box, ui.style.tooltip_rounding, fill_color)
		if side, ok := side.?; ok {
			SIZE :: 5
			#partial switch side {
				case .Bottom: 
				c := (layer.box.high.x + layer.box.low.x) / 2
				paint_triangle_fill(ui.painter, {c - SIZE, layer.box.low.y}, {c + SIZE, layer.box.low.y}, {c, layer.box.low.y - SIZE}, fill_color)
				case .Top:
				c := (layer.box.high.x + layer.box.low.x) / 2
				paint_triangle_fill(ui.painter, {c - SIZE, layer.box.high.y}, {c, layer.box.high.y + SIZE}, {c + SIZE, layer.box.high.y}, fill_color)
				case .Right:
				c := (layer.box.low.y + layer.box.high.y) / 2
				paint_triangle_fill(ui.painter, {layer.box.low.x, c - SIZE}, {layer.box.low.x, c + SIZE}, {layer.box.low.x - SIZE, c}, fill_color)
				case .Left:
				c := (layer.box.low.y + layer.box.high.y) / 2
				paint_triangle_fill(ui.painter, {layer.box.high.x, c - SIZE}, {layer.box.high.x + SIZE, c}, {layer.box.high.x, c + SIZE}, fill_color)
			}
		}
		paint_text(
			ui.painter,
			layer.box.low + ui.style.tooltip_padding, 
			{font = ui.style.font.title, size = ui.style.text_size.tooltip, text = text},
			ui.style.color.accent_text,
			)
		end_layer(ui, layer)
	}
	return result
}
/*
	Helper proc for displaying a tooltip attached to a box
*/
tooltip_box ::proc(ui: ^UI, id: Id, text: string, anchor: Box, side: Box_Side, offset: f32) {
	origin: [2]f32
	align: [2]Alignment
	switch side {
		case .Bottom:		
		origin.x = (anchor.low.x + anchor.high.x) / 2
		origin.y = anchor.high.y + offset
		align.x = .Middle
		align.y = .Near
		case .Left:
		origin.x = anchor.low.x - offset
		origin.y = (anchor.low.y + anchor.high.y) / 2
		align.x = .Near
		align.y = .Middle
		case .Right:
		origin.x = anchor.high.x - offset
		origin.y = (anchor.low.y + anchor.high.y) / 2
		align.x = .Far
		align.y = .Middle
		case .Top:
		origin.x = (anchor.low.x + anchor.high.x) / 2
		origin.y = anchor.low.y - offset
		align.x = .Middle
		align.y = .Far
	}
	tooltip(ui, id, text, origin, align, side)
}
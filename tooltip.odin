package maui

/*
	Tooltips
*/
Tooltip_Info :: struct {
	text: string,
	box_side: Box_Side,
}
/*
	Deploy a tooltip layer aligned to a given side of the origin
*/
tooltip :: proc(ui: ^UI, id: Id, text: string, origin: [2]f32, align: [2]Alignment, side: Maybe(Box_Side) = nil) {
	text_size := measure_text(ui.painter, {
		text = text,
		font = ui.style.font.title,
		size = ui.style.text_size.title,
	})
	PADDING :: 3
	size := text_size + PADDING * 2
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
	if layer, ok := begin_layer(ui, {
		placement = box, 
		id = id,
		options = {.No_Scroll_X, .No_Scroll_Y},
	}); ok {
		layer.order = .Tooltip
		BLACK :: Color{0, 0, 0, 255}
		paint_rounded_box_fill(ui.painter, layer.box, ui.style.tooltip_rounding, {0, 0, 0, 255})
		if side, ok := side.?; ok {
			SIZE :: 5
			#partial switch side {
				case .Bottom: 
				c := (layer.box.high.x + layer.box.low.x) / 2
				paint_triangle_fill(ui.painter, {c - SIZE, layer.box.low.y}, {c + SIZE, layer.box.low.y}, {c, layer.box.low.y - SIZE}, BLACK)
				case .Top:
				c := (layer.box.high.x + layer.box.low.x) / 2
				paint_triangle_fill(ui.painter, {c - SIZE, layer.box.high.y}, {c, layer.box.high.y + SIZE}, {c + SIZE, layer.box.high.y}, BLACK)
				case .Right:
				c := (layer.box.low.y + layer.box.high.y) / 2
				paint_triangle_fill(ui.painter, {layer.box.low.x, c - SIZE}, {layer.box.low.x, c + SIZE}, {layer.box.low.x - SIZE, c}, BLACK)
				case .Left:
				c := (layer.box.low.y + layer.box.high.y) / 2
				paint_triangle_fill(ui.painter, {layer.box.high.x, c - SIZE}, {layer.box.high.x + SIZE, c}, {layer.box.high.x, c + SIZE}, BLACK)
			}
		}
		paint_text(
			ui.painter,
			layer.box.low + PADDING, 
			{font = ui.style.font.title, size = ui.style.text_size.title, text = text},
			255,
			)
		end_layer(ui, layer)
	}
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
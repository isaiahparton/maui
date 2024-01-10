package maui
import "core:fmt"

Attached_Layer_Mode :: enum {
	Focus,
	Hover,
}

Attached_Layer_Info :: struct {
	id: Maybe(Id),
	mode: Attached_Layer_Mode,
	grow: Maybe(Direction),
	side: Maybe(Box_Side),
	align: Maybe(Alignment),
	fill_color: Maybe(Color),
	stroke_color: Maybe(Color),
	layer_options: Layer_Options,
	opacity: Maybe(f32),
	shadow: Maybe(Layer_Shadow_Info),
}

Attached_Layer_Result :: struct {
	dismissed: bool,
	self: ^Layer,
}

// Main attached layer functionality
begin_attached_layer :: proc(ui: ^UI, result: Generic_Widget_Result, info: Attached_Layer_Info) -> (layer: ^Layer, ok: bool) {
	if widget, k := result.self.?; k {

	}
	if ok {
		side := info.side.? or_else .Bottom
		// Determine layout
		anchor := result.self.?.box

		placement_info: Layer_Placement_Info

		switch side {
			case .Bottom: 
			placement_info.origin = {anchor.low.x, anchor.high.y}
			placement_info.size.x = width(anchor)
			case .Left: 
			placement_info.origin = anchor.low
			placement_info.align = {.Far, .Near}
			placement_info.size.x = width(anchor)
			case .Right: 
			placement_info.origin = {anchor.high.x, anchor.low.y}
			placement_info.size.x = width(anchor)
			case .Top: 
			placement_info.origin = anchor.low
			placement_info.align = {.Near, .Far}
			placement_info.size.x = width(anchor)
		}

		// Begin the new layer
		layer, ok = begin_layer(ui, {
			id = info.id.? or_else result.self.?.id, 
			placement = placement_info,
			grow = info.grow,
			options = info.layer_options + {.Attached},
			opacity = info.opacity,
			owner = result.self.? or_else nil,
		})

		if ok {
			// Paint the fill color
			if info.fill_color != nil {
				paint_box_fill(ui.painter, layer.box, info.fill_color.?)
			}
		}
	}
	return
}

end_attached_layer :: proc(ui: ^UI, info: Attached_Layer_Info, layer: ^Layer) {
	// Check if the layer was dismissed by input
	if widget, ok := layer.owner.?; ok {
		dismiss: bool
		switch info.mode {
			case .Focus:
			dismiss = (.Focused not_in (widget.state | widget.last_state)) && (layer.state & {.Focused} == {})
			case .Hover:
			dismiss = (.Hovered not_in widget.state) && (.Hovered not_in (layer.state | layer.last_state))
		}
		if .Dismissed in layer.bits || dismiss || key_pressed(ui.io, .Escape) {
			ui.painter.next_frame = true
			if dismiss {
				ui.open_menus = false
			}
		}
	}

	// Paint stroke color
	if info.stroke_color != nil {
		paint_box_stroke(ui.painter, layer.box, 1, info.stroke_color.?)
	}

	// End the layer
	end_layer(ui, layer)
}

@(deferred_in_out=_attached_layer)
attached_layer :: proc(ui: ^UI, result: Generic_Widget_Result, info: Attached_Layer_Info) -> (layer: ^Layer, ok: bool) {
	return begin_attached_layer(ui, result, info)
}
_attached_layer :: proc(ui: ^UI, _: Generic_Widget_Result, info: Attached_Layer_Info, layer: ^Layer, ok: bool) {
	if ok {
		end_attached_layer(ui, info, layer)
	}
}
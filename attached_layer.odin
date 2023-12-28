package maui

Attached_Layer_Parent :: union {
	Box,
	^Widget,
}

Attached_Layer_Mode :: enum {
	Focus,
	Hover,
}

Attached_Layer_Info :: struct {
	id: Maybe(Id),
	mode: Attached_Layer_Mode,
	parent: Attached_Layer_Parent,
	size: [2]f32,
	grow: Maybe(Box_Side),
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
begin_attached_layer :: proc(info: Attached_Layer_Info) -> (result: Attached_Layer_Result, ok: bool) {
	if widget, is_widget := info.parent.(^Widget); is_widget {
		ok = .Menu_Open in widget.bits
		if .Menu_Open not_in widget.bits {
			switch info.mode {
				case .Focus:
				if .Focused in widget.state && .Menu_Open not_in widget.bits {
					widget.bits += {.Menu_Open}
				}
				case .Hover:
				if .Hovered in widget.state && .Menu_Open not_in widget.bits {
					widget.bits += {.Menu_Open}
				}
			}
		}
	}
	if ok {
		side := info.side.? or_else .Bottom
		// Determine layout
		anchor := info.parent.(Box) or_else info.parent.(^Widget).box

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
		result.self, ok = begin_layer({
			id = info.id.? or_else info.parent.(^Widget).id, 
			placement = placement_info,
			grow = info.grow,
			options = info.layer_options + {.Attached},
			opacity = info.opacity,
			owner = info.parent.(^Widget) or_else nil,
			shadow = info.shadow,
		})

		if ok {
			// Paint the fill color
			if info.fill_color != nil {
				paint_box_fill(result.self.box, info.fill_color.?)
			}
		}
	}
	return
}

end_attached_layer :: proc(info: Attached_Layer_Info, layer: ^Layer) {
	// Check if the layer was dismissed by input
	if widget, ok := layer.owner.?; ok {
		dismiss: bool
		switch info.mode {
			case .Focus:
			dismiss = (.Focused not_in widget.state | widget.last_state) && (layer.state & {.Focused} == {})
			case .Hover:
			dismiss = (.Hovered not_in widget.state) && (.Hovered not_in layer.state | layer.last_state)
		}
		if .Dismissed in layer.bits || dismiss || key_pressed(.Escape) {
			widget.bits -= {.Menu_Open}
			ctx.painter.next_frame = true
			if dismiss {
				ctx.open_menus = false
			}
		}
	}

	// Paint stroke color
	if info.stroke_color != nil {
		paint_rounded_box_stroke(layer.box, ctx.style.rounding, 2, info.stroke_color.?)
	}

	// End the layer
	end_layer(layer)
}

@(deferred_in_out=_do_attached_layer)
do_attached_layer :: proc(info: Attached_Layer_Info) -> (result: Attached_Layer_Result, ok: bool) {
	return begin_attached_layer(info)
}
_do_attached_layer :: proc(info: Attached_Layer_Info, result: Attached_Layer_Result, ok: bool) {
	if ok {
		end_attached_layer(info, result.self)
	}
}
package maui
import "core:runtime"
import "core:fmt"

Attached_Layer_Parent :: union {
	Box,
	^Widget,
}

Attached_Layer_Info :: struct {
	id: Maybe(Id),
	parent: Attached_Layer_Parent,
	size: [2]f32,
	layout_size: Maybe([2]f32),
	side: Maybe(Box_Side),
	align: Maybe(Alignment),
	fill_color: Maybe(Color),
	stroke_color: Maybe(Color),
	layer_options: Layer_Options,
}

Attached_Layer_Result :: struct {
	dismissed: bool,
	self: ^Layer,
}

// Main attached layer functionality
@private 
begin_attached_layer :: proc(info: Attached_Layer_Info) -> (result: Attached_Layer_Result, ok: bool) {
	if widget, is_widget := info.parent.(^Widget); is_widget {
		ok = .Menu_Open in widget.bits
		if .Got_Press in widget.state {
			widget.bits ~= {.Menu_Open}
		}
		if .Focused in widget.state && .Menu_Open not_in widget.bits {
			widget.bits += {.Menu_Open}
		}
	}
	if ok {
		side := info.side.? or_else .Bottom
		// Determine layout
		horizontal := side == .Left || side == .Right
		anchor_box := info.parent.(Box) or_else info.parent.(^Widget).box

		box: Box = attach_box(anchor_box, side, info.size.x if horizontal else info.size.y)

		if horizontal {
			box.h = max(info.size.y, anchor_box.h)
			if info.align == .Middle {
				box.y = anchor_box.y + anchor_box.h / 2 - info.size.y / 2
			} else if info.align == .Far {
				box.y = anchor_box.y + anchor_box.h - info.size.y
			}
		} else {
			box.w = max(info.size.x, anchor_box.w)
			if info.align == .Middle {
				box.x = anchor_box.x + anchor_box.w / 2 - info.size.x / 2
			} else if info.align == .Far {
				box.x = anchor_box.x + anchor_box.w - info.size.x
			}	
		}

		// Begin the new layer
		result.self, ok = begin_layer({
			id = info.id.? or_else info.parent.(^Widget).id, 
			box = box, 
			layout_size = info.layout_size.? or_else {},
			options = info.layer_options + {.Attached},
			shadow = Layer_Shadow_Info({
				offset = SHADOW_OFFSET,
			}),
		})

		if ok {
			// Paint the fill color
			if info.fill_color != nil {
				paint_box_fill(result.self.box, info.fill_color.?)
			}

			// Check if the layer was dismissed by input
			if widget, ok := info.parent.(^Widget); ok {
				if .Dismissed in result.self.bits || (.Focused not_in result.self.state && .Focused not_in widget.state) {
					widget.bits -= {.Menu_Open}
					core.paint_next_frame = true
				}
			}
		}
	}
	return
}

@private
end_attached_layer :: proc(info: Attached_Layer_Info, layer: ^Layer) {
	if (.Hovered not_in layer.state && .Hovered not_in layer.parent.state && mouse_pressed(.Left)) || key_pressed(.Escape) {
		layer.bits += {.Dismissed}
	}	

	// Paint stroke color
	if info.stroke_color != nil {
		paint_box_stroke(layer.box, 1, info.stroke_color.?)
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

Menu_Info :: struct {
	label: Label,
	title: Maybe(string),
	size: [2]f32,
	align: Maybe(Alignment),
	side: Maybe(Box_Side),
	layer_align: Maybe(Alignment),
	layout_size: Maybe([2]f32),
}

Menu_Result :: struct {
	layer_result: Attached_Layer_Result,
	active: bool,
}

// Menu starting point
@(deferred_out=_do_menu)
do_menu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id, use_next_box() or_else layout_next(current_layout())); ok {
		using self
		// Animation
		push_id(id) 
			hover_time := animate_bool(hash_int(0), .Hovered in state, 0.15)
			state_time := animate_bool(hash_int(1), active, 0.125)
		pop_id()
		// Painting
		if .Should_Paint in bits {
			paint_box_fill(box, alpha_blend_colors(get_color(.Widget_BG), get_color(.Widget_Shade), 0.2 if .Pressed in state else hover_time * 0.1))
			paint_labeled_widget_frame(box, info.title, WIDGET_TEXT_OFFSET, 1, get_color(.Base_Stroke, 0.5 + 0.5 * hover_time))
			paint_rotating_arrow({box.x + box.w - box.h / 2, box.y + box.h / 2}, 6, -1 + state_time, get_color(.Text))
			paint_label_box(info.label, shrink_box_separate(box, {box.h * 0.25, 0}), get_color(.Text), {info.align.? or_else .Near, .Middle})
		}
		// Begin layer if expanded
		result: Attached_Layer_Result
		result, active = begin_attached_layer({
			id = shared_id,
			parent = self,
			side = .Bottom,
			size = info.size,
			layout_size = info.layout_size,
			align = info.layer_align,
		})
		if active {
			push_color(.Base, get_color(.Widget_BG))
		}
	}
	return
}

@private 
_do_menu :: proc(active: bool) {
	if active {
		end_attached_layer({
			stroke_color = get_color(.Base_Stroke),
		}, current_layer())
		pop_color()
	}
}

// Options within menus
@(deferred_out=_do_submenu)
do_submenu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id, use_next_box() or_else layout_next(current_layout())); ok {
		using self
		active = .Active in bits
		// Animation
		hover_time := animate_bool(self.id, .Hovered in state || active, 0.15)
		// Paint
		if .Should_Paint in bits {
			paint_box_fill(box, alpha_blend_colors(get_color(.Widget_BG), get_color(.Widget_Shade), 0.2 if .Pressed in state else hover_time * 0.1))
			paint_flipping_arrow({box.x + box.w - box.h / 2, box.y + box.h / 2}, 8, 0, get_color(.Text))
			paint_label_box(info.label, box, get_color(.Text), {info.align.? or_else .Near, .Middle})
		}
		// Swap state when clicked
		if state & {.Hovered, .Lost_Hover} != {} {
			bits += {.Active}
		} else if .Hovered in self.layer.state && .Got_Hover not_in self.layer.state {
			bits -= {.Active}
		}
		// Begin layer
		if active {
			layer_result, _ := begin_attached_layer({
				id = shared_id,
				parent = self.box,
				side = .Right,
				size = info.size,
				layout_size = info.layout_size,
				align = info.layer_align,
				fill_color = get_color(.Widget_BG),
			})
			if layer_result.self.state & {.Hovered, .Lost_Hover} != {} {
				bits += {.Active}
			}
			if layer_result.dismissed {
				bits -= {.Active}
			}
		}
	}
	return
}

@private
_do_submenu :: proc(active: bool) {
	if active {
		end_attached_layer({
			stroke_color = get_color(.Base_Stroke),
		}, current_layer())
	}
}

Option_Info :: struct {
	label: Label,
	active: bool,
	align: Maybe(Alignment),
	no_dismiss: bool,
}

do_option :: proc(info: Option_Info, loc := #caller_location) -> (clicked: bool) {
	if self, ok := do_widget(hash(loc), layout_next(current_layout())); ok {
		// Animation
		hover_time := animate_bool(self.id, .Hovered in self.state, 0.1)
		// Painting
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, alpha_blend_colors(get_color(.Widget_BG), get_color(.Widget_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1))
			paint_label_box(info.label, shrink_box_separate(self.box, {self.box.h * 0.25, 0}), get_color(.Text), {info.align.? or_else .Near, .Middle})
			if info.active {
				paint_aligned_icon(get_font_data(.Header), .Check, {self.box.x + self.box.w - self.box.h / 2, self.box.y + self.box.h / 2}, 1, get_color(.Text), {.Middle, .Middle})
			}
		}
		// Dismiss the root menu
		if widget_clicked(self, .Left) {
			clicked = true
			layer := current_layer()
			if !info.no_dismiss {
				layer.bits += {.Dismissed}
			}
			for layer.parent != nil && layer.options >= {.Attached} {
				layer = layer.parent
				layer.bits += {.Dismissed}
			}
		}
	}
	return
}

do_enum_options :: proc(value: $T, loc := #caller_location) -> (result: Maybe(T)) {
	for member in T {
		push_id(hash_int(int(member)))
			if do_option({label = text_capitalize(format(member))}) {
				result = member
			}
		pop_id()
	}
	return
}

do_bit_set_options :: proc(set: $S/bit_set[$E;$U], loc := #caller_location) -> (newSet: S) {
	newSet = set
	for member in E {
		push_id(hash_int(int(member)))
			if do_option({label = text_capitalize(format(member)), active = member in set}) {
				newSet = newSet ~ {member}
			}
		pop_id()
	}
	return
}
package maui_widgets

import "../"

// Square buttons that toggle something
Toggle_Button_Info :: struct {
	label: maui.Label,
	state: bool,
	align: Maybe(maui.Alignment),
	color: Maybe(maui.Color),
	fit_to_label: bool,
	join: maui.Box_Sides,
}
do_toggle_button :: proc(info: Toggle_Button_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		// Colocate
		layout := current_layout()
		if next_box, ok := use_next_box(); ok {
			self.box = next_box
		} else if info.fit_to_label && int(placement.side) > 1 {
			self.box = layout_next_of_size(layout, get_size_for_label(layout, info.label))
		} else {
			self.box = layout_next(layout)
		}
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		// Paint
		if .Should_Paint in self.bits {
			color := get_color(.Accent if info.state else .Widget_Stroke)
			if info.state {
				paint_box_fill(self.box, alpha_blend_colors(get_color(.Accent), 255, 0.5 if .Pressed in self.state else (hover_time * 0.25)))
			} else {
				paint_box_fill(self.box, get_color(.Base_Shade, 0.2 if .Pressed in self.state else 0.1 * hover_time))
			}

			if info.state {
				paint_label_box(info.label, shrink_box_double(self.box, {(self.box.high.y - self.box.low.y) * 0.25, 0}), get_color(.Base), .Middle, .Middle)
			} else {
				color := get_color(.Widget_Stroke)
				if .Left not_in info.join {
					paint_box_fill(get_box_left(self.box, Exact(1)), color)
				}
				if .Right not_in info.join {
					paint_box_fill(get_box_right(self.box, Exact(1)), color)
				}
				if .Top not_in info.join {
					paint_box_fill(get_box_top(self.box, Exact(1)), color)
				}
				if .Bottom not_in info.join {
					paint_box_fill(get_box_bottom(self.box, Exact(1)), color)
				}
				paint_label_box(info.label, shrink_box_double(self.box, {(self.box.high.y - self.box.low.y) * 0.25, 0}), color, .Middle, .Middle)
			}
		}
		// Hover
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
		// Result
		clicked = widget_clicked(self, .Left)
	}
	return
}
do_toggle_button_bit :: proc(set: ^$S/bit_set[$B], bit: B, label: maui.Label, loc := #caller_location) -> (click: bool) {
	using maui
	click = toggle_button(
		value = bit in set, 
		label = label, 
		loc = loc,
		)
	if click {
		set^ ~= {bit}
	}
	return
}
do_enum_toggle_buttons :: proc(value: $T, loc := #caller_location) -> (new_value: T) {
	using maui
	new_value = value
	layout := current_layout()
	horizontal := placement.side == .Left || placement.side == .Right
	for member, i in T {
		push_id(int(member))
			sides: Box_Sides
			if i > 0 {
				sides += {.Left} if horizontal else {.Top}
			}
			if i < len(T) - 1 {
				sides += {.Right} if horizontal else {.Bottom}
			}
			if do_toggle_button({label = tmp_printf("%v", member), state = value == member, join = sides}) {
				new_value = member
			}
		pop_id()
	}
	return
}
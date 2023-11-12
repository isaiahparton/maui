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
		// Cursor
		if .Hovered in self.state {
			core.cursor = .Hand
		}
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		// Paint
		if .Should_Paint in self.bits {
			inner_box := shrink_box(self.box, 1)
			// Body
			color := info.color.? or_else (style.color.accent[1] if info.state else style.color.substance[1])
			if info.state {
				paint_button_shape_fill(self.box, fade(color, 0.1))
			}
			paint_button_shape_fill(self.box, fade(color, 0.1 + (0.1 * hover_time) + (0.8 * press_time)))
			paint_button_shape_stroke(self.box, 1, fade(color, 0.5 + hover_time * 0.5))
			// Label
			paint_label_box(info.label, self.box, blend_colors(color, style.color.base[0], press_time), .Middle, .Middle)
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
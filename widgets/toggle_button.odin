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
			if info.state {
				paint_shaded_box(inner_box, {style.color.base_dark, style.color.base, style.color.base_light})
			} else {
				paint_shaded_box(inner_box, {style.color.extrusion_light, style.color.extrusion, style.color.extrusion_dark})
			}
			// Outline
			paint_box_stroke(self.box, 1, alpha_blend_colors(style.color.base_stroke, style.color.status, press_time))
			// Interaction Shading
			paint_box_fill(inner_box, alpha_blend_colors(fade(255, hover_time * 0.1), style.color.status, press_time * 0.5))
			// Label
			paint_label_box(info.label, move_box(self.box, 2 * f32(int(info.state))), style.color.text, .Middle, .Middle)
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
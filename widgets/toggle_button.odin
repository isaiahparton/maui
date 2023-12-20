package maui_widgets

import "../"

// Square buttons that toggle something
Toggle_Button_Info :: struct {
	label: maui.Label,
	state: bool,
	align: Maybe(maui.Alignment),
	color: Maybe(maui.Color),
	fit_to_label: bool,
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
			ctx.cursor = .Hand
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
				paint_rounded_box_corners_fill(self.box, style.rounding, style.rounded_corners, alpha_blend_colors(alpha_blend_colors(style.color.substance[1], style.color.substance_hover, hover_time), style.color.substance_click, press_time))
			} else if hover_time > 0 || press_time > 0 {
				paint_rounded_box_corners_fill(self.box, style.rounding, style.rounded_corners, fade(style.color.base_hover, hover_time))
				paint_rounded_box_corners_fill(self.box, style.rounding, style.rounded_corners, fade(style.color.base_click, press_time))
			}
			// Label
			paint_label_box(info.label, self.box, style.color.base_text[1], .Middle, .Middle)
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
	if do_toggle_button({
		state = bit in set, 
		label = label, 
	}, loc = loc) {
		set^ ~= {bit}
	}
	return
}
do_enum_toggle_buttons :: proc(value: $T, loc := #caller_location) -> (new_value: T) {
	using maui
	new_value = value
	layout := current_layout()
	horizontal := placement.side == .Left || placement.side == .Right
	prev_rounded_corners := style.rounded_corners
	for member, i in T {
		push_id(int(member))
			style.rounded_corners = {}
			if horizontal {
				if i == 0 {
					style.rounded_corners += {.Top_Left, .Bottom_Left}
				} else if i == len(T) - 1 {
					style.rounded_corners += {.Top_Right, .Bottom_Right}
				}
			} else {
				if i == 0 {
					style.rounded_corners += {.Top_Left, .Top_Right}
				} else if i == len(T) - 1 {
					style.rounded_corners += {.Bottom_Left, .Bottom_Right}
				}
			}
			if do_toggle_button({label = tmp_printf("%v", member), state = value == member}) {
				new_value = member
			}
		pop_id()
	}
	return
}
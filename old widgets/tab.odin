package maui_widgets
/*import "../"

// Navigation tabs
Tab_Info :: struct {
	using info: maui.Widget_Info,
	state: bool,
	label: maui.Label,
	side: Maybe(maui.Box_Side),
	has_close_button: bool,
	show_divider: bool,
}

Tab_Result :: struct {
	self: ^maui.Widget,
	clicked,
	closed: bool,
}

do_tab :: proc(info: Tab_Info, loc := #caller_location) -> (result: Tab_Result) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		self.box = info.box.? or_else layout_next(current_layout())
		// Default connecting side
		side := info.side.? or_else .Bottom
		// Animations
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
		state_time := animate_bool(&self.timers[1], info.state, 0.1)
		update_widget(self)
		label_box := self.box
		if info.has_close_button {
			set_next_box(shrink_box(cut_box_right(&label_box, height(label_box)), 4))
		}

		ROUNDNESS :: 7
		if self.bits >= {.Should_Paint} {
			paint_rounded_box_corners_fill(self.box, ROUNDNESS, side_corners(side), get_color(.Base, 1 if info.state else 0.5 * hover_time))

			opacity: f32 = 0.5 + min(state_time + hover_time, 1)
			paint_rounded_box_corners_fill(self.box, ROUNDNESS, {.Top_Left, .Top_Right}, get_color(.Base_Shade, (1 - state_time) * 0.1))
			paint_rounded_box_sides_stroke(self.box, ROUNDNESS, 1, {.Left, .Top, .Bottom, .Right} - {side}, get_color(.Base_Stroke, opacity))
			if info.state {
				paint_box_fill({{self.box.low.x + 1, self.box.high.y}, {self.box.high.x - 1, self.box.high.y + 1}}, get_color(.Base))
			}

			paint_label(info.label, {self.box.low.x + height(self.box) * 0.25, center_y(self.box)}, get_color(.Text, opacity), .Left, .Middle)
		}

		if info.has_close_button {
			if do_button({
				label = 'X',
				style = .Subtle,
			}) {
				result.closed = true
			}
		}

		result.self = self
		result.clicked = !info.state && widget_clicked(self, .Left, 1)
	}
	return
}

do_enum_tabs :: proc(value: $T, tab_size: f32, loc := #caller_location) -> (new_value: T) { 
	using maui
	new_value = value
	box := layout_next(current_layout())
	if do_layout_box(box) {
		placement.side = .Left
		if tab_size == 0 {
			placement.size = Relative(1.0 / f32(len(T)))
		} else {
			placement.size = tab_size
		}
		for member in T {
			push_id(int(member))
				if do_tab({
					state = member == value, 
					label = text_capitalize(fprint(member)), 
				}, loc).clicked {
					new_value = member
				}
			pop_id()
		}
	}
	return
}*/
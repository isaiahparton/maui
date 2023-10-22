package maui_widgets
/*import "../"

import "core:math/ease"

// Radio buttons
Radio_Button_Info :: struct {
	on: bool,
	text: string,
	text_side: Maybe(maui.Box_Side),
}

do_radio_button :: proc(info: Radio_Button_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	SIZE :: 22
	RADIUS :: SIZE / 2
	// Determine total size
	text_side := info.text_side.? or_else .Left
	text_size := measure_text({text = info.text, font = painter.style.default_font, size = painter.style.default_font_size})
	size: [2]f32
	if text_side == .Bottom || text_side == .Top {
		size.x = max(SIZE, text_size.x)
		size.y = SIZE + text_size.y
	} else {
		size.x = SIZE + text_size.x + WIDGET_PADDING * 2
		size.y = SIZE
	}
	// The widget
	if self, ok := do_widget(hash(loc)); ok {
		self.box = use_next_box() or_else layout_next_child(current_layout(), size)
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
		state_time := animate_bool(&self.timers[1], info.on, 0.24)
		// Graphics
		if .Should_Paint in self.bits {
			center: [2]f32
			switch text_side {
				case .Left: 	
				center = {self.box.low.x + RADIUS, self.box.low.y + RADIUS}
				case .Right: 	
				center = {self.box.high.x - RADIUS, self.box.low.y + RADIUS}
				case .Top: 		
				center = {center_x(self.box), self.box.high.y - RADIUS}
				case .Bottom: 	
				center = {center_x(self.box), self.box.low.y + RADIUS}
			}
			if hover_time > 0 {
				paint_pill_fill_h(self.box, get_color(.Base_Shade, hover_time * 0.1))
			}
			paint_circle_fill_texture(center, RADIUS, blend_colors(alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), 0.1 if .Pressed in self.state else 0), alpha_blend_colors(get_color(.Intense), get_color(.Intense_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1), state_time))
			if info.on {
				paint_circle_fill(center, ease.quadratic_in_out(state_time) * 6, 18, get_color(.Widget_Back, state_time))
			}
			if state_time < 1 {
				paint_ring_fill_texture(center, RADIUS - 2, RADIUS, get_color(.Widget_Stroke, 0.5 + 0.5 * hover_time))
			}
			switch text_side {
				case .Left: 	
				paint_text({self.box.low.x + SIZE + WIDGET_PADDING, center.y - text_size.y / 2}, {text = info.text, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text, 1))
				case .Right: 	
				paint_text({self.box.low.x, center.y - text_size.y / 2}, {text = info.text, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text, 1))
				case .Top: 		
				paint_text(self.box.low, {text = info.text, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text, 1))
				case .Bottom: 	
				paint_text({self.box.low.x, self.box.high.y - text_size.y}, {text = info.text, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text, 1))
			}
		}
		// Click result
		clicked = .Clicked in self.state && self.click_button == .Left
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

// Helper functions
do_enum_radio_buttons :: proc(
	value: $T, 
	text_side: maui.Box_Side = .Left, 
	loc := #caller_location,
) -> (new_value: T) {
	using maui
	new_value = value
	push_id(hash(loc))
	for member in T {
		push_id(hash_int(int(member)))
			if do_radio_button({
				on = member == value, 
				text = tmp_print(member), 
				text_side = text_side,
			}) {
				new_value = member
			}
		pop_id()
	}
	pop_id()
	return
}*/
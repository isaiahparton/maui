package maui_widgets
import "../"

Toggle_Switch_State :: union #no_nil {
	bool,
	^bool,
}

Toggle_Switch_Info :: struct {
	state: Toggle_Switch_State,
	color: Maybe(maui.Color),
}

// Sliding toggle switch
do_toggle_switch :: proc(info: Toggle_Switch_Info, loc := #caller_location) -> (new_state: bool) {
	using maui
	state := info.state.(bool) or_else info.state.(^bool)^
	new_state = state
	WIDTH :: 38
	HEIGHT :: 28
	if self, ok := do_widget(hash(loc)); ok {
		// Colocate
		self.box = layout_next_child(current_layout(), {WIDTH, HEIGHT})
		// Update
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.15)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, 0.15)
		how_on := animate_bool(&self.timers[2], state, 0.2, .Quadratic_In_Out)
		// Painting
		if .Should_Paint in self.bits {
			base_box: Box = {{self.box.low.x, self.box.low.y + 6}, {self.box.high.x, self.box.high.y - 6}}
			base_radius := height(base_box) * 0.5
			start: [2]f32 = {base_box.low.x + base_radius, center_y(base_box)}
			move := width(base_box) - height(base_box)
			knob_center := start + {move * (how_on if state else how_on), 0}
			color := info.color.? or_else get_color(.Accent)
			back_color := alpha_blend_colors(color, {0, 0, 0, 255}, 0.25)
			// Background
			if how_on < 1 {
				paint_rounded_box_fill(base_box, base_radius, get_color(.Widget_Back))
			}
			// Background
			if how_on > 0 {
				if how_on < 1 {
					paint_rounded_box_fill({base_box.low, {knob_center.x, base_box.high.y}}, base_radius, back_color)
				} else {
					paint_rounded_box_fill(base_box, base_radius, back_color)
				}
			}
			// Knob
			paint_circle_fill_texture(knob_center, 11, alpha_blend_colors(color, 255, (hover_time + press_time) * 0.25))
		}
		// Invert state on click
		if .Clicked in self.state {
			new_state = !state
			#partial switch v in info.state {
				case ^bool: v^ = new_state
			}
		}
		// Hover
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
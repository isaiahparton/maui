package maui_widgets
import "../"

import "core:math"

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
	WIDTH :: 50
	HEIGHT :: 25
	if self, ok := do_widget(hash(loc)); ok {
		// Colocate
		self.box = use_next_box() or_else layout_next_child(current_layout(), {WIDTH, HEIGHT})
		// Update
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		how_on := animate_bool(&self.timers[2], state, 0.2, .Quadratic_In_Out)
		// Painting
		if .Should_Paint in self.bits {
			base_radius := height(self.box) * 0.5

			move := width(self.box) / 2
			offset := move * how_on
			knob_box: Box = {{self.box.low.x + offset, self.box.low.y}, {self.box.low.x + move + offset, self.box.high.y}}
			back_color: Color = {0, 150, 255, 100}
			// Background
			paint_shaded_box(self.box, {style.color.indent_dark, style.color.indent, style.color.indent_light})
			// Text
			if how_on > 0 {
				paint_check(self.box.low + 12.5, 6 * how_on, fade(style.color.status, how_on))
			}
			if how_on < 1 {
				paint_cross(self.box.high - 12.5, 7, math.PI * 0.25 * (1 - how_on), 2, fade(style.color.status, 1 - how_on))
			}
			// Knob
			paint_shaded_box(shrink_box(knob_box, 1), {style.color.extrusion_light, style.color.extrusion, style.color.extrusion_dark})
			paint_box_fill(shrink_box(knob_box, 1), fade({255, 255, 255, 40}, hover_time))
			paint_box_stroke(knob_box, 1, style.color.base_stroke)

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
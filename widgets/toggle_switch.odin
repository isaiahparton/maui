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
	WIDTH :: 48
	KNOB_WIDTH :: 16
	HEIGHT :: 24
	if self, ok := do_widget(hash(loc)); ok {
		// Colocate
		self.box = use_next_box() or_else layout_next_child(current_layout(), {WIDTH, HEIGHT})
		// Update
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		how_on := animate_bool(&self.timers[2], state, 0.2, .Circular_In_Out)
		// Painting
		if .Should_Paint in self.bits {
			base_radius := height(self.box) * 0.5

			move := width(self.box) - KNOB_WIDTH
			offset := move * how_on
			knob_box: Box = {{self.box.low.x + offset, self.box.low.y}, {self.box.low.x + KNOB_WIDTH + offset, self.box.high.y}}
			back_color: Color = {0, 150, 255, 100}
			// Background
			paint_shaded_box(self.box, {style.color.indent_dark, style.color.indent, style.color.indent_light})
			// Text
			if how_on > 0 {
				paint_text(knob_box.low + {-6, 12}, {text = "ON", font = style.font.label, size = 16}, {align = .Right, baseline = .Middle, clip = self.box}, fade(style.color.status, how_on))
			}
			if how_on < 1 {
				paint_text(knob_box.high + {4, -12}, {text = "OFF", font = style.font.label, size = 16}, {align = .Left, baseline = .Middle, clip = self.box}, fade(style.color.status, 1 - how_on))
			}
			// Knob
			paint_shaded_box(shrink_box(knob_box, 1), {style.color.extrusion_light, style.color.extrusion, style.color.extrusion_dark})
			paint_gradient_box_v(shrink_box(knob_box, 2), {0, 0, 0, 60}, {255, 255, 255, 40})
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
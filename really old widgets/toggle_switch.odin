package maui_widgets
import "../"

import "core:fmt"
import "core:math"

Toggle_Switch_State :: union #no_nil {
	bool,
	^bool,
}

Toggle_Switch_Info :: struct {
	using info: maui.Widget_Info,
	state: Toggle_Switch_State,
	color: Maybe(maui.Color),
}

// Sliding toggle switch
do_toggle_switch :: proc(info: Toggle_Switch_Info, loc := #caller_location) -> (new_state: bool) {
	using maui
	state := info.state.(bool) or_else info.state.(^bool)^
	new_state = state
	WIDTH :: 56
	HEIGHT :: 24
	RADIUS :: HEIGHT / 2
	TEXT_OFFSET :: WIDTH / 2
	if self, ok := do_widget(hash(loc)); ok {
		// Colocate
		self.box = info.box.? or_else layout_next_child(current_layout(), {WIDTH, HEIGHT})
		// Update
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		how_on := animate_bool(&self.timers[2], state, 0.2, .Circular_In_Out)
		// Painting
		if .Should_Paint in self.bits {
			base_radius := height(self.box) * 0.5

			move := width(self.box) - HEIGHT
			offset := RADIUS + move * how_on
			thumb_center: [2]f32 = self.box.low + {offset, RADIUS}
			back_color: Color = {0, 150, 255, 100}
			// Background
			paint_pill_fill_h(self.box, ui.style.color.substance[0])
			// Text
			if how_on > 0 {
				paint_text(thumb_center + {-TEXT_OFFSET, 0}, {text = "ON", font = ui.style.font.label, size = 18}, {align = .Middle, baseline = .Middle, clip = self.box}, blend_colors(ui.style.color.base[0], ui.style.color.accent[0], how_on))
			}
			if how_on < 1 {
				paint_text(thumb_center + {TEXT_OFFSET, 0}, {text = "OFF", font = ui.style.font.label, size = 18}, {align = .Middle, baseline = .Middle, clip = self.box}, ui.style.color.base[0])
			}
			// Knob
			paint_circle_fill_texture(thumb_center, RADIUS, alpha_blend_colors(ui.style.color.substance[1], ui.style.color.substance_hover, hover_time))
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
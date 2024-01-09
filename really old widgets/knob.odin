package maui_widgets
import "../"

import "core:math"
import "core:math/linalg"

Knob_Info :: struct($T: typeid) {
	using info: maui.Widget_Info,
	value,
	low,
	high: T,
	format: Maybe(string),
}

do_knob :: proc(info: Knob_Info($T), loc := #caller_location) -> (new_value: T) {
	using maui
	RADIUS :: 20
	new_value = info.value
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		// Load resources
		// Colocate
		self.box = info.box.? or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animate
		press_time := animate_bool(&self.timers[0], .Pressed in self.state, 0.35, .Cubic_In_Out)
		// Trap and hide cursor when dragging
		if .Pressed in self.state {
			ctx.cursor = .None
		}
		// Other stuff
		center := box_center(self.box)
		start: f32 = -math.PI * 1.25
		end: f32 = math.PI * 0.25	
		range := info.high - info.low
		time := clamp(f32((info.value - info.low) / range), 0, 1)
		point := start + (end - start) * time
		radius := RADIUS - 2 * press_time
		norm: [2]f32 = {math.cos(point), math.sin(point)}

		// Knob body
		// Line
		paint_line(center + norm * radius, center + norm * (radius - 10), 1, ui.style.color.substance[1])
		// Outline
		paint_ring_fill(center, radius, radius + 1, 32, ui.style.color.substance[1])
		// Another line
		paint_ring_sector_fill(center, RADIUS + 6, RADIUS + 8, start, end, 24, fade(ui.style.color.substance[1], 0.5))
		// Text
		paint_text(center + {0, RADIUS + 4}, {text = tmp_printf(info.format.? or_else "%v", info.value), font = ui.style.font.label, size = 14}, {align = .Middle, baseline = .Top}, ui.style.color.base_text)

		if .Pressed in self.state {
			new_value -= T(input.last_mouse_point.x - input.mouse_point.x) * (range / (math.PI * 1.5)) * 0.005
			new_value = clamp(new_value, info.low, info.high)
		}

		update_widget_hover(self, linalg.length(input.mouse_point - center) <= RADIUS)
	}
	return
}
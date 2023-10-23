package maui_widgets
import "../"

import "core:math"
import "core:math/linalg"

Knob_Info :: struct($T: typeid) {
	value,
	low,
	high: T,
}

do_knob :: proc(info: Knob_Info($T), loc := #caller_location) -> (new_value: T) {
	using maui
	RADIUS :: 18
	new_value = info.value
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)

		press_time := animate_bool(&self.timers[0], .Pressed in self.state, 0.35, .Cubic_In_Out)

		center := box_center(self.box)
		start: f32 = -math.PI * 1.25
		end: f32 = math.PI * 0.25	
		range := info.high - info.low
		time := clamp(f32((info.value - info.low) / range), 0, 1)
		point := start + (end - start) * time
		radius := RADIUS - 2 * press_time

		paint_circle_fill(center, radius, 18, {195, 195, 195, 255})
		paint_circle_sector_fill(center, radius, -(math.PI + 0.75), -math.PI, 3, 255)
		paint_circle_sector_fill(center, radius, -0.75, 0, 3, 255)

		// Pointer
		a, b, c: [2]f32 = {math.cos(point - 0.15), math.sin(point - 0.15)} * radius, {math.cos(point + 0.15), math.sin(point + 0.15)} * radius, {math.cos(point), math.sin(point)} * (radius - 10)
		paint_triangle_fill(center + a, center + c, center + b, {125, 125, 125, 255})
		paint_ring_fill(center, radius - 2, radius, 24, {125, 125, 125, 255})
		paint_ring_fill(center, radius, radius + 1, 24, style.color.base_stroke)

		paint_ring_sector_fill(center, 22, 25, start, end, 24, style.color.indent)
		paint_ring_sector_fill(center, 22, 25, start, point, 24, style.color.status)

		if .Pressed in self.state {
			new_value -= T(input.last_mouse_point.x - input.mouse_point.x) * ((math.PI * 1.5) / range) * 0.075
			new_value = clamp(new_value, info.low, info.high)
		}

		update_widget_hover(self, linalg.length(input.mouse_point - center) <= RADIUS)
	}
	return
}
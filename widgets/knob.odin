package maui_widgets
import "../"

import "core:math"
import "core:math/linalg"

Knob_Info :: struct($T: typeid) {
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
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animate
		press_time := animate_bool(&self.timers[0], .Pressed in self.state, 0.35, .Cubic_In_Out)
		// Trap and hide cursor when dragging
		if .Pressed in self.state {
			core.cursor = .None
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
		if resource, ok := require_resource(int(Resource.Knob_Large), RADIUS * 2); ok {
			if !resource.ready {
				center: [2]f32 = box_center(resource.src) - 0.5
				image := &painter.atlas.image
				for y in int(resource.src.low.y)..<int(resource.src.high.y) {
					for x in int(resource.src.low.x)..<int(resource.src.high.x) {
						point: [2]f32 = {f32(x), f32(y)}
						diff := point - center
						dist := math.sqrt((diff.x * diff.x) + (diff.y * diff.y))
						if dist > RADIUS + 1 {
							continue
						}
						i := (x + y * image.width) * image.channels
						color: [4]f32 = {0.65, 0.65, 0.65, 1 - max(0, dist - RADIUS)}
						INNER_RADIUS :: RADIUS - 5
						if dist > INNER_RADIUS {
							value := 1 - ((point.y - resource.src.low.y) / height(resource.src) * 1.75) * 0.5
							color.rgb += (value - color.rgb) * clamp(dist - INNER_RADIUS, 0, 1)
						}
						image.data[i    ] = u8(color.r * 255)
						image.data[i + 1] = u8(color.g * 255)
						image.data[i + 2] = u8(color.b * 255)
						image.data[i + 3] = u8(color.a * 255)
					}
				}
			}
			half_size := (resource.src.high - resource.src.low) / 2
			paint_textured_box(painter.atlas.texture, resource.src, {center - radius, center + radius}, style.color.extrusion)
		}
		// Line
		paint_line(center + norm * radius, center + norm * (radius - 10), 1, style.color.base_text)
		// Outline
		paint_ring_fill(center, radius, radius + 1, 32, style.color.base_stroke)
		// Another line
		paint_ring_sector_fill(center, RADIUS + 6, RADIUS + 8, start, end, 24, fade(style.color.base_text, 0.5))
		// Text
		paint_text(center + {0, RADIUS + 4}, {text = tmp_printf(info.format.? or_else "%v", info.value), font = style.font.label, size = 14}, {align = .Middle, baseline = .Top}, style.color.base_text)

		if .Pressed in self.state {
			new_value -= T(input.last_mouse_point.x - input.mouse_point.x) * (range / (math.PI * 1.5)) * 0.005
			new_value = clamp(new_value, info.low, info.high)
		}

		update_widget_hover(self, linalg.length(input.mouse_point - center) <= RADIUS)
	}
	return
}
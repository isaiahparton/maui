package maui_widgets
import "../"

import "core:fmt"
import "core:math"
import "core:math/linalg"

COLOR_PICKER_INNER_RADIUS :: 50
COLOR_PICKER_OUTER_RADIUS :: 70

/*
	Coordinate conversion
*/
barycentric :: proc(point, a, b, c: [2]f32) -> (u, v, w: f32) {
	v0 := b - a
	v1 := c - a
	v2 := point - a
	d00 := linalg.dot(v0, v0)
	d01 := linalg.dot(v0, v1)
	d11 := linalg.dot(v1, v1)
	d20 := linalg.dot(v2, v0)
	d21 := linalg.dot(v2, v1)
	denom := d00 * d11 - d01 * d01
	v = (d11 * d20 - d01 * d21) / denom
	w = (d00 * d21 - d01 * d20) / denom
	u = 1.0 - v - w
	return
}
/*
	Procedures for color conversion
*/
rgba_to_hsva :: proc(color: maui.Color) -> (hsva: [4]f32) {
	rgba: [4]f32 = {f32(color.r), f32(color.g), f32(color.b), f32(color.a)} / 255

	low := min(rgba.r, rgba.g, rgba.b)
	high := max(rgba.r, rgba.g, rgba.b)
	hsva.w = rgba.a

	hsva.z = high
	delta := high - low

	if delta < 0.00001 {
		return
	}

	if high > 0 {
		hsva.y = delta / high
	} else {
		return
	}

	if rgba.r >= high {
		hsva.x = (rgba.g - rgba.b) / delta
	} else {
		if rgba.g >= high {
			hsva.x = 2.0 + (rgba.b - rgba.r) / delta
		} else {
			hsva.x = 4.0 + (rgba.r - rgba.g) / delta
		}
	}

	hsva.x *= 60

	if hsva.x < 0 {
		hsva.x += 360
	}

	return
}
hsva_to_rgba :: proc(hsva: [4]f32) -> maui.Color {
  r, g, b, k, t: f32

  k = math.mod(5.0 + hsva.x / 60.0, 6)
  t = 4.0 - k
  k = clamp(min(t, k), 0, 1)
  r = hsva.z - hsva.z * hsva.y * k

  k = math.mod(3.0 + hsva.x / 60.0, 6)
  t = 4.0 - k
  k = clamp(min(t, k), 0, 1)
  g = hsva.z - hsva.z * hsva.y * k

  k = math.mod(1.0 + hsva.x / 60.0, 6)
  t = 4.0 - k
  k = clamp(min(t, k), 0, 1)
  b = hsva.z - hsva.z * hsva.y * k

  return {u8(r * 255.0), u8(g * 255.0), u8(b * 255.0), u8(hsva.a * 255.0)}
}

Color_Picker_Info :: struct {
	hsva: [4]f32,
}
do_color_wheel :: proc(info: Color_Picker_Info, loc := #caller_location) -> (new_hsva: [4]f32, changed: bool) {
	using maui
	new_hsva = info.hsva
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		self.box = use_next_box() or_else layout_next(current_layout())

		size := min(width(self.box), height(self.box))
		outer := size / 2
		inner := outer - 15

		self.box = child_box(self.box, size, placement.align)
		update_widget(self)
		
		center := center(self.box)
		angle := info.hsva.x * math.RAD_PER_DEG
		// Three points of the inner triangle
		point_a: [2]f32 = center + {math.cos(angle - TRIANGLE_STEP), math.sin(angle - TRIANGLE_STEP)} * inner
		point_b: [2]f32 = center + {math.cos(angle) * inner, math.sin(angle) * inner}
		point_c: [2]f32 = center + {math.cos(angle + TRIANGLE_STEP), math.sin(angle + TRIANGLE_STEP)} * inner
		
		if .Should_Paint in self.bits {
			mesh := &painter.meshes[painter.target]
			// Outer ring
			STEP :: math.TAU / 36.0
			for t: f32 = 0; t < math.TAU; t += STEP {
				color: Color = hsva_to_rgba({t * math.DEG_PER_RAD, 1, 1, 1})
				next_color: Color = hsva_to_rgba({(t + STEP) * math.DEG_PER_RAD, 1, 1, 1})
				paint_indices(
					mesh,
					mesh.vertices_offset,
					mesh.vertices_offset + 1,
					mesh.vertices_offset + 2,
					mesh.vertices_offset,
					mesh.vertices_offset + 2,
					mesh.vertices_offset + 3,
					)
				paint_vertices(
					mesh,
					{point = center + {math.cos(t) * outer, math.sin(t) * outer}, color = color},
					{point = center + {math.cos(t) * inner, math.sin(t) * inner}, color = color},
					{point = center + {math.cos(t + STEP) * inner, math.sin(t + STEP) * inner}, color = next_color},
					{point = center + {math.cos(t + STEP) * outer, math.sin(t + STEP) * outer}, color = next_color},
					)
			}
			// Inner triangle
			paint_indices(
				mesh,
				mesh.vertices_offset,
				mesh.vertices_offset + 1,
				mesh.vertices_offset + 2,
				)
			// Inner Triangle
			paint_vertices(
				mesh,
				{point = point_a, color = 255},
				{point = point_b, color = hsva_to_rgba({info.hsva.x, 1, 1, 1})},
				{point = point_c, color = {0, 0, 0, 255}},
				)
			// Selector circle
			point := point_c
			point += (point_a - point) * info.hsva.z
			point += (point_b - point) * info.hsva.y * info.hsva.z
			paint_ring_fill_texture(point, 3, 5, 255)
		}

		diff := input.mouse_point - center
		dist := linalg.length(diff)

		if .Got_Press in self.state {
			if dist > inner && dist <= outer {
				self.bits += {.Active}
			}
		} else if .Pressed in self.state {
			if .Active in self.bits {
				// Hue assignment
				new_hsva.x = math.atan2(diff.y, diff.x) / math.RAD_PER_DEG
				if new_hsva.x < 0 {
					new_hsva.x += 360
				}
			} else {
				// Saturation and value assignment
				u, v, w := barycentric(input.mouse_point, point_a, point_b, point_c)
				u = clamp(u, 0, 1)
				v = clamp(v, 0, 1)
				w = clamp(w, 0, 1)
				when ODIN_DEBUG {
					paint_text(point_a, {text = tmp_print(u), font = style.font.label, size = 16}, {}, {0, 0, 0, 255})
					paint_text(point_b, {text = tmp_print(v), font = style.font.label, size = 16}, {}, {0, 0, 0, 255})
					paint_text(point_c, {text = tmp_print(w), font = style.font.label, size = 16}, {}, {0, 0, 0, 255})
				}
				// Saturation
				new_hsva.y = 1 if w >= 1 else ((1 - u) * v)
				// Value
				new_hsva.z = 1 - w
			}
			changed = true
		} else {
			self.bits -= {.Active}
		}

		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

do_color_picker_2d :: proc(info: Color_Picker_Info, loc := #caller_location) -> (new_hsva: [4]f32, changed: bool) {
	using maui
	new_hsva = info.hsva
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		self.box = use_next_box() or_else layout_next(current_layout())

		size := min(width(self.box), height(self.box))
		outer := size / 2
		inner := outer - 15

		self.box = child_box(self.box, size, placement.align)
		update_widget(self)
		
		center := center(self.box)
		angle := math.TAU * info.hsva.x
		
		if .Should_Paint in self.bits {
			paint_quad_vertices(
				{point = self.box.low, color = 255},
				{point = {self.box.high.x, self.box.low.y}, color = hsva_to_rgba({info.hsva.x, 1, 0.5, 1})},
				{point = self.box.high, color = {0, 0, 0, 255}},
				{point = {self.box.low.x, self.box.high.y}, color = {0, 0, 0, 255}},
				)
		}

		diff := input.mouse_point - center
		dist := linalg.length(diff)

		if .Pressed in self.state {
			
			changed = true
		}

		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

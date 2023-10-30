package maui

// Scroll bars for scrolling bars
Scrollbar_Info :: struct {
	value,
	low,
	high,
	knob_size: f32,
	vertical: bool,
}

do_scrollbar :: proc(info: Scrollbar_Info, loc := #caller_location) -> (changed: bool, new_value: f32) {
	new_value = info.value
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		// Colocate
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
		// Vector component to modify
		i := int(info.vertical)
		// Control info
		size := self.box.high[i] - self.box.low[i]
		range := size - info.knob_size
		value_range := (info.high - info.low) if info.high > info.low else 1
		// Part dragged by user
		knob_box := self.box
		knob_size := knob_box.high[i] - knob_box.low[i]
		knob_box.low[i] += range * clamp((info.value - info.low) / value_range, 0, 1)
		knob_size = min(info.knob_size, knob_size)
		knob_box.high[i] = knob_box.low[i] + knob_size
		// Painting
		if .Should_Paint in self.bits {
			knob_box = shrink_box(knob_box, 1)
			paint_box_fill(self.box, style.color.scroll_bar)
			paint_shaded_box(knob_box, {style.color.extrusion_light, style.color.extrusion, style.color.extrusion_dark})
			paint_gradient_box_v(shrink_box(knob_box, 1), {0, 0, 0, 60}, {255, 255, 255, 40})
			paint_box_fill(knob_box, fade(255, hover_time * 0.1))
			paint_box_stroke(self.box, 1, style.color.base_stroke)
		}
		// Dragging
		if .Got_Press in self.state {
			if point_in_box(input.mouse_point, transmute(Box)knob_box) {
				core.drag_anchor = input.mouse_point - knob_box.low
				self.bits += {.Active}
			} else {
				normal := clamp((input.mouse_point[i] - self.box.low[i]) / range, 0, 1)
				new_value = info.low + (info.high - info.low) * normal
				changed = true
			}
		}
		if self.bits >= {.Active} {
			normal := clamp(((input.mouse_point[i] - core.drag_anchor[i]) - self.box.low[i]) / range, 0, 1)
			new_value = info.low + (info.high - info.low) * normal
			changed = true
		}
		if self.state & {.Lost_Press, .Lost_Focus} != {} {
			self.bits -= {.Active}
		}
		// Hover
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
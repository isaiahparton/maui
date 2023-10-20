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
		i := int(info.vertical)

		size := self.box.high[i] - self.box.low[i]
		range := size - info.knob_size
		value_range := (info.high - info.low) if info.high > info.low else 1


		knob_box := self.box
		knob_size := knob_box.high[i] - knob_box.low[i]
		knob_box.low[i] += range * clamp((info.value - info.low) / value_range, 0, 1)
		knob_size = min(info.knob_size, knob_size)
		knob_box.high[i] = knob_box.low[i] + knob_size
		// Painting
		if .Should_Paint in self.bits {
			r := (self.box.high[1 - i] - self.box.low[1 - i]) * 0.5
			paint_rounded_box_fill(self.box, r, get_color(.Scrollbar))
			paint_rounded_box_fill(knob_box, r, blend_colors(get_color(.Scroll_Thumb), get_color(.Scroll_Thumb_Shade), (2 if .Pressed in self.state else hover_time) * 0.1))
		}
		// Dragging
		if .Got_Press in self.state {
			if point_in_box(input.mouse_point, transmute(Box)knob_box) {
				core.drag_anchor = input.mouse_point - knob_box.low
				self.bits += {.Active}
			}/* else {
				normal := clamp((input.mouse_point[i] - box[i]) / range, 0, 1)
				new_value = low + (high - low) * normal
				changed = true
			}*/
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
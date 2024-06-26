package maui_widgets
import "../"

import "core:fmt"
import "core:strconv"
import "core:math"
import "core:intrinsics"

// Fancy slider
Slider_Info :: struct($T: typeid) {
	using info: maui.Widget_Info,
	value,
	low,
	high: T,
	guides: Maybe([]T),
	format: Maybe(string),
	orientation: Orientation,
}
do_slider :: proc(info: Slider_Info($T), loc := #caller_location) -> T {
	using maui
	SIZE :: 20
	RADIUS :: 9
	THICKNESS :: 1
	HALF_THICKNESS :: SIZE - THICKNESS
	value := info.value
	if self, ok := do_widget(info.id.? or_else hash(loc), {.Draggable}); ok {
		// Colocate
		self.box = info.box.? or_else layout_next(current_layout())
		size: [2]f32 = {width(self.box), SIZE} if info.orientation == .Horizontal else {SIZE, height(self.box)}
		self.box = align_inner(self.box, size, {.Near, .Middle})
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], self.state & {.Hovered, .Pressed} != {}, 0.1)	
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, 0.1)
		// Axis index
		i := int(info.orientation)
		j := 1 - i
		// The range along which the knob may travel
		range := (self.box.high[i] - self.box.low[i])
		// The offset of the knob for the current value
		offset := range * clamp(f32((info.value - info.low) / (info.high - info.low)), 0, 1)
		// The body
		bar_box: Box = self.box
		bar_box.low[j] += 4
		bar_box.high[j] -= 4
		// The knob shape
		knob_center: [2]f32
		switch info.orientation {
			case .Horizontal: 
			knob_center = {self.box.low.x + offset, (self.box.low.y + self.box.high.y) * 0.5}
			case .Vertical: 
			knob_center = {(self.box.low.x + self.box.high.x) * 0.5, self.box.high.y - offset}
		}
		// Formatting for the value
		format := info.format.? or_else "%v"
		// Paint!
		if .Should_Paint in self.bits {
			// Paint guides if there are some
			if info.guides != nil {
				r := f32(info.high - info.low)
				for entry in info.guides.? {
					x := bar_box.low.x + HALF_THICKNESS + range * (f32(entry - info.low) / r)
					paint_line({x, bar_box.low.y}, {x, bar_box.low.y - 10}, 1, ui.style.color.substance[1])
					paint_text(
						{x, bar_box.low.y - 12}, 
						{text = tmp_print(format, entry), font = ui.style.font.title, size = ui.style.text_size.title}, 
						{align = .Middle, baseline = .Bottom}, 
						ui.style.color.base_text[1],
						)
				}
			}
			// Paint the filled part of the body
			switch info.orientation {
				case .Horizontal: 
				paint_pill_fill_h({{min(bar_box.low.x + offset, bar_box.low.y), bar_box.low.y}, {bar_box.high.x, bar_box.high.y}}, ui.style.color.substance[0])
				paint_pill_fill_h({bar_box.low, {max(bar_box.low.x, bar_box.low.x + offset), bar_box.high.y}}, ui.style.color.accent[0])
				case .Vertical: 
				paint_pill_fill_v({bar_box.low, {bar_box.high.x, bar_box.high.y - (offset)}}, ui.style.color.substance[0])
				paint_pill_fill_v({{bar_box.low.x, bar_box.high.y - (offset)}, bar_box.high}, ui.style.color.accent[0])
			}
			paint_circle_fill_texture(knob_center, RADIUS, alpha_blend_colors(ui.style.color.accent[1], ui.style.color.accent_hover, hover_time * 0.1))
		}
		// Add a tooltip if hovered
		if hover_time > 0 {
			if info.orientation == .Horizontal {
				tooltip(self.id, tmp_printf(format, info.value), knob_center + {0, -((RADIUS + 7) + 7 * press_time)}, {.Middle, .Far}, .Top)
			} else {
				tooltip(self.id, tmp_printf(format, info.value), knob_center + {(RADIUS + 7) + 7 * press_time, 0}, {.Near, .Middle}, .Right)
			}
		}
		// Detect press
		if .Pressed in self.state {
			// Update the value
			self.state += {.Changed}
			point := input.mouse_point[i]

			switch info.orientation {
				case .Horizontal:
				value = clamp(info.low + T((point - self.box.low.x) / range) * (info.high - info.low), info.low, info.high)
				case .Vertical: 
				value = clamp(info.low + T((self.box.high.y - point) / range) * (info.high - info.low), info.low, info.high)
			}
			// Snap to guides
			if info.guides != nil {
				r := info.high - info.low
				for entry in info.guides.? {
					x := self.box.low.x + HALF_THICKNESS + f32(entry / r) * range
					if abs(x - point) < 10 {
						value = entry
					}
				}
			}
		}
		// Update hover state
		update_widget_hover(self, point_in_box(input.mouse_point, self.box) || point_in_box(input.mouse_point, Box{knob_center - RADIUS, knob_center + RADIUS}))
	}
	return value
}

// Boxangle slider with text edit
Box_Slider_Info :: struct($T: typeid) {
	value,
	low,
	high: T,
}
do_box_slider :: proc(info: Box_Slider_Info($T), loc := #caller_location) -> (new_value: T) where intrinsics.type_is_integer(T) {
	using maui
	new_value = info.value
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		// Colocate
		self.box = info.box.? or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		// Whatever
		box_width := width(self.box)
		// Focus
		if widget_clicked(self, .Left, 2) {
			self.bits += {.Active}
			self.state += {.Got_Focus}
		}
		// Paint
		if self.bits >= {.Should_Paint} {
			if .Active not_in self.bits {
				if info.low < info.high {
					paint_box_fill({self.box.low, {self.box.low.x + box_width * (f32(info.value - info.low) / f32(info.high - info.low)), self.box.high.y}}, ui.style.color.accent[1])
				} else {
					paint_box_fill(self.box, ui.style.color.accent[1])
				}
			}
		}
		// Format
		text := tmp_printf("%i", info.value)
		if .Active in self.bits {
			if self.state & {.Pressed, .Hovered} != {} {
				ctx.cursor = .Beam
			}
			// Get the buffer
			buffer := typing_agent_get_buffer(&ctx.typing_agent, self.id)
			// Do interactable text
			text_res := paint_interact_text(box_center(self.box), self, &ctx.typing_agent, {text = string(buffer[:]), font = ui.style.font.monospace, size = ui.style.text_size.field}, {align = .Middle, baseline = .Middle}, {}, ui.style.color.base_text[1])
			// Copy text to buffer when focused
			if .Got_Focus in self.state {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			// Update text editing
			if .Focused in self.state {
				if typing_agent_edit(&ctx.typing_agent, {
					array = buffer,
					bits = {.Numeric, .Integer},
				}) {
					if parsed_value, parse_ok := strconv.parse_int(string(buffer[:])); parse_ok {
						new_value = T(parsed_value)
					}
					ctx.painter.next_frame = true
				}
			}
		} else {
			center := box_center(self.box)
			paint_text(center, {font = painter.ui.style.default_font, size = painter.ui.style.default_font_size, text = text}, {align = .Middle, baseline = .Middle}, get_color(.Text, 0.5))
			if .Pressed in self.state {
				if info.low < info.high {
					new_value = T(f32(info.low) + clamp((input.mouse_point.x - self.box.low.x) / box_width, 0, 1) * f32(info.high - info.low))
				} else {
					new_value = info.value + T(input.mouse_point.x - input.last_mouse_point.x) + T(input.mouse_point.y - input.last_mouse_point.y)
				}
			}
			if .Hovered in self.state {
				ctx.cursor = .Resize_EW
			}
		}
		// Unfocus
		if .Focused not_in self.state {
			self.bits -= {.Active}
		}
		// Hovered?
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	if info.low < info.high {
		new_value = clamp(new_value, info.low, info.high)
	}
	return
}
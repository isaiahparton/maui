package maui_widgets
import "../"

import "core:fmt"
import "core:strconv"
import "core:math"
import "core:intrinsics"

// Fancy slider
Slider_Info :: struct($T: typeid) {
	value,
	low,
	high: T,
	guides: Maybe([]T),
	format: Maybe(string),
}
do_slider :: proc(info: Slider_Info($T), loc := #caller_location) -> T {
	using maui
	SIZE :: 20
	HEIGHT :: SIZE / 2
	HALF_HEIGHT :: HEIGHT / 2
	value := info.value
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		// Colocate
		self.box = layout_next(current_layout())
		self.box = child_box(self.box, {width(self.box), SIZE}, {.Near, .Middle})
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], self.state & {.Hovered, .Pressed} != {}, 0.1)	
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, 0.1)
		// The range along which the knob may travel
		range := width(self.box) - HEIGHT
		// The offset of the knob for the current value
		offset := range * clamp(f32((info.value - info.low) / (info.high - info.low)), 0, 1)
		// The body
		bar_box: Box = {{self.box.low.x, self.box.low.y + HALF_HEIGHT}, {self.box.high.x, self.box.high.y - HALF_HEIGHT}}
		// The knob shape
		knob_center: [2]f32 = {self.box.low.x + HALF_HEIGHT + offset, (self.box.low.y + self.box.high.y) * 0.5}
		knob_radius: f32 = 9
		// Interaction shading
		shade_radius := knob_radius + 5 * (press_time + hover_time)
		// Formatting for the value
		format := info.format.? or_else "%v"
		// Paint!
		if .Should_Paint in self.bits {
			// Paint guides if there are some
			if info.guides != nil {
				r := f32(info.high - info.low)
				for entry in info.guides.? {
					x := bar_box.low.x + HALF_HEIGHT + range * (f32(entry - info.low) / r)
					//paint_line({x, bar_box.low.y}, {x, bar_box.low.y - 10}, 1, get_color(.Widget))
					paint_text(
						{x, bar_box.low.y - 12}, 
						{text = tmp_print(format, entry), font = style.font.title, size = style.text_size.title}, 
						{align = .Middle, baseline = .Bottom}, 
						style.color.text,
						)
				}
			}
			// Paint the background if needed
			if info.value < info.high {
				//paint_rounded_box_fill(bar_box, HALF_HEIGHT, get_color(.Widget_Back))
			}
			// Paint the filled part of the body
			//paint_rounded_box_fill({bar_box.low, {bar_box.low.x + offset, bar_box.high.y}}, HALF_HEIGHT, alpha_blend_colors(color, {0, 0, 0, 255}, 0.25))
			// Paint the knob
			//paint_circle_fill_texture(knob_center, knob_radius, alpha_blend_colors(color, 255, (hover_time + press_time) * 0.25))
		}
		// Add a tooltip if hovered
		if hover_time > 0 {
			tooltip(self.id, tmp_printf(format, info.value), knob_center + {0, -shade_radius - 2}, {.Middle, .Far})
		}
		// Detect press
		if .Pressed in self.state {
			// Update the value
			self.state += {.Changed}
			point := input.mouse_point.x
			value = clamp(info.low + T((point - (self.box.low.x + HALF_HEIGHT)) / range) * (info.high - info.low), info.low, info.high)
			// Snap to guides
			if info.guides != nil {
				r := info.high - info.low
				for entry in info.guides.? {
					x := self.box.low.x + HALF_HEIGHT + f32(entry / r) * range
					if abs(x - point) < 10 {
						value = entry
					}
				}
			}
		}
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return clamp(value, info.low, info.high)
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
		self.box = use_next_box() or_else layout_next(current_layout())
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
			paint_shaded_box(self.box, {style.color.indent_dark, style.color.indent, style.color.indent_light})
			if .Active not_in self.bits {
				if info.low < info.high {
					paint_box_fill({self.box.low, {self.box.low.x + box_width * (f32(info.value - info.low) / f32(info.high - info.low)), self.box.high.y}}, style.color.accent)
				} else {
					paint_box_fill(self.box, style.color.accent)
				}
			}
			// paint_box_stroke(self.box, 1, get_color(.Widget_Stroke_Focused) if .Active in self.bits else get_color(.Widget_Stroke, hover_time))
		}
		// Format
		text := tmp_printf("%i", info.value)
		if .Active in self.bits {
			if self.state & {.Pressed, .Hovered} != {} {
				core.cursor = .Beam
			}
			// Get the buffer
			buffer := typing_agent_get_buffer(&core.typing_agent, self.id)
			// Do interactable text
			text_res := paint_interact_text(box_center(self.box), self, &core.typing_agent, {text = string(buffer[:]), font = style.font.monospace, size = style.text_size.field}, {align = .Middle, baseline = .Middle}, {}, style.color.text)
			// Copy text to buffer when focused
			if .Got_Focus in self.state {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			// Update text editing
			if .Focused in self.state {
				if typing_agent_edit(&core.typing_agent, {
					array = buffer,
					bits = {.Numeric, .Integer},
				}) {
					if parsed_value, parse_ok := strconv.parse_int(string(buffer[:])); parse_ok {
						new_value = T(parsed_value)
					}
					core.paint_next_frame = true
				}
			}
		} else {
			center := box_center(self.box)
			paint_text(center, {font = painter.style.default_font, size = painter.style.default_font_size, text = text}, {align = .Middle, baseline = .Middle}, get_color(.Text, 0.5))
			if .Pressed in self.state {
				if info.low < info.high {
					new_value = T(f32(info.low) + clamp((input.mouse_point.x - self.box.low.x) / box_width, 0, 1) * f32(info.high - info.low))
				} else {
					new_value = info.value + T(input.mouse_point.x - input.last_mouse_point.x) + T(input.mouse_point.y - input.last_mouse_point.y)
				}
			}
			if .Hovered in self.state {
				core.cursor = .Resize_EW
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
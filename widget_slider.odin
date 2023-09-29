package maui

import "core:strconv"
import "core:fmt"
import "core:intrinsics"

Orientation :: enum {
	Horizontal,
	Vertical,
}

// Integer spinner (compound widget)
Spinner_Info :: struct($T: typeid) where intrinsics.type_is_numeric(T) {
	value,
	low,
	high: T,
	increment: Maybe(T),
	orientation: Orientation,
	trim_decimal: bool,
}

do_spinner :: proc(info: Spinner_Info($T), loc := #caller_location) -> (new_value: T) {
	loc := loc
	new_value = info.value
	// Sub-widget boxes
	box := layout_next(current_layout())
	increase_box, decrease_box: Box
	if info.orientation == .Horizontal {
		buttons_box := get_box_right(box, box.h)
		increase_box = get_box_top(buttons_box, box.h / 2)
		decrease_box = get_box_bottom(buttons_box, box.h / 2)
	} else {
		increase_box = get_box_top(box, box.w / 2)
		decrease_box = get_box_bottom(box, box.w / 2)
	}
	increment := info.increment.? or_else T(1)
	// Number input
	set_next_box(box)
	paint_box_fill(box, get_color(.Widget_Back))
	new_value = clamp(do_number_input(Number_Input_Info(T){
		value = info.value,
		text_align = ([2]Alignment){
			.Middle, 
			.Middle,
		} if info.orientation == .Vertical else nil,
		trim_decimal = info.trim_decimal,
	}, loc), info.low, info.high)
	// Step buttons
	loc.column += 1
	set_next_box(decrease_box)
	if do_button({
		label = "\uEA4E", 
		align = .Middle,
		style = .Subtle,
	}, loc) {
		new_value = max(info.low, info.value - increment)
	}
	loc.column += 1
	set_next_box(increase_box)
	if do_button({
		label = "\uEA78", 
		align = .Middle,
		style = .Subtle,
	}, loc) {
		new_value = min(info.high, info.value + increment)
	}
	return
}

// Fancy slider
Slider_Info :: struct($T: typeid) {
	value,
	low,
	high: T,
	guides: Maybe([]T),
	format: Maybe(string),
}
do_slider :: proc(info: Slider_Info($T), loc := #caller_location) -> T {
	SIZE :: 20
	HEIGHT :: SIZE / 2
	HALF_HEIGHT :: HEIGHT / 2
	value := info.value
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		self.box = layout_next(current_layout())
		self.box = child_box(self.box, {width(self.box), SIZE}, {.Near, .Middle})
		hover_time := animate_bool(&self.timers[0], self.state & {.Hovered, .Pressed} != {}, 0.1)	
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, 0.1)
		update_widget(self)

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
					paint_line({x, bar_box.low.y}, {x, bar_box.low.y - 10}, 1, get_color(.Widget))
					paint_text(
						{x, bar_box.low.y - 12}, 
						{text = tmp_print(format, entry), font = painter.style.title_font, size = painter.style.title_font_size}, 
						{align = .Middle, baseline = .Bottom}, 
						get_color(.Widget),
						)
				}
			}
			// Paint the background if needed
			if info.value < info.high {
				paint_rounded_box_fill(bar_box, HALF_HEIGHT, get_color(.Widget_Back))
			}
			// Paint the filled part of the body
			paint_rounded_box_fill({bar_box.low, {bar_box.low.x + offset, bar_box.high.y}}, HALF_HEIGHT, get_color(.Widget))
			// Paint the outline
			paint_rounded_box_stroke(bar_box, HALF_HEIGHT, 2, get_color(.Widget))
			// Paint the interactive shading
			paint_circle_fill(knob_center, shade_radius, 24, get_color(.Base_Shade, BASE_SHADE_ALPHA * hover_time))
			// Paint the knob
			paint_circle_fill_texture(knob_center, knob_radius, blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), hover_time * 0.1))
			paint_ring_fill_texture(knob_center, knob_radius - 2, knob_radius, get_color(.Widget_Stroke))
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
	new_value = info.value
	if self, ok := do_widget(hash(loc), layout_next(current_layout()), {.Draggable}); ok {
		hover_time := animate_bool(self.id, .Hovered in self.state, 0.1)

		if self.bits >= {.Should_Paint} {
			paint_box_fill(self.box, get_color(.Widget_Back))
			if .Active not_in self.bits {
				if info.low < info.high {
					paint_box_fill({self.box.x, self.box.y, self.box.w * (f32(info.value - info.low) / f32(info.high - info.low)), self.box.h}, alpha_blend_colors(get_color(.Widget), get_color(.Widget_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1))
				} else {
					paint_box_fill(self.box, get_color(.Widget))
				}
			}
			paint_box_stroke(self.box, 1, get_color(.Widget_Stroke, 0.5 + 0.5 * hover_time))
		}
		font_data := get_font_data(.Monospace)
		text := format_to_slice(info.value)
		if widget_clicked(self, .Left, 2) {
			self.bits += {.Active}
			self.state += {.Got_Focus}
		}
		if .Active in self.bits {
			if self.state & {.Pressed, .Hovered} != {} {
				core.cursor = .Beam
			}
			buffer := typing_agent_get_buffer(&core.typing_agent, self.id)
			select_result := selectable_text(self, {
				font_data = font_data, 
				data = buffer[:], 
				box = self.box, 
				padding = {self.box.h * 0.25, self.box.h / 2 - font_data.size / 2}, 
				align = {
					.Middle,
					.Middle,
				},
				bits = {
					.Select_All,
				},
			})
			if .Got_Focus in self.state {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			if .Focused in self.state {
				if typing_agent_edit(&core.typing_agent, {
					array = buffer,
					bits = {.Numeric, .Integer},
					select_result = select_result,
				}) {
					if parsed_value, parse_ok := strconv.parse_int(string(buffer[:])); parse_ok {
						new_value = T(parsed_value)
					}
					core.paint_next_frame = true
				}
			}
		} else {
			center: [2]f32 = {self.box.x + self.box.w / 2, self.box.y + self.box.h / 2}
			paint_aligned_string(font_data, string(text), center, get_color(.Text), {.Middle, .Middle})
			if .Pressed in self.state {
				if info.low < info.high {
					new_value = T(f32(info.low) + clamp((input.mouse_point.x - self.box.x) / self.box.w, 0, 1) * f32(info.high - info.low))
				} else {
					new_value = info.value + T(input.mouse_point.x - input.last_mouse_point.x) + T(input.mouse_point.y - input.last_mouse_point.y)
				}
			}
			if .Hovered in self.state {
				core.cursor = .Resize_EW
			}
		}

		if .Focused not_in self.state {
			self.bits -= {.Active}
		}
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	if info.low < info.high {
		new_value = clamp(new_value, info.low, info.high)
	}
	return
}
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
	value: T,
	low,
	high: Maybe(T),
	title: Maybe(string),
	increment: Maybe(T),
	orientation: Orientation,
	trim_decimal: bool,
}

do_spinner :: proc(info: Spinner_Info($T), loc := #caller_location) -> (new_value: T) where intrinsics.type_is_numeric(T) {
	loc := loc
	new_value = info.value
	// Sub-widget boxes
	box := use_next_box() or_else layout_next(current_layout())
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
	paint_box_fill(box, get_color(.Widget_BG))
	new_value = do_number_input(Number_Input_Info(T){
		value = info.value,
		title = info.title,
		select_all_on_focus = true,
		text_align = ([2]Alignment){
			.Middle, 
			.Middle,
		} if info.orientation == .Vertical else nil,
		trim_decimal = info.trim_decimal,
	}, loc)
	if new_value != info.value {
		if low, ok := info.low.?; ok {
			new_value = max(new_value, low)
		}
		if high, ok := info.high.?; ok {
			new_value = min(new_value, high)
		}
	}
	// Step buttons
	loc.column += 1
	set_next_box(decrease_box)
	if do_button({
		label = "\uEA4E", 
		align = .Middle,
		style = .Subtle,
		no_key_select = true,
	}, loc) {
		new_value -= increment
		if low, ok := info.low.?; ok {
			new_value = max(low, new_value)
		}
		if core.group_stack.height > 0 {
			core.group_stack.items[core.group_stack.height - 1].state += {.Changed}
		}
	}
	loc.column += 1
	set_next_box(increase_box)
	if do_button({
		label = "\uEA78", 
		align = .Middle,
		style = .Subtle,
		no_key_select = true,
	}, loc) {
		new_value += increment
		if high, ok := info.high.?; ok {
			new_value = min(high, new_value)
		}
		if core.group_stack.height > 0 {
			core.group_stack.items[core.group_stack.height - 1].state += {.Changed}
		}
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
do_slider :: proc(info: Slider_Info($T), loc := #caller_location) -> (changed: bool, new_value: T) {
	SIZE :: 16
	HEIGHT :: SIZE / 2
	HALF_HEIGHT :: HEIGHT / 2
	format := info.format.? or_else "%v"
	box := layout_next(current_layout())
	box = child_box(box, {box.w, SIZE}, {.Near, .Middle})
	if self, ok := do_widget(hash(loc), box, {.Draggable}); ok {
		push_id(self.id) 
			hover_time := animate_bool(hash_int(0), self.state & {.Hovered, .Pressed} != {}, 0.1)
			press_time := animate_bool(hash_int(1), .Pressed in self.state, 0.1)
		pop_id()
		range := self.box.w - HEIGHT
		offset := range * clamp(f32((info.value - info.low) / info.high), 0, 1)
		bar_box: Box = {self.box.x, self.box.y + HALF_HEIGHT, self.box.w, self.box.h - HEIGHT}
		thumb_center: [2]f32 = {self.box.x + HALF_HEIGHT + offset, self.box.y + self.box.h / 2}
		thumb_radius: f32 = 9
		shade_radius := thumb_radius + 5 * (press_time + hover_time)
		if .Should_Paint in self.bits {
			if info.guides != nil {
				r := f32(info.high - info.low)
				font_data := get_font_data(.Label)
				for entry in info.guides.? {
					x := bar_box.x + HALF_HEIGHT + range * (f32(entry - info.low) / r)
					paint_line({x, bar_box.y}, {x, bar_box.y - 10}, 1, get_color(.Widget))
					paint_aligned_string(font_data, text_format(format, entry), {x, bar_box.y - 12}, get_color(.Widget), {.Middle, .Far})
				}
			}
			if info.value < info.high {
				paint_rounded_box_fill(bar_box, HALF_HEIGHT, get_color(.Widget_BG))
			}
			paint_rounded_box_fill({bar_box.x, bar_box.y, offset, bar_box.h}, HALF_HEIGHT, blend_colors(get_color(.Widget), get_color(.Accent), hover_time))
			paint_rounded_box_stroke(bar_box, HALF_HEIGHT, true, get_color(.Widget_Stroke, 0.5))
			paint_circle_fill(thumb_center, shade_radius, 12, get_color(.Base_Shade, BASE_SHADE_ALPHA * hover_time))
			paint_circle_fill_texture(thumb_center, thumb_radius * 2, blend_colors(get_color(.Widget_BG), get_color(.Accent), hover_time))
			paint_circle_stroke_texture(thumb_center, thumb_radius * 2, true, get_color(.Widget_Stroke, 0.5))
		}
		if hover_time > 0 {
			tooltip(self.id, text_format(format, info.value), thumb_center + {0, -shade_radius - 2}, {.Middle, .Far})
		}

		if .Pressed in self.state {
			changed = true
			point := input.mouse_point.x
			new_value = clamp(info.low + T((point - self.box.x - HALF_HEIGHT) / range) * (info.high - info.low), info.low, info.high)
			if info.guides != nil {
				r := info.high - info.low
				for entry in info.guides.? {
					x := self.box.x + HALF_HEIGHT + f32(entry / r) * range
					if abs(x - point) < 10 {
						new_value = entry
					}
				}
			}
		}
	}
	return
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
			paint_box_fill(self.box, get_color(.Widget_BG))
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
	}
	if info.low < info.high {
		new_value = clamp(new_value, info.low, info.high)
	}
	return
}
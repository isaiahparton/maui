package maui

import "core:strconv"
import "core:fmt"
import "core:intrinsics"

// Integer spinner (compound widget)
Spinner_Info :: struct {
	value,
	low,
	high: int,
}
spinner :: proc(info: Spinner_Info, loc := #caller_location) -> (new_value: int) {
	loc := loc
	new_value = info.value
	// Sub-widget boxes
	box := layout_next(current_layout())
	left_box := box_cut_left(&box, box.h)
	right_box := box_cut_right(&box, box.h)
	// Number input
	set_next_box(box)
	paint_box_fill(box, get_color(.widget_bg))
	new_value = clamp(number_input(Number_Input_Info(int){
		value = info.value,
		select_options = {.align_center},
		no_outline = true,
	}), info.low, info.high)
	// Step buttons
	loc.column += 1
	set_next_box(left_box)
	if button({
		label = Icon.remove, 
		align = .middle,
	}, loc) {
		new_value = max(info.low, info.value - 1)
	}
	loc.column += 1
	set_next_box(right_box)
	if button({
		label = Icon.add, 
		align = .middle,
	}, loc) {
		new_value = min(info.high, info.value + 1)
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
slider :: proc(info: Slider_Info($T), loc := #caller_location) -> (changed: bool, new_value: T) {
	SIZE :: 16
	HEIGHT :: SIZE / 2
	HALF_HEIGHT :: HEIGHT / 2
	format := info.format.? or_else "%v"
	box := layout_next(current_layout())
	box = child_box(box, {box.w, SIZE}, {.near, .middle})
	if self, ok := widget(hash(loc), box, {.draggable}); ok {
		push_id(self.id) 
			hover_time := animate_bool(hash_int(0), self.state & {.hovered, .pressed} != {}, 0.1)
			press_time := animate_bool(hash_int(1), .pressed in self.state, 0.1)
		pop_id()
		range := self.box.w - HEIGHT
		offset := range * clamp(f32((info.value - info.low) / info.high), 0, 1)
		bar_box: Box = {self.box.x, self.box.y + HALF_HEIGHT, self.box.w, self.box.h - HEIGHT}
		thumb_center: [2]f32 = {self.box.x + HALF_HEIGHT + offset, self.box.y + self.box.h / 2}
		thumb_radius: f32 = 9
		shade_radius := thumb_radius + 5 * (press_time + hover_time)
		if .should_paint in self.bits {
			if info.guides != nil {
				r := f32(info.high - info.low)
				font_data := get_font_data(.label)
				for entry in info.guides.? {
					x := bar_box.x + HALF_HEIGHT + range * (f32(entry - info.low) / r)
					paint_line({x, bar_box.y}, {x, bar_box.y - 10}, 1, get_color(.widget))
					paint_aligned_string(font_data, text_format(format, entry), {x, bar_box.y - 12}, get_color(.widget), {.middle, .far})
				}
			}
			if info.value < info.high {
				paint_rounded_box_fill(bar_box, HALF_HEIGHT, get_color(.widget_bg))
			}
			paint_rounded_box_fill({bar_box.x, bar_box.y, offset, bar_box.h}, HALF_HEIGHT, blend_colors(get_color(.widget), get_color(.accent), hover_time))
			paint_circle_fill(thumb_center, shade_radius, 12, get_color(.base_shade, BASE_SHADE_ALPHA * hover_time))
			paint_circle_fill_texture(thumb_center, thumb_radius * 2, blend_colors(get_color(.widget), get_color(.accent), hover_time))
		}
		if hover_time > 0 {
			tooltip(self.id, text_format(format, info.value), thumb_center + {0, -shade_radius - 2}, {.middle, .far})
		}

		if .pressed in self.state {
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
box_slider :: proc(info: Box_Slider_Info($T), loc := #caller_location) -> (new_value: T) where intrinsics.type_is_integer(T) {
	new_value = info.value
	if self, ok := widget(hash(loc), layout_next(current_layout()), {.draggable}); ok {
		push_id(self.id) 
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.1)
			press_time := animate_bool(hash_int(1), .pressed in self.state, 0.1)
		pop_id()

		if self.bits >= {.should_paint} {
			paint_box_fill(self.box, get_color(.widget_bg))
			if .active not_in self.bits {
				if info.low < info.high {
					paint_box_fill({self.box.x, self.box.y, self.box.w * (f32(info.value - info.low) / f32(info.high - info.low)), self.box.h}, AlphaBlend(get_color(.widget), get_color(.widget_shade), 0.2 if .pressed in self.state else hover_time * 0.1))
				} else {
					paint_box_fill(self.box, get_color(.widget))
				}
			} else {
				paint_box_stroke(self.box, 2, get_color(.accent))
			}
		}
		font_data := get_font_data(.monospace)
		text := format_to_slice(info.value)
		if widget_clicked(self, .left, 2) {
			self.bits += {.active}
			self.state += {.got_focus}
		}
		if .active in self.bits {
			if self.state & {.pressed, .hovered} != {} {
				core.cursor = .beam
			}
			buffer := get_text_buffer(self.id)
			selectable_text(font_data, buffer[:], self.box, {.align_center, .select_all}, self)
			if .got_focus in self.state {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			if .focused in self.state {
				if text_edit(buffer, {.numeric, .integer}) {
					if parsedValue, ok := strconv.parse_int(string(buffer[:])); ok {
						new_value = T(parsedValue)
					}
					core.paintThisFrame = true
				}
			}
		} else {
			center: [2]f32 = {self.box.x + self.box.w / 2, self.box.y + self.box.h / 2}
			paint_aligned_string(font_data, string(text), center, get_color(.text), .middle, .middle)
			if .pressed in self.state {
				if info.low < info.high {
					new_value = T(f32(info.low) + clamp((input.mouse_point.x - self.box.x) / self.box.w, 0, 1) * f32(info.high - info.low))
				} else {
					new_value = info.value + T(input.mouse_point.x - input.prevMousePoint.x) + T(input.mouse_point.y - input.prevMousePoint.y)
				}
			}
			if .hovered in self.state {
				core.cursor = .resizeEW
			}
		}

		if .focused not_in self.state {
			self.bits -= {.active}
		}
	}
	if info.low < info.high {
		new_value = clamp(new_value, info.low, info.high)
	}
	return
}
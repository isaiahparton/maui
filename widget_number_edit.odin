package maui

import "core:fmt"
import "core:strconv"
import "core:math"
import "core:math/linalg"
import "core:runtime"
import "core:intrinsics"

/*
	Mathematical number input
*/
Numeric_Field_Info :: struct($T: typeid) where intrinsics.type_is_numeric(T) {
	precision: int,
	value: T,
	title,
	prefix,
	suffix: Maybe(string),
}
Numeric_Field_Result :: struct($T: typeid) where intrinsics.type_is_numeric(T) {
	value: T,
	changed,
	submitted: bool,
}
do_numeric_field :: proc(info: Numeric_Field_Info($T), loc := #caller_location) -> (res: Numeric_Field_Result(T)) {
	value := info.value
	if self, ok := do_widget(hash(loc), {.Draggable, .Can_Key_Select}); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		// Cursor style
		if self.state & {.Hovered, .Pressed} != {} {
			core.cursor = .Beam
		}
		// Get a temporary buffer
		buffer := get_tmp_buffer()
		// Format the value to text
		text := string(strconv.generic_ftoa(buffer, f64(value), 'f', info.precision, size_of(T) * 8))
		if text[0] == '+' && text[1] != 'I' {
			text = text[1:] 
		}
		// Paint!
		if (.Should_Paint in self.bits) {
			paint_rounded_box_fill(self.box, painter.style.widget_rounding, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), hover_time * 0.05))
			paint_rounded_box_stroke(self.box, painter.style.widget_rounding, 2, get_color(.Widget_Stroke, 1.0 if .Focused in self.state else (0.5 + 0.5 * hover_time)))
		}
		// Text!
		text_origin: [2]f32 = {self.box.high.x - WIDGET_PADDING, (self.box.low.y + self.box.high.y) / 2}
		if text, ok := info.suffix.?; ok {
			size := paint_text(text_origin, {text = text, font = painter.style.monospace_font, size = painter.style.monospace_font_size}, {align = .Right, baseline = .Middle}, get_color(.Text, 0.5))
			text_origin.x -= size.x
		}
		text_res := paint_interact_text(text_origin, self, &core.typing_agent, {text = text, font = painter.style.monospace_font, size = painter.style.monospace_font_size}, {align = .Right, baseline = .Middle}, {read_only = true}, get_color(.Text))
		text_origin.x = text_res.bounds.low.x
		if text, ok := info.prefix.?; ok {
			paint_text(text_origin, {text = text, font = painter.style.monospace_font, size = painter.style.monospace_font_size}, {align = .Right, baseline = .Middle}, get_color(.Text, 0.5))
		}
		// Value manipulation
		if (.Focused in self.state) {
			// Get the number info
			power: f64 = math.pow(10.0, f64(info.precision))
			base: f64 = 1.0 / power
			// The delete key clears the value
			if key_pressed(.Delete) {
				value = T(0)
				res.changed = true
			}
			// Paste
			if (key_pressed(.V) && (key_down(.Left_Control) || key_down(.Right_Control))) {
				if n, ok := strconv.parse_f64(get_clipboard_string()); ok {
					value = T(n)
					res.changed = true
				}
			}
			// Number input
			for r in input.runes[:input.rune_count] {
				r := r
				// Transform keypad input to regular numbers
				if (r >= 320 && r <= 329) {
					r -= 272
				}
				// Exclude anything that is not a number
				if (r < 48 || r > 57) {
					continue
				}
				number := int(r) - 48
				if (number == 0 && value < base) {
					continue
				}
				value *= 10.0 
				value += base * T(number) 
				// Set changed flag
				res.changed = true
			}
			// Deletion
			if (key_pressed(.Backspace) && value >= base) {
				if info.precision > 0 {
					value = f64(int(value / (base * 10.0)))
					value *= base 
				} else {
					value *= 0.1
					value = f64(int(value))
				}
				if value < base {
					value = 0
				}
				// Set changed flag
				res.changed = true
			}
			// Submit
			if (key_pressed(.Enter) || key_pressed(.Keypad_Enter)) {
				res.submitted = true
			}
		}
		// Hover state
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	res.value = value
	return
}	

/*
	Text based number input
*/
Number_Input_Info :: struct($T: typeid) where intrinsics.type_is_numeric(T) {
	value: T,
	title,
	suffix,
	format: Maybe(string),
	text_align: Maybe([2]Alignment),
	trim_decimal,
	no_outline: bool,
}
do_number_input :: proc(info: Number_Input_Info($T), loc := #caller_location) -> (new_value: T) {
	new_value = info.value
	if self, ok := do_widget(hash(loc), {.Draggable, .Can_Key_Select}); ok {
		using self
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)
		// Animation values
		hover_time := animate_bool(&timers[0], .Hovered in state, 0.1)
		// Cursor style
		if state & {.Hovered, .Pressed} != {} {
			core.cursor = .Beam
		}
		// Has decimal?
		has_decimal := false 
		switch typeid_of(T) {
			case f16, f32, f64: has_decimal = true
		}
		// Formatting
		text := transmute([]u8)tmp_printf(info.format.? or_else "%v", info.value)
		if info.trim_decimal && has_decimal {
			text = transmute([]u8)trim_zeroes(string(text))
		}
		// Painting
		text_align := info.text_align.? or_else {
			.Near,
			.Middle,
		}
		paint_box_fill(box, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), hover_time * 0.05))
		if !info.no_outline {
			stroke_color := get_color(.Widget_Stroke) if .Focused in self.state else get_color(.Widget_Stroke, 0.5 + 0.5 * hover_time)
			paint_labeled_widget_frame(
				box = box, 
				text = info.title, 
				offset = WIDGET_PADDING, 
				thickness = 1, 
				color = stroke_color,
			)
		}
		select_result: Selectable_Text_Result

		// Update text input
		if state >= {.Focused} {
			buffer := typing_agent_get_buffer(&core.typing_agent, id)
			if state >= {.Got_Focus} {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			text_edit_bits: Text_Edit_Bits = {.Numeric, .Integer}
			switch typeid_of(T) {
				case f16, f32, f64: text_edit_bits -= {.Integer}
			}
			select_result = selectable_text(self, {
				font_data = font_data, 
				data = buffer[:], 
				box = box, 
				padding = {box.h * 0.25, box.h / 2 - font_data.size / 2},
				align = text_align,
			})
			if typing_agent_edit(&core.typing_agent, {
				array = buffer, 
				bits = text_edit_bits, 
				capacity = 18,
				select_result = select_result,
			}) {
				core.paint_next_frame = true
				str := string(buffer[:])
				switch typeid_of(T) {
					case f64, f32, f16:  		
					new_value = T(strconv.parse_f64(str) or_else 0)
					case int, i128, i64, i32, i16, i8: 
					new_value = T(strconv.parse_i128(str) or_else 0)
					case u128, u64, u32, u16, u8:
					new_value = T(strconv.parse_u128(str) or_else 0)
				}
				state += {.Changed}
			}
		} else {
			select_result = selectable_text(self, {
				font_data = font_data, 
				data = text, 
				box = box, 
				padding = {box.h * 0.25, box.h / 2 - font_data.size / 2},
				align = text_align,
			})
		}

		if suffix, ok := info.suffix.?; ok {
			paint_string(font_data, suffix, {box.x + box.h * 0.25, box.y + box.h / 2} + select_result.view_offset + {select_result.text_size.x, 0}, get_color(.Text, 0.5), {
				align = {.Near, .Middle},
				clip_box = box,
			})
		}
	}
	return
}
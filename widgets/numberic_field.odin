package maui_widgets
import "../"

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
	using maui
	value := info.value
	if self, ok := do_widget(hash(loc), {.Draggable, .Can_Key_Select}); ok {
		// Colocate
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animate
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
			paint_rounded_box_corners_fill(self.box, style.rounding, style.rounded_corners, style.color.base[1])
			if .Focused in self.state {
				paint_rounded_box_corners_stroke(self.box, style.rounding, 2, style.rounded_corners, style.color.accent[1])
			}
		}
		// Get text origin
		text_origin: [2]f32 = {self.box.high.x - style.layout.widget_padding, (self.box.low.y + self.box.high.y) / 2}
		// Draw suffix
		if text, ok := info.suffix.?; ok {
			size := paint_text(text_origin, {text = text, font = style.font.content, size = style.text_size.field}, {align = .Right, baseline = .Middle}, style.color.base_text[0])
			text_origin.x -= size.x
		}
		// Main text
		text_res := paint_interact_text(text_origin, self, &core.typing_agent, {text = text, font = style.font.content, size = style.text_size.field}, {align = .Right, baseline = .Middle}, {read_only = true}, style.color.base_text[1])
		text_origin.x = text_res.bounds.low.x
		// Draw prefix
		if text, ok := info.prefix.?; ok {
			paint_text(text_origin, {text = text, font = style.font.content, size = style.text_size.field}, {align = .Right, baseline = .Middle}, style.color.base_text[0])
		}
		// Value manipulation
		if (.Focused in self.state) {
			// Get the number info
			power: f64 = math.pow(10.0, f64(info.precision))
			base: f64 = 1.0 / power
			factor: f64 = -1 if .Negative in self.bits else 1
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
				if (number == 0 && value < T(base)) {
					continue
				}
				value *= 10.0 
				value += T(base * factor) * T(number)
				// Set changed flag
				res.changed = true
			}
			when !intrinsics.type_is_unsigned(T) {
				if key_pressed(.Minus) || key_pressed(.Keypad_Minus) {
					value = -value
					self.bits ~= {.Negative}
				}
			}
			// Deletion
			if (key_pressed(.Backspace) && value >= T(base)) {
				if info.precision > 0 {
					value = T(int(value / T(base * 10.0)))
					value *= T(base) 
				} else {
					value /= 10
					value = T(int(value))
				}
				if value < T(base) {
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
	text_align: Maybe(maui.Text_Align),
	trim_decimal,
	no_outline: bool,
}
do_number_input :: proc(info: Number_Input_Info($T), loc := #caller_location) -> (new_value: T) {
	using maui
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
		text := tmp_printf(info.format.? or_else "%v", info.value)
		if info.trim_decimal && has_decimal {
			text = trim_zeroes(text)
		}
		// Background
		if .Should_Paint in self.bits {
			paint_rounded_box_corners_fill(box, style.rounding, style.rounded_corners, style.color.base[1])
			if .Focused in self.state {
				paint_rounded_box_corners_stroke(box, style.rounding, 2, style.rounded_corners, style.color.accent[1])
			}
		}
		// Do text interaction
		text_align := info.text_align.? or_else .Left
		inner_box: Box = {{self.box.low.x + style.layout.widget_padding, self.box.low.y}, {self.box.high.x - style.layout.widget_padding, self.box.high.y}}
		text_origin: [2]f32 = {inner_box.low.x, (inner_box.low.y + inner_box.high.y) / 2} - self.offset
		if text_align == .Middle {
			text_origin.x += width(inner_box) / 2
		}
		text_res: Text_Interact_Result
		// Focus
		if .Focused in self.state {
			offset_x_limit := max(width(text_res.bounds) - width(inner_box), 0)
			if .Pressed in self.state {
				left_over := self.box.low.x - input.mouse_point.x 
				if left_over > 0 {
					self.offset.x -= left_over * 0.2
					painter.next_frame = true
				}
				right_over := input.mouse_point.x - self.box.high.x
				if right_over > 0 {
					self.offset.x += right_over * 0.2
					painter.next_frame = true
				}
				self.offset.x = clamp(self.offset.x, 0, offset_x_limit)
			} else {
				if core.typing_agent.index < core.typing_agent.last_index {
					if text_res.selection_bounds.low.x < inner_box.low.x {
						self.offset.x = max(0, text_res.selection_bounds.low.x - text_res.bounds.low.x)
					}
				} else if core.typing_agent.index > core.typing_agent.last_index || core.typing_agent.length > core.typing_agent.last_length {
					if text_res.selection_bounds.high.x > inner_box.high.x {
						self.offset.x = min(offset_x_limit, (text_res.selection_bounds.high.x - text_res.bounds.low.x) - width(inner_box))
					}
				}
			}
		}
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
			text_res = paint_interact_text(
				text_origin, 
				self,
				&core.typing_agent, 
				{text = string(buffer[:]), font = style.font.label, size = style.text_size.label},
				{align = text_align, baseline = .Middle, clip = self.box},
				{},
				style.color.base_text[1],
			)
			if typing_agent_edit(&core.typing_agent, {
				array = buffer, 
				bits = text_edit_bits, 
				capacity = 18,
			}) {
				painter.next_frame = true
				str := string(buffer[:])
				switch typeid_of(T) {
					case f64, f32, f16:  		
					new_value = T(strconv.parse_f64(str) or_else 0)
					case int, i128, i64, i32, i16, i8: 
					new_value = T(strconv.parse_i128(str) or_else 0)
					case uint, u128, u64, u32, u16, u8:
					new_value = T(strconv.parse_u128(str) or_else 0)
				}
				state += {.Changed}
			}
		} else {
			text_res = paint_interact_text(
				text_origin, 
				self,
				&core.typing_agent, 
				{text = text, font = style.font.label, size = style.text_size.label},
				{align = text_align, baseline = .Middle, clip = self.box},
				{},
				style.color.base_text[1],
			)
		}

		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
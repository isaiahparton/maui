package maui_widgets
import "../"

import "core:io"
import "core:fmt"
import "core:strconv"
import "core:strconv/decimal"
import "core:math"
import "core:math/linalg"
import "core:runtime"
import "core:intrinsics"

Digit :: u8

Digits :: struct {
	digits: [39]Digit,
	count,
	decimal: int,
	negative: bool,
}
pop_digit :: proc(d: ^Digits) -> Digit {
	d.count = max(d.count - 1, 0)
	return d.digits[d.count]
}
push_digit :: proc(d: ^Digits, digit: Digit) {
	if d.count >= len(d.digits) {
		return
	}
	d.digits[d.count] = min(digit, 9)
	d.count += 1
}
f64_to_digits :: proc(value: f64, precision: int) -> (d: Digits) {
	bits := transmute(u64)value
	flt := &strconv._f64_info

	neg := bits >> (flt.expbits + flt.mantbits) != 0
	exp := int(bits >> flt.mantbits) & (1 << flt.expbits - 1)
	mant := bits & (u64(1) << flt.mantbits - 1)

	switch exp {
		case 1 << flt.expbits - 1: break
		case 0: exp += 1
		case: mant |= u64(1) << flt.mantbits
	}

	exp += flt.bias

	d_: decimal.Decimal
	dec := &d_
	decimal.assign(dec, mant)
	decimal.shift(dec, exp - int(flt.mantbits))

	return
}
digits_to_f64 :: proc(d: ^Digits) -> (value: f64) {
	for n, e in d.digits[:d.count] {
		e := e - d.decimal
		value += math.pow(10, f64(e)) * f64(n)
	}
	if d.negative {
		value = -value
	}
	return
}
write_digits :: proc(d: ^Digits, w: io.Writer) -> (n: int) {
	for i := 0; i < d.count; i += 1 {
		io.write_byte(w, '0' + d.digits[i], &n)
		if i == d.count - d.decimal {
			io.write_byte(w, '.', &n)
		}
	}
	return
}

/*
	Mathematical number input
*/
Numeric_Field_Info :: struct($T: typeid) where intrinsics.type_is_numeric(T) {
	using info: maui.Widget_Info,
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
		self.box = info.box.? or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		// Cursor style
		if self.state & {.Hovered, .Pressed} != {} {
			ctx.cursor = .Beam
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
			paint_rounded_box_corners_fill(self.box, ctx.style.rounding, ctx.style.rounded_corners, ctx.style.color.base[1])
			if .Focused in self.state {
				paint_rounded_box_corners_stroke(self.box, ctx.style.rounding, 2, ctx.style.rounded_corners, ctx.style.color.accent[1])
			}
		}
		// Get text origin
		text_origin: [2]f32 = {self.box.high.x - ctx.style.layout.widget_padding, (self.box.low.y + self.box.high.y) / 2}
		// Draw suffix
		if text, ok := info.suffix.?; ok {
			size := paint_text(text_origin, {text = text, font = ctx.style.font.content, size = ctx.style.text_size.field}, {align = .Right, baseline = .Middle}, ctx.style.color.base_text[0])
			text_origin.x -= size.x
		}
		// Main text
		text_res := paint_interact_text(text_origin, self, &ctx.typing_agent, {text = text, font = ctx.style.font.content, size = ctx.style.text_size.field}, {align = .Right, baseline = .Middle, clip = self.box}, {read_only = true}, ctx.style.color.base_text[1])
		text_origin.x = text_res.bounds.low.x
		// Draw prefix
		if text, ok := info.prefix.?; ok {
			paint_text(text_origin, {text = text, font = ctx.style.font.content, size = ctx.style.text_size.field}, {align = .Right, baseline = .Middle, clip = self.box}, ctx.style.color.base_text[0])
		}
		// Value manipulation
		if (.Focused in self.state) {
			// Get the number info
			power: f64 = math.pow(10.0, f64(info.precision))
			factor: f64 = -1 if .Negative in self.bits else 1
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
			significant: bool
			if .Negative in self.bits {
				significant = value <= T(base)
			} else {
				significant = value >= T(base)
			}
			// Deletion
			if (key_pressed(.Backspace) && significant) {
				if info.precision > 0 {
					value = T(int(value / T(base * 10.0)))
					value *= T(base) 
				} else {
					value /= 10
					value = T(int(value))
				}
				if .Negative in self.bits {
					if value > T(base) {
						value = 0
					}
				} else {
					if value < T(base) {
						value = 0
					}
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
		self.box = info.box.? or_else layout_next(current_layout())
		update_widget(self)
		// Animation values
		hover_time := animate_bool(&timers[0], .Hovered in state, 0.1)
		// Cursor style
		if state & {.Hovered, .Pressed} != {} {
			ctx.cursor = .Beam
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
			paint_rounded_box_corners_fill(box, ctx.style.rounding, ctx.style.rounded_corners, ctx.style.color.base[1])
			if .Focused in self.state {
				paint_rounded_box_corners_stroke(box, ctx.style.rounding, 2, ctx.style.rounded_corners, ctx.style.color.accent[1])
			}
		}
		// Do text interaction
		text_align := info.text_align.? or_else .Left
		inner_box: Box = {{self.box.low.x + ctx.style.layout.widget_padding, self.box.low.y}, {self.box.high.x - ctx.style.layout.widget_padding, self.box.high.y}}
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
					ctx.painter.next_frame = true
				}
				right_over := input.mouse_point.x - self.box.high.x
				if right_over > 0 {
					self.offset.x += right_over * 0.2
					ctx.painter.next_frame = true
				}
				self.offset.x = clamp(self.offset.x, 0, offset_x_limit)
			} else {
				if ctx.typing_agent.index < ctx.typing_agent.last_index {
					if text_res.selection_bounds.low.x < inner_box.low.x {
						self.offset.x = max(0, text_res.selection_bounds.low.x - text_res.bounds.low.x)
					}
				} else if ctx.typing_agent.index > ctx.typing_agent.last_index || ctx.typing_agent.length > ctx.typing_agent.last_length {
					if text_res.selection_bounds.high.x > inner_box.high.x {
						self.offset.x = min(offset_x_limit, (text_res.selection_bounds.high.x - text_res.bounds.low.x) - width(inner_box))
					}
				}
			}
		}
		// Update text input
		if state >= {.Focused} {
			buffer := typing_agent_get_buffer(&ctx.typing_agent, id)
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
				&ctx.typing_agent, 
				{text = string(buffer[:]), font = ctx.style.font.label, size = ctx.style.text_size.label},
				{align = text_align, baseline = .Middle, clip = self.box},
				{},
				ctx.style.color.base_text[1],
			)
			if typing_agent_edit(&ctx.typing_agent, {
				array = buffer, 
				bits = text_edit_bits, 
				capacity = 18,
			}) {
				ctx.painter.next_frame = true
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
				&ctx.typing_agent, 
				{text = text, font = ctx.style.font.label, size = ctx.style.text_size.label},
				{align = text_align, baseline = .Middle, clip = self.box},
				{},
				ctx.style.color.base_text[1],
			)
		}

		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
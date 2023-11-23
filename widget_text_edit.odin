package maui
// Core dependencies
import "core:fmt"
import "core:runtime"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:unicode/utf8"
import "core:math"
import "core:math/linalg"
import "core:intrinsics"

Text_Edit_Result :: struct {
	using self: ^Widget,
	changed: bool,
}

// Edit a dynamic array of bytes
Text_Input_Data :: union {
	^[dynamic]u8,
	^string,
}

Text_Input_Info :: struct {
	data: Text_Input_Data,
	title: Maybe(string),
	placeholder: Maybe(string),
	line_height: Maybe(f32),
	edit_bits: Text_Edit_Bits,
	select_all_on_focus: bool,
	hidden: bool,
}
Text_Input_Result :: struct {
	changed: bool,
	chip_clicked: Maybe(int),
}
do_text_input :: proc(info: Text_Input_Info, loc := #caller_location) -> (change: bool) {
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(current_layout()), {.Draggable, .Is_Text_Input}); ok {
		using self
		// Text cursor
		if .Hovered in self.state {
			core.cursor = .Beam
		}

		// Animation values
		hover_time := animate_bool(self.id, .Hovered in state, 0.1)
		buffer := info.data.(^[dynamic]u8) or_else typing_agent_get_buffer(&core.typing_agent, self.id)
		font_data := get_font_data(.Default)

		// Text edit
		if state >= {.Got_Focus} {
			if text, ok := info.data.(^string); ok {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
		}

		should_paint := .Should_Paint in bits && !(info.hidden && .Focused not_in state)

		// Paint!
		if should_paint {
			paint_box_fill(box, alpha_blend_colors(get_color(.Widget_BG), get_color(.Widget_Shade), hover_time * 0.05))
		}
		line_height := info.line_height.? or_else box.h
		y_padding := line_height / 2 - font_data.size / 2
		data_slice: []u8
		switch type in info.data {
			case ^string:
			data_slice = transmute([]u8)type[:]
			case ^[dynamic]u8:
			data_slice = type[:]
		}

		padding: [2]f32 = {WIDGET_TEXT_OFFSET, y_padding}

		text_bits: Selectable_Text_Bits
		if .Should_Paint not_in bits {
			text_bits += {.No_Paint}
		}
		if info.select_all_on_focus {
			text_bits += {.Select_All}
		}

		// Set text offset
		select_result := selectable_text(self, {
			font_data = font_data, 
			data = data_slice, 
			box = box, 
			padding = padding,
			view_offset = core.typing_agent.view_offset if .Focused in state else {},
			bits = text_bits,
		})
		if .Focused in state {
			core.typing_agent.view_offset = select_result.view_offset
			change = typing_agent_edit(&core.typing_agent, {
				array = buffer,
				bits = info.edit_bits,
				select_result = select_result,
			})
			if change {
				state += {.Changed}
				core.paint_next_frame = true
				if value, ok := info.data.(^string); ok {
					delete(value^)
					value^ = strings.clone_from_bytes(buffer[:])
				}
			}
		}

		// Widget decoration
		if should_paint {

			// Widget decor
			stroke_color := get_color(.Widget_Stroke, 1.0 if .Focused in self.state else (0.5 + 0.5 * hover_time))
			paint_labeled_widget_frame(
				box = box, 
				text = info.title, 
				offset = WIDGET_TEXT_OFFSET,
				thickness = 1, 
				color = stroke_color,
			)

			// Draw placeholder
			if info.placeholder != nil {
				if len(buffer) == 0 {
					paint_string(font_data, info.placeholder.?, {box.x + padding.x, box.y + padding.y}, get_color(.Text, 0.5))
				}
			}

			if info.title != nil {
				box.y -= 10
				box.h += 10
			}
		}
	}
	return
}
// Edit number values
Number_Input_Info :: struct($T: typeid) where intrinsics.type_is_numeric(T) {
	value: T,
	title,
	suffix,
	format: Maybe(string),
	text_align: Maybe([2]Alignment),
	trim_decimal,
	no_outline: bool,
	select_all_on_focus: bool,
}
do_number_input :: proc(info: Number_Input_Info($T), loc := #caller_location) -> (new_value: T) {
	new_value = info.value
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(current_layout()), {.Draggable, .Is_Text_Input}); ok {
		using self
		// Animation values
		hover_time := animate_bool(self.id, .Hovered in state, 0.1)
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
		text := text_format_slice(info.format.? or_else "%v", info.value)
		if info.trim_decimal && has_decimal {
			text = transmute([]u8)text_remove_trailing_zeroes(string(text))
		}
		// Painting
		text_align := info.text_align.? or_else {
			.Near,
			.Middle,
		}
		font_data := get_font_data(.Default)
		paint_box_fill(box, alpha_blend_colors(get_color(.Widget_BG), get_color(.Widget_Shade), hover_time * 0.05))
		if !info.no_outline {
			stroke_color := get_color(.Widget_Stroke) if .Focused in self.state else get_color(.Widget_Stroke, 0.5 + 0.5 * hover_time)
			paint_labeled_widget_frame(
				box = box, 
				text = info.title, 
				offset = WIDGET_TEXT_OFFSET, 
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
				bits = Selectable_Text_Bits{.Select_All} if info.select_all_on_focus else {},
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
					
					case uint, u128, u64, u32, u16, u8:
					new_value = T(strconv.parse_u128(str) or_else 0)
				}
				self.value = new_value
				state += {.Changed}
			}
		} else {
			select_result = selectable_text(self, {
				font_data = font_data, 
				data = text, 
				box = box, 
				padding = {box.h * 0.25, box.h / 2 - font_data.size / 2},
				align = text_align,
				bits = Selectable_Text_Bits{.Select_All} if info.select_all_on_focus else {},
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
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(current_layout()), {.Draggable}); ok {
		// Animate
		hover_time := animate_bool(self.id, .Hovered in self.state, 0.075)
		// Cursor style
		if self.state & {.Hovered, .Pressed} != {} {
			core.cursor = .Beam
		}
		// Get a temporary buffer
		buffer: [32]u8
		// Format the value to text
		text := string(strconv.generic_ftoa(buffer[:], f64(value), 'f', info.precision, size_of(T) * 8))
		if text[0] == '+' && text[1] != 'I' {
			text = text[1:] 
		}
		// Painting
		font_data := get_font_data(.Default)
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, alpha_blend_colors(get_color(.Widget_BG), get_color(.Widget_Shade), hover_time * 0.05))
			stroke_color := get_color(.Widget_Stroke) if .Focused in self.state else get_color(.Widget_Stroke, 0.5 + 0.5 * hover_time)
			paint_labeled_widget_frame(
				box = self.box, 
				text = info.title, 
				offset = WIDGET_TEXT_OFFSET, 
				thickness = 1, 
				color = stroke_color,
			)
		}
		paint_aligned_string(font_data, text, {self.box.x + self.box.w - self.box.h * 0.25, self.box.y + self.box.h / 2}, get_color(.Text), {.Far, .Middle})
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
			if (key_pressed(.V) && key_down(.Control)) {
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
			if (key_pressed(.Enter)) {
				res.submitted = true
			}
		}
	}
	if res.changed {
		core.paint_next_frame = true
	}
	res.value = value
	return
}	
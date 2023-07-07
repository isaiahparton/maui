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
	select_bits: Selectable_Text_Bits,
	edit_bits: Text_Edit_Bits,
}
do_text_input :: proc(info: Text_Input_Info, loc := #caller_location) -> (change: bool) {
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(current_layout()), {.draggable, .can_key_select}); ok {
		using self
		// Text cursor
		if .hovered in self.state {
			core.cursor = .beam
		}

		// Animation values
		hover_time := animate_bool(self.id, .hovered in state, 0.1)

		buffer := info.data.(^[dynamic]u8) or_else typing_agent_get_buffer(&core.typing_agent, self.id)

		// Text edit
		if state >= {.focused} {
			change = typing_agent_edit(&core.typing_agent, buffer, info.edit_bits)
			if change {
				state += {.changed}
				core.paint_next_frame = true
				if value, ok := info.data.(^string); ok {
					delete(value^)
					value^ = strings.clone_from_bytes(buffer[:])
				}
			}
		}
		if state >= {.got_focus} {
			if text, ok := info.data.(^string); ok {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
		}

		// Paint!
		paint_box_fill(box, alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), hover_time * 0.05))
		line_height := info.line_height.? or_else box.h
		y_padding := line_height / 2 - font_data.size / 2
		data_slice: []u8
		switch type in info.data {
			case ^string:
			data_slice = transmute([]u8)type[:]
			case ^[dynamic]u8:
			data_slice = type[:]
		}

		padding: [2]f32 = {line_height * 0.25, y_padding}

		text_bits: Selectable_Text_Bits
		if .should_paint not_in bits {
			text_bits += {.no_paint}
		}

		// Set text offset
		select_result := selectable_text(self, {
			font_data = font_data, 
			data = data_slice, 
			box = box, 
			padding = padding,
			view_offset = core.typing_agent.view_offset if .focused in state else {},
			bits = text_bits,
		})
		if .focused in state {
			core.typing_agent.view_offset = select_result.view_offset
		}

		// Text edit
		if state >= {.focused} {
			change = typing_agent_edit(&core.typing_agent, {
				array = buffer, 
				bits = info.edit_bits,
				select_result = select_result,
			})
			if change {
				core.paint_next_frame = true
				if value, ok := info.data.(^string); ok {
					delete(value^)
					value^ = strings.clone_from_bytes(buffer[:])
				}
			}
		}

		// Widget decoration
		if .should_paint in bits {

			// Widget decor
			stroke_color := get_color(.widget_stroke, 1.0 if .focused in self.state else (0.5 + 0.5 * hover_time))
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
					paint_string(font_data, info.placeholder.?, {box.x + padding.x, box.y + padding.y}, get_color(.text, 0.5))
				}
			}
		}
	}
	return
}
// Edit number values
Number_Input_Info :: struct($T: typeid) {
	value: T,
	title,
	format: Maybe(string),
	text_align: Maybe([2]Alignment),
	no_outline: bool,
}
do_number_input :: proc(info: Number_Input_Info($T), loc := #caller_location) -> (newValue: T) {
	newValue = info.value
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(current_layout()), {.draggable, .can_key_select}); ok {
		using self
		// Animation values
		hover_time := animate_bool(self.id, .hovered in state, 0.1)
		// Cursor style
		if state & {.hovered, .pressed} != {} {
			core.cursor = .beam
		}

		// Formatting
		text := text_format_slice(info.format.? or_else "%v", info.value)

		// Painting
		text_align := info.text_align.? or_else {
			.near,
			.middle,
		}
		font_data := get_font_data(.monospace)
		paint_box_fill(box, alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), hover_time * 0.05))
		if !info.no_outline {
			stroke_color := get_color(.widget_stroke) if .focused in self.state else get_color(.widget_stroke, 0.5 + 0.5 * hover_time)
			paint_labeled_widget_frame(
				box = box, 
				text = info.title, 
				offset = WIDGET_TEXT_OFFSET, 
				thickness = 1, 
				color = stroke_color,
				)
		}
		// Update text input
		if state >= {.focused} {
			buffer := typing_agent_get_buffer(&core.typing_agent, id)
			if state >= {.got_focus} {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			text_edit_bits: Text_Edit_Bits = {.numeric, .integer}
			switch typeid_of(T) {
				case f16, f32, f64: text_edit_bits -= {.integer}
			}
			select_result := selectable_text(self, {
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
					if temp, ok := strconv.parse_f64(str); ok {
						newValue = T(temp)
					}
					case int, i128, i64, i32, i16, i8: 
					if temp, ok := strconv.parse_i128(str); ok {
						newValue = T(temp)
					}
					case u128, u64, u32, u16, u8:
					if temp, ok := strconv.parse_u128(str); ok {
						newValue = T(temp)
					}
				}
				state += {.changed}
			}
		} else {
			selectable_text(self, {
				font_data = font_data, 
				data = text, 
				box = box, 
				padding = {box.h * 0.25, box.h / 2 - font_data.size / 2},
				align = text_align,
			})
		}
	}
	return
}

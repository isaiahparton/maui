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
// Advanced interactive text
Selectable_Text_Option :: enum {
	password,
	select_all,
	align_center,
	align_right,
}
Selectable_Text_Options :: bit_set[Selectable_Text_Option]
// Displays clipped, selectable text that can be copied to clipboard
selectable_text :: proc(font_data: ^Font_Data, data: []u8, box: Box, options: Selectable_Text_Options, widget: ^Widget) {
	state := &core.scribe
	// Hovered index
	hover_index := 0
	min_dist: f32 = math.F32_MAX
	// Determine text origin
	origin: [2]f32 = {box.x + box.h * 0.25, box.y + box.h / 2 - font_data.size / 2}
	if options & {.align_center, .align_right} != {} {
		textSize := measure_string(font_data, string(data))
		if options >= {.align_center} {
			origin.x = box.x + box.w / 2 - textSize.x / 2
		} else if options >= {.align_right} {
			origin.x = box.x + box.w - textSize.x
		}
	}
	point := origin
	// Total text size
	size: [2]f32
	// Cursor start and end position
	cursor_start, 
	cursor_end: [2]f32
	// Reset view offset when just focused
	if .got_focus in widget.state {
		core.scribe.index = 0
		core.scribe.offset = {}
	}
	// Offset view when currently focused
	if .focused in widget.state {
		point -= core.scribe.offset
		if key_down(.control) {
			if key_pressed(.c) {
				if state.length > 0 {
					set_clipboard_string(string(data[state.index:][:state.length]))
				} else {
					set_clipboard_string(string(data[:]))
				}
			}
		}
	}
	// Iterate over the bytes
	for index := 0; index <= len(data); {
		// Decode the next glyph
		bytes := 1
		glyph: rune
		if index < len(data) {
			glyph, bytes = utf8.decode_rune_in_bytes(data[index:])
		}
		// Password placeholder glyph
		if .password in options {
			glyph = '•'
		}
		// Get glyph data
		glyph_data := get_glyph_data(font_data, glyph)
		glyph_width := glyph_data.advance + GLYPH_SPACING
		// Draw cursors
		highlight := false
		if .focused in widget.state && .got_focus not_in widget.state {
			if state.length == 0 {
				if state.index == index && point.x >= box.x && point.x < box.x + box.w {
					paint_box_fill({math.floor(point.x), point.y, 1, font_data.size}, get_color(.text))
				}
			} else if index >= state.index && index < state.index + state.length {
				paint_box_fill({max(point.x, box.x), point.y, min(glyph_width, box.w - (point.x - box.x), (point.x + glyph_width) - box.x), font_data.size}, get_color(.text))
				highlight = true
			}

			if state.index == index {
				cursor_start = size
			}
			if state.index + state.length == index {
				cursor_end = size
			}
		}
		// Decide the hovered glyph
		glyph_point := point + {0, font_data.size / 2}
		dist := linalg.length(glyph_point - input.mouse_point)
		if dist < min_dist {
			min_dist = dist
			hover_index = index
		}
		// Anything past here requires a valid glyph
		if index == len(data) {
			break
		}
		// Draw the glyph
		if glyph == '\n' {
			point.x = origin.x
			point.y += font_data.size
		} else if glyph != '\t' && glyph != ' ' {
			paint_clipped_glyph(glyph_data, point, box, get_color(.text_inverted if highlight else .text, 1))
		}
		// Finished, move index and point
		point.x += glyph_width
		size.x += glyph_width
		index += bytes
	}
	// Handle initial text selection
	if .select_all in options {
		if .got_focus in widget.state {
			core.scribe.index = 0
			core.scribe.anchor = 0
			core.scribe.length = len(data)
		}
	}
	if .got_press in widget.state {
		if widget.click_count == 1 {
			core.scribe.index = 0
			core.scribe.anchor = 0
			core.scribe.length = len(data)
		} else {
			core.scribe.index = hover_index
			core.scribe.anchor = hover_index
			core.scribe.length = 0
		}
	}
	// View offset
	if widget.state >= {.pressed} && widget.click_count != 1 {
		// Selection by dragging
		if hover_index < core.scribe.anchor {
			core.scribe.index = hover_index
			core.scribe.length = core.scribe.anchor - hover_index
		} else {
			core.scribe.index = core.scribe.anchor
			core.scribe.length = hover_index - core.scribe.anchor
		}
		if size.x > box.w {
			if input.mouse_point.x < box.x {
				core.scribe.offset.x -= (box.x - input.mouse_point.x) * 0.5
			} else if input.mouse_point.x > box.x + box.w {
				core.scribe.offset.x += (input.mouse_point.x - (box.x + box.w)) * 0.5
			}
		}
	} else if widget.state >= {.focused} {
		// Handle view offset
		if core.scribe.index < core.scribe.last_index {
			if cursor_start.x < core.scribe.offset.x {
				core.scribe.offset.x = cursor_start.x
			}
		} else if core.scribe.index > core.scribe.last_index || core.scribe.length > core.scribe.last_length {
			if cursor_end.x > core.scribe.offset.x + (box.w - box.h * 0.5) {
				core.scribe.offset.x = cursor_end.x - box.w + box.h * 0.5
			}
		}
		core.scribe.last_index = core.scribe.index
		core.scribe.last_length = core.scribe.length
	}
	// Clamp view offset
	if size.x > box.w {
		state.offset.x = clamp(state.offset.x, 0, (size.x - box.w) + box.h * 0.5)
	} else {
		state.offset.x = 0
	}
	return
}
// Standalone text editing
Text_Edit_Option :: enum {
	multiline,
	numeric,
	integer,
	focus_select_all,
}
Text_Edit_Options :: bit_set[Text_Edit_Option]
// Updates a given text buffer with user input
text_edit :: proc(buf: ^[dynamic]u8, options: Text_Edit_Options, max_len: int = 0) -> (change: bool) {
	state := &core.scribe
	// Control commands
	if key_down(.control) {
		if key_pressed(.a) {
			state.index = 0
			state.anchor = 0
			state.length = len(buf)
		}
		if key_pressed(.v) {
			text_edit_insert_string(buf, max_len, get_clipboard_string())
			change = true
		}
	}
	// Normal character input
	if input.rune_count > 0 {
		if .numeric in options {
			for i in 0 ..< input.rune_count {
				glyph := int(input.runes[i])
				if (glyph >= 48 && glyph <= 57) || glyph == 45 || (glyph == 46 && .integer not_in options) {
					text_edit_insert_runes(buf, max_len, input.runes[i:i + 1])
					change = true
				}
			}
		} else {
			text_edit_insert_runes(buf, max_len, input.runes[:input.rune_count])
			change = true
		}
	}
	// Enter
	if .multiline in options && key_pressed(.enter) {
		text_edit_insert_runes(buf, max_len, {'\n'})
		change = true
	}
	// Backspacing
	if key_pressed(.backspace) {
		text_edit_backspace(buf)
		change = true
	}
	// Arrowkey navigation
	// TODO(isaiah): Implement up/down navigation for multiline text input
	if key_pressed(.left) {
		delta := 0
		// How far should the cursor move?
		if key_down(.control) {
			delta = find_last_seperator(buf[:state.index])
		} else{
			_, delta = utf8.decode_last_rune_in_bytes(buf[:state.index + state.length])
			delta = -delta
		}
		// Highlight or not
		if key_down(.shift) {
			if state.index < state.anchor {
				new_index := state.index + delta
				state.index = max(0, new_index)
				state.length = state.anchor - state.index
			} else {
				new_index := state.index + state.length + delta
				state.index = min(state.anchor, new_index)
				state.length = max(state.anchor, new_index) - state.index
			}
		} else {
			if state.length == 0 {
				state.index += delta
			}
			state.length = 0
			state.anchor = state.index
		}
		core.paint_next_frame = true
		// Clamp cursor
		state.index = max(0, state.index)
		state.length = max(0, state.length)
	}
	if key_pressed(.right) {
		delta := 0
		// How far should the cursor move
		if key_down(.control) {
			delta = find_next_seperator(buf[state.index + state.length:])
		} else {
			_, delta = utf8.decode_rune_in_bytes(buf[state.index + state.length:])
		}
		// Highlight or not?
		if key_down(.shift) {
			if state.index < state.anchor {
				new_index := state.index + delta
				state.index = new_index
				state.length = state.anchor - new_index
			} else {
				new_index := state.index + state.length + delta
				state.index = state.anchor
				state.length = new_index - state.index
			}
		} else {
			if state.length > 0 {
				state.index += state.length
			} else {
				state.index += delta
			}
			state.length = 0
			state.anchor = state.index
		}
		// Clamp cursor
		if state.length == 0 {
			if state.index > len(buf) {
				state.index = len(buf)
			}
		} else {
			if state.index + state.length > len(buf) {
				state.length = len(buf) - state.index
			}
		}
		core.paint_next_frame = true
		state.index = max(0, state.index)
		state.length = max(0, state.length)
	}
	if change {
		state.length = min(state.length, len(buf) - state.index)
	}
	return
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
	select_options: Selectable_Text_Options,
	edit_options: Text_Edit_Options,
}
text_input :: proc(info: Text_Input_Info, loc := #caller_location) -> (change: bool) {
	if self, ok := widget(hash(loc), use_next_box() or_else layout_next(current_layout()), {.draggable, .can_key_select}); ok {
		using self
		// Text cursor
		if state & {.hovered, .pressed} != {} {
			core.cursor = .beam
		}
		// Animation values
		hover_time := animate_bool(self.id, .hovered in state, 0.1)

		buffer := info.data.(^[dynamic]u8) or_else get_text_buffer(self.id)

		// Text edit
		if state >= {.focused} {
			change = text_edit(buffer, info.edit_options)
			if change {
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
		font_data := get_font_data(.default)
		switch type in info.data {
			case ^string:
			selectable_text(font_data, transmute([]u8)type[:], box, {}, self)

			case ^[dynamic]u8:
			selectable_text(font_data, type[:], box, {}, self)
		}
		if .should_paint in bits {
			stroke_color := get_color(.accent) if .focused in self.state else blend_colors(get_color(.base_stroke), get_color(.text), hover_time)
			paint_labeled_widget_frame(box, info.title, 1, stroke_color)
			// Draw placeholder
			if info.placeholder != nil {
				if len(buffer) == 0 {
					paint_aligned_string(font_data, info.placeholder.?, {box.x + box.h * 0.25, box.y + box.h / 2}, get_color(.text, GHOST_TEXT_ALPHA), {.near, .middle})
				}
			}
		}
	}
	return
}
// Edit number values
Number_Input_Info :: struct($T: typeid) where intrinsics.type_is_float(T) || intrinsics.type_is_integer(T) {
	value: T,
	title,
	format: Maybe(string),
	select_options: Selectable_Text_Options,
	no_outline: bool,
}
number_input :: proc(info: Number_Input_Info($T), loc := #caller_location) -> (newValue: T) {
	newValue = info.value
	if self, ok := widget(hash(loc), use_next_box() or_else layout_next(current_layout()), {.draggable, .can_key_select}); ok {
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
		font_data := get_font_data(.monospace)
		paint_box_fill(box, alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), hover_time * 0.05))
		if !info.no_outline {
			stroke_color := get_color(.accent) if .focused in self.state else blend_colors(get_color(.base_stroke), get_color(.text), hover_time)
			paint_labeled_widget_frame(box, info.title, 1, stroke_color)
		}
		// Update text input
		if state >= {.focused} {
			buffer := get_text_buffer(id)
			if state >= {.got_focus} {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			text_edit_options: Text_Edit_Options = {.numeric, .integer}
			switch typeid_of(T) {
				case f16, f32, f64: text_edit_options -= {.integer}
			}
			selectable_text(
				font_data, 
				buffer[:], 
				box, 
				info.select_options, 
				self,
				)
			if text_edit(buffer, text_edit_options, 18) {
				core.paint_next_frame = true
				str := string(buffer[:])
				switch typeid_of(T) {
					case f64:  		
					if temp, ok := strconv.parse_f64(str); ok {
						newValue = T(temp)
					}
					case int: 
					if temp, ok := strconv.parse_int(str); ok {
						newValue = T(temp)
					}
				}
				state += {.changed}
			}
		} else {
			selectable_text(
				font_data, 
				text, 
				box, 
				info.select_options, 
				self,
				)
		}
	}
	return
}
// Labels for text edit widgets
paint_labeled_widget_frame :: proc(box: Box, text: Maybe(string), thickness: f32, color: Color) {
	if text != nil {
		labelFont := get_font_data(.label)
		textSize := measure_string(labelFont, text.?)
		paint_widget_frame(box, box.h * 0.25 - 2, textSize.x + 4, thickness, color)
		paint_string(get_font_data(.label), text.?, {box.x + box.h * 0.25, box.y - textSize.y / 2}, color)
	} else {
		paint_box_stroke(box, thickness, color)
	}
}
// Text edit helpers
text_edit_insert_string :: proc(buf: ^[dynamic]u8, max_len: int, str: string) {
	using core.scribe
	if length > 0 {
		remove_range(buf, index, index + length)
		length = 0
	}
	n := len(str)
	if max_len > 0 {
		n = min(n, max_len - len(buf))
	}
	inject_at_elem_string(buf, index, str[:n])
	index += n
}
text_edit_insert_runes :: proc(buf: ^[dynamic]u8, max_len: int, runes: []rune) {
	str := utf8.runes_to_string(runes)
	text_edit_insert_string(buf, max_len, str)
	delete(str)
}
text_edit_backspace :: proc(buf: ^[dynamic]u8){
	using core.scribe
	if length == 0 {
		if index > 0 {
			end := index
			_, size := utf8.decode_last_rune_in_bytes(buf[:index])
			index -= size
			remove_range(buf, index, end)
		}
	} else {
		remove_range(buf, index, index + length)
		length = 0
	}
}
is_seperator :: proc(glyph: u8) -> bool {
	return glyph == ' ' || glyph == '\n' || glyph == '\t' || glyph == '\\' || glyph == '/'
}
find_next_seperator :: proc(slice: []u8) -> int {
	for i in 1 ..< len(slice) {
		if is_seperator(slice[i]) {
			return i
		}
	}
	return len(slice) - 1
}
find_last_seperator :: proc(slice: []u8) -> int {
	for i in len(slice) - 1 ..= 1 {
		if is_seperator(slice[i]) {
			return i
		}
	}
	return 0
}
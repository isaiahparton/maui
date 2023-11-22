package maui

import "core:fmt"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

Text_Location :: struct {
	offset,
	line, 
	column: int,
}

Text_Buffer :: struct {
	keep_alive: bool,
	buffer: [dynamic]u8,
}
Typing_Agent :: struct {
	//TODO: Introduce new approach!
	// loc,
	// last_loc: Text_Location,
	anchor,
	index,
	length,
	last_index,
	last_length: int,

	left_offset: f32,

	buffers: map[Id]Text_Buffer,
}

typing_agent_destroy :: proc(using self: ^Typing_Agent) {
	for _, value in buffers {
		delete(value.buffer)
	}
	delete(buffers)
}
typing_agent_get_buffer :: proc(using self: ^Typing_Agent, id: Id) -> (buffer: ^[dynamic]u8) {
	value, ok := &buffers[id]
	if !ok {
		value = map_insert(&buffers, id, Text_Buffer({}))
		ok = true
	}
	value.keep_alive = true
	return &value.buffer
}
typing_agent_step :: proc(using self: ^Typing_Agent) {
	last_index = index
	last_length = length
	for key, value in &buffers {
		if value.keep_alive {
			value.keep_alive = false
		} else {
			delete(value.buffer)
			delete_key(&buffers, key)
		}
	}
}

// Text edit helpers
typing_agent_insert_string :: proc(using self: ^Typing_Agent, buf: ^[dynamic]u8, max_len: int, str: string) {
	
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
typing_agent_insert_runes :: proc(using self: ^Typing_Agent, buf: ^[dynamic]u8, max_len: int, runes: []rune) {
	str := utf8.runes_to_string(runes)
	typing_agent_insert_string(self, buf, max_len, str)
	delete(str)
}
typing_agent_backspace :: proc(using self: ^Typing_Agent, buf: ^[dynamic]u8){
	if length == 0 {
		if index > 0 {
			end := index
			if key_down(.Left_Control) || key_down(.Right_Control) {
				index = find_last_seperator(buf[:index])
			} else {
				_, size := utf8.decode_last_rune_in_bytes(buf[:index])
				index -= size
			}
			remove_range(buf, index, end)
		}
	} else {
		remove_range(buf, index, index + length)
		length = 0
	}
}
get_last_line :: proc(data: []u8, index: int) -> (int, bool) {
	f: bool
	for i := index - 1; i >= 0; i -= 1 {
		if data[i] == '\n' {
			if f {
				return i + 1, true
			} else {
				f = true
			}
		}
	}
	return 0, f
}
get_next_line :: proc(data: []u8, index: int) -> (int, bool) {
	for i := index + 1; i < len(data); i += 1 {
		if data[i] == '\n' {
			return i + 1, true
		}
	}
	return len(data) - 1, false
}
is_seperator :: proc(glyph: u8) -> bool {
	return glyph == ' ' || glyph == '\"' || glyph == '\n' || glyph == '\t' || glyph == '\\' || glyph == '/'
}
find_next_seperator :: proc(slice: []u8) -> int {
	for i in 1 ..< len(slice) {
		if is_seperator(slice[i]) {
			return i
		}
	}
	return len(slice)
}
find_last_seperator :: proc(slice: []u8) -> int {
	for i := len(slice) - 1; i > 0; i -= 1 {
		if is_seperator(slice[i]) {
			return i
		}
	}
	return 0
}

Text_Edit_Bit :: enum {
	Multiline,
	Numeric,
	Integer,
	Focus_Selects_All,
}

Text_Edit_Bits :: bit_set[Text_Edit_Bit]

Text_Edit_Info :: struct {
	bits: Text_Edit_Bits,
	array: ^[dynamic]u8,
	capacity: int,
}

typing_agent_edit :: proc(using self: ^Typing_Agent, info: Text_Edit_Info) -> (change: bool) {
	// Control commands
	if key_down(.Left_Control) {
		// Select all
		if key_pressed(.A) {
			index = 0
			anchor = 0
			length = len(info.array)
		}
		// Clipboard paste
		if key_pressed(.V) {
			valid := true
			content := get_clipboard_string()
			if .Multiline not_in info.bits {
				if strings.contains_rune(content, '\n') {
					valid = false
				}
			}
			if valid {
				typing_agent_insert_string(self, info.array, info.capacity, content)
				change = true
				anchor = index
			}
		}
	}
	// Normal character input
	if input.rune_count > 0 {
		if .Numeric in info.bits {
			for i in 0 ..< input.rune_count {
				glyph := int(input.runes[i])
				if (glyph >= 48 && glyph <= 57) || glyph == 45 || (glyph == 46 && .Integer not_in info.bits) {
					typing_agent_insert_runes(self, info.array, info.capacity, input.runes[i:i + 1])
					change = true
				}
			}
		} else {
			typing_agent_insert_runes(self, info.array, info.capacity, input.runes[:input.rune_count])
			change = true
		}
		anchor = index
	}
	// Enter
	if .Multiline in info.bits && key_pressed(.Enter) {
		typing_agent_insert_runes(self, info.array, info.capacity, {'\n'})
		change = true
	}
	// Backspacing
	if key_pressed(.Backspace) {
		if len(info.array) > 0 {
			typing_agent_backspace(self, info.array)
			change = true
			anchor = index
		}
	}
	// Arrowkey navigation
	if key_pressed(.Left) {
		delta := 0
		// How far should the cursor move?
		if key_down(.Left_Control) || key_down(.Right_Control) {
			delta = find_last_seperator(info.array[:index]) - index
		} else{
			_, delta = utf8.decode_last_rune_in_bytes(info.array[:index + length])
			delta = -delta
		}
		// Highlight or not
		if key_down(.Left_Shift) || key_down(.Right_Shift) {
			if index < anchor {
				new_index := index + delta
				index = max(0, new_index)
				length = anchor - index
			} else {
				new_index := index + length + delta
				index = min(anchor, new_index)
				length = max(anchor, new_index) - index
			}
		} else {
			if length == 0 {
				index += delta
			}
			length = 0
			anchor = index
		}
		painter.next_frame = true
		// Clamp cursor
		index = max(0, index)
		length = max(0, length)
	}
	if key_pressed(.Right) {
		delta := 0
		// How far should the cursor move
		if key_down(.Left_Control) || key_down(.Right_Control) {
			delta = find_next_seperator(info.array[index + length:])
		} else {
			_, delta = utf8.decode_rune_in_bytes(info.array[index + length:])
		}
		// Highlight or not?
		if key_down(.Left_Shift) || key_down(.Right_Shift) {
			if index < anchor {
				new_index := index + delta
				index = new_index
				length = anchor - new_index
			} else {
				new_index := index + length + delta
				index = anchor
				length = new_index - index
			}
		} else {
			if length > 0 {
				index += length
			} else {
				index += delta
			}
			length = 0
			anchor = index
		}
		// Clamp cursor
		if length == 0 {
			if index > len(info.array) {
				index = len(info.array)
			}
		} else {
			if index + length > len(info.array) {
				length = len(info.array) - index
			}
		}
		painter.next_frame = true
		index = max(0, index)
		length = max(0, length)
	}
	if change {
		length = min(length, len(info.array) - index)
	}
	return
}
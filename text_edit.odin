package maui

import "core:io"
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
Scribe :: struct {
	//TODO: Introduce new approach!
	// loc,
	// last_loc: Text_Location,
	anchor,
	index,
	length,
	last_index,
	last_length: int,

	vertical_anchor: int,

	buffers: map[Id]Text_Buffer,
}
destroy_scribe :: proc(using self: ^Scribe) {
	for _, value in buffers {
		delete(value.buffer)
	}
	delete(buffers)
}

get_scribe_buffer :: proc(scribe: ^Scribe, id: Id) -> (buffer: ^[dynamic]u8) {
	value, ok := &scribe.buffers[id]
	if !ok {
		value = map_insert(&scribe.buffers, id, Text_Buffer({}))
		ok = true
	}
	value.keep_alive = true
	return &value.buffer
}

update_scribe :: proc(scribe: ^Scribe) {
	scribe.last_index = scribe.index
	scribe.last_length = scribe.length
	for key, value in &scribe.buffers {
		if value.keep_alive {
			value.keep_alive = false
		} else {
			delete(value.buffer)
			delete_key(&scribe.buffers, key)
		}
	}
}

// Text edit helpers
scribe_insert_string :: proc(using self: ^Scribe, buf: ^[dynamic]u8, max_len: int, str: string) {
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
insert_runes :: proc(using self: ^Scribe, buf: ^[dynamic]u8, max_len: int, runes: []rune) {
	str := utf8.runes_to_string(runes)
	scribe_insert_string(self, buf, max_len, str)
	delete(str)
}
scribe_backspace :: proc(using self: ^Scribe, buf: ^[dynamic]u8){
	
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

escribe_text :: proc(scribe: ^Scribe, io: ^IO, info: Text_Edit_Info) -> (change: bool) {
	// Control commands
	if key_down(io, .Left_Control) {
		// Select all
		if key_pressed(io, .A) {
			scribe.index = 0
			scribe.anchor = 0
			scribe.length = len(info.array)
		}
		// Clipboard paste
		if key_pressed(io, .V) {
			valid := true
			content := get_clipboard_string(io)
			if .Multiline not_in info.bits {
				if strings.contains_rune(content, '\n') {
					valid = false
				}
			}
			if valid {
				scribe_insert_string(scribe, info.array, info.capacity, content)
				change = true
				scribe.anchor = scribe.index
			}
		}
	}
	// Normal character input
	if io.rune_count > 0 {
		if .Numeric in info.bits {
			for i in 0 ..< io.rune_count {
				glyph := int(io.runes[i])
				if (glyph >= 48 && glyph <= 57) || glyph == 45 || (glyph == 46 && .Integer not_in info.bits) {
					insert_runes(scribe, info.array, info.capacity, io.runes[i:i + 1])
					change = true
				}
			}
		} else {
			insert_runes(scribe, info.array, info.capacity, io.runes[:io.rune_count])
			change = true
		}
		scribe.anchor = scribe.index
	}
	// Enter
	if .Multiline in info.bits && key_pressed(io, .Enter) {
		insert_runes(scribe, info.array, info.capacity, {'\n'})
		change = true
	}
	// Backspacing
	if key_pressed(io, .Backspace) {
		if len(info.array) > 0 {
			if scribe.length == 0 {
				if scribe.index > 0 {
					end := scribe.index
					if key_down(io, .Left_Control) || key_down(io, .Right_Control) {
						scribe.index = find_last_seperator(info.array[:scribe.index])
					} else {
						_, size := utf8.decode_last_rune_in_bytes(info.array[:scribe.index])
						scribe.index -= size
					}
					remove_range(info.array, scribe.index, end)
				}
			} else {
				remove_range(info.array, scribe.index, scribe.index + scribe.length)
				scribe.length = 0
			}
			change = true
			scribe.anchor = scribe.index
		}
	}
	// Arrowkey navigation
	if key_pressed(io, .Up) {
		i := strings.last_index_byte(string(info.array[:scribe.vertical_anchor]), '\n')
		offset := scribe.vertical_anchor - i
		if i >= 0 {
			scribe.index = strings.last_index_byte(string(info.array[:i]), '\n') + offset
		}
	}
	if key_pressed(io, .Down) {
		i := max(strings.last_index_byte(string(info.array[:scribe.vertical_anchor]), '\n'), 0)
		offset := scribe.vertical_anchor - i
		i = strings.index_byte(string(info.array[scribe.vertical_anchor:]), '\n')
		if i >= 0 {
			scribe.index = min(scribe.index + i + offset + 1, len(info.array))
		}
	}
	if key_pressed(io, .Left) {
		delta := 0
		// How far should the cursor move?
		if key_down(io, .Left_Control) || key_down(io, .Right_Control) {
			delta = find_last_seperator(info.array[:scribe.index]) - scribe.index
		} else{
			_, delta = utf8.decode_last_rune_in_bytes(info.array[:scribe.index + scribe.length])
			delta = -delta
		}
		// Highlight or not
		if key_down(io, .Left_Shift) || key_down(io, .Right_Shift) {
			if scribe.index < scribe.anchor {
				new_index := scribe.index + delta
				scribe.index = max(0, new_index)
				scribe.length = scribe.anchor - scribe.index
			} else {
				new_index := scribe.index + scribe.length + delta
				scribe.index = min(scribe.anchor, new_index)
				scribe.length = max(scribe.anchor, new_index) - scribe.index
			}
		} else {
			if scribe.length == 0 {
				scribe.index += delta
			}
			scribe.length = 0
			scribe.anchor = scribe.index
		}
		// Clamp cursor
		scribe.index = max(0, scribe.index)
		scribe.length = max(0, scribe.length)
		scribe.vertical_anchor = scribe.index
	}
	if key_pressed(io, .Right) {
		delta := 0
		// How far should the cursor move
		if key_down(io, .Left_Control) || key_down(io, .Right_Control) {
			delta = find_next_seperator(info.array[scribe.index + scribe.length:])
		} else {
			_, delta = utf8.decode_rune_in_bytes(info.array[scribe.index + scribe.length:])
		}
		// Highlight or not?
		if key_down(io, .Left_Shift) || key_down(io, .Right_Shift) {
			if scribe.index < scribe.anchor {
				new_index := scribe.index + delta
				scribe.index = new_index
				scribe.length = scribe.anchor - new_index
			} else {
				new_index := scribe.index + scribe.length + delta
				scribe.index = scribe.anchor
				scribe.length = new_index - scribe.index
			}
		} else {
			if scribe.length > 0 {
				scribe.index += scribe.length
			} else {
				scribe.index += delta
			}
			scribe.length = 0
			scribe.anchor = scribe.index
		}
		// Clamp cursor
		if scribe.length == 0 {
			if scribe.index > len(info.array) {
				scribe.index = len(info.array)
			}
		} else {
			if scribe.index + scribe.length > len(info.array) {
				scribe.length = len(info.array) - scribe.index
			}
		}
		scribe.index = max(0, scribe.index)
		scribe.length = max(0, scribe.length)
		scribe.vertical_anchor = scribe.index
	}
	if change {
		scribe.length = min(scribe.length, len(info.array) - scribe.index)
	}
	return
}
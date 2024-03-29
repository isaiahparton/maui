package maui

import "core:io"
import "core:fmt"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

Text_Selection :: struct {
	offset,
	length,
	line, 
	column: int,
}
Text_Buffer :: struct {
	keep_alive: bool,
	buffer: [dynamic]u8,
}
Scribe :: struct {
	// Editing state
	using selection: Text_Selection,
	last_selection: Text_Selection,
	anchor: int,
	// Temporary buffers
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
scribe_insert_string :: proc(scribe: ^Scribe, buf: ^[dynamic]u8, str: string) {
	if scribe.length > 0 {
		remove_range(buf, scribe.offset, scribe.offset + scribe.length)
		scribe.length = 0
	}
	inject_at_elem_string(buf, scribe.offset, str)
	scribe.offset += len(str)
}
insert_runes :: proc(using self: ^Scribe, buf: ^[dynamic]u8, runes: []rune) {
	str := utf8.runes_to_string(runes)
	scribe_insert_string(self, buf, str)
	delete(str)
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

Text_Edit_Info :: struct {
	array: ^[dynamic]u8,
	allowed_runes,
	forbidden_runes: string,
	capacity: Maybe(int),
	multiline: bool,
}

escribe_text :: proc(scribe: ^Scribe, io: ^IO, info: Text_Edit_Info) -> (change: bool) {
	// Control commands
	if key_down(io, .Left_Control) {
		// Select all
		if key_pressed(io, .A) {
			scribe.offset = 0
			scribe.length = len(info.array)
			scribe.anchor = 0
		}
		// Clipboard paste
		if key_pressed(io, .V) {
			valid := true
			content := get_clipboard_string(io)
			if !info.multiline {
				if strings.contains_rune(content, '\n') {
					valid = false
				}
			}
			if valid {
				n := len(content)
				if capacity, ok := info.capacity.?; ok {
					n = min(n, capacity - len(info.array))
				}
				scribe_insert_string(scribe, info.array, content[:n])
				scribe.anchor = scribe.offset
				change = true
			}
		}
	}
	// Normal character input
	if io.rune_count > 0 {
		for r in io.runes[:io.rune_count] {
			allowed := true
			if info.allowed_runes != "" && !strings.contains_rune(info.allowed_runes, r) {
				allowed = false
			} else if strings.contains_rune(info.forbidden_runes, r) {
				allowed = false
			}
			if capacity, ok := info.capacity.?; ok && len(info.array) >= capacity {
				allowed = false
			}
			if allowed {
				insert_runes(scribe, info.array, {r})
				change = true
			}
		}
		scribe.anchor = scribe.offset
	}
	/*
		Inserting new lines
	*/
	if info.multiline && key_pressed(io, .Enter) && !(info.capacity != nil && info.capacity.? > len(info.array)) {
		insert_runes(scribe, info.array, {'\n'})
		change = true
	}
	/*
		Deleting
	*/
	if key_pressed(io, .Backspace) {
		if len(info.array) > 0 {
			if scribe.length == 0 {
				if scribe.offset > 0 {
					end := scribe.offset
					if key_down(io, .Left_Control) || key_down(io, .Right_Control) {
						scribe.offset = find_last_seperator(info.array[:scribe.offset])
					} else {
						_, size := utf8.decode_last_rune_in_bytes(info.array[:scribe.offset])
						scribe.offset -= size
					}
					remove_range(info.array, scribe.offset, end)
				}
			} else {
				remove_range(info.array, scribe.offset, scribe.offset + scribe.length)
				scribe.length = 0
			}
			change = true
			scribe.anchor = scribe.offset
		}
	}
	/*
		Horizontal navigation
	*/
	if key_pressed(io, .Left) {
		delta := 0
		// How far should the cursor move?
		if key_down(io, .Left_Control) || key_down(io, .Right_Control) {
			delta = find_last_seperator(info.array[:scribe.offset]) - scribe.offset
		} else{
			_, delta = utf8.decode_last_rune_in_bytes(info.array[:scribe.offset + scribe.length])
			delta = -delta
		}
		// Highlight or not
		if key_down(io, .Left_Shift) || key_down(io, .Right_Shift) {
			if scribe.offset < scribe.anchor {
				new_index := scribe.offset + delta
				scribe.offset = max(0, new_index)
				scribe.length = scribe.anchor - scribe.offset
			} else {
				new_index := scribe.offset + scribe.length + delta
				scribe.offset = min(scribe.anchor, new_index)
				scribe.length = max(scribe.anchor, new_index) - scribe.offset
			}
		} else {
			if scribe.length == 0 {
				scribe.offset += delta
			}
			scribe.length = 0
			scribe.anchor = scribe.offset
		}
		// Clamp cursor
		scribe.offset = max(0, scribe.offset)
	}
	if key_pressed(io, .Right) {
		delta := 0
		// How far should the cursor move
		if key_down(io, .Left_Control) || key_down(io, .Right_Control) {
			delta = find_next_seperator(info.array[scribe.offset + scribe.length:])
		} else {
			_, delta = utf8.decode_rune_in_bytes(info.array[scribe.offset + scribe.length:])
		}
		// Highlight or not?
		if key_down(io, .Left_Shift) || key_down(io, .Right_Shift) {
			if scribe.offset < scribe.anchor {
				new_index := scribe.offset + delta
				scribe.offset = new_index
				scribe.length = scribe.anchor - new_index
			} else {
				new_index := scribe.offset + scribe.length + delta
				scribe.offset = scribe.anchor
				scribe.length = new_index - scribe.offset
			}
		} else {
			if scribe.length > 0 {
				scribe.offset += scribe.length
			} else {
				scribe.offset += delta
			}
			scribe.length = 0
			scribe.anchor = scribe.offset
		}
		// Clamp cursor
		if scribe.length == 0 {
			if scribe.offset > len(info.array) {
				scribe.offset = len(info.array)
			}
		} else {
			if scribe.offset + scribe.length > len(info.array) {
				scribe.length = len(info.array) - scribe.offset
			}
		}
		scribe.offset = max(0, scribe.offset)
	}
	if change {
		scribe.length = min(scribe.length, len(info.array) - scribe.offset)
	}
	return
}
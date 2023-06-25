package maui

import "core:math"
import "core:math/linalg"

import "core:fmt"

import "core:unicode"
import "core:unicode/utf8"

TEXT_BREAK :: "..."

// Text formatting for short term usage
// each string is valid until it's home buffer is reused
@private fmtBuffers: [FMT_BUFFER_COUNT][FMT_BUFFER_SIZE]u8
@private fmtBufferIndex: u8
text_format :: proc(text: string, args: ..any) -> string {
	str := fmt.bprintf(fmtBuffers[fmtBufferIndex][:], text, ..args)
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
text_format_slice :: proc(text: string, args: ..any) -> []u8 {
	str := fmt.bprintf(fmtBuffers[fmtBufferIndex][:], text, ..args)
	slice := fmtBuffers[fmtBufferIndex][:len(str)]
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return slice
}
text_join :: proc(args: []string, sep := " ") -> string {
	size := 0
	buffer := &fmtBuffers[fmtBufferIndex]
	for arg, index in args {
		copy(buffer[size:size + len(arg)], arg[:])
		size += len(arg)
		if index < len(args) - 1 {
			copy(buffer[size:size + len(sep)], sep[:])
			size += len(sep)
		}
	}
	str := string(buffer[:size])
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
text_capitalize :: proc(str: string) -> string {
	buffer := &fmtBuffers[fmtBufferIndex]
	copy(buffer[:], str[:])
	buffer[0] = u8(unicode.to_upper(rune(buffer[0])))
	str := string(buffer[:len(str)])
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
// Format types to text
format :: proc(args: ..any) -> string {
	str := fmt.bprint(fmtBuffers[fmtBufferIndex][:], ..args)
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
format_to_slice :: proc(args: ..any) -> []u8 {
	str := fmt.bprint(fmtBuffers[fmtBufferIndex][:], ..args)
	buf := fmtBuffers[fmtBufferIndex][:len(str)]
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return buf
}
format_bit_set :: proc(set: $S/bit_set[$E;$U], sep := " ") -> string {
	size := 0
	buffer := &fmtBuffers[fmtBufferIndex]
	count := 0
	max := card(set)
	for member in E {
		if member not_in set {
			continue
		}
		name := TextCapitalize(Format(member))
		copy(buffer[size:size + len(name)], name[:])
		size += len(name)
		if count < max - 1 {
			copy(buffer[size:size + len(sep)], sep[:])
			size += len(sep)
		}
		count += 1
	}
	str := string(buffer[:size])
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}

// Unicode values from the remixicons set
Icon :: enum rune {
	code 				= 0xeba8,
	github 				= 0xedca,
	check 				= 0xEB7A,
	error 				= 0xECA0,
	close 				= 0xEB98,
	heart 				= 0xEE0E,
	alert 				= 0xEA20,
	edit 				= 0xEFDF,
	home 				= 0xEE18,
	add 				= 0xEA12,
	undo 				= 0xEA58,
	shopping_cart 		= 0xF11D,
	attach_file			= 0xEA84,
	remove 				= 0xF1AE,
	delete 				= 0xEC1D,
	user 				= 0xF25F,
	format_italic		= 0xe23f,
	format_bold			= 0xe238,
	format_underline	= 0xe249,
	chevron_down 		= 0xEA4E,
	chevron_left 		= 0xEA64,
	chevron_right 		= 0xEA6E,
	chevron_up			= 0xEA78,
	folder 				= 0xED57,
	admin 				= 0xEA14,
	shopping_basket 	= 0xF11A,
	shopping_bag 		= 0xF115,
	receipt 			= 0xEAC2,
	calendar 			= 0xEB20,
	inventory 			= 0xF1C6,
	history 			= 0xEE17,
	copy 				= 0xECD2,
	checkbox_multiple	= 0xEB88,
	eye 				= 0xECB4,
	eye_off 			= 0xECB6,
	cog 				= 0xF0ED,
	group 				= 0xEDE2,
	flow_chart 			= 0xEF59,
	pie_chart 			= 0xEFF5,
	keyboard 			= 0xEE74,
	spreadsheet			= 0xECDE,
	contact_book 		= 0xEBCB,
	pin 				= 0xF038,
	un_pin 				= 0xF376,
	filter 				= 0xED26,
	filter_off 			= 0xED28,
	search 				= 0xF0D1,
	printer 			= 0xF028,
}

String_Paint_Option :: enum {
	wrap,
	word_wrap,
}
String_Paint_Options :: bit_set[String_Paint_Option]
Contained_String_Info :: struct {
	wrap,
	word_wrap: bool,
	align: [2]Alignment,
}
paint_contained_string :: proc(font: ^Font_Data, text: string, box: Box, color: Color, info: Contained_String_Info) -> [2]f32 {

	point: [2]f32 = {box.x, box.y}
	size: [2]f32
	next_word_index: int

	totalSize: [2]f32
	if info.align.x != .near || info.align.y != .near {
		totalSize = measure_string(font, text)
		#partial switch info.align.x {
			case .far: point.x += box.w - totalSize.x
			case .middle: point.x += box.w / 2 - totalSize.x / 2
		}
		#partial switch info.align.y {
			case .far: point.y += box.h - totalSize.y
			case .middle: point.y += box.h / 2 - totalSize.y / 2
		}
	}

	break_size: f32
	if !info.wrap {
		//TODO(isaiah): Optimize this
		break_size = measure_string(font, TEXT_BREAK).x
	}

	for codepoint, index in text {
		glyph := get_glyph_data(font, codepoint)
		total_advance := glyph.advance + GLYPH_SPACING
		space := total_advance

		if info.wrap {
			if info.word_wrap && index >= next_word_index {
				for word_rune, word_index in text[index:] {
					text_index := index + word_index
					if word_rune == ' ' {
						next_word_index = text_index
						break
					} else if text_index >= len(text) - 1 {
						next_word_index = text_index + 1
						break
					}
				}
				if next_word_index > index {
					space = measure_string(font, text[index:next_word_index]).x
				}
			}
			if point.x + space > box.x + box.w && codepoint != ' ' {
				if info.wrap {
					point.x = box.x
					point.y += font.size
				}
			}
		} else if point.x + total_advance + break_size >= box.x + box.w {
			paint_string(font, TEXT_BREAK, point, color)
			break
		}

		if codepoint == '\n' {
			point.x = box.x
			point.y += font.size
		} else {
			if point.y + font.size >= box.y + box.h {
				paint_clipped_glyph(glyph, point, box, color)
			} else {
				paint_texture(glyph.src, {math.trunc(point.x + glyph.offset.x), point.y + glyph.offset.y, glyph.src.w, glyph.src.h}, color)
			}
			point.x += total_advance
		}
		size.x = max(size.x, point.x - box.x)

		if point.y >= box.y + box.h {
			break
		}
	}
	size.y = point.y - box.y

	return size
}

// Text painting
measure_string :: proc(font: ^Font_Data, text: string) -> (size: [2]f32) {
	line_size: [2]f32
	lines := 1
	for codepoint in text {
		glyph := get_glyph_data(font, codepoint)
		line_size.x += glyph.advance + GLYPH_SPACING
		// Update the maximum width
		if codepoint == '\n' {
			size.x = max(size.x, line_size.x)
			line_size = {}
			lines += 1
		}
	}
	// Account for the last line
	size.x = max(size.x, line_size.x)
	// Height is simple
	size.y = font.size * f32(lines)
	return size
}
paint_string :: proc(font: ^Font_Data, text: string, origin: [2]f32, color: Color) -> [2]f32 {
	point := origin
	size := [2]f32{}
	for codepoint in text {
		glyph := get_glyph_data(font, codepoint)
		if codepoint == '\n' {
			point.x = origin.x
			point.y += font.size
		} else {
			paint_texture(glyph.src, {math.trunc(point.x + glyph.offset.x), point.y + glyph.offset.y, glyph.src.w, glyph.src.h}, color)
			point.x += glyph.advance + GLYPH_SPACING
		}
		size.x = max(size.x, point.x - origin.x)
	}
	size.y = font.size
	return size
}
paint_aligned_string :: proc(font: ^Font_Data, text: string, origin: [2]f32, color: Color, align: [2]Alignment) -> [2]f32 {
	origin := origin
	if align.x == .middle {
		origin.x -= math.trunc(measure_string(font, text).x / 2)
	} else if align.x == .far {
		origin.x -= measure_string(font, text).x
	}
	if align.y == .middle {
		origin.y -= measure_string(font, text).y / 2
	} else if align.y == .far {
		origin.y -= measure_string(font, text).y
	}
	return paint_string(font, text, origin, color)
}
paint_aligned_glyph :: proc(glyph: Glyph_Data, origin: [2]f32, color: Color, align: [2]Alignment) -> [2]f32 {
   	box := glyph.src
	switch align.x {
		case .far: box.x = origin.x - box.w
		case .middle: box.x = origin.x - math.floor(box.w / 2)
		case .near: box.x = origin.x
	}
	switch align.y {
		case .far: box.y = origin.y - box.h
		case .middle: box.y = origin.y - math.floor(box.h / 2)
		case .near: box.y = origin.y
	}
    paint_texture(glyph.src, box, color)

    return {box.w, box.h}
}
paint_aligned_icon :: proc(font_data: ^Font_Data, icon: Icon, origin: [2]f32, size: f32, color: Color, align: [2]Alignment) -> [2]f32 {
	glyph := get_glyph_data(font_data, rune(icon))
	box := glyph.src
	box.w *= size
	box.h *= size
	switch align.x {
		case .far: box.x = origin.x - box.w
		case .middle: box.x = origin.x - box.w / 2
		case .near: box.x = origin.x
	}
	switch align.y {
		case .far: box.y = origin.y - box.h
		case .middle: box.y = origin.y - box.h / 2
		case .near: box.y = origin.y
	}
    paint_texture(glyph.src, box, color)
    return {box.w, box.h}
}
// Draw a glyph, mathematically clipped to 'clipBox'
paint_clipped_glyph :: proc(glyph: Glyph_Data, origin: [2]f32, clip: Box, color: Color) {
  	src := glyph.src
    dst := Box{ 
        f32(i32(origin.x + glyph.offset.x)), 
        f32(i32(origin.y + glyph.offset.y)), 
        src.w, 
        src.h,
    }
    if dst.x < clip.x {
    	delta := clip.x - dst.x
    	dst.w -= delta
    	dst.x += delta
    	src.x += delta
    }
    if dst.y < clip.y {
    	delta := clip.y - dst.y
    	dst.h -= delta
    	dst.y += delta
    	src.y += delta
    }
    if dst.x + dst.w > clip.x + clip.w {
    	dst.w = (clip.x + clip.w) - dst.x
    }
    if dst.y + dst.h > clip.y + clip.h {
    	dst.h = (clip.y + clip.h) - dst.y
    }
    src.w = dst.w
    src.h = dst.h
    if src.w <= 0 || src.h <= 0 {
    	return
    }
    paint_texture(src, dst, color)
}

// Advanced interactive text
Selectable_Text_Bit :: enum {
	password,
	select_all,
	no_paint,
}
Selectable_Text_Bits :: bit_set[Selectable_Text_Bit]
Selectable_Text_Info :: struct {
	font_data: ^Font_Data,
	data: []u8,
	box: Box,
	view_offset: [2]f32,
	bits: Selectable_Text_Bits,
	padding: [2]f32,
	align: [2]Alignment,
}
Selectable_Text_Result :: struct {
	text_size,
	view_offset: [2]f32,
}
// Displays clipped, selectable text that can be copied to clipboard
selectable_text :: proc(widget: ^Widget, info: Selectable_Text_Info) -> (result: Selectable_Text_Result) {
	assert(widget != nil)

	result.view_offset = info.view_offset

	// Alias scribe state
	//FIXME: fix me!
	state := &core.typing_agent

	// Should paint?
	should_paint := .no_paint not_in info.bits

	// For calculating hovered glyph
	hover_index := 0
	min_dist: f32 = math.F32_MAX

	// Determine text origin
	origin: [2]f32 = {info.box.x, info.box.y}

	// Get text size if necessary
	text_size: [2]f32
	if info.align.x != .near || info.align.y != .near {
		text_size = measure_string(info.font_data, string(info.data))
	}

	// Handle alignment
	switch info.align.x {
		case .near: origin.x += info.padding.x
		case .middle: origin.x += info.box.w / 2 - text_size.x / 2
		case .far: origin.x += info.box.w - text_size.x - info.padding.x
	}
	switch info.align.y {
		case .near: origin.y += info.padding.y
		case .middle: origin.y += info.box.h / 2 - text_size.y / 2
		case .far: origin.y += info.box.h - text_size.y - info.padding.y
	}

	point := origin

	// Total text size
	size: [2]f32

	// Cursor start and end position
	cursor_start, 
	cursor_end: [2]f32

	// Reset view offset when just focused
	if .got_focus in widget.state {
		state.index = 0
		result.view_offset = {}
	}

	if .focused in widget.state {
		// Offset view when currently focused
		point -= info.view_offset
		// Content copy
		if key_down(.control) {
			if key_pressed(.c) {
				if state.length > 0 {
					set_clipboard_string(string(info.data[state.index:][:state.length]))
				} else {
					set_clipboard_string(string(info.data[:]))
				}
			}
		}
	}

	// Iterate over the bytes
	for index := 0; index <= len(info.data); {

		// Decode the next glyph
		bytes := 1
		glyph: rune
		if index < len(info.data) {
			glyph, bytes = utf8.decode_rune_in_bytes(info.data[index:])
		}

		// Password placeholder glyph
		if .password in info.bits {
			glyph = '•'
		}

		is_tab := glyph == '\t'

		// Get glyph data
		glyph_data := get_glyph_data(info.font_data, 32 if is_tab else glyph)
		glyph_width := glyph_data.advance + GLYPH_SPACING
		if is_tab {
			TAB_SPACES :: 3
			glyph_width *= TAB_SPACES
		}

		// Draw cursors
		highlight := false
		if .focused in widget.state && .got_focus not_in widget.state {

			// Draw cursor/selection if allowed
			if should_paint {
				if state.length == 0 {
					if state.index == index && point.x >= info.box.x && point.x < info.box.x + info.box.w {
						// Bar cursor
						cursor_point := linalg.floor(point)
						cursor_point.y = max(cursor_point.y, info.box.y)
						paint_box_fill(
							box = {
								cursor_point.x, 
								cursor_point.y, 
								1, 
								min(info.font_data.size, info.box.y + info.box.h - cursor_point.y),
							}, 
							color = get_color(.text),
							)
					}
				} else if index >= state.index && index < state.index + state.length {
					// Selection
					cursor_point := linalg.floor(point)
					cursor_point = {
						max(cursor_point.x, info.box.x),
						max(cursor_point.y, info.box.y),
					}
					paint_box_fill(
						box = {
							cursor_point.x, 
							cursor_point.y, 
							min(glyph_width, info.box.w - (cursor_point.x - info.box.x), (point.x + glyph_width) - info.box.x), 
							min(info.font_data.size, info.box.y + info.box.h - cursor_point.y),
						}, 
						color = get_color(.text),
						)
					highlight = true
				}
			}

			// Set cursor start/end points
			if state.index == index {
				cursor_start = size
			}
			if state.index + state.length == index {
				cursor_end = size
			}
		}

		// Decide the hovered glyph
		glyph_point := point + {0, info.font_data.size / 2}
		dist := linalg.length(glyph_point - input.mouse_point)
		if dist < min_dist {
			min_dist = dist
			hover_index = index
		}

		// Anything past here requires a valid glyph
		if index == len(info.data) {
			break
		}

		// Draw the glyph
		if glyph == '\n' {
			point.x = origin.x
			point.y += info.font_data.size
			size.y += info.font_data.size
		} else if glyph != '\t' && glyph != ' ' && should_paint {
			paint_clipped_glyph(glyph_data, point, info.box, get_color(.text_inverted if highlight else .text, 1))
		}

		// Finished, move index and point
		point.x += glyph_width
		size.x = max(size.x, point.x - origin.x)
		index += bytes
	}

	// Handle initial text selection
	if .select_all in info.bits {
		if .got_focus in widget.state {
			state.index = 0
			state.anchor = 0
			state.length = len(info.data)
		}
	}
	if .got_press in widget.state {
		if widget.click_count == 1 {
			for i := min(state.index, len(info.data) - 1); i >= 0; i -= 1 {
				if is_seperator(info.data[i]) {
					state.index = i + 1
					break
				} else if i == 0 {
					state.index = 0
					break
				}
			}
			for j := state.index + 1; j < len(info.data); j += 1 {
				if is_seperator(info.data[j]) {
					state.length = j - state.index
					break
				} else if j == len(info.data) - 1 {
					state.length = len(info.data) - state.index
					break
				}
			}
		} else if widget.click_count == 2 {
			state.index = 0
			state.anchor = 0
			state.length = len(info.data)
		} else {
			state.index = hover_index
			state.anchor = hover_index
			state.length = 0
		}
	}

	// View offset
	if widget.state >= {.pressed} && widget.click_count == 0 {
		// Selection by dragging
		if hover_index < state.anchor {
			state.index = hover_index
			state.length = state.anchor - hover_index
		} else {
			state.index = state.anchor
			state.length = hover_index - state.anchor
		}
		if size.x > info.box.w {
			// Offset view by dragging
			DRAG_SPEED :: 15
			if input.mouse_point.x < info.box.x {
				result.view_offset.x -= (info.box.x - input.mouse_point.x) * DRAG_SPEED * core.delta_time
			} else if input.mouse_point.x > info.box.x + info.box.w {
				result.view_offset.x += (input.mouse_point.x - (info.box.x + info.box.w)) * DRAG_SPEED * core.delta_time
			}
		}
	} else if widget.state >= {.focused} {
		// Handle view offset
		if state.index < state.last_index {
			if cursor_start.x < result.view_offset.x {
				result.view_offset.x = cursor_start.x
			}
		} else if state.index > state.last_index || state.length > state.last_length {
			if cursor_end.x > result.view_offset.x + (info.box.w - info.view_offset.x) {
				result.view_offset.x = cursor_end.x - info.box.w + info.view_offset.x
			}
		}
		state.last_index = state.index
		state.last_length = state.length
	}

	// Clamp view offset
	if size.x > info.box.w {
		result.view_offset.x = clamp(result.view_offset.x, 0, (size.x - info.box.w) + info.view_offset.x)
	} else {
		result.view_offset.x = 0
	}

	result.text_size = size

	return
}
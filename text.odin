package maui

import "core:math"
import "core:math/bits"
import "core:math/linalg"

import "core:fmt"

import "core:unicode"
import "core:unicode/utf8"

TEXT_BREAK :: "..."

Icon :: enum rune {
	Cloud 				= 0xEB9C,
	Hard_Drive 			= 0xF394,
	Sliders 			= 0xEC9C,
	Tree_Nodes 			= 0xEF90,
	Ball_Pen  			= 0xEA8D,
	More_Horizontal 	= 0xEF78,
	Code 				= 0xeba8,
	Github 				= 0xedca,
	Check 				= 0xEB7A,
	Error 				= 0xECA0,
	Close 				= 0xEB98,
	Heart 				= 0xEE0E,
	Alert 				= 0xEA20,
	Edit 				= 0xEC7F,
	Home 				= 0xEE18,
	Server 				= 0xF0DF,
	Add 				= 0xEA12,
	Undo 				= 0xEA58,
	Shopping_Cart 		= 0xF11D,
	Attach_File			= 0xEA84,
	Remove 				= 0xF1AE,
	Delete 				= 0xEC1D,
	User 				= 0xF25F,
	Format_Italic		= 0xe23f,
	Format_Bold			= 0xe238,
	Format_Underline	= 0xe249,
	Chevron_Down 		= 0xEA4E,
	Chevron_Left 		= 0xEA64,
	Chevron_Right 		= 0xEA6E,
	Chevron_Up			= 0xEA78,
	Folder 				= 0xED57,
	Admin 				= 0xEA14,
	Shopping_Basket 	= 0xF11A,
	Shopping_Bag 		= 0xF115,
	Receipt 			= 0xEAC2,
	File_Paper 			= 0xECF8,
	File_New 			= 0xECC2,
	Calendar 			= 0xEB20,
	Inventory 			= 0xF1C6,
	History 			= 0xEE17,
	Copy 				= 0xECD2,
	Checkbox_Multiple	= 0xEB88,
	Eye 				= 0xECB4,
	Eye_Off 			= 0xECB6,
	Box 				= 0xF2F3,
	Archive 			= 0xEA47,
	Cog 				= 0xF0ED,
	Group 				= 0xEDE2,
	Flow_Chart 			= 0xEF59,
	Pie_Chart 			= 0xEFF5,
	Keyboard 			= 0xEE74,
	Spreadsheet			= 0xECDE,
	Contact_Book 		= 0xEBCB,
	Pin 				= 0xF038,
	Unpin 				= 0xF376,
	Filter 				= 0xED26,
	Filter_Off 			= 0xED28,
	Search 				= 0xF0CD,
	Printer 			= 0xF028,
	Draft_Fill 			= 0xEC5B,
	Check_List 			= 0xEEB9,
	Numbers 			= 0xEFA9,
	Refund 				= 0xF067,
	Wallet 				= 0xF2AB,
	Bank_Card 			= 0xEA91,
}

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
text_remove_trailing_zeroes :: proc(text: string) -> string {
	text := text
	for i := len(text) - 1; i >= 0; i -= 1 {
		if text[i] != '0' {
			if text[i] == '.' {
				text = text[:i]
			}
			break
		} else {
			text = text[:i]
		}
	}
	return text
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

	total_size: [2]f32
	if info.align.x != .near || info.align.y != .near {
		total_size = measure_string(font, text)
		#partial switch info.align.x {
			case .far: point.x += box.w - total_size.x
			case .middle: point.x += box.w / 2 - total_size.x / 2
		}
		#partial switch info.align.y {
			case .far: point.y += box.h - total_size.y
			case .middle: point.y += box.h / 2 - total_size.y / 2
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

String_Paint_Info :: struct {
	align: [2]Alignment,
	clip_box: Maybe(Box),
}

paint_string :: proc(font: ^Font_Data, text: string, origin: [2]f32, color: Color, info: String_Paint_Info = {}) -> [2]f32 {
	origin := origin
	size: [2]f32
	if info.align.x != .near || info.align.y != .near {
		size = measure_string(font, text)
	}
	#partial switch info.align.x {
		case .middle: origin.x -= math.trunc(size.x / 2)
		case .far: origin.x -= size.x
	}
	#partial switch info.align.y {
		case .middle: origin.y -= math.trunc(size.y / 2)
		case .far: origin.y -= size.y
	}
	size = {}
	point := origin
	for codepoint in text {
		glyph := get_glyph_data(font, codepoint)
		if codepoint == '\n' {
			point.x = origin.x
			point.y += font.size
			size.y += font.size
		} else {
			if info.clip_box != nil {
				paint_clipped_glyph(glyph, point, info.clip_box.?, color)
			} else {
				paint_texture(glyph.src, {math.trunc(point.x + glyph.offset.x), point.y + glyph.offset.y, glyph.src.w, glyph.src.h}, color)
			}
			point.x += glyph.advance + GLYPH_SPACING
		}
		size.x = max(size.x, point.x - origin.x)
	}
	size.y += font.size
	return size
}

paint_aligned_string :: proc(font: ^Font_Data, text: string, origin: [2]f32, color: Color, align: [2]Alignment) -> [2]f32 {
	return paint_string(font, text, origin, color, {align = align})
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
	mutable,
	select_all,
	multiline,
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
	line_count: int,
	font_data: ^Font_Data,
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
	// Offset view when currently focused
	if .got_focus not_in widget.state {
		origin -= info.view_offset
	}
	point := origin
	// Total text size
	size: [2]f32
	// Cursor start and end position
	cursor_low: [2]f32 = 3.40282347E+38
	cursor_high: [2]f32
	// Reset view offset when just focused
	if .got_focus in widget.state {
		state.index = 0
		state.length = 0
		state.last_index = 0
		state.last_length = 0
		state.anchor = 0
		result.view_offset = {}
	}
	if .focused in widget.state {
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
		highlight := false
		// Draw cursors
		if should_paint && .focused in widget.state && .got_focus not_in widget.state {
			// Draw cursor/selection if allowed
			if state.length == 0 {
				if state.index == index && point.x >= info.box.x && point.x < info.box.x + info.box.w {
					// Bar cursor
					cursor_point := linalg.floor(point)
					cursor_point.y = max(cursor_point.y, info.box.y)
					paint_box_fill(
						box = clip_box({
							cursor_point.x, 
							cursor_point.y, 
							1, 
							info.font_data.size,
						}, info.box), 
						color = get_color(.text),
						)
				}
			} else if index >= state.index && index < state.index + state.length {
				// Selection
				cursor_point := linalg.floor(point)
				paint_box_fill(
					box = clip_box({
						cursor_point.x, 
						cursor_point.y, 
						glyph_width,
						info.font_data.size,
					}, info.box), 
					color = get_color(.text),
					)
				highlight = true
			}
		}
		// Decide the hovered glyph
		glyph_point := point + {0, info.font_data.size / 2}
		dist := linalg.length(glyph_point - input.mouse_point)
		if dist < min_dist {
			min_dist = dist
			hover_index = index
		}
		if .focused in widget.state {
			if index == state.index {
				cursor_low = point - origin
			}
			if index == state.index + state.length {
				cursor_high = (point + {0, info.font_data.size}) - origin
			}
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
			result.line_count += 1
		} else if should_paint && glyph != '\t' && glyph != ' ' {
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
	// Text selection by clicking
	if .got_press in widget.state {
		if widget.click_count == 1 {
			// Select the hovered word
			// Move index to the beginning of the hovered word
			for i := min(state.index, len(info.data) - 1); ; i -= 1 {
				if i == 0 {
					state.index = 0
					break
				} else if is_seperator(info.data[i]) {
					state.index = i + 1
					break
				}
			}
			// Find length of the word
			for j := state.index + 1; ; j += 1 {
				if j >= len(info.data) - 1 {
					state.length = len(info.data) - state.index
					break
				} else if is_seperator(info.data[j]) {
					state.length = j - state.index
					break
				}
			}
		} else if widget.click_count == 2 {
			// Select everything
			state.index = 0
			state.anchor = 0
			state.length = len(info.data)
		} else {
			// Normal select
			state.index = hover_index
			state.anchor = hover_index
			state.length = 0
		}
	}
	// Get desired bounds for cursor
	inner_size: [2]f32 = {info.box.w, info.box.h} - info.padding * 2
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
		// Offset view by dragging
		DRAG_SPEED :: 15
		if size.x > info.box.w {
			if input.mouse_point.x < info.box.x {
				result.view_offset.x -= (info.box.x - input.mouse_point.x) * DRAG_SPEED * core.delta_time
			} else if input.mouse_point.x > info.box.x + info.box.w {
				result.view_offset.x += (input.mouse_point.x - (info.box.x + info.box.w)) * DRAG_SPEED * core.delta_time
			}
		}
		if size.y > info.box.h && result.line_count > 0 {
			if input.mouse_point.y < info.box.y {
				result.view_offset.y -= (info.box.y - input.mouse_point.y) * DRAG_SPEED * core.delta_time
			} else if input.mouse_point.y > info.box.y + info.box.h {
				result.view_offset.y += (input.mouse_point.y - (info.box.y + info.box.h)) * DRAG_SPEED * core.delta_time
			}
		}
		core.paint_next_frame = true
	} else if .focused in widget.state && .lost_press not_in widget.state {
		// Handle view offset
		if state.index != state.last_index || state.length != state.last_length {
			if cursor_low.x < result.view_offset.x {
				result.view_offset.x = cursor_low.x
			}
			if cursor_low.y < result.view_offset.y {
				result.view_offset.y = cursor_low.y
			}
			if cursor_high.x > result.view_offset.x + inner_size.x {
				result.view_offset.x = cursor_high.x - inner_size.x
			}
			if cursor_high.y + info.font_data.size > result.view_offset.y + inner_size.y {
				result.view_offset.y = (cursor_high.y + info.font_data.size) - inner_size.y
			}
		}
		state.index = clamp(state.index, 0, len(info.data))
		state.length = clamp(state.length, 0, len(info.data) - state.index)
		state.last_index = state.index
		state.last_length = state.length
	}
	// Clamp view offset
	if size.x >= inner_size.x {
		result.view_offset.x = clamp(result.view_offset.x, 0, (size.x - info.box.w) + info.padding.x * 2)
	} else {
		result.view_offset.x = 0
	}
	if size.y >= inner_size.y {
		result.view_offset.y = clamp(result.view_offset.y, 0, (size.y - info.box.h) + info.padding.y * 2 + info.font_data.size)
	} else {
		result.view_offset.y = 0
	}
	result.text_size = size
	result.font_data = info.font_data
	return
}
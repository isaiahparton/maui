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
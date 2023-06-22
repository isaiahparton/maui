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
TextFormat :: proc(text: string, args: ..any) -> string {
	str := fmt.bprintf(fmtBuffers[fmtBufferIndex][:], text, ..args)
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
TextFormatSlice :: proc(text: string, args: ..any) -> []u8 {
	str := fmt.bprintf(fmtBuffers[fmtBufferIndex][:], text, ..args)
	slice := fmtBuffers[fmtBufferIndex][:len(str)]
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return slice
}
TextJoin :: proc(args: []string, sep := " ") -> string {
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
TextCapitalize :: proc(str: string) -> string {
	buffer := &fmtBuffers[fmtBufferIndex]
	copy(buffer[:], str[:])
	buffer[0] = u8(unicode.to_upper(rune(buffer[0])))
	str := string(buffer[:len(str)])
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
// Format types to text
Format :: proc(args: ..any) -> string {
	str := fmt.bprint(fmtBuffers[fmtBufferIndex][:], ..args)
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
FormatToSlice :: proc(args: ..any) -> []u8 {
	str := fmt.bprint(fmtBuffers[fmtBufferIndex][:], ..args)
	buf := fmtBuffers[fmtBufferIndex][:len(str)]
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return buf
}
FormatBitSet :: proc(set: $S/bit_set[$E;$U], sep := " ") -> string {
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
	bulletList 			= 0xEEBA,
	listFile 			= 0xECEC,
	undo 				= 0xEA58,
	shoppingCart 		= 0xF11D,
	attachFile			= 0xEA84,
	remove 				= 0xF1AE,
	delete 				= 0xEC1D,
	user 				= 0xF25F,
	formatItalic		= 0xe23f,
	formatBold			= 0xe238,
	formatUnderline		= 0xe249,
	chevronDown 		= 0xEA4E,
	chevronLeft 		= 0xEA64,
	chevronRight 		= 0xEA6E,
	chevronUp			= 0xEA78,
	folder 				= 0xED57,
	admin 				= 0xEA14,
	shoppingBasket 		= 0xF11A,
	shoppingBag 		= 0xF115,
	receipt 			= 0xEAC2,
	calendar 			= 0xEB20,
	inventory 			= 0xF1C6,
	history 			= 0xEE17,
	copy 				= 0xECD2,
	checkBoxMultiple	= 0xEB88,
	eye 				= 0xECB4,
	eyeOff 				= 0xECB6,
	cog 				= 0xF0ED,
	group 				= 0xEDE2,
	flowChart 			= 0xEF59,
	pieChart 			= 0xEFF5,
	keyboard 			= 0xEE74,
	spreadsheet			= 0xECDE,
	contactBook 		= 0xEBCB,
	pin 				= 0xF038,
	unPin 				= 0xF376,
	filter 				= 0xED26,
	filterOff 			= 0xED28,
	search 				= 0xF0D1,
	printer 			= 0xF028,
	table 				= 0xF1DD,
	layout 				= 0xEE8E,
}

StringPaintOption :: enum {
	wrap,
	word_wrap,
}
StringPaintOptions :: bit_set[StringPaintOption]
PaintStringContained :: proc(font: ^FontData, text: string, rect: Rect, options: StringPaintOptions, color: Color) -> Vec2 {
	return PaintStringContainedEx(font, text, rect, options, .near, .near, color)
}
PaintStringContainedEx :: proc(font: ^FontData, text: string, rect: Rect, options: StringPaintOptions, alignX, alignY: Alignment, color: Color) -> Vec2 {

	point: Vec2 = {rect.x, rect.y}
	size: Vec2
	nextWord: int

	totalSize: Vec2
	if alignX != .near || alignY != .near {
		totalSize = MeasureString(font, text)
		#partial switch alignX {
			case .far: point.x += rect.w - totalSize.x
			case .middle: point.x += rect.w / 2 - totalSize.x / 2
		}
		#partial switch alignY {
			case .far: point.y += rect.h - totalSize.y
			case .middle: point.y += rect.h / 2 - totalSize.y / 2
		}
	}

	breakSize: f32
	if options < {.wrap} {
		//TODO(isaiah): Optimize this
		breakSize = MeasureString(font, TEXT_BREAK).x
	}

	for codepoint, index in text {
		glyph := GetGlyphData(font, codepoint)
		totalAdvance := glyph.advance + GLYPH_SPACING
		space := totalAdvance

		if options >= {.wrap} {
			if options >= {.word_wrap} && index >= nextWord {
				for wordCodepoint, wordIndex in text[index:] {
					textIndex := index + wordIndex
					if wordCodepoint == ' ' {
						nextWord = textIndex
						break
					} else if textIndex >= len(text) - 1 {
						nextWord = textIndex + 1
						break
					}
				}
				if nextWord > index {
					space = MeasureString(font, text[index:nextWord]).x
				}
			}
			if point.x + space > rect.x + rect.w && codepoint != ' ' {
				if options >= {.wrap} {
					point.x = rect.x
					point.y += font.size
				}
			}
		} else if point.x + space > rect.x + rect.w {
			PaintString(font, TEXT_BREAK, point, color)
			break
		}

		if codepoint == '\n' {
			point.x = rect.x
			point.y += font.size
		} else {
			if point.y + font.size >= rect.y + rect.h {
				PaintGlyphClipped(glyph, point, rect, color)
			} else {
				PaintTexture(glyph.source, {math.trunc(point.x + glyph.offset.x), point.y + glyph.offset.y, glyph.source.w, glyph.source.h}, color)
			}
			point.x += totalAdvance
		}
		size.x = max(size.x, point.x - rect.x)

		if point.y >= rect.y + rect.h {
			break
		}
	}
	size.y = point.y - rect.y

	return size
}

// Text painting
MeasureString :: proc(font: ^FontData, text: string) -> (size: Vec2) {
	lineSize: Vec2
	lines := 1
	for codepoint in text {
		glyph := GetGlyphData(font, codepoint)
		lineSize.x += glyph.advance + GLYPH_SPACING
		// Update the maximum width
		if codepoint == '\n' {
			size.x = max(size.x, lineSize.x)
			lineSize = {}
			lines += 1
		}
	}
	// Account for the last line
	size.x = max(size.x, lineSize.x)
	// Height is simple
	size.y = font.size * f32(lines)
	return size
}
PaintString :: proc(font: ^FontData, text: string, origin: Vec2, color: Color) -> Vec2 {
	point := origin
	size := Vec2{}
	for codepoint in text {
		glyph := GetGlyphData(font, codepoint)
		if codepoint == '\n' {
			point.x = origin.x
			point.y += font.size
		} else {
			PaintTexture(glyph.source, {math.trunc(point.x + glyph.offset.x), point.y + glyph.offset.y, glyph.source.w, glyph.source.h}, color)
			point.x += glyph.advance + GLYPH_SPACING
		}
		size.x = max(size.x, point.x - origin.x)
	}
	size.y = font.size
	return size
}
PaintStringAligned :: proc(font: ^FontData, text: string, origin: Vec2, color: Color, alignX, alignY: Alignment) -> Vec2 {
	origin := origin
	if alignX == .middle {
		origin.x -= math.floor(MeasureString(font, text).x / 2)
	} else if alignX == .far {
		origin.x -= MeasureString(font, text).x
	}
	if alignY == .middle {
		origin.y -= math.floor(MeasureString(font, text).y / 2)
	} else if alignY == .far {
		origin.y -= MeasureString(font, text).y
	}
	return PaintString(font, text, linalg.floor(origin), color)
}
PaintGlyphAligned :: proc(glyph: GlyphData, origin: Vec2, color: Color, alignX, alignY: Alignment) -> Vec2 {
   	rect := glyph.source
	switch alignX {
		case .far: rect.x = origin.x - rect.w
		case .middle: rect.x = origin.x - math.floor(rect.w / 2)
		case .near: rect.x = origin.x
	}
	switch alignY {
		case .far: rect.y = origin.y - rect.h
		case .middle: rect.y = origin.y - math.floor(rect.h / 2)
		case .near: rect.y = origin.y
	}
    PaintTexture(glyph.source, rect, color)

    return {rect.w, rect.h}
}
PaintIconAligned :: proc(fontData: ^FontData, icon: Icon, origin: Vec2, color: Color, alignX, alignY: Alignment) -> Vec2 {
	return PaintGlyphAligned(GetGlyphData(fontData, rune(icon)), origin, color, alignX, alignY)
}
PaintIconAlignedEx :: proc(fontData: ^FontData, icon: Icon, origin: Vec2, size: f32, color: Color, alignX, alignY: Alignment) -> Vec2 {
	glyph := GetGlyphData(fontData, rune(icon))
	rect := glyph.source
	rect.w *= size
	rect.h *= size
	switch alignX {
		case .far: rect.x = origin.x - rect.w
		case .middle: rect.x = origin.x - rect.w / 2
		case .near: rect.x = origin.x
	}
	switch alignY {
		case .far: rect.y = origin.y - rect.h
		case .middle: rect.y = origin.y - rect.h / 2
		case .near: rect.y = origin.y
	}
    PaintTexture(glyph.source, rect, color)
    return {rect.w, rect.h}
}
// Draw a glyph, mathematically clipped to 'clipRect'
PaintGlyphClipped :: proc(glyph: GlyphData, origin: Vec2, clipRect: Rect, color: Color) {
  	src := glyph.source
    dst := Rect{ 
        f32(i32(origin.x + glyph.offset.x)), 
        f32(i32(origin.y + glyph.offset.y)), 
        src.w, 
        src.h,
    }
    if dst.x < clipRect.x {
    	delta := clipRect.x - dst.x
    	dst.w -= delta
    	dst.x += delta
    	src.x += delta
    }
    if dst.y < clipRect.y {
    	delta := clipRect.y - dst.y
    	dst.h -= delta
    	dst.y += delta
    	src.y += delta
    }
    if dst.x + dst.w > clipRect.x + clipRect.w {
    	dst.w = (clipRect.x + clipRect.w) - dst.x
    }
    if dst.y + dst.h > clipRect.y + clipRect.h {
    	dst.h = (clipRect.y + clipRect.h) - dst.y
    }
    src.w = dst.w
    src.h = dst.h
    if src.w <= 0 || src.h <= 0 {
    	return
    }
    PaintTexture(src, dst, color)
}
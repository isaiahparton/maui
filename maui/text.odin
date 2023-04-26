package maui

import "core:math"

import "core:fmt"

import "core:unicode"
import "core:unicode/utf8"

/*
	Safe text formatting for short-term usage
*/
@private fmtBuffers: [FMT_BUFFER_COUNT][FMT_BUFFER_SIZE]u8
@private fmtBufferIndex: u8
StringFormat :: proc(text: string, args: ..any) -> string {
	str := fmt.bprintf(fmtBuffers[fmtBufferIndex][:], text, ..args)
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
SPrintF :: proc(text: string, args: ..any) -> []u8 {
	str := fmt.bprintf(fmtBuffers[fmtBufferIndex][:], text, ..args)
	slice := fmtBuffers[fmtBufferIndex][:len(str)]
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return slice
}
Format :: proc(args: ..any) -> string {
	str := fmt.bprint(fmtBuffers[fmtBufferIndex][:], ..args)
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
Join :: proc(args: []string, sep := " ") -> string {
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
CapitalizeString :: proc(str: string) -> string {
	buffer := &fmtBuffers[fmtBufferIndex]
	copy(buffer[:len(str)], str[:])
	buffer[0] = u8(unicode.to_upper(rune(buffer[0])))
	str := string(buffer[:len(str)])
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
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
		name := CapitalizeString(Format(member))
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

/*
	These are the unicode values of the icons
	in google's material symbols font
*/
Icon :: enum rune {
	check 				= 0xe5ca,
	close 				= 0xe5cd,
	heart 				= 0xe87d,
	edit 				= 0xe3c9,
	home 				= 0xe88a,
	add 				= 0xe145,
	shoppingCart 		= 0xe8cc,
	attachFile			= 0xe226,
	remove 				= 0xe15b,
	delete 				= 0xe872,
	user 				= 0xe7fd,
	formatItalic		= 0xe23f,
	formatBold			= 0xe238,
	formatUnderline		= 0xe249,
}

StringPaintOption :: enum {
	wordwrap,
}
StringPaintOptions :: bit_set[StringPaintOption]
PaintStringContained :: proc(font: FontData, text: string, rect: Rect, options: StringPaintOptions, color: Color) -> Vec2 {
	if !ctx.shouldRender {
		return {}
	}

	point: Vec2 = {rect.x, rect.y}
	size: Vec2
	nextWord: int
	for codepoint, index in text {
		glyph := GetGlyphData(font, codepoint)
		totalAdvance := glyph.advance + GLYPH_SPACING
		space := totalAdvance

		if .wordwrap in options && index >= nextWord {
			for wordCodepoint, wordIndex in text[index:] {
				textIndex := index + wordIndex
				if wordCodepoint == ' ' || textIndex == len(text) - 1 {
					nextWord = textIndex
					break
				}
			}
			if nextWord > index {
				space = MeasureString(font, text[index:nextWord]).x
			}
		}
		if point.x + space > rect.x + rect.w && codepoint != ' ' {
			point.x = rect.x
			point.y += font.size
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

/*
	Text rendering
*/
Alignment :: enum {
	near,
	middle,
	far,
}
MeasureString :: proc(font: FontData, text: string) -> Vec2 {
	size, lineSize: Vec2
	lines := 1
	for codepoint, index in text {
		glyph := GetGlyphData(font, codepoint)
		lineSize.x += glyph.advance + GLYPH_SPACING
		size.x = max(size.x, lineSize.x)
		if codepoint == '\n' {
			size.x = max(size.x, lineSize.x)
			lines += 1
		}
	}
	size.y = font.size * f32(lines)
	return size
}
PaintString :: proc(font: FontData, text: string, origin: Vec2, color: Color) -> Vec2 {
	if !ctx.shouldRender {
		return {}
	}

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
PaintAlignedString :: proc(font: FontData, text: string, origin: Vec2, color: Color, alignX, alignY: Alignment) -> Vec2 {
	if !ctx.shouldRender {
		return {}
	}

	origin := origin
	if alignX == .middle {
		origin.x -= math.trunc(MeasureString(font, text).x / 2)
	} else if alignX == .far {
		origin.x -= MeasureString(font, text).x
	}
	if alignY == .middle {
		origin.y -= MeasureString(font, text).y / 2
	} else if alignY == .far {
		origin.y -= MeasureString(font, text).y
	}
	return PaintString(font, text, origin, color)
}

PaintGlyphAligned :: proc(glyph: GlyphData, origin: Vec2, color: Color, alignX, alignY: Alignment) {
	if !ctx.shouldRender {
		return
	}

   	rect := glyph.source
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
}
PaintIconAligned :: proc(fontData: FontData, icon: Icon, origin: Vec2, color: Color, alignX, alignY: Alignment) {
	PaintGlyphAligned(GetGlyphData(fontData, rune(icon)), origin, color, alignX, alignY)
}
// Draw a glyph, mathematically clipped to 'clipRect'
PaintGlyphClipped :: proc(glyph: GlyphData, origin: Vec2, clipRect: Rect, color: Color) {
	if !ctx.shouldRender {
		return
	}

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
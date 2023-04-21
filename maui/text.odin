package maui
import "core:math"
import "core:fmt"

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
				if wordCodepoint == ' ' {
					nextWord = index + wordIndex
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
				PaintClippedGlyph(glyph, point, rect, color)
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
	for codepoint, index in text {
		glyph := GetGlyphData(font, codepoint)
		lineSize.x += glyph.advance + GLYPH_SPACING
		size.x = max(size.x, lineSize.x)
		if codepoint == '\n' || index == len(text) - 1 {
			size.x = max(size.x, lineSize.x)
			size.y += font.size
		}
	}
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

// Draw a glyph, mathematically clipped to 'clipRect'
PaintClippedGlyph :: proc(glyph: GlyphData, origin: Vec2, clipRect: Rect, color: Color) {
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
package maui

import "core:fmt"
import "core:math"
import "core:runtime"
import "core:unicode/utf8"
import "core:math/linalg"
import "core:strconv"
import "core:strings"
import "core:slice"

TextInputOption :: enum {
	readOnly,
	multiline,
	hidden,
	numeric,
	integer,
	selectAll,
}
TextInputOptions :: bit_set[TextInputOption]
TextInputFormat :: struct {
	options: TextInputOptions,
	align: Alignment,
	capacity: int,
}
MutableTextFromBytes :: proc(font: FontData, data: []u8, rect: Rect, format: TextInputFormat, state: WidgetState) -> (change: bool, newData: []u8) {

	hoverIndex := 0
	minDist: f32 = 9999

	origin: Vec2 = {rect.x + WIDGET_TEXT_OFFSET, rect.y + rect.h / 2 - font.size / 2}
	if format.align != .near {
		textSize := MeasureString(font, string(data))
		if format.align == .middle {
			origin.x = rect.x + rect.w / 2 - textSize.x / 2
		} else if format.align == .far {
			origin.x = rect.x + rect.w - textSize.x
		}
	}
	point := origin
	size: Vec2
	cursorStart, cursorEnd: Vec2

	if .justFocused in state {
		ctx.scribe.offset = {}
	}
	if .focused in state {
		point -= ctx.scribe.offset
	}
	// Iterate over the bytes
	for index := 0; index <= len(data); {
		// Decode the next glyph
		bytes := 1
		glyph: rune = 0
		if index < len(data) {
			glyph, bytes = utf8.decode_rune_in_bytes(data[index:])
		}
		if .hidden in format.options {
			glyph = '•'
		}
		glyphData := GetGlyphData(font, glyph)
		glyphWidth := glyphData.advance + GLYPH_SPACING
		// Draw cursors
		highlight := false
		if .focused in state && .justFocused not_in state {
			if ctx.scribe.length == 0 && .readOnly not_in format.options {
				if ctx.scribe.index == index && point.x >= rect.x && point.x < rect.x + rect.w {
					PaintRect({math.floor(point.x), point.y, 1, font.size}, GetColor(.text))
				}
			} else if index >= ctx.scribe.index && index < ctx.scribe.index + ctx.scribe.length {
				PaintRect({max(point.x, rect.x), point.y, min(glyphWidth, rect.w - (point.x - rect.x), (point.x + glyphWidth) - rect.x), font.size}, GetColor(.text))
				highlight = true
			}

			if ctx.scribe.index == index {
				cursorStart = size
			}
			if ctx.scribe.index + ctx.scribe.length == index {
				cursorEnd = size
			}
		}
		// Decide the hovered glyph
		glyphPoint := point + {0, font.size / 2}
		dist := linalg.length(glyphPoint - input.mousePoint)
		if dist < minDist {
			minDist = dist
			hoverIndex = index
		}
		// Anything past here requires a valid glyph
		if index == len(data) {
			break
		}
		// Draw the glyph
		if glyph == '\n' {
			if .multiline in format.options {
				point.x = origin.x
				point.y += font.size
			}
		} else if glyph != '\t' && glyph != ' ' {
			PaintGlyphClipped(glyphData, point, rect, GetColor(.highlightedText if highlight else .text, 1))
		}
		// Finished, move index and point
		point.x += glyphData.advance + GLYPH_SPACING
		size.x += glyphData.advance + GLYPH_SPACING
		index += bytes
	}
	// Mouse
	if state >= {.down} {
		if hoverIndex < ctx.scribe.anchor {
			ctx.scribe.index = hoverIndex
			ctx.scribe.length = ctx.scribe.anchor - hoverIndex
		} else {
			ctx.scribe.index = ctx.scribe.anchor
			ctx.scribe.length = hoverIndex - ctx.scribe.anchor
		}
		if size.x > rect.w {
			if input.mousePoint.x < rect.x {
				ctx.scribe.offset.x -= (rect.x - input.mousePoint.x) * 0.5
			} else if input.mousePoint.x > rect.x + rect.w {
				ctx.scribe.offset.x += (input.mousePoint.x - (rect.x + rect.w)) * 0.5
			}
		}
	} else if state >= {.focused} {
		// Handle view offset
		if ctx.scribe.index < ctx.scribe.prev_index {
			if cursorStart.x < ctx.scribe.offset.x {
				ctx.scribe.offset.x = cursorStart.x
			}
		} else if ctx.scribe.index > ctx.scribe.prev_index || ctx.scribe.length > ctx.scribe.prev_length {
			if cursorEnd.x > ctx.scribe.offset.x + (rect.w - WIDGET_TEXT_OFFSET * 2) {
				ctx.scribe.offset.x = cursorEnd.x - rect.w + WIDGET_TEXT_OFFSET * 2
			}
		}
		ctx.scribe.prev_index = ctx.scribe.index
		ctx.scribe.prev_length = ctx.scribe.length
	}
	// Handle initial text selection
	if state & {.justFocused, .pressed} != {} {
		ctx.scribe.index = hoverIndex
		ctx.scribe.anchor = hoverIndex
		ctx.scribe.length = 0
	}
	if format.options >= {.selectAll} && state >= {.justFocused} {
		ctx.scribe.index = 0
		ctx.scribe.anchor = 0
		ctx.scribe.length = len(data)
	}
	// Text manipulation
	if state >= {.focused} {
		// Bring 'index' and 'length' into scope
		using ctx.scribe
		// Copying
		if KeyDown(.control) {
			if KeyPressed(.c) {
				if length > 0 {
					SetClipboardString(string(data[index:index + length]))
				} else {
					SetClipboardString(string(data[:]))
				}
			}
		}
		// Input
		if .readOnly not_in format.options {
			if KeyDown(.control) {
				if KeyPressed(.a) {
					index = 0
					anchor = 0
					length = len(data)
				}
				if KeyPressed(.v) {
					ScribeInsertString(GetClipboardString())
					change = true
				}
			}
			// Normal character input
			if input.runeCount > 0 {
				if .numeric in format.options {
					for i in 0 ..< input.runeCount {
						glyph := int(input.runes[i])
						if (glyph >= 48 && glyph <= 57) || glyph == 45 || (glyph == 46 && .integer not_in format.options) {
							ScribeInsertRunes(input.runes[i:i+1])
							change = true
						}
					}
				} else {
					ScribeInsertRunes(input.runes[:input.runeCount])
					change = true
				}
			}
			// Enter
			if .multiline in format.options && KeyPressed(.enter) {
				ScribeInsertRunes({'\n'})
				change = true
			}
			// Backspacing
			if KeyPressed(.backspace) {
				ScribeBackspace()
				change = true
			}
			// Arrowkey navigation
			// TODO(isaiah): Implement up/down navigation for multiline text input
			if KeyPressed(.left) {
				delta := 0
				// How far should the cursor move?
				if KeyDown(.control) {
					delta = FindLastSeperator(buffer[:index])
				} else{
					_, delta = utf8.decode_last_rune_in_bytes(buffer[:index + length])
					delta = -delta
				}
				// Highlight or not
				if KeyDown(.shift) {
					if index < anchor {
						newIndex := index + delta
						index = max(0, newIndex)
						length = anchor - index
					} else {
						newIndex := index + length + delta
						index = min(anchor, newIndex)
						length = max(anchor, newIndex) - index
					}
				} else {
					if length == 0 {
						index += delta
					}
					length = 0
					anchor = index
				}
				// Clamp cursor
				index = max(0, index)
				length = max(0, length)
				
			}
			if KeyPressed(.right) {
				delta := 0
				// How far should the cursor move
				if KeyDown(.control) {
					delta = FindNextSeperator(buffer[index + length:])
				} else {
					_, delta = utf8.decode_rune_in_bytes(buffer[index + length:])
				}
				// Highlight or not?
				if KeyDown(.shift) {
					if index < anchor {
						newIndex := index + delta
						index = newIndex
						length = anchor - newIndex
					} else {
						newIndex := index + length + delta
						index = anchor
						length = newIndex - index
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
					if index > len(buffer) {
						index = len(buffer)
					}
				} else {
					if index + length > len(buffer) {
						length = len(buffer) - index
					}
				}
				index = max(0, index)
				length = max(0, length)
			}
		}
		// When the text input is clicked, resize the
		// scribe buffer and copy the data to it
		if .readOnly not_in format.options && .justFocused in state {
			length := len(data)
			if format.capacity > 0 {
				length = min(length, format.capacity)
			}
			resize(&ctx.scribe.buffer, length)
			copy(ctx.scribe.buffer[:], data[:length])
		}
		// Create new data slice
		if change {
			if ctx.groupDepth > 0 {
				ctx.groups[ctx.groupDepth - 1].state += {.changed}
			}

			ctx.renderTime = RENDER_TIMEOUT

			length := len(ctx.scribe.buffer) 
			if format.capacity > 0 {
				length = min(length, format.capacity)
			}
			newData = ctx.scribe.buffer[:length]
		}
		if size.x > rect.w {
			ctx.scribe.offset.x = clamp(ctx.scribe.offset.x, 0, (size.x - rect.w) + WIDGET_TEXT_OFFSET * 2)
		} else {
			ctx.scribe.offset.x = 0
		}
	}
	return
}

/*
	Text input widgets
*/
StringInputUnsafe :: proc(text: ^string, label, placeholder: string, format: TextInputFormat, loc := #caller_location) -> bool {
	if change, newData := TextInputBytes(transmute([]u8)text[:], label, placeholder, format, loc); change {
		delete(text^)
		text^ = strings.clone_from_bytes(newData)
		return true
	}
	return false
}
TextInputBytes :: proc(data: []u8, label, placeholder: string, format: TextInputFormat, loc := #caller_location) -> (change: bool, newData: []u8) {
	if control, ok := BeginWidget(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		options += {.draggable, .keySelect}
		UpdateWidget(control)

		// Animation values
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), .focused in state, 0.2)
		PopId()

		if .hovered in state || .down in state {
			ctx.cursor = .beam
		}

		PaintRect(body, GetColor(.foreground))
		font := GetFontData(.default)
		change, newData = MutableTextFromBytes(font, data, control.body, format, control.state)
		outlineColor := BlendColors(GetColor(.outlineBase), GetColor(.accentHover), min(1, hoverTime + stateTime))
		PaintRectLines(body, 2 if state >= {.focused} else 1, outlineColor)

		// Draw placeholder
		PaintWidgetLabel(body, label, outlineColor, GetColor(.foreground))
		if len(placeholder) != 0 {
			if len(data) == 0 {
				PaintStringAligned(font, placeholder, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.widgetPress, 1), .near, .middle)
			}
		}

		body.y -= 10
		body.h += 10
	}
	return
}
NumberInputFloat64 :: proc(value: f64, label: string, loc := #caller_location) -> (newValue: f64) {
	return NumberInputFloat64Ex(value, label, "%.2f", loc)
}
NumberInputFloat64Ex :: proc(value: f64, label, format: string, loc := #caller_location) -> (newValue: f64) {
	if control, ok := BeginWidget(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control

		newValue = value
		control.options += {.draggable, .keySelect}
		UpdateWidget(control)

		// Animation values
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), .focused in state, 0.2)
		PopId()

		if .hovered in state || .down in state {
			ctx.cursor = .beam
		}

		PaintRect(body, GetColor(.foreground))
		font := GetFontData(.monospace)

		data := SPrintF(format, value)
		if .justFocused in state {
			delete(ctx.numberText)
			ctx.numberText = slice.clone(data)
		}
		change, newData := MutableTextFromBytes(font, ctx.numberText if .focused in state else data, control.body, {options = {.numeric}, capacity = 15}, control.state)
		outlineColor := BlendColors(GetColor(.outlineBase), GetColor(.accentHover), min(1, hoverTime + stateTime))
		PaintRectLines(body, 2 if state >= {.focused} else 1, outlineColor)
		if change {
			newValue, ok = strconv.parse_f64(string(newData))
			delete(ctx.numberText)
			ctx.numberText = slice.clone(newData)
		}
		PaintWidgetLabel(body, label, outlineColor, GetColor(.foreground))

		body.y -= 10
		body.h += 10
	}
	return
}

PaintWidgetLabel :: proc(rect: Rect, label: string, fillColor, backgroundColor: Color) {
	if len(label) > 0 {
		labelFont := GetFontData(.label)
		textSize := MeasureString(labelFont, label)
		PaintRect({rect.x + WIDGET_TEXT_OFFSET - 2, rect.y - 4, textSize.x + 4, 6}, backgroundColor)
		PaintString(GetFontData(.label), label, {rect.x + WIDGET_TEXT_OFFSET, rect.y - textSize.y / 2}, fillColor)
	}
}
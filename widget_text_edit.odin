package maui
// Core dependencies
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:unicode/utf8"
import "core:math"
import "core:math/linalg"
// Advanced interactive text
TextProOption :: enum {
	password,
	selectAll,
	align_center,
	align_right,
}
TextProOptions :: bit_set[TextProOption]
// Displays clipped, selectable text that can be copied to clipboard
TextPro :: proc(fontData: FontData, data: []u8, rect: Rect, options: TextProOptions, widgetState: WidgetState) {
	state := &ctx.scribe
	// Hovered index
	hoverIndex := 0
	minDist: f32 = math.F32_MAX
	// Determine text origin
	origin: Vec2 = {rect.x + WIDGET_TEXT_OFFSET, rect.y + rect.h / 2 - fontData.size / 2}
	if options & {.align_center, .align_right} != {} {
		textSize := MeasureString(fontData, string(data))
		if options >= {.align_center} {
			origin.x = rect.x + rect.w / 2 - textSize.x / 2
		} else if options >= {.align_right} {
			origin.x = rect.x + rect.w - textSize.x
		}
	}
	point := origin
	// Total text size
	size: Vec2
	// Cursor start and end position
	cursorStart, 
	cursorEnd: Vec2
	// Reset view offset when just focused
	if .justFocused in widgetState {
		ctx.scribe.offset = {}
	}
	// Offset view when currently focused
	if .focused in widgetState {
		point -= ctx.scribe.offset
		if KeyDown(.control) {
			if KeyPressed(.c) {
				if state.length > 0 {
					SetClipboardString(string(data[state.index:][:state.length]))
				} else {
					SetClipboardString(string(data[:]))
				}
			}
		}
	}
	// Iterate over the bytes
	for index := 0; index <= len(data); {
		// Decode the next glyph
		bytes := 1
		glyph: rune
		if index < len(data) {
			glyph, bytes = utf8.decode_rune_in_bytes(data[index:])
		}
		// Password placeholder glyph
		if .password in options {
			glyph = '•'
		}
		// Get glyph data
		glyphData := GetGlyphData(fontData, glyph)
		glyphWidth := glyphData.advance + GLYPH_SPACING
		// Draw cursors
		highlight := false
		if .focused in widgetState && .justFocused not_in widgetState {
			if state.length == 0 {
				if state.index == index && point.x >= rect.x && point.x < rect.x + rect.w {
					PaintRect({math.floor(point.x), point.y, 1, fontData.size}, GetColor(.text))
				}
			} else if index >= state.index && index < state.index + state.length {
				PaintRect({max(point.x, rect.x), point.y, min(glyphWidth, rect.w - (point.x - rect.x), (point.x + glyphWidth) - rect.x), fontData.size}, GetColor(.text))
				highlight = true
			}

			if state.index == index {
				cursorStart = size
			}
			if state.index + state.length == index {
				cursorEnd = size
			}
		}
		// Decide the hovered glyph
		glyphPoint := point + {0, fontData.size / 2}
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
			point.x = origin.x
			point.y += fontData.size
		} else if glyph != '\t' && glyph != ' ' {
			PaintGlyphClipped(glyphData, point, rect, GetColor(.highlightedText if highlight else .text, 1))
		}
		// Finished, move index and point
		point.x += glyphWidth
		size.x += glyphWidth
		index += bytes
	}
	// View offset
	if widgetState >= {.down} {
		// Selection by dragging
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
	} else if widgetState >= {.focused} {
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
	if widgetState & {.justFocused, .pressed} != {} {
		if options >= {.selectAll} {
			ctx.scribe.index = 0
			ctx.scribe.anchor = 0
			ctx.scribe.length = len(data)
		} else {
			ctx.scribe.index = hoverIndex
			ctx.scribe.anchor = hoverIndex
			ctx.scribe.length = 0
		}
	}
	// Clamp view offset
	if size.x > rect.w {
		state.offset.x = clamp(state.offset.x, 0, (size.x - rect.w) + WIDGET_TEXT_OFFSET * 2)
	} else {
		state.offset.x = 0
	}
	return
}
// Standalone text editing
TextEditOption :: enum {
	multiline,
	numeric,
	integer,
	selectAllWhenFocused,
}
TextEditOptions :: bit_set[TextEditOption]
// Updates a given text buffer with user input
TextEdit :: proc(buf: ^[dynamic]u8, options: TextEditOptions, maxLength: int = 0) -> (change: bool) {
	state := &ctx.scribe
	// Control commands
	if KeyDown(.control) {
		if KeyPressed(.a) {
			state.index = 0
			state.anchor = 0
			state.length = len(buf)
		}
		if KeyPressed(.v) {
			TextEditInsertString(buf, maxLength, GetClipboardString())
			change = true
		}
	}
	// Normal character input
	if input.runeCount > 0 {
		if .numeric in options {
			for i in 0 ..< input.runeCount {
				glyph := int(input.runes[i])
				if (glyph >= 48 && glyph <= 57) || glyph == 45 || (glyph == 46 && .integer not_in options) {
					TextEditInsertRunes(buf, maxLength, input.runes[i:i + 1])
					change = true
				}
			}
		} else {
			TextEditInsertRunes(buf, maxLength, input.runes[:input.runeCount])
			change = true
		}
	}
	// Enter
	if .multiline in options && KeyPressed(.enter) {
		TextEditInsertRunes(buf, maxLength, {'\n'})
		change = true
	}
	// Backspacing
	if KeyPressed(.backspace) {
		TextEditBackspace(buf)
		change = true
	}
	// Arrowkey navigation
	// TODO(isaiah): Implement up/down navigation for multiline text input
	if KeyPressed(.left) {
		delta := 0
		// How far should the cursor move?
		if KeyDown(.control) {
			delta = FindLastSeperator(buf[:state.index])
		} else{
			_, delta = utf8.decode_last_rune_in_bytes(buf[:state.index + state.length])
			delta = -delta
		}
		// Highlight or not
		if KeyDown(.shift) {
			if state.index < state.anchor {
				newIndex := state.index + delta
				state.index = max(0, newIndex)
				state.length = state.anchor - state.index
			} else {
				newIndex := state.index + state.length + delta
				state.index = min(state.anchor, newIndex)
				state.length = max(state.anchor, newIndex) - state.index
			}
		} else {
			if state.length == 0 {
				state.index += delta
			}
			state.length = 0
			state.anchor = state.index
		}
		// Clamp cursor
		state.index = max(0, state.index)
		state.length = max(0, state.length)
	}
	if KeyPressed(.right) {
		delta := 0
		// How far should the cursor move
		if KeyDown(.control) {
			delta = FindNextSeperator(buf[state.index + state.length:])
		} else {
			_, delta = utf8.decode_rune_in_bytes(buf[state.index + state.length:])
		}
		// Highlight or not?
		if KeyDown(.shift) {
			if state.index < state.anchor {
				newIndex := state.index + delta
				state.index = newIndex
				state.length = state.anchor - newIndex
			} else {
				newIndex := state.index + state.length + delta
				state.index = state.anchor
				state.length = newIndex - state.index
			}
		} else {
			if state.length > 0 {
				state.index += state.length
			} else {
				state.index += delta
			}
			state.length = 0
			state.anchor = state.index
		}
		// Clamp cursor
		if state.length == 0 {
			if state.index > len(buf) {
				state.index = len(buf)
			}
		} else {
			if state.index + state.length > len(buf) {
				state.length = len(buf) - state.index
			}
		}
		state.index = max(0, state.index)
		state.length = max(0, state.length)
	}
	if change {
		state.length = min(state.length, len(buf) - state.index)
	}
	return
}
// Unsafe way to edit a string directly
// will segfault if the string is static
StringInputUnsafe :: proc(text: ^string, label, placeholder: string, loc := #caller_location) -> (change: bool) {
	if control, ok := BeginWidget(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		options += {.draggable, .keySelect}
		UpdateWidget(control)

		if state & {.hovered, .down} != {} {
			ctx.cursor = .beam
		}
		// Animation values
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), .focused in state, 0.2)
		PopId()
		// Copy to temp buffer if focused
		if state >= {.justFocused} {
			resize(&ctx.tempBuffer, len(text))
			copy(ctx.tempBuffer[:], text[:])
		}
		// Paint!
		PaintRect(body, GetColor(.foreground))

		fontData := GetFontData(.default)
		TextPro(fontData, transmute([]u8)text[:], body, {}, state)
		if state >= {.focused} {
			change = TextEdit(&ctx.tempBuffer, {})
			if change {
				ctx.renderTime = RENDER_TIMEOUT
				delete(text^)
				text^ = strings.clone_from_bytes(ctx.tempBuffer[:])
			}
		}
		
		outlineColor := BlendColors(GetColor(.outlineBase), GetColor(.accentHover), min(1, hoverTime + stateTime))
		PaintRectLines(body, 2 if state >= {.focused} else 1, outlineColor)
		// Draw placeholder
		PaintWidgetLabel(body, label, outlineColor, GetColor(.foreground))
		if len(placeholder) != 0 {
			if len(text) == 0 {
				PaintStringAligned(fontData, placeholder, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.widgetPress, 1), .near, .middle)
			}
		}
	}
	return
}
// Edit a dynamic array of bytes
TextInput :: proc(buf: ^[dynamic]u8, label, placeholder: string, loc := #caller_location) -> (change: bool) {
	return TextInputEx(buf, label, placeholder, {}, {}, loc)
}
TextInputEx :: proc(buf: ^[dynamic]u8, label, placeholder: string, textOptions: TextProOptions, editOptions: TextEditOptions, loc := #caller_location) -> (change: bool) {
	if control, ok := BeginWidget(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		options += {.draggable, .keySelect}
		UpdateWidget(control)

		if state & {.hovered, .down} != {} {
			ctx.cursor = .beam
		}
		// Animation values
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), .focused in state, 0.2)
		PopId()
		// Paint!
		PaintRect(body, GetColor(.foreground))
		fontData := GetFontData(.default)
		TextPro(fontData, buf[:], body, {}, state)
		if state >= {.focused} {
			change = TextEdit(buf, editOptions)
			if change {
				ctx.renderTime = RENDER_TIMEOUT
			}
		}
		outlineColor := BlendColors(GetColor(.outlineBase), GetColor(.accentHover), min(1, hoverTime + stateTime))
		PaintRectLines(body, 2 if state >= {.focused} else 1, outlineColor)
		// Draw placeholder
		PaintWidgetLabel(body, label, outlineColor, GetColor(.foreground))
		if len(placeholder) != 0 {
			if len(buf) == 0 {
				PaintStringAligned(fontData, placeholder, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.widgetPress, 1), .near, .middle)
			}
		}
	}
	return
}
// Edit number values
Number :: union {
	f64,
	int,
}
NumberInputFloat64 :: proc(value: f64, label: string, loc := #caller_location) -> (newValue: f64) {
	return NumberInputEx(value, label, "%.2f", loc).(f64)
}
NumberInputInt :: proc(value: int, label: string, loc := #caller_location) -> (newValue: int) {
	return NumberInputEx(value, label, "%i", loc).(int)
}
@private
NumberInputEx :: proc(value: Number, label, format: string, loc := #caller_location) -> (newValue: Number) {
	newValue = value
	if self, ok := BeginWidget(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using self
		self.options += {.draggable, .keySelect}
		UpdateWidget(self)
		// Animation values
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), .focused in state, 0.2)
		PopId()
		// Cursor style
		if state & {.hovered, .down} != {} {
			ctx.cursor = .beam
		}
		// Formatting
		text := SPrintF(format, value)
		// Copy to temp buffer if focused
		if state >= {.justFocused} {
			resize(&ctx.tempBuffer, len(text))
			copy(ctx.tempBuffer[:], text[:])
		}
		// Painting
		PaintRect(body, GetColor(.foreground))
		fontData := GetFontData(.monospace)
		TextPro(
			fontData, 
			ctx.tempBuffer[:] if state & {.focused, .justUnfocused} != {} else text, 
			body, 
			{}, 
			state,
			)
		outlineColor := BlendColors(GetColor(.outlineBase), GetColor(.accentHover), min(1, hoverTime + stateTime))
		PaintRectLines(body, 2 if state >= {.focused} else 1, outlineColor)
		PaintWidgetLabel(body, label, outlineColor, GetColor(.foreground))
		// Update text input
		if state >= {.focused} {
			if TextEdit(&ctx.tempBuffer, {.numeric}, 18) {
				ctx.renderTime = RENDER_TIMEOUT
				str := string(ctx.tempBuffer[:])
				switch v in value {
					case f64:  		
					if temp, ok := strconv.parse_f64(str); ok {
						newValue = temp
					}
					case int: 
					if temp, ok := strconv.parse_int(str); ok {
						newValue = temp
					}
				}
			}
		}
	}
	return
}
// Labels for text edit widgets
PaintWidgetLabel :: proc(rect: Rect, label: string, fillColor, backgroundColor: Color) {
	if len(label) > 0 {
		labelFont := GetFontData(.label)
		textSize := MeasureString(labelFont, label)
		PaintRect({rect.x + WIDGET_TEXT_OFFSET - 2, rect.y - 4, textSize.x + 4, 6}, backgroundColor)
		PaintString(GetFontData(.label), label, {rect.x + WIDGET_TEXT_OFFSET, rect.y - textSize.y / 2}, fillColor)
	}
}
// Text edit helpers
@private
TextEditInsertString :: proc(buf: ^[dynamic]u8, maxLength: int, str: string) {
	using ctx.scribe
	if length > 0 {
		remove_range(buf, index, index + length)
		length = 0
	}
	n := len(str)
	if maxLength > 0 {
		length = min(n, maxLength - len(buf))
	}
	inject_at_elem_string(buf, index, str[:n])
	index += n
}
@private
TextEditInsertRunes :: proc(buf: ^[dynamic]u8, maxLength: int, runes: []rune) {
	str := utf8.runes_to_string(runes)
	TextEditInsertString(buf, maxLength, str)
	delete(str)
}
@private
TextEditBackspace :: proc(buf: ^[dynamic]u8){
	using ctx.scribe
	if length == 0 {
		if index > 0 {
			end := index
			_, size := utf8.decode_last_rune_in_bytes(buf[:index])
			index -= size
			remove_range(buf, index, end)
		}
	} else {
		remove_range(buf, index, index + length)
		length = 0
	}
}
IsSeperator :: proc(glyph: u8) -> bool {
	return glyph == ' ' || glyph == '\n' || glyph == '\t' || glyph == '\\' || glyph == '/'
}
FindNextSeperator :: proc(slice: []u8) -> int {
	for i in 1 ..< len(slice) {
		if IsSeperator(slice[i]) {
			return i
		}
	}
	return len(slice) - 1
}
FindLastSeperator :: proc(slice: []u8) -> int {
	for i in len(slice) - 1 ..= 1 {
		if IsSeperator(slice[i]) {
			return i
		}
	}
	return 0
}
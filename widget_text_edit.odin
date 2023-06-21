package maui
// Core dependencies
import "core:fmt"
import "core:runtime"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:unicode/utf8"
import "core:math"
import "core:math/linalg"
import "core:intrinsics"
TextEditResult :: struct {
	using self: ^WidgetData,
	changed: bool,
}
// Advanced interactive text
TextProOption :: enum {
	password,
	selectAll,
	alignCenter,
	alignRight,
}
TextProOptions :: bit_set[TextProOption]
// Displays clipped, selectable text that can be copied to clipboard
TextPro :: proc(fontData: ^FontData, data: []u8, rect: Rect, options: TextProOptions, widget: ^WidgetData) {
	state := &ctx.scribe
	// Hovered index
	hoverIndex := 0
	minDist: f32 = math.F32_MAX
	// Determine text origin
	origin: Vec2 = {rect.x + rect.h * 0.25, rect.y + rect.h / 2 - fontData.size / 2}
	if options & {.alignCenter, .alignRight} != {} {
		textSize := MeasureString(fontData, string(data))
		if options >= {.alignCenter} {
			origin.x = rect.x + rect.w / 2 - textSize.x / 2
		} else if options >= {.alignRight} {
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
	if .gotFocus in widget.state {
		ctx.scribe.index = 0
		ctx.scribe.offset = {}
	}
	// Offset view when currently focused
	if .focused in widget.state {
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
		if .focused in widget.state && .gotFocus not_in widget.state {
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
			PaintGlyphClipped(glyphData, point, rect, GetColor(.textInverted if highlight else .text, 1))
		}
		// Finished, move index and point
		point.x += glyphWidth
		size.x += glyphWidth
		index += bytes
	}
	// Handle initial text selection
	if .selectAll in options {
		if .gotFocus in widget.state {
			ctx.scribe.index = 0
			ctx.scribe.anchor = 0
			ctx.scribe.length = len(data)
		}
	}
	if .gotPress in widget.state {
		if widget.clickCount == 1 {
			ctx.scribe.index = 0
			ctx.scribe.anchor = 0
			ctx.scribe.length = len(data)
		} else {
			ctx.scribe.index = hoverIndex
			ctx.scribe.anchor = hoverIndex
			ctx.scribe.length = 0
		}
	}
	// View offset
	if widget.state >= {.pressed} && widget.clickCount != 1 {
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
	} else if widget.state >= {.focused} {
		// Handle view offset
		if ctx.scribe.index < ctx.scribe.prev_index {
			if cursorStart.x < ctx.scribe.offset.x {
				ctx.scribe.offset.x = cursorStart.x
			}
		} else if ctx.scribe.index > ctx.scribe.prev_index || ctx.scribe.length > ctx.scribe.prev_length {
			if cursorEnd.x > ctx.scribe.offset.x + (rect.w - GetRule(.widgetTextOffset) * 2) {
				ctx.scribe.offset.x = cursorEnd.x - rect.w + GetRule(.widgetTextOffset) * 2
			}
		}
		ctx.scribe.prev_index = ctx.scribe.index
		ctx.scribe.prev_length = ctx.scribe.length
	}
	// Clamp view offset
	if size.x > rect.w {
		state.offset.x = clamp(state.offset.x, 0, (size.x - rect.w) + GetRule(.widgetTextOffset) * 2)
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
		ctx.paintNextFrame = true
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
		ctx.paintNextFrame = true
		state.index = max(0, state.index)
		state.length = max(0, state.length)
	}
	if change {
		state.length = min(state.length, len(buf) - state.index)
	}
	return
}
// Edit a dynamic array of bytes
TextInputData :: union {
	^[dynamic]u8,
	^string,
}
TextInputInfo :: struct {
	data: TextInputData,
	title: Maybe(string),
	placeholder: Maybe(string),
	textOptions: TextProOptions,
	editOptions: TextEditOptions,
}
TextInput :: proc(info: TextInputInfo, loc := #caller_location) -> (change: bool) {
	if self, ok := Widget(HashId(loc), UseNextRect() or_else LayoutNext(CurrentLayout()), {.draggable, .keySelect}); ok {
		using self
		// Text cursor
		if state & {.hovered, .pressed} != {} {
			ctx.cursor = .beam
		}
		// Animation values
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
		PopId()

		buffer := info.data.(^[dynamic]u8) or_else GetTextBuffer(self.id)

		// Text edit
		if state >= {.focused} {
			change = TextEdit(buffer, info.editOptions)
			if change {
				ctx.paintNextFrame = true
				if value, ok := info.data.(^string); ok {
					delete(value^)
					value^ = strings.clone_from_bytes(buffer[:])
				}
			}
		}
		if state >= {.gotFocus} {
			if text, ok := info.data.(^string); ok {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
		}
		// Paint!
		PaintRect(body, AlphaBlend(GetColor(.widgetBackground), GetColor(.widgetShade), hoverTime * 0.05))
		fontData := GetFontData(.default)
		switch type in info.data {
			case ^string:
			TextPro(fontData, transmute([]u8)type[:], body, {}, self)

			case ^[dynamic]u8:
			TextPro(fontData, type[:], body, {}, self)
		}
		if .shouldPaint in bits {
			outlineColor := GetColor(.accent) if .focused in self.state else BlendColors(GetColor(.baseStroke), GetColor(.text), hoverTime)
			PaintLabeledWidgetFrame(body, info.title, 1, outlineColor)
			// Draw placeholder
			if info.placeholder != nil {
				if len(buffer) == 0 {
					PaintStringAligned(fontData, info.placeholder.?, {body.x + body.h * 0.25, body.y + body.h / 2}, GetColor(.text, GHOST_TEXT_ALPHA), .near, .middle)
				}
			}
		}
	}
	return
}
// Edit number values
NumberInputInfo :: struct($T: typeid) where intrinsics.type_is_float(T) || intrinsics.type_is_integer(T) {
	value: T,
	title,
	format: Maybe(string),
	textOptions: TextProOptions,
	noOutline: bool,
}
NumberInput :: proc(info: NumberInputInfo($T), loc := #caller_location) -> (newValue: T) {
	newValue = info.value
	if self, ok := Widget(HashId(loc), UseNextRect() or_else LayoutNext(CurrentLayout()), {.draggable, .keySelect}); ok {
		using self
		// Animation values
		hoverTime := AnimateBool(self.id, .hovered in state, 0.1)
		// Cursor style
		if state & {.hovered, .pressed} != {} {
			ctx.cursor = .beam
		}
		// Formatting
		text := TextFormatSlice(info.format.? or_else "%v", info.value)
		// Painting
		fontData := GetFontData(.monospace)
		PaintRect(body, AlphaBlend(GetColor(.widgetBackground), GetColor(.widgetShade), hoverTime * 0.05))
		if !info.noOutline {
			outlineColor := GetColor(.accent) if .focused in self.state else BlendColors(GetColor(.baseStroke), GetColor(.text), hoverTime)
			PaintLabeledWidgetFrame(body, info.title, 1, outlineColor)
		}
		// Update text input
		if state >= {.focused} {
			buffer := GetTextBuffer(id)
			if state >= {.gotFocus} {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			textEditOptions: TextEditOptions = {.numeric, .integer}
			switch typeid_of(T) {
				case f16, f32, f64: textEditOptions -= {.integer}
			}
			TextPro(
				fontData, 
				buffer[:], 
				body, 
				info.textOptions, 
				self,
				)
			if TextEdit(buffer, textEditOptions, 18) {
				ctx.paintNextFrame = true
				str := string(buffer[:])
				switch typeid_of(T) {
					case f64:  		
					if temp, ok := strconv.parse_f64(str); ok {
						newValue = T(temp)
					}
					case int: 
					if temp, ok := strconv.parse_int(str); ok {
						newValue = T(temp)
					}
				}
				state += {.changed}
			}
		} else {
			TextPro(
				fontData, 
				text, 
				body, 
				info.textOptions, 
				self,
				)
		}
	}
	return
}
// Labels for text edit widgets
PaintLabeledWidgetFrame :: proc(rect: Rect, text: Maybe(string), thickness: f32, color: Color) {
	if text != nil {
		labelFont := GetFontData(.label)
		textSize := MeasureString(labelFont, text.?)
		PaintWidgetFrame(rect, rect.h * 0.25 - 2, textSize.x + 4, thickness, color)
		PaintString(GetFontData(.label), text.?, {rect.x + rect.h * 0.25, rect.y - textSize.y / 2}, color)
	} else {
		PaintRectLines(rect, thickness, color)
	}
}
// Text edit helpers
TextEditInsertString :: proc(buf: ^[dynamic]u8, maxLength: int, str: string) {
	using ctx.scribe
	if length > 0 {
		remove_range(buf, index, index + length)
		length = 0
	}
	n := len(str)
	if maxLength > 0 {
		n = min(n, maxLength - len(buf))
	}
	inject_at_elem_string(buf, index, str[:n])
	index += n
}
TextEditInsertRunes :: proc(buf: ^[dynamic]u8, maxLength: int, runes: []rune) {
	str := utf8.runes_to_string(runes)
	TextEditInsertString(buf, maxLength, str)
	delete(str)
}
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
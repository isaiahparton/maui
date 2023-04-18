package maui

import "core:fmt"
import "core:math"
import "core:runtime"
import "core:unicode/utf8"
import "core:math/linalg"
import "core:strconv"
import "core:strings"
import "core:slice"

import rl "vendor:raylib"

// General purpose booleans
ControlBit :: enum {
	stayAlive,
	active,
}
ControlBits :: bit_set[ControlBit]
// Behavior options
ControlOption :: enum {
	holdFocus,
	draggable,
	tabSelect,
}
ControlOptions :: bit_set[ControlOption]
// User input state
ControlStatus :: enum {
	hovered,

	justFocused,
	focused,
	justUnfocused,

	pressed,
	down,
	released,

	doubleClicked,
}
ControlState :: bit_set[ControlStatus]
// Universal control data
Control :: struct {
	id: Id,
	body: Rect,
	bits: ControlBits,
	options: ControlOptions,
	state: ControlState,
}
@(deferred_out=EndControl)
BeginControl :: proc(id: Id, rect: Rect) -> (control: ^Control, ok: bool) {
	using ctx

	//id := UseNextId() or_else HashId(loc)
	layer := GetCurrentLayer()
	idx, found := layer.contents[id]
	if !found {
		idx = -1
		for i in 0 ..< MAX_CONTROLS {
			if !controlExists[i] {
				controlExists[i] = true
				controls[i] = {}
				idx = i32(i)
				layer.contents[id] = idx
				break
			}
		}
	}
	ok = idx >= 0
	if ok {
		control = &ctx.controls[idx]
		control.id = id
		control.body = rect
		control.state = {}
		control.bits += {.stayAlive}
		if control.id == ctx.focusId {
			ctx.focusIndex = idx
		}
	}

	return
}
EndControl :: proc(control: ^Control, ok: bool) {
	if !ok {
		return
	}
	if ctx.disabled {
		PaintDisableShade(control.body)
	}

	layer := GetCurrentLayer()
	layer.contentRect.x = min(layer.contentRect.x, control.body.x)
	layer.contentRect.y = min(layer.contentRect.y, control.body.y)
	layer.contentRect.w = max(layer.contentRect.w, (control.body.x + control.body.w) - layer.contentRect.x)
	layer.contentRect.h = max(layer.contentRect.h, (control.body.y + control.body.h) - layer.contentRect.y)
}
UpdateControl :: proc(using control: ^Control) {
	if ctx.disabled {
		return
	}

	// Request hover status
	if VecVsRect(input.mousePoint, body) && ctx.hoveredLayer == GetCurrentLayer().id {
		ctx.nextHoverId = id
	}

	// If hovered
	if ctx.hoverId == id {
		state += {.hovered}
	} else if ctx.pressId == id {
		if .draggable in options {
			if MouseReleased(.left) {
				ctx.pressId = 0
			}
			//ctx.dragging = true
		} else if (.draggable not_in options) {
			ctx.pressId = 0
		}
	}

	// Press
	if ctx.pressId == id {
		if ctx.prevPressId != id {
			state += {.pressed}
			if ctx.doubleClick {
				state += {.doubleClicked}
			}
		}
		if MouseReleased(.left) {
			state += {.released}
			ctx.pressId = 0
			GetCurrentLayer().bits += {.submit}
		} else {
			ctx.dragging = .draggable in options
			state += {.down}
		}
	}

	// Focus
	if ctx.focusId == id {
		state += {.focused}
		if ctx.prevFocusId != id {
			state += {.justFocused}
		}
	} else if ctx.prevFocusId == id {
		state += {.justUnfocused}
	}

	return
}

PaintDisableShade :: proc(rect: Rect) {
	PaintRect(rect, GetColor(.foreground, 0.5))
}

// Primitives??
//
//	| basic text 			| editable text 		| clickable

// Basic controls
//
// 	| button				| checkbox				| switch
// 	| text field			| spinner				| menu
// 	| slider				| range slider			| scroll bar

// Advanced controls
//
// 	| calendar				| color picker

/*
	Text input
*/
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
MutableTextFromBytes :: proc(font: FontData, data: []u8, rect: Rect, format: TextInputFormat, state: ControlState) -> (change: bool, newData: []u8) {

	hoverIndex := 0
	minDist: f32 = 9999

	origin: Vec2 = {rect.x + WIDGET_TEXT_OFFSET, rect.y + rect.h / 2 - font.size / 2}
	if format.align != .near {
		textSize := MeasureString(font, string(data))
		if format.align == .middle {
			origin.x = rect.x + rect.w / 2 - textSize.x / 2
		} else if format.align == .far {
			origin.x = rect.x + rect.w - WIDGET_ROUNDNESS - 2 - textSize.x
		}
	}
	point := origin

	// Iterate over the bytes
	for index := 0; index <= len(data); {
		// Decode the next glyph
		bytes := 1
		glyph: rune = 0
		if index < len(data) {
			glyph, bytes = utf8.decode_rune_in_bytes(data[index:])
		}
		glyphData := GetGlyphData(font, glyph)
		glyphWidth := glyphData.advance + GLYPH_SPACING

		// Draw cursors
		highlight := false
		if .focused in state && .justFocused not_in state {
			if ctx.scribe.length == 0 && .readOnly not_in format.options {
				if ctx.scribe.index == index {
					PaintRect({point.x - 1, point.y, 2, font.size}, GetColor(.text))
				}
			} else if index >= ctx.scribe.index && index < ctx.scribe.index + ctx.scribe.length {
				PaintRect({point.x, point.y, glyphWidth, font.size}, GetColor(.text))
				highlight = true
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
		if .multiline in format.options && glyph == '\n' {
			point.x = origin.x
			point.y += font.size * 1.5
		} else if glyph != '\t' && glyph != ' ' {
			PaintClippedGlyph(glyphData, point, rect, GetColor(.backing if highlight else .textBright, 1))
		}

		/*
			Finished, move index and point
		*/
		point.x += glyphData.advance + GLYPH_SPACING
		index += bytes
	}

	/*
		Mouse selection
	*/
	if .down in state {
		if hoverIndex < ctx.scribe.anchor {
			ctx.scribe.index = hoverIndex
			ctx.scribe.length = ctx.scribe.anchor - hoverIndex
		} else {
			ctx.scribe.index = ctx.scribe.anchor
			ctx.scribe.length = hoverIndex - ctx.scribe.anchor
		}
	}
	if .justFocused in state || .pressed in state {
		ctx.scribe.index = hoverIndex
		ctx.scribe.anchor = hoverIndex
		ctx.scribe.length = 0
	}
	if .selectAll in format.options && .justFocused in state {
		ctx.scribe.index = 0
		ctx.scribe.anchor = 0
		ctx.scribe.length = len(data)
	}

	// Text manipulation
	if .focused not_in state {
		return
	}
	using ctx.scribe

	if KeyDown(.control) {
		if KeyPressed(.c) {
			// copy to clipboard
		}
	}
	if .readOnly not_in format.options {
		if KeyDown(.control) {
			if KeyPressed(.a) {
				index = 0
				anchor = 0
				length = len(data)
			}
			if KeyPressed(.v) {
				// paste from clipboard
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
		ctx.renderTime = 1
		length := len(ctx.scribe.buffer) 
		if format.capacity > 0 {
			length = min(length, format.capacity)
		}
		newData = ctx.scribe.buffer[:length]
	}

	return
}

/*
	Text input widgets
*/
TextInputBytes :: proc(data: []u8, label, placeholder: string, format: TextInputFormat, loc := #caller_location) -> (change: bool, newData: []u8) {
	if control, ok := BeginControl(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control
		options += {.draggable, .tabSelect}
		UpdateControl(control)

		// Animation values
		hoverTime := AnimateBool(id, .hovered in state, 0.1)

		// Painting
		PaintRoundedRect(body, WIDGET_ROUNDNESS, GetColor(.backing, 1))

		if .hovered in state || .down in state {
			ctx.cursor = .beam
		}

		font := GetFontData(.default)
		PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, .focused not_in state, GetColor(.accent, 1) if .focused in state else GetColor(.outlineBase, hoverTime))
		change, newData = MutableTextFromBytes(font, data, control.body, format, control.state)

		// Draw placeholder
		if len(label) > 0 {
			labelFont := GetFontData(.label)
			textSize := MeasureString(labelFont, label)
			PaintRect({body.x + WIDGET_TEXT_OFFSET - 2, body.y, textSize.x + 4, 2}, GetColor(.backing, 1))
			PaintString(GetFontData(.label), label, {body.x + WIDGET_TEXT_OFFSET, body.y - textSize.y / 2}, GetColor(.text, 1))
		}
		if len(placeholder) != 0 {
			if len(data) == 0 {
				PaintAlignedString(font, placeholder, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.widgetPress, 1), .near, .middle)
			}
		}

		body.y -= 10
		body.h += 10
		
	}
	return
}
NumberInputFloat32 :: proc(value: f32, label: string, loc := #caller_location) -> (newValue: f32) {
	if control, ok := BeginControl(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control

		newValue = value
		control.options += {.draggable, .tabSelect}
		UpdateControl(control)

		// Animation values
		hoverTime := AnimateBool(id, .hovered in state, 0.1)

		// Painting
		PaintRoundedRect(body, WIDGET_ROUNDNESS, GetColor(.backing, 1))

		if .hovered in state || .down in state {
			ctx.cursor = .beam
		}

		data := SPrintF("%.2f", value)
		if .justFocused in state {
			delete(ctx.numberText)
			ctx.numberText = slice.clone(data)
		}

		font := GetFontData(.monospace)
		change, newData := MutableTextFromBytes(font, ctx.numberText if .focused in state else data, control.body, {options = {.numeric}, capacity = 15}, control.state)
		if change {
			newValue, ok = strconv.parse_f32(string(newData))
			delete(ctx.numberText)
			ctx.numberText = slice.clone(newData)
		}

		PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, .focused not_in state, GetColor(.accent, 1) if .focused in state else GetColor(.outlineBase, hoverTime))
		// Draw placeholder
		if len(label) > 0 {
			labelFont := GetFontData(.label)
			textSize := MeasureString(labelFont, label)
			PaintRect({body.x + WIDGET_TEXT_OFFSET - 2, body.y, textSize.x + 4, 2}, GetColor(.backing, 1))
			PaintString(GetFontData(.label), label, {body.x + WIDGET_TEXT_OFFSET, body.y - textSize.y / 2}, GetColor(.text, 1))
		}

		body.y -= 10
		body.h += 10
		
	}
	return
}

/*
	Regular Button
*/
ButtonStyle :: enum {
	normal,
	bright,
	subtle,
}
ButtonPro :: proc(text: string, style: ButtonStyle, corners: RectCorners, loc := #caller_location) -> (result: bool) {
	layout := GetCurrentLayout()
	if layout.side == .left || layout.side == .right {
		layout.size = MeasureString(GetFontData(.default), text).x + layout.rect.h + layout.margin * 2
	}
	if control, ok := BeginControl(HashId(loc), LayoutNext(layout)); ok {
		using control
		UpdateControl(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.25)
		PopId()

		roundness := body.h / 2

		if style == .subtle {
			if hoverTime < 1 {
				PaintRoundedRectOutlineEx(body, roundness, false, corners, GetColor(.widgetHover))
			}
			PaintRoundedRectEx(body, roundness, corners, GetColor(.widgetPress) if .down in state else GetColor(.widgetHover, hoverTime))
			if .down not_in state {
				PaintRoundedRectOutlineEx(body, roundness, false, corners, GetColor(.widgetPress, pressTime))
			}
			PaintAlignedString(GetFontData(.default), text, {body.x + body.w / 2, body.y + body.h / 2}, BlendColors(GetColor(.widgetPress), GetColor(.backing), hoverTime), .middle, .middle)
		} else if style == .normal {
			PaintRoundedRectEx(body, roundness, corners, GetColor(.widgetPress) if .down in state else BlendColors(GetColor(.widgetBase), GetColor(.widgetHover), hoverTime))
			if .down not_in state {
				PaintRoundedRectOutlineEx(body, roundness, false, corners, GetColor(.widgetPress, pressTime))
			}
			PaintAlignedString(GetFontData(.default), text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.backing), .middle, .middle)
		} else {
			PaintRoundedRectEx(body, roundness, corners, GetColor(.accentPress) if .down in state else BlendColors(GetColor(.accent), GetColor(.accentHover), hoverTime))
			if .down not_in state {
				PaintRoundedRectOutlineEx(body, roundness, false, corners, GetColor(.accentPress, pressTime))
			}
			PaintAlignedString(GetFontData(.default), text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.backing), .middle, .middle)
		}
		

		
		result = .released in state
	}
	return
}
ButtonEx :: proc(text: string, style: ButtonStyle, loc := #caller_location) -> bool {
	return ButtonPro(text, style, ALL_CORNERS, loc)
}
Button :: proc(text: string, loc := #caller_location) -> bool {
	return ButtonEx(text, .normal, loc)
}



/*
	Icon Buttons
*/
IconButtonEx :: proc(icon: IconIndex, corners: RectCorners, loc := #caller_location) -> (result: bool) {
	if control, ok := BeginControl(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateControl(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.075)
		PopId()

		PaintRoundedRectEx(body, WIDGET_ROUNDNESS, corners, GetColor(.widgetPress) if .down in state else BlendColors(GetColor(.widgetBase), GetColor(.widgetHover), hoverTime))
		if .down not_in state {
			PaintRoundedRectOutlineEx(body, WIDGET_ROUNDNESS, false, corners, GetColor(.widgetPress, pressTime))
		}
		DrawIconEx(icon, {body.x + body.w / 2, body.y + body.h / 2}, 1, .middle, .middle, GetColor(.text, 1))

		
		result = .released in state
	}
	return
}
IconButton :: proc(icon: IconIndex, loc := #caller_location) -> bool {
	return IconButtonEx(icon, ALL_CORNERS, loc)
}

IconButtonToggleEx :: proc(value: bool, icon: IconIndex, corners: RectCorners, loc := #caller_location) -> (newValue: bool) {
	newValue = value
	if control, ok := BeginControl(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateControl(control)
		if .released in state {
			newValue = !value
		}

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(1), value, 0.15)
		PopId()

		fillColor: Color
		if newValue {
			fillColor = GetColor(.widgetPress) if .down in state else BlendColors(GetColor(.widgetBase), GetColor(.widgetHover), hoverTime)
		} else {
			fillColor = GetColor(.foregroundPress) if .down in state else BlendColors(GetColor(.foreground), GetColor(.foregroundHover), hoverTime)
		}
		PaintRoundedRectEx(body, WIDGET_ROUNDNESS, corners, fillColor)
		PaintRoundedRectOutlineEx(body, WIDGET_ROUNDNESS, false, corners, GetColor(.outlineBase))
		if corners & {.topRight, .bottomRight} == {} {
			PaintRect({body.x + body.w - 2, body.y + 2, 1, body.h - 4}, fillColor)
		}
		if corners & {.topLeft, .bottomLeft} == {} {
			PaintRect({body.x + 1, body.y + 2, 1, body.h - 4}, fillColor)
		}
		DrawIconEx(icon, {body.x + body.w / 2, body.y + body.h / 2}, 1, .middle, .middle, GetColor(.text if newValue else .outlineBase))
	}
	return
}
IconButtonToggle :: proc(value: bool, icon: IconIndex, loc := #caller_location) -> bool {
	return IconButtonToggleEx(value, icon, ALL_CORNERS, loc)
}

/*
	Spinner compound widget
*/
Spinner :: proc(value, low, high: int, loc := #caller_location) -> (newValue: int) {
	rect := LayoutNext(GetCurrentLayout())
	leftButtonRect := CutRectLeft(&rect, 30)
	rightButtonRect := CutRectRight(&rect, 30)
	newValue = value
	loc := loc
	/*
		Number input first
	*/
	if control, ok := BeginControl(HashId(loc), rect); ok {
		using control
		newValue = value
		control.options += {.draggable}
		UpdateControl(control)

		// Animation values
		hoverTime := AnimateBool(id, .hovered in state, 0.1)

		// Painting
		PaintRect(body, GetColor(.backing, 1))

		if .hovered in state || .down in state {
			ctx.cursor = .beam
		}

		data := SPrintF("%i", value)
		if .justFocused in state {
			delete(ctx.numberText)
			ctx.numberText = slice.clone(data)
		}

		font := GetFontData(.monospace)
		change, newData := MutableTextFromBytes(
			font, 
			ctx.numberText if .focused in state else data, 
			control.body, 
			{ options = {.numeric, .integer}, align = .middle },
			control.state,
			)
		if change {
			newValue, ok = strconv.parse_int(string(newData))
			newValue = clamp(newValue, low, high)
			delete(ctx.numberText)
			ctx.numberText = slice.clone(newData)
		}
		PaintRectLines(body, 2 if .focused in state else 1, GetColor(.accent, 1) if .focused in state else GetColor(.outlineBase, hoverTime))
	}

	/*
		Buttons
	*/
	loc.column += 1
	SetNextRect(leftButtonRect)
	if IconButtonEx(.minus, {.topLeft, .bottomLeft}, loc) {
		newValue = max(low, value - 1)
	}
	loc.column += 1
	SetNextRect(rightButtonRect)
	if IconButtonEx(.plus, {.topRight, .bottomRight}, loc) {
		newValue = min(high, value + 1)
	}
	return
}

/*
	Bar Slider
*/
SliderEx :: proc(value, low, high: f32, name: string, loc := #caller_location) -> (change: bool, newValue: f32) {
	SIZE :: 16
	HEIGHT :: SIZE / 2
	HALF_HEIGHT :: HEIGHT / 2
	rect := LayoutNext(GetCurrentLayout())
	rect = ChildRect(rect, {rect.w, SIZE}, .near, .middle)
	if control, ok := BeginControl(HashId(loc), rect); ok {
		using control
		control.options += {.draggable}
		UpdateControl(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state || .down in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
		PopId()

		barRect: Rect = {body.x, body.y + HALF_HEIGHT, body.w, body.h - HEIGHT}
		if value < high {
			PaintRoundedRect(barRect, HALF_HEIGHT, GetColor(.backing))
		}

		range := body.w - HEIGHT
		offset := range * clamp((value - low) / high, 0, 1)
		fillColor := BlendColors(GetColor(.widgetBase), GetColor(.accent), hoverTime)
		PaintRoundedRect({barRect.x, barRect.y, offset, barRect.h}, HALF_HEIGHT, fillColor)

		thumbCenter: Vec2 = {body.x + HALF_HEIGHT + offset, body.y + body.h / 2}
		// TODO: Constants for these
		thumbRadius := body.h
		if hoverTime > 0 {
			PaintCircle(thumbCenter, thumbRadius + 10 * (pressTime + hoverTime), StyleGetShadeColor(1))
		}
		PaintCircle(thumbCenter, thumbRadius, fillColor)

		if .down in state {
			change = true
			newValue = clamp(low + ((input.mousePoint.x - body.x - HALF_HEIGHT) / range) * (high - low), low, high)
		}

		
	}
	return
}

/*
	Spinner slider
*/
DragSpinner :: proc(value, low, high: int, loc := #caller_location) -> (newValue: int) {
	newValue = value
	if control, ok := BeginControl(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control
		control.options += {.draggable}
		UpdateControl(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state || .down in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
		PopId()

		font := GetFontData(.monospace)

		PaintRect(body, GetColor(.backing if .active in bits else .widgetBase))
		PaintRectLines(body, 2 if .active in bits else 1, GetColor(.accent) if .active in bits else GetColor(.outlineBase, hoverTime))

		numberText := Format(value)
		center: Vec2 = {body.x + body.w / 2, body.y + body.h / 2}

		if .doubleClicked in state {
			bits = bits ~ {.active}
			state += {.justFocused}
		}

		if .active in bits {
			if change, newData := MutableTextFromBytes(
				font, 
				transmute([]u8)numberText[:], 
				body, 
				{align = .middle, options = {.selectAll}}, 
				state,
			); change {
				if parsedValue, ok := strconv.parse_int(string(newData)); ok {
					newValue = parsedValue
				}
			}
		} else {
			PaintAlignedString(font, numberText, center, GetColor(.text), .middle, .middle)

			if .down in state {
				newValue = value + int(input.mousePoint.x - input.prevMousePoint.x) + int(input.mousePoint.y - input.prevMousePoint.y)
			}
			if .hovered in state {
				ctx.cursor = .resizeEW
			}
		}

		if .focused not_in state {
			bits -= {.active}
		}

		
	}
	if low < high {
		newValue = clamp(newValue, low, high)
	}
	return
}

/*
	Checkbox
*/
CheckBoxStatus :: enum u8 {
	on,
	off,
	unknown,
}
CheckBoxEx :: proc(status: CheckBoxStatus, text: string, loc := #caller_location) -> (change, newValue: bool) {
	SIZE :: 22
	HALF_SIZE :: SIZE / 2
	if control, ok := BeginControl(HashId(loc), LayoutNextEx(GetCurrentLayout(), SIZE)); ok {
		using control

		active := (status == .on || status == .unknown)
		textSize := MeasureString(GetFontData(.default), text)
		body.w += textSize.x + WIDGET_TEXT_OFFSET
		UpdateControl(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), active, 0.1)
		PopId()

		body.w = SIZE
		center: Vec2 = {body.x + HALF_SIZE, body.y + HALF_SIZE}
		if hoverTime > 0 {
			PaintCircle(center, 34, StyleGetShadeColor(hoverTime))
		}
		if pressTime > 0 {
			if .down in state {
				PaintCircle(center, 26 + pressTime * 8, StyleGetShadeColor(1))
			} else {
				PaintCircle(center, 34, StyleGetShadeColor(pressTime))
			}
		}

		if stateTime < 1 {
			PaintRoundedRect(body, 5, GetColor(.foreground if ctx.disabled else .backing, 1))
			PaintRoundedRectOutline(body, 5, false, BlendColors(GetColor(.outlineBase, 1), GetColor(.accent, 1), hoverTime))
		}
		if stateTime > 0 {
			PaintRoundedRect(body, 5, GetColor(.widgetBase if ctx.disabled else .accent, stateTime))
			DrawIconEx(.minus if status == .unknown else .check, center, stateTime, .middle, .middle, GetColor(.foreground, 1))
		}
		PaintString(GetFontData(.default), text, {body.x + body.w + WIDGET_TEXT_OFFSET, center.y - textSize.y / 2}, GetColor(.text, 1))
		if .released in state {
			if status != .on {
				newValue = true
			}
			change = true
		}

		
	}
	return
}
CheckBox :: proc(value: ^bool, text: string, loc := #caller_location) -> bool {
	if value == nil {
		return false
	}
	if change, newValue := CheckBoxEx(.on if value^ else .off, text, loc); change {
		value^ = newValue
		return true
	}
	return false
}
CheckBoxBitSet :: proc(set: ^$S/bit_set[$E;$U], bit: E, text: string, loc := #caller_location) -> bool {
	if set == nil {
		return false
	}
	if change, newValue := CheckBoxEx(.on if bit in set else .off, text, loc); change {
		if newValue {
			incl(set, bit)
		} else {
			excl(set, bit)
		}
		return true
	}
	return false
}
CheckBoxBitSetHeader :: proc(set: ^$S/bit_set[$E;$U], text: string, loc := #caller_location) -> bool {
	if set == nil {
		return false
	}
	state := CheckBoxStatus.off
	elementCount := card(set^)
	if elementCount == len(E) {
		state = .on
	} else if elementCount > 0 {
		state = .unknown
	}
	if change, newValue := CheckBoxEx(state, text, loc); change {
		if newValue {
			for element in E {
				incl(set, element)
			}
		} else {
			set^ = {}
		}
		return true
	}
	return false
}

/*
	Toggle Switch
*/
ToggleSwitch :: proc(value: bool, loc := #caller_location) -> (newValue: bool) {
	newValue = value
	if control, ok := BeginControl(HashId(loc), LayoutNextEx(GetCurrentLayout(), {34, 26})); ok {
		using control
		UpdateControl(control)

		// Animation
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.15)
			howOn := AnimateBool(HashIdFromInt(2), value, 0.25)
		PopId()

		baseRect: Rect = {body.x, body.y + 4, body.w, body.h - 8}
		baseRadius := baseRect.h / 2
		start: Vec2 = {baseRect.x + baseRadius, baseRect.y + baseRect.h / 2}
		move := baseRect.w - baseRect.h
		thumbCenter := start + {move * (rl.EaseBackOut(howOn, 0, 1, 1) if value else rl.EaseBackIn(howOn, 0, 1, 1)), 0}

		strokeColor := BlendColors(GetColor(.outlineBase), GetColor(.widgetBase if ctx.disabled else .accent), howOn)
		if howOn < 1 {
			if !ctx.disabled {
				PaintRoundedRect(baseRect, baseRadius, GetColor(.backing))
			}
			PaintRoundedRectOutline(baseRect, baseRadius, false, strokeColor)
		}
		if howOn > 0 {
			if howOn < 1 {
				PaintRoundedRect({baseRect.x, baseRect.y, thumbCenter.x - baseRect.x, baseRect.h}, baseRadius, GetColor(.widgetBase if ctx.disabled else .accent))
			} else {
				PaintRoundedRect(baseRect, baseRadius, GetColor(.widgetBase if ctx.disabled else .accent))
			}
		}
		if hoverTime > 0 {
			PaintCircle(thumbCenter, 30, StyleGetShadeColor(hoverTime))
		}
		if pressTime > 0 {
			if .down in state {
				PaintCircle(thumbCenter, 19 + 11 * pressTime, StyleGetShadeColor())
			} else {
				PaintCircle(thumbCenter, 30, StyleGetShadeColor(pressTime))
			}
		}
		PaintCircle(thumbCenter, 17, GetColor(.foreground if ctx.disabled else .backing))
		PaintCircleOutline(thumbCenter, 19, false, strokeColor)
		
		if .released in state {
			newValue = !value
		}

		
	}
	return
}

/*
	Radio Button
*/
RadioButton :: proc(value: bool, name: string, loc := #caller_location) -> bool {
	return RadioButtonEx(value, name, .left, loc)
}
RadioButtonEx :: proc(value: bool, name: string, textSide: RectSide, loc := #caller_location) -> (selected: bool) {
	SIZE :: 22
	HALF_SIZE :: 12

	textSize := MeasureString(GetFontData(.default), name)
	size: Vec2
	if textSide == .bottom || textSide == .top {
		size.x = max(SIZE, textSize.x)
		size.y = SIZE + textSize.y
	} else {
		size.x = SIZE + WIDGET_TEXT_OFFSET + textSize.x
		size.y = SIZE
	}

	if control, ok := BeginControl(HashId(loc), LayoutNextEx(GetCurrentLayout(), size)); ok {
		using control
		UpdateControl(control)

		// Animation
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state && !value, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), value, 0.2)
		PopId()

		// Button
		center: Vec2
		switch textSide {
			case .left: center = {body.x + HALF_SIZE, body.y + HALF_SIZE}
			case .right: center = {body.x + body.w - HALF_SIZE, body.y + HALF_SIZE}
			case .top: center = {body.x + body.w / 2, body.y + body.h - HALF_SIZE}
			case .bottom: center = {body.x + body.w / 2, body.y + HALF_SIZE}
		}
		outerRadius := 21 - 4 * pressTime
		if hoverTime > 0 {
			PaintCircle(center, 32, StyleGetShadeColor(hoverTime))
			PaintCircle(center, outerRadius, GetColor(.foreground))
		}
		if !ctx.disabled {
			PaintCircle(center, outerRadius, GetColor(.backing))
		}
		PaintCircleOutline(center, outerRadius, false, BlendColors(GetColor(.outlineBase, 1), GetColor(.accent, 1), hoverTime + stateTime))
		if stateTime > 0 {
			PaintCircle(center, rl.EaseCircOut(stateTime, 0, 12, 1), GetColor(.accent, 1))
		}

		// Text
		switch textSide {
			case .left: PaintString(GetFontData(.default), name, {body.x + 24 + WIDGET_TEXT_OFFSET, center.y - textSize.y / 2}, GetColor(.text, 1))
			case .right: PaintString(GetFontData(.default), name, {body.x, center.y - textSize.y / 2}, GetColor(.text, 1))
			case .top: PaintString(GetFontData(.default), name, {body.x, body.y}, GetColor(.text, 1))
			case .bottom: PaintString(GetFontData(.default), name, {body.x, body.y + body.h - textSize.y}, GetColor(.text, 1))
		}

		if .released in state {
			selected = true
		}

		
	}
	return
}
RadioButtons :: proc(value: $T, side: RectSide, loc := #caller_location) -> (newValue: T) {
	newValue = value
	for member in T {
		PushId(HashIdFromInt(int(member)))
			if RadioButtonEx(member == value, strings.to_upper_camel_case(Format(member), ctx.allocator), side) {
				newValue = member
			}
		PopId()
	}
	return
}

/*
	Drop-down Menus
	FIXME: Menu closes when clicked on!
*/
@(deferred_out=_Menu)
Menu :: proc(text: string, menuSize: f32, loc := #caller_location) -> (layer: ^LayerData, active: bool) {
	sharedId := HashId(loc)
	if control, ok := BeginControl(sharedId, LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateControl(control)
		active = .active in bits

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), active, 0.125)
		PopId()

		corners: RectCorners = {.topLeft, .topRight}
		if !active {
			corners += {.bottomLeft, .bottomRight}
		}
		PaintRoundedRectEx(body, WIDGET_ROUNDNESS, corners, BlendColors(GetColor(.backing), GetColor(.backingHighlight), pressTime))
		PaintRoundedRectOutlineEx(body, WIDGET_ROUNDNESS, true, corners, GetColor(.outlineBase, hoverTime + stateTime))
		PaintCollapseArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, -1 + stateTime, GetColor(.text))
		PaintAlignedString(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text), .near, .middle)

		
		if .released in state {
			bits = bits ~ {.active}
		}

		if active {
			layer, ok = BeginLayer(AttachRectBottom(body, menuSize + WIDGET_ROUNDNESS), {}, sharedId, {.outlined})
			layer.order = .popup

			if (.hovered not_in state && ctx.hoveredLayer != layer.id && MousePressed(.left)) || .submit in layer.bits {
				bits -= {.active}
			}

			PaintRoundedRectEx(layer.body, WIDGET_ROUNDNESS, {.bottomLeft, .bottomRight}, GetColor(.widgetBase, 1))

			PushLayout(layer.body)
		}
	}
	return 
}
@private _Menu :: proc(layer: ^LayerData, active: bool) {
	if active {
		//PaintRoundedRectOutlineEx(layer.body, WIDGET_ROUNDNESS, true, {.bottomLeft, .bottomRight}, GetColor(.outlineBase))
		EndLayer(layer)
		PopLayout()
	}
}
// Options within menus
MenuOption :: proc(text: string, active: bool, loc := #caller_location) -> (result: bool) {
	if control, ok := BeginControl(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateControl(control)

		PushId(id)
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
		PopId()

		PaintRect(body, GetColor(.widgetHover) if active else BlendThreeColors(GetColor(.widgetBase), GetColor(.widgetHover), GetColor(.widgetPress), hoverTime + pressTime))
		PaintAlignedString(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text, 1), .near, .middle)

		
		result = .released in state
	}
	return result
}
EnumMenu :: proc(value: $T, optionSize: f32, loc := #caller_location) -> (newValue: T) {
	newValue = value
	if layer, active := Menu(strings.to_upper_camel_case(Format(value), ctx.allocator), optionSize * len(T), loc); active {
		SetSize(optionSize)
		for member in T {
			PushId(HashIdFromInt(int(member)))
				if MenuOption(strings.to_upper_camel_case(Format(member), ctx.allocator), value == member) {
					newValue = member
				}
			PopId()
		}
	}
	return
}

/*
	Widgets are buttons that contain other controls
*/
@(deferred_out=_Widget)
Widget :: proc(label: string, sides: RectSides, loc := #caller_location) -> (clicked, yes: bool) {
	if control, ok := BeginControl(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateControl(control)

		PushId(id)
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
		PopId()

		corners := SideCorners(sides)
		if hoverTime > 0 {
			PaintRoundedRectEx(body, WIDGET_ROUNDNESS, corners, StyleGetShadeColor((hoverTime + pressTime) * 0.75))
		}
		PaintRoundedRectOutlineEx(body, WIDGET_ROUNDNESS, true, corners, GetColor(.outlineBase))
		PaintAlignedString(GetFontData(.default), label, {body.x + body.h * 0.25, body.y + body.h / 2}, GetColor(.text), .near, .middle)

		
		PushLayout(body)

		clicked = .released in state
		yes = true
	}
	return
}
@private _Widget :: proc(clicked, yes: bool) {
	if yes {
		PopLayout()
	}
}

/*
	Widget divider
*/
WidgetDivider :: proc() {
	using layout := GetCurrentLayout()
	#partial switch side {
		case .left: PaintRect({rect.x, rect.y + 10, 1, rect.h - 20}, GetColor(.outlineBase))
		case .right: PaintRect({rect.x + rect.w, rect.y + 10, 1, rect.h - 20}, GetColor(.outlineBase))
	}
}

/*
	Sections
*/
@(deferred_out=_Section)
Section :: proc(label: string, sides: RectSides) -> (ok: bool) {
	rect := LayoutNext(GetCurrentLayout())

	PaintRoundedRectOutlineEx(rect, WIDGET_ROUNDNESS, true, SideCorners(sides), GetColor(.outlineBase))
	if len(label) != 0 {
		font := GetFontData(.default)
		textSize := MeasureString(font, label)
		PaintRect({rect.x + WIDGET_ROUNDNESS + WIDGET_TEXT_OFFSET - 2, rect.y, textSize.x + 4, 1}, GetColor(.foreground))
		PaintString(GetFontData(.default), label, {rect.x + WIDGET_ROUNDNESS + WIDGET_TEXT_OFFSET, rect.y - textSize.y / 2}, GetColor(.text))
	}

	PushLayout(rect)
	Shrink(20)
	return true
}
@private _Section :: proc(ok: bool) {
	if ok {
		PopLayout()
	}
}

/*
	Scroll bar
*/
ScrollBarH :: proc(value, low, high, thumbSize: f32, loc := #caller_location) -> (change: bool, newValue: f32) {
	newValue = value
	if control, ok := BeginControl(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		range := body.w - thumbSize
		valueRange := (high - low) if high > low else 1
		thumbRect: Rect = {body.x + range * ((value - low) / valueRange), body.y, thumbSize, body.h}

		control.options += {.draggable}
		UpdateControl(control)
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			pressTime := AnimateBool(HashId(int(1)), .down in state, 0.1)
		PopId()

		opacity := 0.5 + hoverTime * 0.5

		PaintRoundedRect(body, body.h / 2, GetColor(.backing, opacity))
		PaintRoundedRect(thumbRect, body.h / 2, Fade(BlendColors(GetColor(.widgetHover), GetColor(.widgetPress), hoverTime), opacity))

		if .down in state {
			normal := clamp((input.mousePoint.x - (body.x + thumbSize / 2)) / range, 0, 1)
			newValue = low + (high - low) * normal
			change = true
		}
	}
	return
}
ScrollBarV :: proc(value, low, high, thumbSize: f32, loc := #caller_location) -> (change: bool, newValue: f32) {
	newValue = value
	if control, ok := BeginControl(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		range := body.h - thumbSize
		valueRange := (high - low) if high > low else 1
		thumbRect: Rect = {body.x, body.y + range * ((value - low) / valueRange), body.w, thumbSize}

		control.options += {.draggable}
		UpdateControl(control)
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			pressTime := AnimateBool(HashId(int(1)), .down in state, 0.1)
		PopId()

		opacity := 0.5 + hoverTime * 0.5

		PaintRoundedRect(body, body.w / 2, GetColor(.backing, opacity))
		PaintRoundedRect(thumbRect, body.w / 2, Fade(BlendColors(GetColor(.widgetHover), GetColor(.widgetPress), hoverTime), opacity))

		if .down in state {
			normal := clamp((input.mousePoint.y - (body.y + thumbSize / 2)) / range, 0, 1)
			newValue = low + (high - low) * normal
			change = true
		}
	}
	return
}

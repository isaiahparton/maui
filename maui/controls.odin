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
	active,				// toggled state (combo box is expanded)
}
ControlBits :: bit_set[ControlBit]
// Behavior options
ControlOption :: enum {
	holdFocus,
	draggable,
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
}
ControlState :: bit_set[ControlStatus]
// Universal control data
Control :: struct {
	id: Id,
	body: Rect,
	bits: ControlBits,
	opts: ControlOptions,
	state: ControlState,
}

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
	}

	return
}
EndControl :: proc(control: ^Control) {
}
UpdateControl :: proc(using control: ^Control) {
	if ctx.disabled {
		return
	}

	// Request hover status
	if VecVsRect(input.mousePos, body) && ctx.hoveredLayer == GetCurrentLayer().id {
		ctx.nextHoverId = id
	}

	// If hovered
	if ctx.hoverId == id {
		state += {.hovered}
	} else if ctx.pressId == id {
		if .draggable in opts {
			if MouseReleased(.left) {
				ctx.pressId = 0
			}
			//ctx.dragging = true
		} else if (.draggable not_in opts) {
			ctx.pressId = 0
		}
	}

	// Press
	if ctx.pressId == id {
		if ctx.prevPressId != id {
			state += {.pressed}
		}
		if MouseReleased(.left) {
			state += {.released}
			ctx.pressId = 0
		} else {
			ctx.dragging = .draggable in opts
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

	origin: Vec2 = {rect.x + WIDGET_ROUNDNESS + 2, rect.y + rect.h / 2 - font.size / 2}
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
		/*
			Decoding
		*/
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
					PaintRect({point.x - 1, point.y, 2, font.size}, GetColor(.text, 1))
				}
			} else if index >= ctx.scribe.index && index < ctx.scribe.index + ctx.scribe.length {
				PaintRect({point.x, point.y, glyphWidth, font.size}, GetColor(.text, 1))
				highlight = true
			}
		}

		// Decide the hovered glyph
		glyphPoint := point + {0, font.size / 2}
		dist := linalg.length(glyphPoint - input.mousePos)
		if dist < minDist {
			minDist = dist
			hoverIndex = index
		}

		// Anything past here requires a valid glyph
		if index == len(data) {
			break
		}

		/*
			Painting the glyphs and cursors
		*/
		if glyph != '\t' && glyph != ' ' && glyph != '\n' {
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
	if .pressed in state {
		ctx.scribe.index = hoverIndex
		ctx.scribe.anchor = hoverIndex
		ctx.scribe.length = 0
	} else if .down in state {
		if hoverIndex < ctx.scribe.anchor {
			ctx.scribe.index = hoverIndex
			ctx.scribe.length = ctx.scribe.anchor - hoverIndex
		} else {
			ctx.scribe.index = ctx.scribe.anchor
			ctx.scribe.length = hoverIndex - ctx.scribe.anchor
		}
	}

	// Text manipulation
	if .focused in state {
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
				ScribeInsertRunes(input.runes[:input.runeCount])
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
		length := len(ctx.scribe.buffer) 
		if format.capacity > 0 {
			length = min(length, format.capacity)
		}
		newData = ctx.scribe.buffer[:length]
	}

	return
}

TextInputBytes :: proc(data: []u8, label, placeholder: string, options: TextInputOptions, loc := #caller_location) -> (change: bool, newData: []u8) {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return
	}

	control.opts += {.draggable}
	UpdateControl(control)

	// Animation values
	hoverTime := AnimateBool(id, .hovered in state, 0.1)

	// Painting
	PaintRoundedRect(body, WIDGET_ROUNDNESS, GetColor(.backing, 1))

	if .hovered in state || .down in state {
		ctx.cursor = .beam
	}

	font := GetFontData(.default)
	PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, true, GetColor(.accent, 1) if .focused in state else GetColor(.outlineBase, hoverTime))
	change, newData = MutableTextFromBytes(font, data, control.body, {options = options, capacity = 18}, control.state)

	// Draw placeholder
	if len(label) > 0 {
		labelFont := GetFontData(.label)
		textSize := MeasureString(labelFont, label)
		PaintRect(
			{body.x + WIDGET_ROUNDNESS, body.y, textSize.x + 4, 1}, 
			GetColor(.backing, 1),
			)
		PaintString(
			GetFontData(.label), 
			label, 
			{body.x + WIDGET_ROUNDNESS + 2, body.y - textSize.y / 2}, 
			GetColor(.textBright if .focused in state else .text, 1),
			)
	}
	if len(placeholder) != 0 {
		if len(data) == 0 {
			PaintAlignedString(font, placeholder, {body.x + WIDGET_ROUNDNESS + 2, body.y + body.h / 2}, GetColor(.widgetPress, 1), .near, .middle)
		}
	}

	return
}
NumberInputFloat32 :: proc(value: f32, label: string, loc := #caller_location) -> (newValue: f32) {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return
	}

	newValue = value
	control.opts += {.draggable}
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
	change, newData := MutableTextFromBytes(font, ctx.numberText if .focused in state else data, control.body, {options = {.numeric}}, control.state)
	if change {
		newValue, ok = strconv.parse_f32(string(newData))
		delete(ctx.numberText)
		ctx.numberText = slice.clone(newData)
	}

	PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, true, GetColor(.accent, 1) if .focused in state else GetColor(.outlineBase, hoverTime))
	// Draw placeholder
	if len(label) > 0 {
		labelFont := GetFontData(.label)
		textSize := MeasureString(labelFont, label)
		PaintRect(
			{body.x + WIDGET_ROUNDNESS, body.y, textSize.x + 4, 1}, 
			GetColor(.backing, 1),
			)
		PaintString(
			GetFontData(.label), 
			label, 
			{body.x + WIDGET_ROUNDNESS + 2, body.y - textSize.y / 2}, 
			GetColor(.textBright if .focused in state else .text, 1),
			)
	}

	return
}

/*
	Regular Button
*/
ButtonEx :: proc(text: string, corners: Corners, loc := #caller_location) -> bool {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return false
	}
	UpdateControl(control)

	PushId(id) 
		hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
		pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
	PopId()

	PaintRoundedRectEx(body, 5, corners, StyleGetWidgetColor(hoverTime, pressTime))
	PaintAlignedString(GetFontData(.default), text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.text, 1), .middle, .middle)

	EndControl(control)
	return .released in state
}
Button :: proc(text: string, loc := #caller_location) -> bool {
	return ButtonEx(text, {.topLeft, .topRight, .bottomLeft, .bottomRight}, loc)
}

/*
	Icon Buttons
*/
IconButtonEx :: proc(icon: IconIndex, corners: Corners, loc := #caller_location) -> bool {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return false
	}
	UpdateControl(control)

	PushId(id) 
		hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
		pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
	PopId()

	PaintRoundedRectEx(body, 5, corners, BlendColors(GetColor(.widgetBase, 1), GetColor(.widgetPress, 1), pressTime))
	if hoverTime > 0 {
		PaintRoundedRectOutlineEx(body, 5, true, corners, GetColor(.widgetPress, hoverTime))
	}
	DrawIconEx(icon, {body.x + body.w / 2, body.y + body.h / 2}, 1, .middle, .middle, GetColor(.text, 1))

	EndControl(control)
	return .released in state
}
IconButton :: proc(icon: IconIndex, loc := #caller_location) -> bool {
	return IconButtonEx(icon, {.topLeft, .topRight, .bottomLeft, .bottomRight}, loc)
}

/*
	Button option for menus
*/
MenuOption :: proc(text: string, loc := #caller_location) -> bool {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return false
	}
	UpdateControl(control)

	PushId(id) 
		hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
		pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
	PopId()

	PaintRect(body, GetColor(.widgetBase, (hoverTime + pressTime) * 0.5))
	PaintAlignedString(GetFontData(.default), text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.text, 1), .middle, .middle)

	EndControl(control)
	return .released in state
}

/*
	Spinner compound widget
*/
Spinner :: proc(value, low, high: int, loc := #caller_location) -> (newValue: int) {
	rect := GetNextRect()
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
		control.opts += {.draggable}
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
			{ options = {.numeric}, align = .middle },
			control.state,
			)
		if change {
			newValue, ok = strconv.parse_int(string(newData))
			newValue = clamp(newValue, low, high)
			delete(ctx.numberText)
			ctx.numberText = slice.clone(newData)
		}
		PaintRectLines(body, 1, GetColor(.accent, 1) if .focused in state else GetColor(.outlineBase, hoverTime))
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
	Rectangle Slider
*/
SliderEx :: proc(value, low, high: f32, name: string, loc := #caller_location) -> (change: bool, newValue: f32) {
	rect := GetNextRect()
	rect = ChildRect(rect, {rect.w, 10}, .near, .middle)
	if control, ok := BeginControl(HashId(loc), rect); ok {
		using control

		control.opts += {.draggable}
		UpdateControl(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state || .down in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
		PopId()

		/*PaintRoundedRect(body, WIDGET_ROUNDNESS, GetColor(.widgetBase, 1))
		PaintRoundedRect({body.x, body.y, body.w * clamp((value - low) / high, 0, 1), body.h}, WIDGET_ROUNDNESS, BlendColors(GetColor(.widgetPress, 1), GetColor(.accent, 1), hoverTime))
		PaintAlignedString(GetFontData(.default), StringFormat("%s: %.2f", name, value), {body.x + body.w / 2, body.y + body.h / 2}, BlendColors(GetColor(.text, 1), GetColor(.textBright, 1), hoverTime), .middle, .middle)*/
		PaintRoundedRect(body, body.h / 2, GetColor(.backing, 1))

		thumbCenter: Vec2 = {body.x + body.w * ((value - low) / (high - low)), body.y + 5}
		PaintCircle(thumbCenter, 20, StyleGetWidgetColor(hoverTime, pressTime))
		PaintCircle(thumbCenter, 12 + 2 * hoverTime - 4 * pressTime, GetColor(.accent, 1))

		if .down in state {
			change = true
			newValue = clamp(low + ((input.mousePos.x - body.x) / body.w) * (high - low), low, high)
		}

		EndControl(control)
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
	if control, ok := BeginControl(HashId(loc), ChildRect(GetNextRect(), {22, 22}, .near, .middle)); ok {
		using control

		/*
			Control logic
		*/
		active := (status == .on || status == .unknown)
		textSize := MeasureString(GetFontData(.default), text)
		body.w += textSize.x + WIDGET_TEXT_OFFSET
		UpdateControl(control)

		/*
			Animation
		*/
		body.w = 22
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), active, 0.075)
		PopId()

		PaintRoundedRect(
			body, 
			3, 
			BlendColors(GetColor(.accent, stateTime), {255, 255, 255, 255}, pressTime * 0.25),
			)

		if stateTime < 1 {
			PaintRoundedRectOutline(body, 3, true, BlendColors(GetColor(.outlineBase, 1), GetColor(.accent, 1), hoverTime))
		}
		if stateTime > 0 {
			DrawIconEx(.minus if status == .unknown else .check, {body.x + 11, body.y + 11}, stateTime, .middle, .middle, GetColor(.textBright, 1))
		}
		PaintString(GetFontData(.default), text, {body.x + body.w + WIDGET_TEXT_OFFSET, body.y + 10 - textSize.y / 2}, GetColor(.text, 1))
		if .released in state {
			if status != .on {
				newValue = true
			}
			change = true
		}

		EndControl(control)
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
	if control, ok := BeginControl(HashId(loc), ChildRect(GetNextRect(), {32, 24}, .near, .middle)); ok {
		using control

		/*
			Control logic
		*/
		UpdateControl(control)

		/*
			Animation
		*/
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
			howOn := AnimateBool(HashIdFromInt(2), value, 0.2)
		PopId()

		baseRect: Rect = {body.x, body.y + 4, body.w, body.h - 8}
		baseRadius := baseRect.h / 2
		start: Vec2 = {baseRect.x + baseRadius, baseRect.y + baseRect.h / 2}
		move := baseRect.w - baseRect.h
		thumbCenter := start + {move * (rl.EaseBackOut(howOn, 0, 1, 1) if value else rl.EaseBackIn(howOn, 0, 1, 1)), 0}

		if howOn < 1 {
			PaintRoundedRectOutline(baseRect, baseRadius, true, BlendColors(GetColor(.outlineBase, 1), GetColor(.accent, 1), howOn))
		}
		if howOn > 0 {
			PaintRoundedRect({baseRect.x, baseRect.y, thumbCenter.x - baseRect.x, baseRect.h}, baseRadius, GetColor(.accent, 1))
		}
		PaintCircle(thumbCenter, 17, StyleGetWidgetColor(hoverTime, pressTime))
		PaintCircleOutline(thumbCenter, 19, true, BlendColors(GetColor(.outlineBase, 1), GetColor(.accent, 1), hoverTime + howOn))
		
		if .released in state {
			newValue = !value
		}

		EndControl(control)
	}
	return
}

/*
	Radio Button
*/
RadioButton :: proc(value: bool, name: string, loc := #caller_location) -> (selected: bool) {
	if control, ok := BeginControl(HashId(loc), ChildRect(GetNextRect(), {24, 24}, .near, .middle)); ok {
		using control

		/*
			Control logic
		*/
		body.w += WIDGET_TEXT_OFFSET + MeasureString(GetFontData(.default), name).x
		UpdateControl(control)
		body.w = 24

		/*
			Animation
		*/
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state && !value, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), value, 0.2)
		PopId()

		center: Vec2 = {body.x + 12, body.y + 12}

		PaintCircleOutline(center, 22 - 4 * pressTime, true, BlendColors(GetColor(.outlineBase, 1), GetColor(.accent, 1), hoverTime + stateTime))
		if stateTime > 0 {
			PaintCircle(center, rl.EaseCircOut(stateTime, 0, 14, 1), GetColor(.accent, 1))
		}
		PaintAlignedString(GetFontData(.default), name, {body.x + body.w + 5, center.y}, GetColor(.text, 1), .near, .middle)
		if .released in state {
			selected = true
		}

		EndControl(control)
	}
	return
}
RadioButtons :: proc(value: $T, loc := #caller_location) -> (newValue: T) {
	newValue = value
	for member in T {
		PushId(HashIdFromInt(int(member)))
			if RadioButton(member == value, strings.to_upper_camel_case(Format(member), ctx.allocator)) {
				newValue = member
			}
		PopId()
	}
	return
}

/*
	Drop-down Menus
*/
@(deferred_out=_Menu)
Menu :: proc(text: string, menuSize: f32, loc := #caller_location) -> (layer: ^LayerData, active: bool) {
	sharedId := HashId(loc)
	using control, ok := BeginControl(sharedId, GetNextRect())
	if !ok {
		return
	}
	UpdateControl(control)

	PushId(id) 
		hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
		pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
	PopId()

	active = .active in bits
	corners: Corners = {.topLeft, .topRight}
	if !active {
		corners += {.bottomLeft, .bottomRight}
	}
	PaintRoundedRectEx(body, WIDGET_ROUNDNESS, corners, GetColor(.backing, 1))
	PaintRoundedRectOutlineEx(body, WIDGET_ROUNDNESS, true, corners, GetColor(.outlineBase, hoverTime))
	PaintAlignedString(GetFontData(.default), text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.text, 1), .middle, .middle)

	EndControl(control)
	if .released in state {
		if .active in bits {
			bits -= {.active}
		} else {
			bits += {.active}
		}
	}

	if active {
		layer, ok = BeginLayer(AttachRectBottom(body, menuSize + WINDOW_ROUNDNESS), sharedId, {})
		layer.order = .popup

		PaintRoundedRectEx(layer.body, WINDOW_ROUNDNESS, {.bottomLeft, .bottomRight}, GetColor(.backing, 1))

		PushLayout(layer.body)
		CutSize(28)
	}
	return 
}
@private _Menu :: proc(layer: ^LayerData, active: bool) {
	if active {
		PaintRoundedRectOutlineEx(layer.body, WINDOW_ROUNDNESS, true, {.bottomLeft, .bottomRight}, GetColor(.outlineBase, 1))
		EndLayer(layer)
		PopLayout()
	}
}
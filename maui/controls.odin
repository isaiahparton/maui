package maui

import "core:fmt"
import "core:math"
import "core:runtime"
import "core:unicode/utf8"
import "core:math/linalg"
import "core:strconv"
import "core:strings"
import "core:slice"

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
	Text input of course
*/
TextInputOption :: enum {
	readOnly,
	multiline,
	hidden,
	numeric,
	integer,
}
TextInputOptions :: bit_set[TextInputOption]

MutableTextFromBytes :: proc(font: FontData, data: []u8, rect: Rect, options: TextInputOptions, state: ControlState) -> (change: bool, newData: []u8) {

	hoverIndex := 0
	minDist: f32 = 9999

	origin: Vec2 = {rect.x + WIDGET_ROUNDNESS + 2, rect.y + rect.h / 2 - font.size / 2}
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
			if ctx.scribe.length == 0 && .readOnly not_in options {
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
		if .readOnly not_in options {
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
	if .readOnly not_in options && .justFocused in state {
		resize(&ctx.scribe.buffer, len(data))
		copy(ctx.scribe.buffer[:], data[:])
	}

	// Create new data slice
	if change {
		newData = ctx.scribe.buffer[:]
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
	PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, false, GetColor(.accent, 1) if .focused in state else GetColor(.widgetHover, hoverTime))
	change, newData = MutableTextFromBytes(font, data, control.body, options, control.state)

	// Draw placeholder
	if len(label) > 0 {
		labelFont := GetFontData(.label)
		textSize := MeasureString(labelFont, label)
		PaintRect(
			{body.x + WIDGET_ROUNDNESS, body.y, textSize.x + 4, 2}, 
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
			PaintAlignedString(font, placeholder, {body.x + WIDGET_ROUNDNESS + 2, body.y + body.h / 2}, GetColor(.widgetBase, 1), .near, .middle)
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
	change, newData := MutableTextFromBytes(font, ctx.numberText if .focused in state else data, control.body, {.numeric}, control.state)
	if change {
		newValue, ok = strconv.parse_f32(string(newData))
		delete(ctx.numberText)
		ctx.numberText = slice.clone(newData)
	}

	PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, false, GetColor(.accent, 1) if .focused in state else GetColor(.widgetHover, hoverTime))
	// Draw placeholder
	if len(label) > 0 {
		labelFont := GetFontData(.label)
		textSize := MeasureString(labelFont, label)
		PaintRect(
			{body.x + WIDGET_ROUNDNESS, body.y, textSize.x + 4, 2}, 
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
	Clicky widgets
*/
ButtonEx :: proc(text: string, loc := #caller_location) -> bool {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return false
	}
	UpdateControl(control)

	PushId(id) 
		hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
		pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
	PopId()

	PaintRoundedRect(body, 5, BlendColors(GetColor(.widgetBase, 1), GetColor(.widgetPress, 1), pressTime))
	if hoverTime > 0 {
		PaintRoundedRectOutline(body, 5, false, GetColor(.widgetPress, hoverTime))
	}
	PaintAlignedString(GetFontData(.default), text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.text, 1), .middle, .middle)

	EndControl(control)
	return .released in state
}
IconButtonEx :: proc(icon: IconIndex, loc := #caller_location) -> bool {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return false
	}
	UpdateControl(control)

	PushId(id) 
		hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
		pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
	PopId()

	PaintRoundedRect(body, 5, BlendColors(GetColor(.widgetBase, 1), GetColor(.widgetPress, 1), pressTime))
	if hoverTime > 0 {
		PaintRoundedRectOutline(body, 5, false, GetColor(.widgetPress, hoverTime))
	}
	DrawIconEx(icon, {body.x + body.w / 2, body.y + body.h / 2}, 1, .middle, .middle, GetColor(.text, 1))

	EndControl(control)
	return .released in state
}

/*
	Draggable widgets
*/
SliderEx :: proc(value, low, high: f32, name: string, loc := #caller_location) -> (change: bool, newValue: f32) {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return
	}
	control.opts += {.draggable}
	UpdateControl(control)

	PushId(id) 
		hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state || .down in state, 0.1)
		pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
	PopId()

	PaintRoundedRect(body, WIDGET_ROUNDNESS, GetColor(.widgetBase, 1))
	PaintRoundedRect({body.x, body.y, body.w * clamp((value - low) / high, 0, 1), body.h}, WIDGET_ROUNDNESS, BlendColors(GetColor(.widgetPress, 1), GetColor(.accent, 1), hoverTime))
	PaintAlignedString(GetFontData(.default), StringFormat("%s: %.2f", name, value), {body.x + body.w / 2, body.y + body.h / 2}, BlendColors(GetColor(.text, 1), GetColor(.textBright, 1), hoverTime), .middle, .middle)

	if .down in state {
		change = true
		newValue = clamp(low + ((input.mousePos.x - body.x) / body.w) * (high - low), low, high)
	}
	if .down in state || .hovered in state {
		ctx.cursor = .resizeEW
	}

	EndControl(control)

	return
}

/*
	Boolean controls
*/
CheckBoxStatus :: enum u8 {
	on,
	off,
	unknown,
}
CheckBoxEx :: proc(status: CheckBoxStatus, text: string, loc := #caller_location) -> (change, newValue: bool) {
	if control, ok := BeginControl(HashId(loc), ChildRect(GetNextRect(), {26, 26}, .near, .middle)); ok {
		using control

		/*
			Control logic
		*/
		active := (status == .on || status == .unknown)
		UpdateControl(control)

		/*
			Animation
		*/
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), active, 0.075)
		PopId()

		PaintRoundedRect(
			body, 
			WIDGET_ROUNDNESS, 
			BlendColors(GetColor(.accent, stateTime), {255, 255, 255, 255}, pressTime * 0.25),
			)

		if stateTime < 1 {
			PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, false, BlendColors(GetColor(.widgetBase, 1), GetColor(.accent, 1), hoverTime))
		}
		if stateTime > 0 {
			DrawIconEx(.minus if status == .unknown else .check, {body.x + 13, body.y + 13}, stateTime, .middle, .middle, GetColor(.textBright, 1))
		}
		PaintAlignedString(GetFontData(.default), text, {body.x + body.w + 5, body.y + body.h / 2}, GetColor(.text, 1), .near, .middle)
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

ToggleSwitch :: proc(value: bool, loc := #caller_location) -> (newValue: bool) {
	newValue = value
	if control, ok := BeginControl(HashId(loc), ChildRect(GetNextRect(), {48, 28}, .near, .middle)); ok {
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
			howOn := AnimateBool(HashIdFromInt(2), value, 0.075)
		PopId()

		strokeColor := BlendColors(GetColor(.widgetBase, 1), GetColor(.accent, 1), pressTime + howOn)

		baseRect := ShrinkRect(body, 3)
		baseRadius := baseRect.h / 2
		start: Vec2 = {baseRect.x + baseRadius, baseRect.y + baseRect.h / 2}
		move := baseRect.w - baseRect.h
		thumbCenter := start + {move * howOn, 0}
		PaintRoundedRect(baseRect, baseRadius, BlendColors(GetColor(.backing, 1), GetColor(.accent, 1), howOn))
		PaintRoundedRectOutline(baseRect, baseRadius, true, strokeColor)
		PaintCircle(thumbCenter, 21, BlendColors(GetColor(.backing, 1), GetColor(.widgetBase, 1), hoverTime))
		PaintCircleOutline(thumbCenter, 23, true, strokeColor)
		
		if .released in state {
			newValue = !value
		}

		EndControl(control)
	}
	return
}


/*
	Combo box or whatever you want it to be
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

	PaintRoundedRect(body, 5, BlendColors(GetColor(.widgetBase, 1), GetColor(.widgetPress, 1), pressTime))
	if hoverTime > 0 {
		PaintRoundedRectOutline(body, 5, false, GetColor(.widgetPress, hoverTime))
	}
	PaintAlignedString(GetFontData(.default), text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.text, 1), .middle, .middle)

	EndControl(control)
	if .released in state {
		if .active in bits {
			bits -= {.active}
		} else {
			bits += {.active}
		}
	}

	active = .active in bits
	if active {
		layer, ok = BeginLayer(AttachRectBottom(body, menuSize), sharedId, {})
		layer.order = .popup

		PaintRoundedRect(layer.body, WINDOW_ROUNDNESS, GetColor(.backing, 1))
		PushLayout(layer.body)
	}
	return 
}
@private _Menu :: proc(layer: ^LayerData, active: bool) {
	if active {
		PaintRoundedRectOutline(layer.body, WINDOW_ROUNDNESS, true, GetColor(.text, 1))
		EndLayer(layer)
		PopLayout()
	}
}
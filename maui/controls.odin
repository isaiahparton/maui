package maui

import "core:fmt"
import "core:math"
import "core:runtime"
import "core:unicode/utf8"
import "core:math/linalg"

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
		if MousePressed(.left) {
			ctx.pressId = id
		}
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
TextInputBytes :: proc(data: []u8, label, placeholder: string, options: TextInputOptions, loc := #caller_location) -> (change: bool, newData: []u8) {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return
	}

	control.opts += {.draggable}
	UpdateControl(control)

	hoverTime := AnimateBool(id, .hovered in state, 0.1)

	PaintRoundedRect(body, WIDGET_ROUNDNESS, GetColor(.backing, 1))
	PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, false, GetColor(.accent, 1) if .focused in state else GetColor(.widgetHover, hoverTime))
	if .hovered in state || .down in state {
		ctx.cursor = .beam
	}

	hoverIndex := 0
	minDist: f32 = 9999

	font := GetFontData(.monospace)
	point: Vec2 = {body.x + 5, body.y + body.h / 2 - font.size / 2}

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
		if .focused in state {
			if ctx.scribe.length == 0 {
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
			PaintClippedGlyph(glyphData, point, body, GetColor(.backing if highlight else .textBright, 1))
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
		ctx.scribe = {
			index = hoverIndex,
			anchor = hoverIndex,
		}
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
		if input.runeCount > 0 {
			ScribeInsertRunes(input.runes[:input.runeCount])
			change = true
		}
		if KeyPressed(.backspace) {
			ScribeBackspace()
		}
	}
	if .justFocused in state {
		clear(&ctx.scribe.buffer)
		append_string(&ctx.scribe.buffer, string(data))
	}

	if change {
		newData = ctx.scribe.buffer[:]
	}

	return
}

/*
	Sub-layer for grouping stuff together
*/
@(deferred_out=_Widget)
Widget :: proc(loc := #caller_location) -> (ok: bool) {
	using control, k := BeginControl(HashId(loc), GetNextRect())
	if !k {
		return
	}
	UpdateControl(control)

	PaintRect(body, GetColor(.widgetBase, 1))
	PaintRectLines(body, 1, GetColor(.outlineBase, 1))

	EndControl(control)

	ok = true
	PushLayout(body)
	return
}
@private _Widget :: proc(ok: bool) {
	if ok {
		PopLayout()
	}
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
	Boolean controls
*/
CheckBoxStatus :: enum u8 {
	on,
	off,
	unknown,
}
CheckBoxEx :: proc(status: CheckBoxStatus, text: string, loc := #caller_location) -> (change, newValue: bool) {
	if control, ok := BeginControl(HashId(loc), ChildRect(GetNextRect(), {24, 24}, .near, .middle)); ok {
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

		PaintRoundedRect(body, WIDGET_ROUNDNESS, BlendColors(GetColor(.widgetBase, 1), GetColor(.accent, 1), stateTime))
		if pressTime > 0 {
			PaintRoundedRect(body, WIDGET_ROUNDNESS, GetColor(.textBright, pressTime * 0.2))
		}
		if hoverTime > 0 && stateTime < 1 {
			PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, false, GetColor(.accent, hoverTime))
		}
		if stateTime > 0 {
			DrawIconEx(.minus if status == .unknown else .check, {body.x + 12, body.y + 12}, stateTime, .middle, .middle, GetColor(.textBright, 1))
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
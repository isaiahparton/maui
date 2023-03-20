package maui

import "core:fmt"
import "core:math"
import "core:runtime"
import "core:unicode/utf8"

/*
	Anything clickable/interactable
*/
ControlBit :: enum {
	stayAlive,
	active,				// toggled state (combo box is expanded)
}
ControlBits :: bit_set[ControlBit]

ControlOption :: enum {
	holdFocus,
	draggable,
}
ControlOptions :: bit_set[ControlOption]

ControlStatus :: enum {
	hovered,
	focused,
	pressed,
	down,
	released,
}
ControlState :: bit_set[ControlStatus]

Control :: struct {
	id: Id,
	body: Rect,
	bits: ControlBits,
	opts: ControlOptions,
	state: ControlState,

	// animation
	hoverTime, pressTime, activeTime: f32,
}

/*BeginControlEx :: proc(loc: runtime.Source_Code_Location) -> (control: ^Control, ok: bool) {
	return BeginControl(loc, GetNextRect())
}*/
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
	layer := GetCurrentLayer()

	layer.contentSize.x = max(layer.contentSize.x, control.body.w + (control.body.x - layer.body.x))
	layer.contentSize.y = max(layer.contentSize.y, control.body.h + (control.body.y - layer.body.y))
}

UpdateControl :: proc(using control: ^Control) {
	if ctx.disabled {
		return
	}

	// request hover status
	if VecVsRect(input.mousePos, body) && ctx.hoveredLayer == ctx.layerStack[ctx.layerDepth - 1] {
		ctx.nextHoverId = id
	}

	// if hovered
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
		} else if (.holdFocus not_in opts) {
			ctx.pressId = 0
		}
	}

	// focusing
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
TextInputEx :: proc(data: []u8, options: TextInputOptions, loc := #caller_location) -> (change: bool, newData: []u8) {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return
	}

	for index := 0; index < len(data); {
		bytes := 0
		codepoint := rune(0)
		if index < len(data) {
			codepoint, bytes = utf8.decode_rune_in_bytes(data[index:])
		}
		glyph := GetGlyphData(ctx.font, codepoint)
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
	hoverTime = ControlTimer(.hovered in state, hoverTime, 7, 7)
	pressTime = ControlTimer(.down in state, pressTime, 9, 9)

	offset := -7 * hoverTime
	if offset != 0 {
		DrawRect(body, GetColor(1, 1))
	}
	body = TranslateRect(body, {offset, offset})
	DrawRect(body, GetColor(0, 1))
	DrawRectLines(body, ctx.style.outline, GetColor(1, 1))

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
ButtonEx :: proc(text: string, alt: bool, loc := #caller_location) -> bool {
	using control, ok := BeginControl(HashId(loc), GetNextRect())
	if !ok {
		return false
	}
	UpdateControl(control)
	hoverTime = ControlTimer(.hovered in state, hoverTime, 6, 6)
	pressTime = ControlTimer(.down in state, pressTime, 6, 6)

	DrawRect(body, GetColor(1 if alt else 0, 1))
	if hoverTime > 0 {
		DrawRectSweep(body, hoverTime, GetColor(3 if alt else 2, 1))
		DrawRect(body, GetColor(1, 0.15 * pressTime))
	}
	if !alt {
		DrawRectLines(body, ctx.style.outline, GetColor(1, 1))
	}
	DrawAlignedString(ctx.font, text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(0 if alt else 1, 1), .middle, .middle)

	EndControl(control)
	return .released in state
}
IconButtonEx :: proc(icon: IconIndex, loc := #caller_location) -> bool {
	using control, ok := BeginControl(UseNextId() or_else HashId(loc), ChildRect(GetNextRect(), {30, 30}, .middle, .middle))
	if !ok {
		return false
	}
	UpdateControl(control)
	hoverTime = ControlTimer(.hovered in state, hoverTime, 6, 6)
	pressTime = ControlTimer(.down in state, pressTime, 6, 6)

	DrawRect(body, GetColor(0, 1))
	if hoverTime > 0 {
		DrawRect(body, GetColor(2, hoverTime))
		DrawRect(body, GetColor(1, 0.1 * pressTime))
	}
	DrawRectLines(body, ctx.style.outline, GetColor(1, 1))
	DrawIconEx(icon, {body.x + 15, body.y + 15}, 1, .middle, .middle, GetColor(1, 1))

	EndControl(control)
	return .released in state
}
FloatingButtonEx :: proc(icon: IconIndex, loc := #caller_location) -> bool {
	using control, ok := BeginControl(UseNextId() or_else HashId(loc), GetNextRectEx({40, 40}, .near, .near))
	if !ok {
		return false
	}
	UpdateControl(control)
	hoverTime = ControlTimer(.hovered in state, hoverTime, 6, 6)
	pressTime = ControlTimer(.down in state, pressTime, 6, 6)

	center := Vector{body.x + body.w / 2, body.y + body.h / 2}
	face := center + {0, 3 * pressTime}
	DrawCircle(center + {0, 3}, 20, 16, GetColor(1, 1))
	DrawCircle(face, 20, 16, GetColor(0, 1))
	if hoverTime > 0 {
		DrawCircle(face, 20, 16, GetColor(1, 0.1 * (pressTime + hoverTime)))
	}
	DrawRing(face, 20 - ctx.style.outline, 20, 18, GetColor(1, 1))
	DrawIconEx(icon, face, 1, .middle, .middle, GetColor(1, 1))

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
	if control, ok := BeginControl(HashId(loc), ChildRect(GetNextRect(), {30, 30}, .near, .middle)); ok {
		using control

		/*
			Control logic
		*/
		active := (status == .on || status == .unknown)
		UpdateControl(control)
		hoverTime = ControlTimer(.hovered in state, hoverTime, 6, 6)
		pressTime = ControlTimer(.down in state, pressTime, 9, 9)
		activeTime = ControlTimer(active, activeTime, 7, 7)

		//DrawRect(body, GetColor(0, 1))
		if active {
			DrawRect(body, GetColor(2, 1))
		}
		if hoverTime > 0 {
			DrawRect(body, GetColor(1, 0.1 * (hoverTime + pressTime)))
		}
		if activeTime > 0 {
			DrawIconEx(.minus if status == .unknown else .check, {body.x + 15, body.y + 15}, activeTime if active else (1 + (1 - activeTime)), .middle, .middle, GetColor(1, 1 if active else activeTime))
		}
		DrawRectLines(body, ctx.style.outline, GetColor(1, 1))
		DrawAlignedString(ctx.font, text, {body.x + body.w + 5, body.y + body.h / 2}, GetColor(1, 1), .near, .middle)

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

ToggleSwitch :: proc(value: ^bool, loc := #caller_location) -> (s: ControlState) {
	using control, ok := BeginControl(HashId(loc), ChildRect(GetNextRect(), {50, 30}, .far, .middle))
	if !ok {
		return
	}
	UpdateControl(control)

	hoverTime = ControlTimer(.hovered in state, hoverTime, 6, 6)
	pressTime = ControlTimer(.down in state, pressTime, 9, 9)
	activeTime = ControlTimer(value^, activeTime, 9, 9)

	baseline := body.y + 15
	thumbCenter := Vector{body.x + 15 + activeTime * (body.w - 30), baseline}

	// body
	bodyColor := GetColor(2 if value^ else 5, 1)
	DrawRect({body.x + 15, body.y, body.w - 30, body.h}, bodyColor)
	DrawRect({body.x + 15, body.y, body.w - 30, ctx.style.outline}, GetColor(1, 1))
	DrawRect({body.x + 15, body.y + body.h - ctx.style.outline, body.w - 30, ctx.style.outline}, GetColor(1, 1))
	DrawCircleSector({body.x + 15, baseline}, 15, math.PI * 0.5, math.PI * 1.5, 4, bodyColor)
	DrawRingSector({body.x + 15, baseline}, 15 - ctx.style.outline, 15, math.PI * 0.5, math.PI * 1.5, 8, GetColor(1, 1))
	DrawCircleSector({body.x + body.w - 15, baseline}, 15, math.PI * 1.5, math.PI * 2.5, 4, bodyColor)
	DrawRingSector({body.x + body.w - 15, baseline}, 15 - ctx.style.outline, 15, math.PI * 1.5, math.PI * 2.5, 8, GetColor(1, 1))

	// thumb (switch part thingy)
	DrawCircle(thumbCenter, 15, 8, GetColor(0, 1))
	DrawRing(thumbCenter, 15 - ctx.style.outline, 15, 16, GetColor(1, 1))
	r := 6 - 2 * pressTime
	DrawRing(thumbCenter, r, r + ctx.style.outline, 12, GetColor(1, 1))

	if .released in state {
		value^ = !value^
	}

	EndControl(control)
	return
}

/*
	Combo box or whatever you want it to be
*/
@(deferred_out=_Menu)
Menu :: proc(text: string, loc := #caller_location) -> (active: bool) {
	sharedId := HashId(loc)
	using control, ok := BeginControl(sharedId, GetNextRect())
	if !ok {
		return
	}
	UpdateControl(control)

	if .hovered in state {
		hoverTime = min(1, hoverTime + 6 * ctx.deltaTime)
	} else {
		hoverTime = max(0, hoverTime - 6 * ctx.deltaTime)
	}
	if .down in state {
		pressTime = min(1, pressTime + 9 * ctx.deltaTime)
	} else {
		pressTime = max(0, pressTime - 9 * ctx.deltaTime)
	}

	DrawRect(body, GetColor(0, 1))
	if hoverTime > 0 {
		DrawRectSweep(body, hoverTime, GetColor(2, 1))
	}
	DrawRectLines(body, ctx.style.outline, GetColor(1, 1))
	DrawAlignedString(ctx.font, text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(1, 1), .middle, .middle)

	EndControl(control)
	active = (.active in bits)
	if active {
		BeginLayerEx(AttachRectBottom(body, 100), sharedId, {.autoFit})
	}
	return 
}
@private _Menu :: proc(active: bool) {
	if active {
		EndLayer()
	}
}
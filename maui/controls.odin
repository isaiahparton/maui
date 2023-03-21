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

	DrawRect(body, GetColor(.widgetBase, 1))
	DrawRectLines(body, ctx.style.outline, GetColor(.outlineBase, 1))

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

	DrawRect(body, GetColor(.widgetPress if .down in state else (.widgetHover if .hovered in state else .widgetBase), 1))
	DrawAlignedString(ctx.font, text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.textBright, 1), .middle, .middle)

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

		//DrawRect(body, GetColor(0, 1))
		if active {
			DrawRect(body, GetColor(.widgetBase, 1))
		}
		DrawIconEx(.minus if status == .unknown else .check, {body.x + 15, body.y + 15}, 1, .middle, .middle, GetColor(.textBright, 1))
		DrawRectLines(body, ctx.style.outline, GetColor(.outlineBase, 1))
		DrawAlignedString(ctx.font, text, {body.x + body.w + 5, body.y + body.h / 2}, GetColor(.textBright, 1), .near, .middle)

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
Menu :: proc(text: string, loc := #caller_location) -> (panel: ^PanelData, active: bool) {
	sharedId := HashId(loc)
	using control, ok := BeginControl(sharedId, GetNextRect())
	if !ok {
		return
	}
	UpdateControl(control)

	DrawRect(body, GetColor(.widgetBase, 1))
	DrawRectLines(body, ctx.style.outline, GetColor(.widgetBase, 1))
	DrawAlignedString(ctx.font, text, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.textBright, 1), .middle, .middle)

	EndControl(control)
	active = (.active in bits)
	if active {
		//panel = BeginPanelEx(AttachRectBottom(body, 100), sharedId, {.fitToContent})
	}
	return 
}
@private _Menu :: proc(panel: ^PanelData, active: bool) {
	if active {
		//EndPanel(panel)
	}
}
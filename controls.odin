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
	noClick,
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
		ctx.lastControl = idx
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
	UpdateLayerContentRect(layer, control.body)
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
		if .noClick in options && MouseDown(.left) {
			ctx.pressId = id
		}
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
				if ctx.scribe.index == index {
					PaintRect({math.floor(point.x - 1), point.y, 1, font.size}, GetColor(.text))
				}
			} else if index >= ctx.scribe.index && index < ctx.scribe.index + ctx.scribe.length {
				PaintRect({max(point.x, rect.x), point.y, min(glyphWidth, rect.w - (point.x - rect.x), (point.x + glyphWidth) - rect.x), font.size}, GetColor(.text))
				highlight = true
			}
		}

		if ctx.scribe.index == index {
			cursorStart = (point + ctx.scribe.offset) - origin
		}
		if ctx.scribe.index + ctx.scribe.length == index {
			cursorEnd = (point + ctx.scribe.offset) - origin
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
			PaintGlyphClipped(glyphData, point, rect, GetColor(.backing if highlight else .textBright, 1))
		}

		// Finished, move index and point
		point.x += glyphData.advance + GLYPH_SPACING
		size.x += glyphData.advance + GLYPH_SPACING
		index += bytes
	}

	if ctx.scribe.move < 0 {
		if cursorStart.x < ctx.scribe.offset.x {
			ctx.scribe.offset.x = cursorStart.x
		}
		if cursorStart.x > ctx.scribe.offset.x + rect.w {
			ctx.scribe.offset.x = cursorStart.x - rect.w
		}
		ctx.scribe.move = 0
	} else if ctx.scribe.move > 0 {
		if cursorEnd.x < ctx.scribe.offset.x {
			ctx.scribe.offset.x = cursorEnd.x
		}
		if cursorEnd.x > ctx.scribe.offset.x + rect.w {
			ctx.scribe.offset.x = cursorEnd.x - rect.w
		}
		ctx.scribe.move = 0
	}

	// Mouse
	if .down in state {
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
	if .focused in state {

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
				// Move offset
				move = -1
				
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
				// Move offset
				move = 1
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
TextInputBytes :: proc(data: []u8, label, placeholder: string, format: TextInputFormat, loc := #caller_location) -> (change: bool, newData: []u8) {
	if control, ok := BeginControl(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control
		options += {.draggable, .tabSelect}
		UpdateControl(control)

		// Animation values
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), .focused in state, 0.2)
		PopId()

		if .hovered in state || .down in state {
			ctx.cursor = .beam
		}

		// Painting
		if stateTime > 0 {
			rect := ExpandRect(body, rl.EaseCubicOut(stateTime, 0, 3, 1))
			PaintRoundedRect(rect, math.floor(f32(WIDGET_ROUNDNESS) * 1.5), StyleGetShadeColor(1))
			PaintRoundedRect(body, WIDGET_ROUNDNESS, GetColor(.foreground))
		}
		font := GetFontData(.default)
		change, newData = MutableTextFromBytes(font, data, control.body, format, control.state)
		outlineColor := BlendColors(GetColor(.outlineBase), GetColor(.accentHover), min(1, hoverTime + stateTime))
		PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, .focused not_in state, outlineColor)

		// Draw placeholder
		PaintControlLabel(body, label, outlineColor, GetColor(.foreground))
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
NumberInputFloat32 :: proc(value: f32, label: string, loc := #caller_location) -> (newValue: f32) {
	if control, ok := BeginControl(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control

		newValue = value
		control.options += {.draggable, .tabSelect}
		UpdateControl(control)

		// Animation values
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), .focused in state, 0.2)
		PopId()

		if .hovered in state || .down in state {
			ctx.cursor = .beam
		}

		// Painting
		if stateTime > 0 {
			rect := ExpandRect(body, rl.EaseCubicOut(stateTime, 0, 3, 1))
			PaintRoundedRect(rect, math.floor(f32(WIDGET_ROUNDNESS) * 1.5), StyleGetShadeColor(1))
			PaintRoundedRect(body, WIDGET_ROUNDNESS, GetColor(.foreground))
		}
		font := GetFontData(.monospace)

		data := SPrintF("%.2f", value)
		if .justFocused in state {
			delete(ctx.numberText)
			ctx.numberText = slice.clone(data)
		}
		change, newData := MutableTextFromBytes(font, ctx.numberText if .focused in state else data, control.body, {options = {.numeric}, capacity = 15}, control.state)
		outlineColor := BlendColors(GetColor(.outlineBase), GetColor(.accentHover), min(1, hoverTime + stateTime))
		PaintRoundedRectOutline(body, WIDGET_ROUNDNESS, .focused not_in state, outlineColor)
		if change {
			newValue, ok = strconv.parse_f32(string(newData))
			delete(ctx.numberText)
			ctx.numberText = slice.clone(newData)
		}
		PaintControlLabel(body, label, outlineColor, GetColor(.foreground))

		body.y -= 10
		body.h += 10
	}
	return
}

PaintControlLabel :: proc(rect: Rect, label: string, fillColor, backgroundColor: Color) {
	if len(label) > 0 {
		labelFont := GetFontData(.label)
		textSize := MeasureString(labelFont, label)
		PaintRect({rect.x + WIDGET_TEXT_OFFSET - 2, rect.y - 4, textSize.x + 4, 6}, backgroundColor)
		PaintString(GetFontData(.label), label, {rect.x + WIDGET_TEXT_OFFSET, rect.y - textSize.y / 2}, fillColor)
	}
}

/*
	The label type
*/
Label :: union {
	string,
	Icon,
}

PaintLabel :: proc(fontData: FontData, label: Label, origin: Vec2, color: Color, alignX, alignY: Alignment) {
	switch variant in label {
		case string: PaintStringAligned(fontData, variant, origin, color, alignX, alignY)
		case Icon: PaintGlyphAligned(GetGlyphData(fontData, rune(variant)), origin, color, alignX, alignY)
	}
}
MeasureLabel :: proc(fontData: FontData, label: Label) -> (size: Vec2) {
	switch variant in label {
		case string: size = MeasureString(fontData, variant)
		case Icon:
		glyph := GetGlyphData(fontData, rune(variant))
		size = {glyph.source.w, glyph.source.y}
	}
	return
}

/*
	Buttons for navigation
*/
NavOptionEx :: proc(active: bool, icon: Icon, text: string, loc := #caller_location) -> (result: bool) {
	if control, ok := BeginControl(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateControl(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(1), active, 0.15)
		PopId()

		PaintRoundedRect(body, WIDGET_ROUNDNESS, Fade(255, min(hoverTime + stateTime, 1) * 0.25))
		PaintIconAligned(GetFontData(.header), icon, {body.x + body.h / 2, body.y + body.h / 2}, GetColor(.foreground), .middle, .middle)
		PaintStringAligned(GetFontData(.default), text, {body.x + body.h * rl.EaseCubicInOut(stateTime, 1, 0.3, 1), body.y + body.h / 2}, GetColor(.foreground), .near, .middle)
		
		result = .released in state
	}
	return
}

ButtonStyle :: enum {
	normal,
	bright,
	subtle,
}
/*
	Rounded, standalone buttons for major actions
*/
PillButtonEx :: proc(label: Label, style: ButtonStyle, loc := #caller_location) -> (result: bool) {
	layout := GetCurrentLayout()
	if layout.side == .left || layout.side == .right {
		layout.size = MeasureLabel(GetFontData(.default), label).x + layout.rect.h + layout.margin * 2
	}
	if control, ok := BeginControl(HashId(loc), LayoutNext(layout)); ok {
		using control
		UpdateControl(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.2)
			if .released in state {
				GetAnimation(HashIdFromInt(1))^ = 1
			}
		PopId()

		roundness := body.h / 2

		if style != .subtle && pressTime > 0 {
			if .down in state {
				rect := ExpandRect(body, rl.EaseCubicOut(pressTime, 0, 5, 1))
				PaintRoundedRect(rect, rect.h / 2, StyleGetShadeColor(1))
			} else {
				rect := ExpandRect(body, 5)
				PaintRoundedRect(rect, rect.h / 2, StyleGetShadeColor(pressTime))
			}
		}
		if style == .subtle {
			PaintRoundedRect(body, roundness, GetColor(.foregroundPress) if .down in state else BlendColors(GetColor(.foreground), GetColor(.foregroundHover), hoverTime))
			if .down not_in state {
				PaintRoundedRectOutline(body, roundness, false, GetColor(.foregroundPress, pressTime))
			}
			PaintLabel(GetFontData(.default), label, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.outlineBase), .middle, .middle)
		} else if style == .normal {
			PaintRoundedRect(body, roundness, GetColor(.foreground))
			PaintRoundedRectOutline(body, roundness, false, BlendColors(GetColor(.outlineBase), GetColor(.accentHover), hoverTime))
			PaintLabel(GetFontData(.default), label, {body.x + body.w / 2, body.y + body.h / 2}, BlendColors(GetColor(.outlineBase), GetColor(.accentHover), hoverTime), .middle, .middle)
		} else {
			PaintRoundedRect(body, roundness, BlendColors(GetColor(.accent), GetColor(.accentHover), hoverTime))
			/*if .down not_in state {
				PaintRoundedRectOutline(body, roundness, false, GetColor(.accentPress, pressTime))
			}*/
			PaintLabel(GetFontData(.default), label, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.foreground), .middle, .middle)
		}
		
		result = .released in state
	}
	return
}
PillButton :: proc(label: Label, loc := #caller_location) -> bool {
	return PillButtonEx(label, .normal, loc)
}


/*
	Regular buttons for secondary actions

	Can be grouped and attached to other controls
*/
ButtonEx :: proc(label: Label, corners: RectCorners, loc := #caller_location) -> (result: bool) {
	layout := GetCurrentLayout()
	if layout.side == .left || layout.side == .right {
		layout.size = MeasureLabel(GetFontData(.default), label).x + layout.rect.h / 2 + layout.margin * 2
	}
	if control, ok := BeginControl(HashId(loc), UseNextRect() or_else LayoutNext(layout)); ok {
		using control
		UpdateControl(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.2)
			if .released in state {
				GetAnimation(HashIdFromInt(1))^ = 1
			}
		PopId()

		/*if pressTime > 0 {
			if .down in state {
				rect := ExpandRect(body, rl.EaseCubicOut(pressTime, 0, 5, 1))
				PaintRoundedRectEx(rect, WIDGET_ROUNDNESS * 1.5, corners, StyleGetShadeColor(1))
			} else {
				rect := ExpandRect(body, 5)
				PaintRoundedRectEx(rect, WIDGET_ROUNDNESS * 1.5, corners, StyleGetShadeColor(pressTime))
			}
		}*/
		PaintRoundedRectEx(body, WIDGET_ROUNDNESS, corners, GetColor(.widgetPress) if .down in state else BlendColors(GetColor(.widgetBase), GetColor(.widgetHover), hoverTime))
		if .down not_in state {
			PaintRoundedRectOutlineEx(body, WIDGET_ROUNDNESS, false, corners, GetColor(.widgetPress, pressTime))
		}

		_, isIcon := label.(Icon)
		PaintLabel(GetFontData(.header if isIcon else .default), label, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.text), .middle, .middle)

		result = .released in state
	}
	return
}
Button :: proc(label: Label, loc := #caller_location) -> bool {
	return ButtonEx(label, ALL_CORNERS, loc)
}

/*
	Toggle buttons
*/
ToggleButtonEx :: proc(value: bool, label: Label, corners: RectCorners, loc := #caller_location) -> (newValue: bool) {
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
		
		_, isIcon := label.(Icon)
		PaintLabel(GetFontData(.header if isIcon else .default), label, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.text if value else .outlineBase), .middle, .middle)
	}
	return
}
ToggleButton :: proc(value: bool, label: Label, loc := #caller_location) -> bool {
	return ToggleButtonEx(value, label, ALL_CORNERS, loc)
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
	if ButtonEx(Icon.remove, {.topLeft, .bottomLeft}, loc) {
		newValue = max(low, value - 1)
	}
	loc.column += 1
	SetNextRect(rightButtonRect)
	if ButtonEx(Icon.add, {.topRight, .bottomRight}, loc) {
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
			PaintStringAligned(font, numberText, center, GetColor(.text), .middle, .middle)

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
			PaintRoundedRect(body, 5, GetColor(.foreground))
			PaintRoundedRectOutline(body, 5, false, GetColor(.outlineBase, 1))
		}
		if stateTime > 0 {
			PaintRoundedRect(body, 5, GetColor(.widgetBase if ctx.disabled else .accent, stateTime))
			PaintIconAligned(GetFontData(.header), .remove if status == .unknown else .check, center, GetColor(.foreground, 1), .middle, .middle)
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
CheckBox :: proc(value: bool, text: string, loc := #caller_location) -> bool {
	if change, newValue := CheckBoxEx(.on if value else .off, text, loc); change {
		return newValue
	}
	return value
}
CheckBoxBitSet :: proc(set: ^$S/bit_set[$E;$U], bit: E, text: string, loc := #caller_location) -> bool {
	if set == nil {
		return false
	}
	if change, _ := CheckBoxEx(.on if bit in set else .off, text, loc); change {
		set^ = set^ ~ {bit}
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
				PaintRoundedRect(baseRect, baseRadius, GetColor(.foreground))
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
		PaintCircle(thumbCenter, 17, GetColor(.foreground))
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
		PaintCircle(center, outerRadius - 2, GetColor(.foreground))
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
			if RadioButtonEx(member == value, CapitalizeString(Format(member)), side) {
				newValue = member
			}
		PopId()
	}
	return
}

/*
	Combo box
*/
@(deferred_out=_Menu)
Menu :: proc(text: string menuSize: f32, loc := #caller_location) -> (layer: ^LayerData, active: bool) {
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
		fill := BlendThreeColors(GetColor(.widgetBase), GetColor(.widgetHover), GetColor(.widgetPress), hoverTime + pressTime)
		PaintRoundedRectEx(body, WIDGET_ROUNDNESS, corners, fill)
		PaintRoundedRectOutlineEx(body, WIDGET_ROUNDNESS, true, corners, GetColor(.outlineBase, stateTime))
		PaintCollapseArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, -1 + stateTime, GetColor(.text))
		PaintStringAligned(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text), .near, .middle)

		if .pressed in state {
			bits = bits ~ {.active}
		}

		if active {
			layer, ok = BeginLayer(AttachRectBottom(body, menuSize), {}, sharedId, {.outlined})
			layer.order = .popup
			layer.opacity = stateTime

			if (.hovered not_in state && ctx.hoveredLayer != layer.id && MousePressed(.left)) {
				bits -= {.active}
			}

			if .submit in layer.bits {
				bits -= {.active}
				EndLayer(layer)
				return nil, false
			}

			//PaintRoundedRectEx(layer.body, WIDGET_ROUNDNESS, {.bottomLeft, .bottomRight}, GetColor(.widgetBase, 1))
			PaintRect(layer.body, GetColor(.widgetBase))

			PushLayout(layer.body)
		}
	}
	return 
}
@private _Menu :: proc(layer: ^LayerData, active: bool) {
	if active {
		//PaintRoundedRectOutlineEx(layer.body, WIDGET_ROUNDNESS, true, {.bottomLeft, .bottomRight}, GetColor(.outlineBase))
		UpdateLayerContentRect(ctx.layerStack[ctx.layerDepth - 2], layer.body)
		PaintRectLines(layer.body, 1, GetColor(.outlineBase))
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
		PaintStringAligned(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text, 1), .near, .middle)

		result = .released in state
	}
	return result
}
EnumMenu :: proc(value: $T, optionSize: f32, loc := #caller_location) -> (newValue: T) {
	newValue = value
	if layer, active := Menu(CapitalizeString(Format(value)), optionSize * len(T), loc); active {
		SetSize(optionSize)
		for member in T {
			PushId(HashIdFromInt(int(member)))
				if MenuOption(CapitalizeString(Format(member)), false) {
					newValue = member
				}
			PopId()
		}
	}
	if ctx.hoverId == ctx.controls[ctx.lastControl].id {
		newValue = cast(T)clamp(int(newValue) - int(input.mouseScroll.y), 0, len(T) - 1)
	}
	return
}
BitSetMenu :: proc(set: $S/bit_set[$E;$U], optionSize: f32, loc := #caller_location) -> (newSet: S) {
	newSet = set
	
	if layer, active := Menu(FormatBitSet(set, ", "), optionSize * len(E), loc); active {
		SetSize(optionSize)
		for member in E {
			PushId(HashIdFromInt(int(member)))
				if MenuOption(CapitalizeString(Format(member)), member in set) {
					newSet = newSet ~ {member}
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
		PaintStringAligned(GetFontData(.default), label, {body.x + body.h * 0.25, body.y + body.h / 2}, GetColor(.text), .near, .middle)

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
	Litterally just a line
*/
Divider :: proc(size: f32) {
	layout := GetCurrentLayout()
	rect := CutRect(&layout.rect, layout.side, size)
	if layout.side == .left || layout.side == .right {
		PaintRect({rect.x + rect.w / 2, rect.y, 1, rect.h}, GetColor(.foregroundHover))
	} else {
		PaintRect({rect.x, rect.y + rect.h / 2, rect.w, 1}, GetColor(.foregroundHover))
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

		control.options += {.draggable}
		UpdateControl(control)
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			pressTime := AnimateBool(HashId(int(1)), .down in state, 0.1)
		PopId()

		time := 0.5 + hoverTime * 0.5

		rect: Rect = {body.x, body.y, body.w, body.h * time}
		thumbRect: Rect = {rect.x + range * clamp((value - low) / valueRange, 0, 1), rect.y, thumbSize, rect.h}
		PaintRoundedRect(rect, math.floor(rect.h / 2), GetColor(.foreground))
		PaintRoundedRect(thumbRect, math.floor(rect.h / 2), BlendColors(GetColor(.widgetHover), GetColor(.widgetPress), hoverTime))

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

		control.options += {.draggable}
		UpdateControl(control)
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			pressTime := AnimateBool(HashId(int(1)), .down in state, 0.1)
		PopId()

		time := 0.5 + hoverTime * 0.5

		rect: Rect = {body.x + body.w * (1 - time), body.y, body.w * time, body.h}
		thumbRect: Rect = {rect.x, rect.y + range * clamp((value - low) / valueRange, 0, 1), rect.w, thumbSize}
		PaintRoundedRect(rect, math.floor(rect.w / 2), GetColor(.foreground))
		PaintRoundedRect(thumbRect, math.floor(rect.w / 2), BlendColors(GetColor(.widgetHover), GetColor(.widgetPress), hoverTime))

		if .down in state {
			normal := clamp((input.mousePoint.y - (body.y + thumbSize / 2)) / range, 0, 1)
			newValue = low + (high - low) * normal
			change = true
		}
	}
	return
}


/*
	Tabs
*/
Tab :: proc(active: bool, label: string, loc := #caller_location) -> (result: bool) {
	if control, ok := BeginControl(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control

		UpdateControl(control)

		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), active, 0.15)
		PopId()

		PaintRect(body, GetColor(.foreground if active else .foregroundHover))
		center: Vec2 = {body.x + body.w / 2, body.y + body.h / 2}
		textSize := PaintStringAligned(GetFontData(.default), label, center, BlendColors(GetColor(.text), GetColor(.textBright), hoverTime + stateTime), .middle, .middle)
		size := textSize.x
		size *= stateTime
		if stateTime > 0 {
			PaintRect({center.x - size / 2, body.y + body.h - 4, size, 4}, GetColor(.accent, stateTime))
		}

		result = .pressed in state
	}
	return
}
EnumTabs :: proc(value: $T, loc := #caller_location) -> (newValue: T) { 
	newValue = value
	rect := LayoutNext(GetCurrentLayout())
	if layout, ok := LayoutEx(rect); ok {
		layout.size = layout.rect.w / f32(len(T)); layout.side = .left
		for member in T {
			PushId(HashId(int(member)))
				if Tab(member == value, CapitalizeString(Format(member)), loc) {
					newValue = member
				}
			PopId()
		}
	}
	return
}

/*
	Plain text
*/
Text :: proc(font: FontIndex, text: string, fit: bool) {
	fontData := GetFontData(font)
	layout := GetCurrentLayout()
	textSize := MeasureString(fontData, text)
	if fit {
		LayoutFitControl(layout, textSize)
	}
	rect := LayoutNextEx(layout, textSize)
	if CheckClip(ctx.clipRect, rect) != .none || true {
		PaintString(fontData, text, {rect.x, rect.y}, GetColor(.text))
	}
	UpdateLayerContentRect(GetCurrentLayer(), rect)
}
TextBox :: proc(font: FontIndex, text: string, options: StringPaintOptions) {
	fontData := GetFontData(font)
	rect := LayoutNext(GetCurrentLayout())
	PaintStringContained(fontData, text, rect, options, GetColor(.text))
}

GlyphIcon :: proc(font: FontIndex, icon: Icon) {
	fontData := GetFontData(font)
	rect := LayoutNext(GetCurrentLayout())
	PaintGlyphAligned(GetGlyphData(fontData, rune(icon)), {rect.x + rect.w / 2, rect.y + rect.h / 2}, GetColor(.text), .middle, .middle)
}

/*
	Progress bar
*/
ProgressBar :: proc(value: f32) {
	rect := LayoutNext(GetCurrentLayout())
	radius := rect.h / 2
	PaintRoundedRect(rect, radius, GetColor(.backing))
	PaintRoundedRect({rect.x, rect.y, rect.w * clamp(value, 0, 1), rect.h}, radius, GetColor(.accent))
}
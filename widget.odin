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
WidgetBit :: enum {
	stayAlive,
	active,
	menuOpen,
	disabled,
	visible,
}
WidgetBits :: bit_set[WidgetBit]
// Behavior options
WidgetOption :: enum {
	holdFocus,
	draggable,
	keySelect,
	noClick,
}
WidgetOptions :: bit_set[WidgetOption]
// User input state
WidgetStatus :: enum {
	hovered,
	justFocused,
	focused,
	justUnfocused,
	pressed,
	down,
	released,
	doubleClicked,
	changed,
}
WidgetState :: bit_set[WidgetStatus]
// Universal control data
Widget :: struct {
	id: 		Id,
	body: 		Rect,
	bits: 		WidgetBits,
	options: 	WidgetOptions,
	state: 		WidgetState,
	// Parent layer
	parent: 	Id,
}

// WidgetButton :: struct {
// 	using widget: Widget,
// 	howHovered,
// 	howFocused: f32,
// }
// WidgetNumberEdit :: struct {
// 	using widget: Widget,
// 	howHovered,
// 	howFocused: f32,
// 	buffer: [dynamic]u8,
// }
// WidgetCheckBox :: struct {
// 	using widget: Widget,
// }

// WidgetVariant :: union {
// 	WidgetButton,
// 	WidgetNumberEdit,
// }

@(deferred_out=EndWidget)
BeginWidget :: proc(id: Id, rect: Rect) -> (widget: ^Widget, ok: bool) {
	using ctx

	layer := CurrentLayer()
	index, found := layer.contents[id]
	if found {
		widget = &controls[index]
		ok = true
	} else {
		for i in 0 ..< MAX_CONTROLS {
			if !controlExists[i] {
				controls[i] = {
					parent = layer.id,
					id = id,
				}
				index = i
				layer.contents[id] = index
				widget = &controls[i]
				break
			}
		}
		ok = true
	}

	if ok {
		controlExists[index] = true
		widget.body = rect
		widget.state = {}
		widget.bits += {.stayAlive}
		if widget.id == ctx.focusId {
			ctx.focusIndex = index
		}
		ctx.lastWidget = index
		if ctx.disabled {
			widget.bits += {.disabled}
		} else {
			widget.bits -= {.disabled}
		}
		if CheckClip(ctx.clipRect, widget.body) != .full {
			widget.bits += {.visible}
		} else {
			widget.bits -= {.visible}
		}
	}

	return
}
EndWidget :: proc(widget: ^Widget, ok: bool) {
	if ok {
		if ctx.disabled {
			PaintDisableShade(widget.body)
		}

		layer := CurrentLayer()
		UpdateLayerContentRect(layer, widget.body)

		if ctx.groupDepth > 0 {
			ctx.groups[ctx.groupDepth - 1].state += widget.state
		}

		if ctx.attachTooltip {
			ctx.attachTooltip = false
			if widget.state >= {.hovered} {
				fontData := GetFontData(.label)
				textSize := MeasureString(fontData, ctx.tooltipText)
				PADDING_X :: 4
				PADDING_Y :: 2
				rect: Rect = {0, 0, textSize.x + PADDING_X * 2, textSize.y + PADDING_Y * 2}
				OFFSET :: 10
				switch ctx.tooltipSide {
					case .bottom:		
					rect.x = widget.body.x + widget.body.w / 2 - rect.w / 2
					rect.y = widget.body.y + widget.body.h + OFFSET
					case .left:
					rect.x = widget.body.x - rect.w - OFFSET
					rect.y = widget.body.y + widget.body.h / 2 - rect.h / 2
					case .right:
					rect.x = widget.body.x + widget.body.w - OFFSET
					rect.y = widget.body.y + widget.body.h / 2 - rect.h / 2
					case .top:
					rect.x = widget.body.x + widget.body.w / 2 - rect.w / 2
					rect.y = widget.body.y - rect.h - OFFSET
				}
				if layer, ok := BeginLayer(rect, {}, widget.id, {.invisible}); ok {
					layer.order = .tooltip
					layer.opacity += (1 - layer.opacity) * 10 * ctx.deltaTime
					PaintRect(layer.body, GetColor(.text))
					PaintString(fontData, ctx.tooltipText, {layer.body.x + PADDING_X, layer.body.y + PADDING_Y}, GetColor(.foreground))
					EndLayer(layer)
				}
			}
		}
	}
}
UpdateWidget :: proc(using widget: ^Widget) {
	if !ctx.disabled {
		// Request hover status
		if VecVsRect(input.mousePoint, body) && ctx.hoveredLayer == parent {
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
				ctx.dragging = true
			} else  {
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
			if MouseReleased(.left) || (ctx.keySelect && KeyReleased(.enter)) {
				state += {.released}
				ctx.pressId = 0
				CurrentLayer().bits += {.submit}
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
	}
	return
}

AttachTooltip :: proc(text: string, side: RectSide) {
	ctx.attachTooltip = true
	ctx.tooltipText = text
	ctx.tooltipSide = side
}

PaintDisableShade :: proc(rect: Rect) {
	PaintRect(rect, GetColor(.foreground, 0.5))
}

// Labels
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
	if self, ok := BeginWidget(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		UpdateWidget(self)

		PushId(self.id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in self.state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(1), active, 0.15)
		PopId()

		PaintRect(self.body, Fade(255, min(hoverTime + stateTime, 1) * 0.25))
		PaintIconAligned(GetFontData(.header), icon, {self.body.x + self.body.h / 2, self.body.y + self.body.h / 2}, GetColor(.foreground), .middle, .middle)
		PaintStringAligned(GetFontData(.default), text, {self.body.x + self.body.h * rl.EaseCubicInOut(stateTime, 1, 0.3, 1), self.body.y + self.body.h / 2}, GetColor(.foreground), .near, .middle)
		
		result = .released in self.state
	}
	return
}

/*
	Spinner compound widget
*/
Spinner :: proc(value, low, high: int, loc := #caller_location) -> (newValue: int) {
	loc := loc
	newValue = value
	// Sub-widget rectangles
	rect := LayoutNext(GetCurrentLayout())
	leftButtonRect := CutRectLeft(&rect, 30)
	rightButtonRect := CutRectRight(&rect, 30)
	// Number input
	SetNextRect(rect)
	newValue = clamp(NumberInputEx(value, {}, "%i", {.align_center}).(int), low, high)
	// Step buttons
	loc.column += 1
	SetNextRect(leftButtonRect)
	if ButtonEx(Icon.remove, .middle, false, loc) {
		newValue = max(low, value - 1)
	}
	loc.column += 1
	SetNextRect(rightButtonRect)
	if ButtonEx(Icon.add, .middle, false, loc) {
		newValue = min(high, value + 1)
	}
	return
}

// Value slider
SliderEx :: proc(value, low, high: f32, name: string, loc := #caller_location) -> (change: bool, newValue: f32) {
	SIZE :: 16
	HEIGHT :: SIZE / 2
	HALF_HEIGHT :: HEIGHT / 2
	rect := LayoutNext(GetCurrentLayout())
	rect = ChildRect(rect, {rect.w, SIZE}, .near, .middle)
	if self, ok := BeginWidget(HashId(loc), rect); ok {
		self.options += {.draggable}
		UpdateWidget(self)

		PushId(self.id) 
			hoverTime := AnimateBool(HashIdFromInt(0), self.state & {.hovered, .down} != {}, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in self.state, 0.1)
		PopId()

		barRect: Rect = {self.body.x, self.body.y + HALF_HEIGHT, self.body.w, self.body.h - HEIGHT}
		if value < high {
			PaintRoundedRect(barRect, HALF_HEIGHT, GetColor(.backing))
		}

		range := self.body.w - HEIGHT
		offset := range * clamp((value - low) / high, 0, 1)
		fillColor := BlendColors(GetColor(.widgetBase), GetColor(.accent), hoverTime)
		PaintRoundedRect({barRect.x, barRect.y, offset, barRect.h}, HALF_HEIGHT, fillColor)

		thumbCenter: Vec2 = {self.body.x + HALF_HEIGHT + offset, self.body.y + self.body.h / 2}
		// TODO: Constants for these
		thumbRadius := self.body.h
		if hoverTime > 0 {
			PaintCircle(thumbCenter, thumbRadius + 10 * (pressTime + hoverTime), StyleGetShadeColor(1))
		}
		PaintCircle(thumbCenter, thumbRadius, fillColor)

		if .down in self.state {
			change = true
			newValue = clamp(low + ((input.mousePoint.x - self.body.x - HALF_HEIGHT) / range) * (high - low), low, high)
		}
	}
	return
}

/*
	Spinner slider
*/
DragSpinner :: proc(value, low, high: int, loc := #caller_location) -> (newValue: int) {
	newValue = value
	if self, ok := BeginWidget(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		self.options += {.draggable}
		UpdateWidget(self)

		PushId(self.id) 
			hoverTime := AnimateBool(HashIdFromInt(0), self.state & {.hovered, .down} != {}, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in self.state, 0.1)
		PopId()

		fontData := GetFontData(.monospace)
		if .active not_in self.bits {
			PaintRect(self.body, GetColor(.widgetBase))
		}
		PaintRectLines(self.body, 2 if .active in self.bits else 1, GetColor(.accent) if .active in self.bits else GetColor(.outlineBase, hoverTime))
		text := FormatSlice(value)
		if .doubleClicked in self.state {
			self.bits = self.bits ~ {.active}
			self.state += {.justFocused}
		}
		if .active in self.bits {
			if self.state & {.down, .hovered} != {} {
				ctx.cursor = .beam
			}
			TextPro(fontData, ctx.tempBuffer[:], self.body, {.align_center}, self.state)
			if .justFocused in self.state {
				resize(&ctx.tempBuffer, len(text))
				copy(ctx.tempBuffer[:], text[:])
			}
			if .focused in self.state {
				if TextEdit(&ctx.tempBuffer, {.numeric, .integer}) {
					if parsedValue, ok := strconv.parse_int(string(ctx.tempBuffer[:])); ok {
						newValue = parsedValue
					}
					ctx.renderTime = RENDER_TIMEOUT
				}
			}
		} else {
			center: Vec2 = {self.body.x + self.body.w / 2, self.body.y + self.body.h / 2}
			PaintStringAligned(fontData, string(text), center, GetColor(.text), .middle, .middle)
			if .down in self.state {
				newValue = value + int(input.mousePoint.x - input.prevMousePoint.x) + int(input.mousePoint.y - input.prevMousePoint.y)
			}
			if .hovered in self.state {
				ctx.cursor = .resizeEW
			}
		}

		if .focused not_in self.state {
			self.bits -= {.active}
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
	if control, ok := BeginWidget(HashId(loc), LayoutNextEx(GetCurrentLayout(), SIZE)); ok {
		using control
		
		box := body

		active := (status == .on || status == .unknown)
		textSize: Vec2
		if len(text) > 0 {
			textSize = MeasureString(GetFontData(.default), text)
			body.w += textSize.x + WIDGET_TEXT_OFFSET * 2
		}
		UpdateWidget(control)

		if .visible in bits {
			PushId(id) 
				hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
				pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.15)
				stateTime := AnimateBool(HashIdFromInt(2), active, 0.1)
			PopId()

			center: Vec2 = {body.x + HALF_SIZE, body.y + HALF_SIZE}

			PaintRect(body, GetColor(.foreground))
			if hoverTime > 0 {
				PaintRect(body, StyleGetShadeColor(hoverTime))
			}

			if stateTime < 1 {
				PaintRectLines(box, 2 + 2 * (pressTime if !active else 1), BlendColors(GetColor(.outlineBase), GetColor(.outlineHot), hoverTime))
			}
			if stateTime > 0 {
				PaintRect(box, Fade(BlendColors(GetColor(.outlineBase), GetColor(.outlineHot), hoverTime), stateTime))
			}
			if active {
				PaintIconAligned(GetFontData(.header), .remove if status == .unknown else .check, center, GetColor(.foreground), .middle, .middle)
			} else if stateTime == 1 {
				PaintIconAligned(GetFontData(.header), .remove if status == .unknown else .check, center, GetColor(.foreground, stateTime), .middle, .middle)
			}
			PaintString(GetFontData(.default), text, {box.x + box.w + WIDGET_TEXT_OFFSET, center.y - textSize.y / 2}, GetColor(.text))
		}
		// Result
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
	if control, ok := BeginWidget(HashId(loc), LayoutNextEx(GetCurrentLayout(), {36, 28})); ok {
		using control
		UpdateWidget(control)

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

		strokeColor := GetColor(.widgetBase if ctx.disabled else .outlineBase)
		if howOn < 1 {
			if !ctx.disabled {
				PaintRoundedRect(baseRect, baseRadius, GetColor(.foreground))
			}
			PaintRoundedRectOutline(baseRect, baseRadius, false, strokeColor)
		}
		if howOn > 0 {
			if howOn < 1 {
				PaintRoundedRect({baseRect.x, baseRect.y, thumbCenter.x - baseRect.x, baseRect.h}, baseRadius, GetColor(.widgetBase if ctx.disabled else .outlineBase))
			} else {
				PaintRoundedRect(baseRect, baseRadius, GetColor(.widgetBase if ctx.disabled else .outlineBase))
			}
		}
		if hoverTime > 0 {
			PaintCircle(thumbCenter, 32, StyleGetShadeColor(hoverTime))
		}
		if pressTime > 0 {
			if .down in state {
				PaintCircle(thumbCenter, 21 + 11 * pressTime, StyleGetShadeColor())
			} else {
				PaintCircle(thumbCenter, 32, StyleGetShadeColor(pressTime))
			}
		}
		PaintCircle(thumbCenter, 18, GetColor(.foreground))
		PaintCircleOutline(thumbCenter, 21, false, strokeColor)
		
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
	HALF_SIZE :: SIZE / 2

	textSize := MeasureString(GetFontData(.default), name)
	size: Vec2
	if textSide == .bottom || textSide == .top {
		size.x = max(SIZE, textSize.x)
		size.y = SIZE + textSize.y
	} else {
		size.x = SIZE + textSize.x + WIDGET_TEXT_OFFSET * 2
		size.y = SIZE
	}

	if control, ok := BeginWidget(HashId(loc), LayoutNextEx(GetCurrentLayout(), size)); ok {
		using control
		UpdateWidget(control)

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
		if hoverTime > 0 {
			PaintRoundedRect(body, HALF_SIZE, StyleGetShadeColor(hoverTime))
		}
		PaintRing(center, HALF_SIZE - rl.EaseQuadOut(stateTime, 2 + 3 * pressTime, 5, 1), HALF_SIZE, 16, BlendColors(GetColor(.outlineBase), GetColor(.outlineHot), hoverTime))

		// Text
		switch textSide {
			case .left: PaintString(GetFontData(.default), name, {body.x + SIZE + WIDGET_TEXT_OFFSET, center.y - textSize.y / 2}, GetColor(.text, 1))
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
@(deferred_out=_Collapser)
Collapser :: proc(text: string, size: f32, loc := #caller_location) -> (active: bool) {
	sharedId := HashId(loc)
	if control, ok := BeginWidget(sharedId, UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateWidget(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), .active in bits, 0.15)
		PopId()

		fill := BlendThreeColors(GetColor(.widgetBase), GetColor(.widgetHover), GetColor(.widgetPress), hoverTime + pressTime)
		PaintRect(body, fill)
		PaintRectLines(body, 1, GetColor(.outlineBase))
		PaintCollapseArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, -1 + stateTime, GetColor(.text))
		PaintStringAligned(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text), .near, .middle)

		if .pressed in state {
			bits = bits ~ {.active}
		}

		if stateTime > 0 {
			rect := Cut(.top, size * stateTime)
			layer: ^LayerData
			layer, active = BeginLayer(rect, {0, size}, id, {.attached, .noScrollMarginX, .noScrollY})
		}
	}
	return 
}
@private _Collapser :: proc(active: bool) {
	if active {
		layer := CurrentLayer()
		//PaintRectLines(layer.body, 1, GetColor(.foregroundPress))
		EndLayer(layer)
	}
}

/*
	Combo box
*/
@(deferred_out=_Menu)
Menu :: proc(text: string, menuSize: f32, loc := #caller_location) -> (active: bool) {
	sharedId := HashId(loc)
	if control, ok := BeginWidget(sharedId, UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateWidget(control)
		active = .active in bits

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), active, 0.125)
		PopId()

		fill := BlendThreeColors(GetColor(.widgetBase), GetColor(.widgetHover), GetColor(.widgetPress), hoverTime + pressTime)
		PaintRect(body, fill)
		PaintRectLines(body, 1, GetColor(.outlineBase))
		PaintCollapseArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, -1 + stateTime, GetColor(.text))
		PaintStringAligned(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text), .near, .middle)

		if .pressed in state {
			bits = bits ~ {.active}
		}

		if active {
			layer: ^LayerData
			layer, ok = BeginLayer(AttachRectBottom(body, menuSize), {}, sharedId, {.attached})

			if ok {
				layer.opacity = stateTime

				if layer.bits & {.submit, .dismissed} != {} {
					bits -= {.active}
					EndLayer(layer)
					return false
				}

				PaintRect(layer.body, GetColor(.widgetBase))
			}
		}
	}
	return 
}
@private _Menu :: proc(active: bool) {
	if active {
		layer := CurrentLayer()

		if (.hovered not_in layer.bits && MousePressed(.left)) || KeyPressed(.escape) {
			layer.bits += {.dismissed}
		}

		PaintRectLines(layer.body, 1, GetColor(.outlineBase))
		EndLayer(layer)
	}
}
// Can be used for auto-complete on a text input
@(deferred_out=_AttachMenu)
AttachMenu :: proc(menuSize: f32, size: Vec2 = {}, options: LayerOptions = {}) -> (ok: bool) {
	if control := GetLastWidget(); control != nil {
		if control.bits >= {.menuOpen} {
			layer: ^LayerData
			layer, ok = BeginLayer(AttachRectBottom(control.body, menuSize), size, control.id, options + {.attached})
			if ok {
				PaintRect(layer.body, GetColor(.widgetBase))
			}

			if ctx.focusId != ctx.prevFocusId && ctx.focusId != control.id && ctx.focusId not_in layer.contents {
				control.bits -= {.menuOpen}
			}
		} else if control.state >= {.justFocused} {
			control.bits += {.menuOpen}
		}
	}
	return 
}
@private 
_AttachMenu :: proc(ok: bool) {
	if ok {
		layer := CurrentLayer()
		PaintRectLines(layer.body, 1, GetColor(.outlineBase))
		EndLayer(layer)
	}
}
// Options within menus
@(deferred_out=_SubMenu)
SubMenu :: proc(text: string, size: Vec2, loc := #caller_location) -> (active: bool) {
	sharedId := HashId(loc)
	if control, yes := BeginWidget(sharedId, UseNextRect() or_else LayoutNext(GetCurrentLayout())); yes {
		using control
		UpdateWidget(control)
		active = .active in bits

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), active, 0.125)
		PopId()

		fill := BlendThreeColors(GetColor(.widgetBase), GetColor(.widgetHover), GetColor(.widgetPress), hoverTime + pressTime)
		PaintRect(body, fill)
		PaintFlipArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, stateTime, GetColor(.text))
		PaintStringAligned(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text), .near, .middle)

		if .pressed in state {
			bits = bits ~ {.active}
		}

		if active {
			layer, ok := BeginLayer({body.x + body.w, body.y, size.x, size.y}, {}, sharedId, {.attached})

			if ok {
				layer.opacity = stateTime

				if layer.bits & {.submit, .dismissed} != {} {
					bits -= {.active}
					EndLayer(layer)
					return false
				}

				PaintRect(layer.body, GetColor(.widgetBase))
			}
		}
	}
	return
}
@private
_SubMenu :: proc(active: bool) {
	if active {
		layer := CurrentLayer()

		if (.hovered not_in layer.bits && MousePressed(.left)) || KeyPressed(.escape) {
			layer.bits += {.dismissed}
		}

		PaintRectLines(layer.body, 1, GetColor(.outlineBase))
		EndLayer(layer)
	}
}
MenuOption :: proc(text: string, active: bool, loc := #caller_location) -> (result: bool) {
	if control, ok := BeginWidget(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateWidget(control)

		PushId(id)
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
		PopId()

		PaintRect(body, GetColor(.widgetHover) if active else BlendThreeColors(GetColor(.widgetBase), GetColor(.widgetHover), GetColor(.widgetPress), hoverTime + pressTime))
		PaintStringAligned(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text, 1), .near, .middle)

		if .focused in state {
			if KeyPressed(.down) || KeyPressed(.up) {
				d := -1 if KeyPressed(.up) else 1
				array: [dynamic]int
				defer delete(array)
				m: int
				for i in 0..<MAX_CONTROLS {
					if ctx.controlExists[i] && ctx.controls[i].parent == CurrentLayer().id {
						if i == int(ctx.lastWidget) {
							m = len(array)
						}
						append(&array, i)
					}
				}
				slice.sort_by(array[:], proc(i, j: int) -> bool {
					return ctx.controls[i].body.y < ctx.controls[j].body.y
				})
				i: int
				for x in 0..<len(array) {
					i += d
					if i < 0 {
						i = len(array) - 1
					} else if i == len(array) {
						i = 0
					}
					if (m - i < 0) == (d < 0) {
						ctx.focusId = ctx.controls[i].id
					}
				}
			}
		}

		result = .released in state
	}
	return result
}
EnumMenu :: proc(value: $T, optionSize: f32, loc := #caller_location) -> (newValue: T) {
	newValue = value
	if Menu(CapitalizeString(Format(value)), optionSize * len(T), loc) {
		SetSize(optionSize)
		for member in T {
			PushId(HashIdFromInt(int(member)))
				if MenuOption(CapitalizeString(Format(member)), false) {
					newValue = member
				}
			PopId()
		}
	}
	return
}
BitSetMenu :: proc(set: $S/bit_set[$E;$U], optionSize: f32, loc := #caller_location) -> (newSet: S) {
	newSet = set
	
	if Menu(FormatBitSet(set, ", "), optionSize * len(E), loc) {
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
@(deferred_out=_Card)
Card :: proc(label: string, sides: RectSides, loc := #caller_location) -> (clicked, yes: bool) {
	if control, ok := BeginWidget(HashId(loc), LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateWidget(control)

		PushId(id)
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.1)
		PopId()

		corners := SideCorners(sides)
		if hoverTime > 0 {
			PaintRect(body, StyleGetShadeColor((hoverTime + pressTime) * 0.75))
		}
		PaintRectLines(body, 1, GetColor(.outlineBase))
		PaintStringAligned(GetFontData(.default), label, {body.x + body.h * 0.25, body.y + body.h / 2}, GetColor(.text), .near, .middle)

		PushLayout(body)

		clicked = .released in state
		yes = true
	}
	return
}
@private _Card :: proc(clicked, yes: bool) {
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
		PaintRect({rect.x + rect.w / 2, rect.y, 1, rect.h}, GetColor(.foregroundPress))
	} else {
		PaintRect({rect.x, rect.y + rect.h / 2, rect.w, 1}, GetColor(.foregroundPress))
	}
}

/*
	Sections
*/
@(deferred_out=_Section)
Section :: proc(label: string, sides: RectSides) -> (ok: bool) {
	rect := LayoutNext(GetCurrentLayout())

	PaintRectLines(rect, 1, GetColor(.outlineBase))
	if len(label) != 0 {
		font := GetFontData(.default)
		textSize := MeasureString(font, label)
		PaintRect({rect.x + WIDGET_TEXT_OFFSET - 2, rect.y, textSize.x + 4, 1}, GetColor(.foreground))
		PaintString(GetFontData(.default), label, {rect.x + WIDGET_TEXT_OFFSET, rect.y - textSize.y / 2}, GetColor(.text))
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
ScrollBar :: proc(value, low, high, thumbSize: f32, vertical: bool, loc := #caller_location) -> (change: bool, newValue: f32) {
	newValue = value
	if control, ok := BeginWidget(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		i := int(vertical)
		rect := transmute([4]f32)body

		range := rect[2 + i] - thumbSize
		valueRange := (high - low) if high > low else 1

		control.options += {.draggable}
		UpdateWidget(control)
		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			pressTime := AnimateBool(HashId(int(1)), .down in state, 0.1)
		PopId()

		time := 0.5 + hoverTime * 0.5

		breadth := rect[3 - i] * time
		rect[1 - i] += rect[3 - i] - breadth
		rect[3 - i] = breadth

		thumbRect := rect
		thumbRect[i] += range * clamp((value - low) / valueRange, 0, 1)
		thumbRect[2 + i] = thumbSize

		PaintRoundedRect(transmute(Rect)rect, math.floor(rect[3 - i] / 2), GetColor(.foreground))
		PaintRoundedRect(transmute(Rect)thumbRect, math.floor(rect[3 - i] / 2), BlendColors(GetColor(.widgetHover), GetColor(.widgetPress), hoverTime))

		if .pressed in state {
			if VecVsRect(input.mousePoint, transmute(Rect)thumbRect) {
				ctx.dragAnchor = input.mousePoint - Vec2({thumbRect.x, thumbRect.y})
				bits += {.active}
			} else {
				normal := clamp((input.mousePoint[i] - rect[i]) / range, 0, 1)
				newValue = low + (high - low) * normal
			}
		} else if bits >= {.active} {
			normal := clamp(((input.mousePoint[i] - ctx.dragAnchor[i]) - rect[i]) / range, 0, 1)
			newValue = low + (high - low) * normal
			change = true
		}
		if .down not_in state {
			bits -= {.active}
		}
	}
	return
}

/*
	Tabs
*/
Tab :: proc(active: bool, label: string, loc := #caller_location) -> (result: bool) {
	if control, ok := BeginWidget(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateWidget(control)

		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), active, 0.15)
		PopId()

		PaintRect(body, GetColor(.foreground if active else .foregroundHover))
		center: Vec2 = {body.x + body.w / 2, body.y + body.h / 2}
		textSize := PaintStringAligned(GetFontData(.default), label, center, GetColor(.text), .middle, .middle)
		size := textSize.x
		size *= stateTime
		if stateTime > 0 {
			PaintRect({center.x - size / 2, body.y + body.h - 4, size, 4}, GetColor(.accent, stateTime))
		}

		result = .pressed in state
	}
	return
}
EnumTabs :: proc(value: $T, tabSize: f32, loc := #caller_location) -> (newValue: T) { 
	newValue = value
	rect := LayoutNext(GetCurrentLayout())
	if layout, ok := LayoutEx(rect); ok {
		layout.size = (layout.rect.w / f32(len(T))) if tabSize == 0 else tabSize; layout.side = .left
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
	TextEx(font, text, fit, GetColor(.text))
}
TextEx :: proc(font: FontIndex, text: string, fit: bool, color: Color) {
	fontData := GetFontData(font)
	layout := GetCurrentLayout()
	textSize := MeasureString(fontData, text)
	if fit {
		LayoutFitWidget(layout, textSize)
	}
	rect := LayoutNextEx(layout, textSize)
	if CheckClip(ctx.clipRect, rect) != .full {
		PaintString(fontData, text, {rect.x, rect.y}, color)
	}
	UpdateLayerContentRect(CurrentLayer(), rect)
}
TextBox :: proc(font: FontIndex, text: string) {
	fontData := GetFontData(font)
	rect := LayoutNext(GetCurrentLayout())
	if CheckClip(ctx.clipRect, rect) != .full {
		PaintStringContained(fontData, text, rect, {}, GetColor(.text))
	}
}
TextBoxEx :: proc(font: FontIndex, text: string, options: StringPaintOptions, alignX, alignY: Alignment) {
	fontData := GetFontData(font)
	rect := LayoutNext(GetCurrentLayout())
	if CheckClip(ctx.clipRect, rect) != .full {
		PaintStringContainedEx(fontData, text, rect, options, alignX, alignY, GetColor(.text))
	}
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

/*
	Simple selectable list item	
*/
ListItemData :: struct {
	text: string,
	size: f32,
}
@(deferred_out=_ListItem)
ListItem :: proc(active: bool, loc := #caller_location) -> (selected, ok: bool) {
	rect := LayoutNext(GetCurrentLayout())
	if CheckClip(ctx.clipRect, rect) != .full {
		if control, yes := BeginWidget(HashId(loc), rect); yes {
			using control 
			UpdateWidget(control)

			hoverTime := AnimateBool(id, .hovered in state, 0.1)
			if active {
				PaintRect(body, GetColor(.widgetBase))
			} else if hoverTime > 0 {
				PaintRect(body, GetColor(.backingHighlight, hoverTime))
			}

			selected = .released in state
			ok = true//.visible in bits
			if ok {
				PushLayout(body)
			}
		}
	}
	return
}
@private _ListItem :: proc(selected, ok: bool) {
	if ok {
		PopLayout()
	}
}
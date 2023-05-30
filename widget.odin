package maui
// Core stuff
import "core:fmt"
import "core:math"
import "core:runtime"
import "core:unicode/utf8"
import "core:math/linalg"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:time"
// For easings
import rl "vendor:raylib"
// General purpose booleans
WidgetBit :: enum {
	// Widget thrown away if 0
	stayAlive,
	// For independently toggled widgets
	active,
	// If the widget is diabled (duh)
	disabled,
	// For attached menus (maybe remove)
	menuOpen,
	// Should be painted this frame
	shouldPaint,
}
WidgetBits :: bit_set[WidgetBit]
// Behavior options
WidgetOption :: enum {
	// The widget does not receive input if 1
	static,
	// The widget will maintain focus, hover and press state if
	// the mouse is held after clicking even when not hovered
	draggable,
	// If the widget can be selected with the keyboard
	keySelect,
}
WidgetOptions :: bit_set[WidgetOption]
// Interaction state
WidgetStatus :: enum {
	// Just got status
	gotHover,
	gotFocus,
	gotPress,
	// Has status
	hovered,
	focused,
	pressed,
	// Just lost status
	lostHover,
	lostFocus,
	lostPress,
	// Textbox change
	changed,
	// Pressed and released
	clicked,
}
WidgetState :: bit_set[WidgetStatus]
// Universal control data (stoopid get rid of it)
WidgetData :: struct {
	id: 			Id,
	body: 			Rect,
	bits: 			WidgetBits,
	options: 		WidgetOptions,
	state: 			WidgetState,
	clickButton:  	MouseButton,
	clickCount: 	int,
	// Parent layer
	layer: 			^LayerData,
}
// Main widget functionality
@(deferred_out=_Widget)
Widget :: proc(id: Id, rect: Rect, options: WidgetOptions = {}) -> (^WidgetData, bool) {
	// Check if clipped
	if CheckClip(ctx.clipRect, rect) == .full {
		return nil, false
	}
	// Check for an existing widget
	layer := CurrentLayer()
	self, ok := layer.contents[id]
	// Allocate a new widget
	if !ok {
		self = new(WidgetData)
		self^ = {
			id = id,
			layer = layer,
		}
		assert(self.layer != nil)
		append(&ctx.widgets, self)
		ctx.renderFrames += 1
	}
	// Prepare widget
	self.body = rect
	self.state = {}
	self.options = options
	self.bits += {.stayAlive}
	if ctx.disabled {
		self.bits += {.disabled}
	} else {
		self.bits -= {.disabled}
	}
	if ctx.shouldRender {
		self.bits += {.shouldPaint}
	} else {
		self.bits -= {.shouldPaint}
	}
	// Nary a nil allowed
	assert(self != nil)
	ctx.currentWidget = self
	// Get input
	if !ctx.disabled {
		using self
		// Request hover status
		if VecVsRect(input.mousePoint, body) && ctx.hoveredLayer == layer.id {
			ctx.nextHoverId = id
		}
		// If hovered
		if ctx.hoverId == id {
			state += {.hovered}
			if ctx.prevHoverId != id {
				state += {.gotHover}
			}
			// Just pressed buttons, I ❤️ bitset math
			pressedButtons := input.mouseBits ~ input.prevMouseBits
			if pressedButtons != {} {
				if clickButton == input.lastMouseButtonPressed {
					clickCount += 1
				}
				clickButton = input.lastMouseButtonPressed
				ctx.pressId = id
			}
			// Just released buttons
			releasedButtons := input.prevMouseBits ~ input.mouseBits
			if releasedButtons != {} {
				for button in MouseButton {
					if button == clickButton {
						state += {.clicked}
						break
					}
				}
				if ctx.pressId == id {
					ctx.pressId = 0
				}
			}
		} else {
			if ctx.prevHoverId == id {
				state += {.lostHover}
			}
			if ctx.pressId == id {
				if .draggable in options {
					if .pressed not_in state {
						ctx.pressId = 0
					}
				} else  {
					ctx.pressId = 0
				}
			}
		}
		// Press
		if ctx.pressId == id {
			state += {.pressed}
			if ctx.prevPressId != id {
				state += {.gotPress}
			}
			ctx.dragging = .draggable in options
		} else if ctx.prevPressId == id {
			state += {.lostPress}
		}
		// Focus
		if ctx.focusId == id {
			state += {.focused}
			if ctx.prevFocusId != id {
				state += {.gotFocus}
			}
		} else if ctx.prevFocusId == id {
			state += {.lostFocus}
		}
	}
	return self, true
}
@private
_Widget :: proc(self: ^WidgetData, ok: bool) {
	if ok {
		// No nils never
		assert(self != nil)
		// Shade over the widget if it is disabled
		if .disabled in self.bits {
			PaintDisableShade(self.body)
		}
		// Update the parent layer's content rect
		layer := CurrentLayer()
		UpdateLayerContentRect(layer, self.body)
		// Update group if there is one
		if ctx.groupDepth > 0 {
			ctx.groups[ctx.groupDepth - 1].state += self.state
		}
		// Display tooltip if there is one
		if ctx.attachTooltip {
			ctx.attachTooltip = false
			if self.state >= {.hovered} {
				TooltipByRect(self.id, ctx.tooltipText, self.body, ctx.tooltipSide, 10)
			}
		}
	}
}

// Helper functions
WidgetClicked :: proc(using self: ^WidgetData, button: MouseButton, times: int = 1) -> bool {
	return .clicked in state && clickButton == button && clickCount == times
}
AttachTooltip :: proc(text: string, side: RectSide) {
	ctx.attachTooltip = true
	ctx.tooltipText = text
	ctx.tooltipSide = side
}
Tooltip :: proc(id: Id, text: string, origin: Vec2, alignX, alignY: Alignment) {
	fontData := GetFontData(.label)
	textSize := MeasureString(fontData, text)
	PADDING_X :: 4
	PADDING_Y :: 2
	rect: Rect = {0, 0, textSize.x + PADDING_X * 2, textSize.y + PADDING_Y * 2}
	switch alignX {
		case .near: rect.x = origin.x
		case .far: rect.x = origin.x - rect.w
		case .middle: rect.x = origin.x - rect.w / 2
	}
	switch alignY {
		case .near: rect.y = origin.y
		case .far: rect.y = origin.y - rect.h
		case .middle: rect.y = origin.y - rect.h / 2
	}
	if layer, ok := BeginLayer(rect, {}, id, {}); ok {
		layer.order = .tooltip
		//layer.opacity += (1 - layer.opacity) * 8 * ctx.deltaTime
		PaintRect(layer.body, GetColor(.tooltipFill))
		PaintRectLines(layer.body, 1, GetColor(.tooltipStroke))
		PaintString(fontData, text, {layer.body.x + PADDING_X, layer.body.y + PADDING_Y}, GetColor(.tooltipText))
		EndLayer(layer)
	}
}
TooltipByRect ::proc(id: Id, text: string, anchorRect: Rect, side: RectSide, offset: f32) {
	origin: Vec2
	alignX, alignY: Alignment
	switch side {
		case .bottom:		
		origin.x = anchorRect.x + anchorRect.w / 2
		origin.y = anchorRect.y + anchorRect.h + offset
		alignX = .middle
		alignY = .near
		case .left:
		origin.x = anchorRect.x - offset
		origin.y = anchorRect.y + anchorRect.h / 2
		alignX = .near
		alignY = .middle
		case .right:
		origin.x = anchorRect.x + anchorRect.w - offset
		origin.y = anchorRect.y + anchorRect.h / 2
		alignX = .far
		alignY = .middle
		case .top:
		origin.x = anchorRect.x + anchorRect.w / 2
		origin.y = anchorRect.y - offset
		alignX = .middle
		alignY = .far
	}
	Tooltip(id, text, origin, alignX, alignY)
}

PaintDisableShade :: proc(rect: Rect) {
	PaintRect(rect, GetColor(.base, DISABLED_SHADE_ALPHA))
}

// Labels
Label :: union {
	string,
	Icon,
}

PaintLabel :: proc(label: Label, origin: Vec2, color: Color, alignX, alignY: Alignment) -> Vec2 {
	switch variant in label {
		case string: 	
		return PaintStringAligned(GetFontData(.default), variant, origin, color, alignX, alignY)

		case Icon: 		
		return PaintGlyphAligned(GetGlyphData(GetFontData(.header), rune(variant)), origin, color, alignX, alignY)
	}
	return {}
}
PaintLabelRect :: proc(label: Label, rect: Rect, color: Color, alignX, alignY: Alignment) {
	origin: Vec2 = {rect.x, rect.y}
	#partial switch alignX {
		case .near: origin.x += WIDGET_TEXT_OFFSET
		case .far: origin.x += rect.w - WIDGET_TEXT_OFFSET
		case .middle: origin.x += rect.w / 2
	}
	#partial switch alignY {
		case .near: origin.y += WIDGET_TEXT_OFFSET
		case .far: origin.y += rect.h - WIDGET_TEXT_OFFSET
		case .middle: origin.y += rect.h / 2
	}
	PaintLabel(label, origin, color, alignX, alignY)
}
MeasureLabel :: proc(label: Label) -> (size: Vec2) {
	switch variant in label {
		case string: 
		size = MeasureString(GetFontData(.default), variant)

		case Icon:
		glyph := GetGlyphData(GetFontData(.header), rune(variant))
		size = {glyph.source.w, glyph.source.y}
	}
	return
}

/*
	Buttons for navigation
*/
NavOption :: proc(active: bool, icon: Icon, text: string, loc := #caller_location) -> (clicked: bool) {
	if self, ok := Widget(HashId(loc), LayoutNext(CurrentLayout())); ok {
		PushId(self.id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in self.state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(1), active, 0.15)
		PopId()

		if .shouldPaint in self.bits {
			PaintRect(self.body, Fade(255, min(hoverTime + stateTime, 1) * 0.25))
			PaintIconAligned(GetFontData(.header), icon, {self.body.x + self.body.h / 2, self.body.y + self.body.h / 2}, GetColor(.base), .middle, .middle)
			PaintStringAligned(GetFontData(.default), text, {self.body.x + self.body.h * rl.EaseCubicInOut(stateTime, 1, 0.3, 1), self.body.y + self.body.h / 2}, GetColor(.base), .near, .middle)
		}
		
		clicked = WidgetClicked(self, .left)
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
CheckBoxEx :: proc(
	status: 		CheckBoxStatus,
	text: 			string,
	textSide: 		RectSide = .left,
	loc := #caller_location,
) -> (change, newValue: bool) {
	SIZE :: 22
	HALF_SIZE :: SIZE / 2

	hasText := len(text) > 0
	size, textSize: Vec2
	if hasText {
		textSize = MeasureString(GetFontData(.default), text)
		if textSide == .bottom || textSide == .top {
			size.x = max(SIZE, textSize.x)
			size.y = SIZE + textSize.y
		} else {
			size.x = SIZE + textSize.x + WIDGET_TEXT_OFFSET * 2
			size.y = SIZE
		}
	}

	if self, ok := Widget(HashId(loc), UseNextRect() or_else LayoutNextEx(CurrentLayout(), size)); ok {
		using self
		active := status != .off
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .pressed in state, 0.15)
			stateTime := AnimateBool(HashIdFromInt(2), active, 0.1)
		PopId()
		// Painting
		if .shouldPaint in bits {
			iconRect: Rect
			if hasText {
				switch textSide {
					case .left: 	
					iconRect = {body.x, body.y, SIZE, SIZE}
					case .right: 	
					iconRect = {body.x + body.w - SIZE, body.y, SIZE, SIZE}
					case .top: 		
					iconRect = {body.x + body.w / 2 - HALF_SIZE, body.y + body.h - SIZE, SIZE, SIZE}
					case .bottom: 	
					iconRect = {body.x + body.w / 2 - HALF_SIZE, body.y, SIZE, SIZE}
				}
			} else {
				iconRect = body
			}
			if hoverTime > 0 {
				PaintRect(body, GetColor(.baseShade, hoverTime * BASE_SHADE_ALPHA))
			}
			if stateTime < 1 {
				PaintRectLines(iconRect, 2 + 2 * (pressTime if !active else 1), StyleIntenseShaded(hoverTime))
			}
			if stateTime > 0 {
				PaintRect(iconRect, Fade(StyleIntenseShaded(hoverTime), stateTime))
			}
			center := RectCenter(iconRect)
			if active || stateTime == 1 {
				PaintIconAligned(GetFontData(.header), .remove if status == .unknown else .check, center, GetColor(.base), .middle, .middle)
			}
			// Draw text
			if hasText {
				switch textSide {
					case .left: 	
					PaintString(GetFontData(.default), text, {iconRect.x + iconRect.w + WIDGET_TEXT_OFFSET, center.y - textSize.y / 2}, GetColor(.text, 1))
					case .right: 	
					PaintString(GetFontData(.default), text, {iconRect.x - WIDGET_TEXT_OFFSET, center.y - textSize.y / 2}, GetColor(.text, 1))
					case .top: 		
					PaintString(GetFontData(.default), text, {body.x, body.y}, GetColor(.text, 1))
					case .bottom: 	
					PaintString(GetFontData(.default), text, {body.x, body.y + body.h - textSize.y}, GetColor(.text, 1))
				}
			}
		}
		// Result
		if .clicked in state && clickButton == .left {
			if status != .on {
				newValue = true
			}
			change = true
		}
	}
	return
}
CheckBox :: proc(value: bool, text: string, loc := #caller_location) -> bool {
	if change, newValue := CheckBoxEx(
		status = .on if value else .off, 
		text = text, 
		loc = loc,
		); change {
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

// Sliding toggle switch
ToggleSwitch :: proc(value: bool, loc := #caller_location) -> (newValue: bool) {
	newValue = value
	if self, ok := Widget(HashId(loc), LayoutNextEx(CurrentLayout(), {36, 28})); ok {
		using self
		// Animation
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .pressed in state, 0.15)
			howOn := AnimateBool(HashIdFromInt(2), value, 0.25)
		PopId()
		// Painting
		if .shouldPaint in bits {
			baseRect: Rect = {body.x, body.y + 4, body.w, body.h - 8}
			baseRadius := baseRect.h / 2
			start: Vec2 = {baseRect.x + baseRadius, baseRect.y + baseRect.h / 2}
			move := baseRect.w - baseRect.h
			thumbCenter := start + {move * (rl.EaseBackOut(howOn, 0, 1, 1) if value else rl.EaseBackIn(howOn, 0, 1, 1)), 0}

			strokeColor := GetColor(.widget if ctx.disabled else .intense)
			if howOn < 1 {
				if !ctx.disabled {
					PaintRoundedRect(baseRect, baseRadius, GetColor(.base))
				}
				PaintRoundedRectOutline(baseRect, baseRadius, false, strokeColor)
			}
			if howOn > 0 {
				if howOn < 1 {
					PaintRoundedRect({baseRect.x, baseRect.y, thumbCenter.x - baseRect.x, baseRect.h}, baseRadius, GetColor(.widget if ctx.disabled else .intense))
				} else {
					PaintRoundedRect(baseRect, baseRadius, GetColor(.widget if ctx.disabled else .intense))
				}
			}
			if hoverTime > 0 {
				PaintCircle(thumbCenter, 32, GetColor(.baseShade, BASE_SHADE_ALPHA * hoverTime))
			}
			if pressTime > 0 {
				if .pressed in state {
					PaintCircle(thumbCenter, 21 + 11 * pressTime, GetColor(.baseShade, BASE_SHADE_ALPHA))
				} else {
					PaintCircle(thumbCenter, 32, GetColor(.baseShade, BASE_SHADE_ALPHA * pressTime))
				}
			}
			PaintCircle(thumbCenter, 18, GetColor(.base))
			PaintCircleOutline(thumbCenter, 21, false, strokeColor)
		}
		// Invert value on click
		if .clicked in state {
			newValue = !value
		}
	}
	return
}

// Radio buttons
RadioButton :: proc(
	on: bool,
	text: string,
	textSide: RectSide = .left,
	loc := #caller_location,
) -> (clicked: bool) {
	SIZE :: 22
	HALF_SIZE :: SIZE / 2
	// Determine total size
	textSize := MeasureString(GetFontData(.default), text)
	size: Vec2
	if textSide == .bottom || textSide == .top {
		size.x = max(SIZE, textSize.x)
		size.y = SIZE + textSize.y
	} else {
		size.x = SIZE + textSize.x + WIDGET_TEXT_OFFSET * 2
		size.y = SIZE
	}
	// The widget
	if self, ok := Widget(HashId(loc), LayoutNextEx(CurrentLayout(), size)); ok {
		// Animation
		PushId(self.id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in self.state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .pressed in self.state && !on, 0.1)
			stateTime := AnimateBool(HashIdFromInt(2), on, 0.2)
		PopId()
		// Graphics
		if .shouldPaint in self.bits {
			center: Vec2
			switch textSide {
				case .left: 	center = {self.body.x + HALF_SIZE, self.body.y + HALF_SIZE}
				case .right: 	center = {self.body.x + self.body.w - HALF_SIZE, self.body.y + HALF_SIZE}
				case .top: 		center = {self.body.x + self.body.w / 2, self.body.y + self.body.h - HALF_SIZE}
				case .bottom: 	center = {self.body.x + self.body.w / 2, self.body.y + HALF_SIZE}
			}
			if hoverTime > 0 {
				PaintRoundedRect(self.body, HALF_SIZE, GetColor(.baseShade, hoverTime * BASE_SHADE_ALPHA))
			}
			PaintRing(center, HALF_SIZE - rl.EaseQuadOut(stateTime, 2 + 3 * pressTime, 5, 1), HALF_SIZE, 16, StyleIntenseShaded(hoverTime))
			switch textSide {
				case .left: 	PaintString(GetFontData(.default), text, {self.body.x + SIZE + WIDGET_TEXT_OFFSET, center.y - textSize.y / 2}, GetColor(.text, 1))
				case .right: 	PaintString(GetFontData(.default), text, {self.body.x, center.y - textSize.y / 2}, GetColor(.text, 1))
				case .top: 		PaintString(GetFontData(.default), text, {self.body.x, self.body.y}, GetColor(.text, 1))
				case .bottom: 	PaintString(GetFontData(.default), text, {self.body.x, self.body.y + self.body.h - textSize.y}, GetColor(.text, 1))
			}
		}
		// Click result
		clicked = .clicked in self.state && self.clickButton == .left
	}
	return
}
// Helper functions
EnumRadioButtons :: proc(
	value: $T, 
	textSide: RectSide = .left, 
	loc := #caller_location,
) -> (newValue: T) {
	newValue = value
	for member in T {
		PushId(HashIdFromInt(int(member)))
			if RadioButton({
				on = member == value, 
				text = TextCapitalize(Format(member)), 
				textSide = textSide,
			}) {
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
Collapser :: proc(
	text: string, 
	size: f32, 
	loc := #caller_location,
) -> (active: bool) {
	sharedId := HashId(loc)
	if control, ok := Widget(sharedId, UseNextRect() or_else LayoutNext(CurrentLayout())); ok {
		using control
		// Animation
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			stateTime := AnimateBool(HashIdFromInt(2), .active in bits, 0.15)
		PopId()
		// Paint
		if .shouldPaint in bits {
			PaintRect(body, StyleWidgetShaded(2 if .pressed in state else hoverTime))
			PaintRectLines(body, 1, GetColor(.widgetStroke))
			PaintCollapseArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, -1 + stateTime, GetColor(.text))
			PaintStringAligned(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text), .near, .middle)
		}
		// Invert state on click
		if .pressed in state {
			bits = bits ~ {.active}
		}
		// Begin layer
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

// Menus for combo boxes or whatever
@private 
BeginMenu :: proc(label: Label, size: Vec2, align: Alignment, loc := #caller_location) -> (active: bool) {
	sharedId := HashId(loc)
	if self, ok := Widget(sharedId, UseNextRect() or_else LayoutNext(CurrentLayout())); ok {
		using self
		active = .active in bits
		// Animation
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			stateTime := AnimateBool(HashIdFromInt(2), active, 0.125)
		PopId()
		// Painting
		if .shouldPaint in bits {
			PaintRect(body, StyleWidgetShaded(2 if .pressed in state else hoverTime))
			PaintRectLines(body, 1, GetColor(.widgetStroke))
			PaintCollapseArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, -1 + stateTime, GetColor(.text))
			PaintLabel(label, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text), .near, .middle)
		}
		// Expand/collapse on click
		if .pressed in state {
			bits = bits ~ {.active}
		}
		// Begin layer if expanded
		if active {
			size := size
			size.x = max(size.x, body.w)
			rect: Rect = {body.x, body.y + body.h, size.x, size.y}
			if align == .middle {
				rect.x = body.x + body.w / 2 - size.x / 2
			} else if align == .far {
				rect.x = body.x + body.w - size.x
			}

			layer: ^LayerData
			layer, ok = BeginLayer(rect, {}, sharedId, {.attached})

			if ok {
				layer.opacity = stateTime

				if layer.bits >= {.dismissed} {
					bits -= {.active}
					EndLayer(layer)
					return false
				}

				PaintRect(layer.body, GetColor(.widget))
			}
		}
	}
	return 
}
@private
EndMenu :: proc(active: bool) {
	if active {
		layer := CurrentLayer()
		if (.hovered not_in layer.bits && MousePressed(.left)) || KeyPressed(.escape) {
			layer.bits += {.dismissed}
		}
		PaintRectLines(layer.body, 1, GetColor(.widgetStroke))
		EndLayer(layer)
	}
}
@(deferred_out=_Menu)
Menu :: proc(
	label: Label, 
	size: Vec2, 
	align: Alignment = .near, 
	loc := #caller_location,
) -> (active: bool) {
	return BeginMenu(label, size, align)
}
@private 
_Menu :: proc(active: bool) {
	EndMenu(active)
}
// Attach a menu to a widget (opens when focused)
@(deferred_out=_AttachMenu)
AttachMenu :: proc(
	widget: ^WidgetData, 
	menuSize: f32, 
	size: Vec2 = {}, 
	options: LayerOptions = {},
) -> (ok: bool) {
	if widget != nil {
		if widget.bits >= {.menuOpen} {
			layer: ^LayerData
			layer, ok = BeginLayer(AttachRectBottom(widget.body, menuSize), size, widget.id, options + {.attached})
			if ok {
				PaintRect(layer.body, GetColor(.base))
			}
			if ctx.focusId != ctx.prevFocusId && ctx.focusId != widget.id && ctx.focusId not_in layer.contents {
				widget.bits -= {.menuOpen}
			}
		} else if widget.state >= {.gotFocus} {
			widget.bits += {.menuOpen}
		}
	}
	return 
}
@private 
_AttachMenu :: proc(ok: bool) {
	if ok {
		layer := CurrentLayer()
		PaintRectLines(layer.body, 1, GetColor(.baseStroke))
		EndLayer(layer)
	}
}
// Options within menus
@(deferred_out=_SubMenu)
SubMenu :: proc(
	text: string, 
	size: Vec2, 
	loc := #caller_location,
) -> (active: bool) {
	sharedId := HashId(loc)
	if self, yes := Widget(sharedId, UseNextRect() or_else LayoutNext(CurrentLayout())); yes {
		using self
		active = .active in bits
		// Animation
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			stateTime := AnimateBool(HashIdFromInt(1), active, 0.15)
		PopId()
		// Paint
		if .shouldPaint in bits {
			PaintRect(body, StyleWidgetShaded(2 if .pressed in state else hoverTime))
			PaintFlipArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, 0, GetColor(.text))
			PaintStringAligned(GetFontData(.default), text, {body.x + WIDGET_TEXT_OFFSET, body.y + body.h / 2}, GetColor(.text), .near, .middle)
		}
		// Swap state when clicked
		if .pressed in state {
			bits = bits ~ {.active}
		}
		// Begin layer
		if active {
			layer, ok := BeginLayer({body.x + body.w, body.y, size.x, size.y}, {}, sharedId, {.attached})

			if ok {
				layer.opacity = stateTime

				if layer.bits >= {.dismissed} {
					bits -= {.active}
					EndLayer(layer)
					return false
				}

				PaintRect(layer.body, GetColor(.widget))
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
		PaintRectLines(layer.body, 1, GetColor(.widgetStroke))
		EndLayer(layer)
	}
}
MenuOption :: proc(
	label: Label, 
	active: bool = false,
	align: Alignment = .near,
	loc := #caller_location,
) -> (clicked: bool) {
	if self, ok := Widget(HashId(loc), LayoutNext(CurrentLayout())); ok {
		// Animation
		PushId(self.id)
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in self.state, 0.1)
		PopId()
		// Painting
		if .shouldPaint in self.bits {
			PaintRect(self.body, StyleWidgetShaded(2 if .pressed in self.state else hoverTime))
			PaintLabelRect(label, self.body, GetColor(.text), align, .middle)
		}
		// Dismiss the root menu
		if .clicked in self.state && self.clickButton == .left {
			clicked = true
			layer := CurrentLayer()
			layer.bits += {.dismissed}
			for layer.parent != nil && layer.options >= {.attached} {
				layer = layer.parent
				layer.bits += {.dismissed}
			}
		}
	}
	return
}
EnumMenuOptions :: proc(
	value: $T, 
	loc := #caller_location,
) -> (newValue: T) {
	newValue = value
	for member in T {
		PushId(HashIdFromInt(int(member)))
			if MenuOption(TextCapitalize(Format(member)), false) {
				newValue = member
			}
		PopId()
	}
	return
}
BitSetMenuOptions :: proc(set: $S/bit_set[$E;$U], loc := #caller_location) -> (newSet: S) {
	newSet = set
	for member in E {
		PushId(HashIdFromInt(int(member)))
			if MenuOption(TextCapitalize(Format(member)), member in set) {
				newSet = newSet ~ {member}
			}
		PopId()
	}
	return
}

// Cards are interactable rectangles that contain other widgets
@(deferred_out=_Card)
Card :: proc(
	text: string, 
	sides: RectSides = {}, 
	loc := #caller_location,
) -> (clicked, ok: bool) {
	if control, yes := Widget(HashId(loc), LayoutNext(CurrentLayout())); yes {
		using control

		PushId(id)
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.15)
			pressTime := AnimateBool(HashIdFromInt(1), .pressed in state, 0.1)
		PopId()

		if hoverTime > 0 {
			PaintRect(body, StyleBaseShaded((hoverTime + pressTime) * 0.75))
		}
		PaintRectLines(body, 1, GetColor(.baseStroke))
		PaintStringAligned(GetFontData(.default), text, {body.x + body.h * 0.25, body.y + body.h / 2}, GetColor(.text), .near, .middle)

		PushLayout(body)

		clicked = .clicked in state && clickButton == .left
		ok = true
	}
	return
}
@private _Card :: proc(clicked, ok: bool) {
	if ok {
		PopLayout()
	}
}

/*
	Widget divider
*/
WidgetDivider :: proc() {
	using layout := CurrentLayout()
	#partial switch side {
		case .left: PaintRect({rect.x, rect.y + 10, 1, rect.h - 20}, GetColor(.baseStroke))
		case .right: PaintRect({rect.x + rect.w, rect.y + 10, 1, rect.h - 20}, GetColor(.baseStroke))
	}
}

// Just a line
Divider :: proc(size: f32) {
	layout := CurrentLayout()
	rect := CutRect(&layout.rect, layout.side, size)
	if layout.side == .left || layout.side == .right {
		PaintRect({rect.x + math.floor(rect.w / 2), rect.y, 1, rect.h}, GetColor(.baseShade, DIVIDER_ALPHA))
	} else {
		PaintRect({rect.x, rect.y + math.floor(rect.h / 2), rect.w, 1}, GetColor(.baseShade, DIVIDER_ALPHA))
	}
}

/*
	Sections
*/
@(deferred_out=_Section)
Section :: proc(label: string, sides: RectSides) -> (ok: bool) {
	rect := LayoutNext(CurrentLayout())

	PaintRectLines(rect, 1, GetColor(.baseStroke))
	if len(label) != 0 {
		font := GetFontData(.default)
		textSize := MeasureString(font, label)
		PaintRect({rect.x + WIDGET_TEXT_OFFSET - 2, rect.y, textSize.x + 4, 1}, GetColor(.base))
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

// Scroll bars for scrolling bars
ScrollBar :: proc(
	value,
	low,
	high,
	thumbSize: f32,
	vertical: bool = false, 
	loc := #caller_location,
) -> (changed: bool, newValue: f32) {
	newValue = value
	if self, ok := Widget(HashId(loc), UseNextRect() or_else LayoutNext(CurrentLayout()), {.draggable}); ok {
		using self
		i := int(vertical)
		rect := transmute([4]f32)body

		range := rect[2 + i] - thumbSize
		valueRange := (high - low) if high > low else 1

		PushId(id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in state, 0.1)
		PopId()

		time := 0.5 + hoverTime * 0.5

		breadth := rect[3 - i] * time
		rect[1 - i] += rect[3 - i] - breadth
		rect[3 - i] = breadth

		thumbRect := rect
		thumbRect[i] += range * clamp((value - low) / valueRange, 0, 1)
		thumbRect[2 + i] = thumbSize
		// Painting
		if .shouldPaint in bits {
			PaintRect(transmute(Rect)rect, GetColor(.widget, hoverTime))
			PaintRectLines(transmute(Rect)rect, 1, GetColor(.widgetStroke, hoverTime))
			PaintRect(ShrinkRect(transmute(Rect)thumbRect, 1), StyleIntenseShaded(2 if .pressed in state else hoverTime))
		}
		// Dragging
		if .pressed in state {
			if VecVsRect(input.mousePoint, transmute(Rect)thumbRect) {
				ctx.dragAnchor = input.mousePoint - Vec2({thumbRect.x, thumbRect.y})
				bits += {.active}
			} else {
				normal := clamp((input.mousePoint[i] - rect[i]) / range, 0, 1)
				newValue = low + (high - low) * normal
				changed = true
			}
		} else if bits >= {.active} {
			normal := clamp(((input.mousePoint[i] - ctx.dragAnchor[i]) - rect[i]) / range, 0, 1)

			newValue = low + (high - low) * normal
			changed = true
		}
		if .pressed not_in state {
			bits -= {.active}
		}
	}
	return
}

// Navigation tabs
Tab :: proc(
	// If the tab is selected
	active: bool, 
	// The displayed label
	label: Label,
	// The side of the tab that is attached
	side: RectSide = .bottom,
	loc := #caller_location,
) -> (result: bool) {
	layout := CurrentLayout()
	horizontal := layout.side == .top || layout.side == .bottom
	if self, ok := Widget(HashId(loc), UseNextRect() or_else LayoutNext(layout)); ok {
		PushId(self.id)
			hoverTime := AnimateBool(HashId(int(0)), .hovered in self.state, 0.1)
			stateTime := AnimateBool(HashId(int(1)), active, 0.15)
		PopId()

		if self.bits >= {.shouldPaint} {
			PaintRoundedRectEx(self.body, 10, SideCorners(side), GetColor(.base, 1 if active else 0.5 * hoverTime))
			center: Vec2 = {self.body.x + self.body.w / 2, self.body.y + self.body.h / 2}
			textSize := PaintLabel(label, center, GetColor(.text), .middle, .middle)
			size := textSize.x
			if stateTime > 0 {
				if active {
					size *= stateTime
				}
				accentRect: Rect
				THICKNESS :: 4
				switch side {
					case .top: 		accentRect = {center.x - size / 2, self.body.y, size, THICKNESS}
					case .bottom: 	accentRect = {center.x - size / 2, self.body.y + self.body.h - THICKNESS, size, THICKNESS}
					case .left: 	accentRect = {self.body.x, center.y - size / 2, size, THICKNESS}
					case .right: 	accentRect = {self.body.x + self.body.y - THICKNESS, center.y - size / 2, size, THICKNESS}
				}
				PaintRect(accentRect, GetColor(.accent, 1 if active else stateTime))
			}
		}

		result = .pressed in self.state
	}
	return
}
EnumTabs :: proc(value: $T, tabSize: f32, loc := #caller_location) -> (newValue: T) { 
	newValue = value
	rect := LayoutNext(CurrentLayout())
	if layout, ok := LayoutEx(rect); ok {
		layout.size = (layout.rect.w / f32(len(T))) if tabSize == 0 else tabSize; layout.side = .left
		for member in T {
			PushId(HashId(int(member)))
				if Tab(
					active = member == value, 
					label = TextCapitalize(Format(member)), 
					loc = loc,
					) {
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
Text :: proc(
	text: string, 
	font: FontIndex = .default, 
	fit: bool = true, 
	color: Maybe(Color) = nil,
) {
	fontData := GetFontData(font)
	layout := CurrentLayout()
	textSize := MeasureString(fontData, text)
	if fit {
		LayoutFitWidget(layout, textSize)
	}
	rect := LayoutNextEx(layout, textSize)
	if CheckClip(ctx.clipRect, rect) != .full {
		PaintString(fontData, text, {rect.x, rect.y}, color if color != nil else GetColor(.text))
	}
	UpdateLayerContentRect(CurrentLayer(), rect)
}
TextBox :: proc(
	text: string, 
	font: FontIndex = .default, 
	options: StringPaintOptions = {}, 
	alignX: Alignment = .near, 
	alignY: Alignment = .near,
) {
	fontData := GetFontData(font)
	rect := LayoutNext(CurrentLayout())
	if CheckClip(ctx.clipRect, rect) != .full {
		PaintStringContainedEx(fontData, text, rect, options, alignX, alignY, GetColor(.text))
	}
}

GlyphIcon :: proc(font: FontIndex, icon: Icon) {
	fontData := GetFontData(font)
	rect := LayoutNext(CurrentLayout())
	PaintGlyphAligned(GetGlyphData(fontData, rune(icon)), {rect.x + rect.w / 2, rect.y + rect.h / 2}, GetColor(.text), .middle, .middle)
}

/*
	Progress bar
*/
ProgressBar :: proc(value: f32) {
	rect := LayoutNext(CurrentLayout())
	radius := rect.h / 2
	PaintRoundedRect(rect, radius, GetColor(.widgetBackground))
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
ListItem :: proc(active: bool, loc := #caller_location) -> (clicked, ok: bool) {
	rect := LayoutNext(CurrentLayout())
	if CheckClip(ctx.clipRect, rect) != .full {
		if self, yes := Widget(HashId(loc), rect); yes {
			hoverTime := AnimateBool(self.id, .hovered in self.state, 0.1)
			if active {
				PaintRect(self.body, GetColor(.widget))
			} else if hoverTime > 0 {
				PaintRect(self.body, GetColor(.widgetShade, BASE_SHADE_ALPHA * hoverTime))
			}

			clicked = .clicked in self.state && self.clickButton == .left
			ok = true//.visible in bits
			if ok {
				PushLayout(self.body)
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


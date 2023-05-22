package maui

import rl "vendor:raylib"

// The three types of buttons
ButtonStyle :: enum {
	normal,
	bright,
	subtle,
}
// Standalone buttons for major actions
PillButtonEx :: proc(label: Label, style: ButtonStyle, loc := #caller_location) -> (result: bool) {
	layout := GetCurrentLayout()
	if layout.side == .left || layout.side == .right {
		layout.size = MeasureLabel(GetFontData(.default), label).x + layout.rect.h + layout.margin * 2
	}
	if control, ok := BeginWidget(HashId(loc), LayoutNext(layout)); ok {
		using control
		UpdateWidget(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.2)
			if .released in state {
				GetAnimation(HashIdFromInt(1))^ = 1
			}
		PopId()

		roundness := body.h / 2

		if pressTime > 0 {
			if .down in state {
				rect := ExpandRect(body, rl.EaseCubicOut(pressTime, 0, 4, 1))
				PaintRoundedRect(rect, rect.h / 2, StyleGetShadeColor(1))
			} else {
				rect := ExpandRect(body, 4)
				PaintRoundedRect(rect, rect.h / 2, StyleGetShadeColor(pressTime))
			}
		}
		if style == .subtle {
			PaintPillH(body, GetColor(.foreground))
			PaintPillOutlineH(body, false, BlendColors(GetColor(.outlineBase), GetColor(.accentHover), hoverTime))
			PaintLabel(GetFontData(.default), label, {body.x + body.w / 2, body.y + body.h / 2}, BlendColors(GetColor(.outlineBase), GetColor(.accentHover), hoverTime), .middle, .middle)
		} else if style == .normal {
			PaintPillH(body, BlendColors(GetColor(.widgetBase), GetColor(.widgetHover), hoverTime))
			PaintLabel(GetFontData(.default), label, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.foreground), .middle, .middle)
		} else {
			PaintPillH(body, BlendColors(GetColor(.accent), GetColor(.accentHover), hoverTime))
			PaintLabel(GetFontData(.default), label, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.foreground), .middle, .middle)
		}
		
		result = .released in state
	}
	return
}
PillButton :: proc(label: Label, loc := #caller_location) -> bool {
	return PillButtonEx(label, .normal, loc)
}

// Regular buttons
ButtonEx :: proc(label: Label, align: Alignment, fit: bool, loc := #caller_location) -> (result: bool) {
	layout := GetCurrentLayout()
	if fit && (layout.side == .left || layout.side == .right) {
		layout.size = MeasureLabel(GetFontData(.default), label).x + layout.rect.h / 2 + layout.margin * 2
	}
	if control, ok := BeginWidget(HashId(loc), UseNextRect() or_else LayoutNext(layout)); ok {
		using control
		UpdateWidget(control)

		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .down in state, 0.2)
			if .released in state {
				GetAnimation(HashIdFromInt(1))^ = 1
			}
		PopId()
		
		PaintRect(body, GetColor(.widgetPress) if .down in state else BlendColors(GetColor(.widgetBase), GetColor(.widgetHover), hoverTime))
		if .down not_in state {
			PaintRectLines(body, 2, GetColor(.widgetPress, pressTime))
		}

		{
			point: Vec2 = {0, body.y + body.h / 2}
			switch align {
				case .far: 		point.x = body.x + body.w - WIDGET_TEXT_OFFSET
				case .middle: 	point.x = body.x + body.w / 2
				case .near: 	point.x = body.x + WIDGET_TEXT_OFFSET
			}
			_, isIcon := label.(Icon)
			PaintLabel(GetFontData(.header if isIcon else .default), label, point, GetColor(.text), align, .middle)
		}

		result = .released in state
	}
	return
}
Button :: proc(label: Label, loc := #caller_location) -> bool {
	return ButtonEx(label, .middle, true, loc)
}

// Toggle buttons
ToggleButtonEx :: proc(value: bool, label: Label, loc := #caller_location) -> (click: bool) {
	if control, ok := BeginWidget(HashId(loc), UseNextRect() or_else LayoutNext(GetCurrentLayout())); ok {
		using control
		UpdateWidget(control)

		if .released in state {
			click = true
		}

		// Graphics
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			stateTime := AnimateBool(HashIdFromInt(1), value, 0.15)
		PopId()

		fillColor: Color
		if value {
			fillColor = GetColor(.widgetPress) if .down in state else BlendColors(GetColor(.widgetBase), GetColor(.widgetHover), hoverTime)
		} else {
			fillColor = GetColor(.foregroundPress) if .down in state else BlendColors(GetColor(.foreground), GetColor(.foregroundHover), hoverTime)
		}
		PaintRect(body, fillColor)
		PaintRectLines(body, 1, GetColor(.outlineBase))
		
		_, isIcon := label.(Icon)
		PaintLabel(GetFontData(.header if isIcon else .default), label, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.text if value else .outlineBase), .middle, .middle)
	}
	return
}
ToggleButton :: proc(value: bool, label: Label, loc := #caller_location) -> (newValue: bool) {
	newValue = value
	if ToggleButtonEx(value, label, loc) {
		newValue = !newValue
	}
	return
}
ToggleButtonBit :: proc(set: ^$S/bit_set[$B], bit: B, label: Label, loc := #caller_location) -> (click: bool) {
	click = ToggleButtonEx(bit in set, label, loc)
	if click {
		set^ ~= {bit}
	}
	return
}
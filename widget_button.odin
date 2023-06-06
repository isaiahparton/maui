package maui

import rl "vendor:raylib"

PillButtonStyle :: enum {
	filled,
	outlined,
	subtle,
}
// Standalone button for major actions
PillButtonInfo :: struct {
	label: Label,
	fitToLabel: bool,
	style: Maybe(PillButtonStyle),
	fillColor: Maybe(Color),
	textColor: Maybe(Color),
}
PillButton :: proc(info: PillButtonInfo, loc := #caller_location) -> (clicked: bool) {
	layout := CurrentLayout()
	if info.fitToLabel && (layout.side == .left || layout.side == .right) {
		layout.size = MeasureLabel(info.label).x + layout.rect.h + layout.margin * 2
	}
	if self, ok := Widget(HashId(loc), LayoutNext(layout)); ok {
		using self
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .pressed in state, 0.2)
			if .lostPress in state {
				GetAnimation(HashIdFromInt(1))^ = 1
			}
		PopId()
		// Graphics
		if .shouldPaint in bits {
			roundness := body.h / 2
			if pressTime > 0 {
				if .pressed in state {
					rect := ExpandRect(body, rl.EaseCubicOut(pressTime, 0, 4, 1))
					PaintRoundedRect(rect, rect.h / 2, GetColor(.baseShade, pressTime * BASE_SHADE_ALPHA))
				} else {
					rect := ExpandRect(body, 4)
					PaintRoundedRect(rect, rect.h / 2, GetColor(.baseShade, pressTime * BASE_SHADE_ALPHA))
				}
			}
			switch info.style.? or_else .filled {
				case .filled:
				PaintPillH(body, StyleShade(info.fillColor .? or_else GetColor(.intense), hoverTime))
				PaintLabel(info.label, {body.x + body.w / 2, body.y + body.h / 2}, info.textColor.? or_else GetColor(.base), .middle, .middle)
				
				case .outlined:
				PaintPillH(body, GetColor(.base))
				color := BlendColors(GetColor(.baseStroke), GetColor(.accent), hoverTime)
				PaintPillOutlineH(body, false, color)
				PaintLabel(info.label, {body.x + body.w / 2, body.y + body.h / 2}, color, .middle, .middle)
			
				case .subtle:
				PaintPillH(body, GetColor(.baseShade, (2 if .pressed in state else hoverTime) * BASE_SHADE_ALPHA))
				PaintLabel(info.label, {body.x + body.w / 2, body.y + body.h / 2}, BlendColors(GetColor(.baseStroke), GetColor(.accent), hoverTime), .middle, .middle)
			}
		}
		// Click result
		clicked = .clicked in state && clickButton == .left
	}
	return
}

// Square buttons
ButtonInfo :: struct {
	label: Label,
	align: Maybe(Alignment),
	fitToLabel: bool,
	subtle: bool,
}
Button :: proc(info: ButtonInfo, loc := #caller_location) -> (clicked: bool) {
	layout := CurrentLayout()
	if info.fitToLabel {
		LayoutFitLabel(layout, info.label)
	}
	if self, ok := Widget(HashId(loc), UseNextRect() or_else LayoutNext(layout)); ok {
		// Animations
		PushId(self.id) 
			hoverTime := AnimateBool(HashId(int(0)), .hovered in self.state, 0.1)
			pressTime := AnimateBool(HashId(int(1)), .pressed in self.state, 0.2)
			if .lostPress in self.state {
				GetAnimation(HashId(int(1)))^ = 1
			}
		PopId()
		// Graphics
		if .shouldPaint in self.bits {
			if info.subtle {
				PaintRect(self.body, GetColor(.baseShade, (2 if .pressed in self.state else hoverTime) * BASE_SHADE_ALPHA))
				if .pressed not_in self.state {
					PaintRectLines(self.body, 2, GetColor(.baseShade, 0.2 * pressTime))
				}
			} else {
				PaintRect(self.body, StyleWidgetShaded(2 if .pressed in self.state else hoverTime))
				if .pressed not_in self.state {
					PaintRectLines(self.body, 2, GetColor(.widgetShade, 0.2 * pressTime))
				}
			}
			PaintLabelRect(info.label, self.body, GetColor(.text), info.align.? or_else .middle, .middle)
		}
		// Result
		clicked = .clicked in self.state && self.clickButton == .left
	}
	return
}

// Square buttons that toggle something
ToggleButtonInfo :: struct {
	label: Label,
	value: bool,
	align: Maybe(Alignment),
	fitToLabel: bool,
}
ToggleButton :: proc(info: ToggleButtonInfo, loc := #caller_location) -> (newValue: bool) {
	newValue = info.value
	layout := CurrentLayout()
	if info.fitToLabel {
		LayoutFitLabel(layout, info.label)
	}
	if self, ok := Widget(HashId(loc), UseNextRect() or_else LayoutNext(layout)); ok {
		// Animations
		hoverTime := AnimateBool(self.id, .hovered in self.state, 0.1)
		// Paintions
		if .shouldPaint in self.bits {
			fillColor: Color
			if info.value {
				fillColor = StyleBaseShaded(2 if .pressed in self.state else hoverTime)
			} else {
				fillColor = StyleWidgetShaded(2 if .pressed in self.state else hoverTime)
			}
			PaintRect(self.body, fillColor)
			PaintRectLines(self.body, 1, GetColor(.widgetStroke if info.value else .baseStroke))
			PaintLabel(info.label, RectCenter(self.body), GetColor(.text), info.align.? or_else .middle, .middle)
		}
		// Result
		if .clicked in self.state && self.clickButton == .left {
			newValue = !newValue
		}
	}
	return
}
ToggleButtonBit :: proc(set: ^$S/bit_set[$B], bit: B, label: Label, loc := #caller_location) -> (click: bool) {
	click = ToggleButton(
		value = bit in set, 
		label = label, 
		loc = loc,
		)
	if click {
		set^ ~= {bit}
	}
	return
}
// Smol subtle buttons
IconButton :: proc(
	icon: Icon, 
	loc := #caller_location,
) -> (clicked: bool) {
	if self, ok := Widget(HashId(loc), ChildRect(UseNextRect() or_else LayoutNext(CurrentLayout()), {24, 24}, .middle, .middle)); ok {
		PushId(self.id)
			hoverTime := AnimateBool(HashId(int(0)), self.state >= {.hovered}, 0.1)
			pressTime := AnimateBool(HashId(int(1)), self.state >= {.pressed}, 0.1)
		PopId()
		// Painting
		if self.bits >= {.shouldPaint} {
			center := RectCenter(self.body)
			PaintCircle(center, 24, 16, GetColor(.baseShade, (2 if self.state >= {.pressed} else hoverTime) * BASE_SHADE_ALPHA))
			if .clicked not_in self.state {
				PaintRing(center, 24, 15, 16, GetColor(.baseShade, pressTime * BASE_SHADE_ALPHA))
			}
			PaintIconAligned(GetFontData(.header), icon, center + 1, GetColor(.text, 0.5 + hoverTime * 0.5), .middle, .middle)
		}
		// Result
		clicked = .clicked in self.state && self.clickButton == .left
	}
	return
}
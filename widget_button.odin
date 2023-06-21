package maui

import "core:math/linalg"
import rl "vendor:raylib"

ButtonStyle :: enum {
	filled,
	outlined,
	subtle,
}
// Standalone button for major actions
PillButtonInfo :: struct {
	label: Label,
	fitToLabel: Maybe(bool),
	style: Maybe(ButtonStyle),
	fillColor: Maybe(Color),
	textColor: Maybe(Color),
}
PillButton :: proc(info: PillButtonInfo, loc := #caller_location) -> (clicked: bool) {
	layout := CurrentLayout()
	if (info.fitToLabel.? or_else true) && (layout.side == .left || layout.side == .right) {
		layout.size = MeasureLabel(info.label).x + layout.rect.h
	}
	if self, ok := Widget(HashId(loc), LayoutNext(layout)); ok {
		using self
		hoverTime := AnimateBool(self.id, .hovered in state, 0.1)
		if .hovered in self.state {
			ctx.cursor = .hand
		}
		// Graphics
		if .shouldPaint in bits {
			roundness := body.h / 2
			switch info.style.? or_else .filled {
				case .filled:
				PaintPillH(self.body, AlphaBlend(GetColor(.buttonBase), GetColor(.buttonShade), 0.3 if .pressed in self.state else hoverTime * 0.15))
				PaintLabelRect(info.label, self.body, GetColor(.buttonText), .middle, .middle)
				
				case .outlined:
				PaintPillH(self.body, GetColor(.buttonBase, 0.2 if .pressed in self.state else hoverTime * 0.1))
				PaintPillOutlineH(self.body, true, GetColor(.buttonBase))
				PaintLabel(info.label, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.buttonBase), .middle, .middle)
			
				case .subtle:
				PaintPillH(self.body, GetColor(.buttonBase, 0.2 if .pressed in self.state else hoverTime * 0.1))
				PaintLabel(info.label, {body.x + body.w / 2, body.y + body.h / 2}, GetColor(.buttonBase), .middle, .middle)
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
	join: RectSides,
	fitToLabel: bool,
	color: Maybe(Color),
	style: ButtonStyle,
}
Button :: proc(info: ButtonInfo, loc := #caller_location) -> (clicked: bool) {
	layout := CurrentLayout()
	if info.fitToLabel {
		LayoutFitLabel(layout, info.label)
	}
	if self, ok := Widget(HashId(loc), UseNextRect() or_else LayoutNext(layout)); ok {
		// Animations
		hoverTime := AnimateBool(self.id, .hovered in self.state, 0.1)
		// Cursor
		if .hovered in self.state {
			ctx.cursor = .hand
		}
		// Graphics
		if .shouldPaint in self.bits {
			color := info.color.? or_else GetColor(.buttonBase)
			switch info.style {
				case .filled:
				PaintRect(self.body, AlphaBlend(color, GetColor(.buttonShade), 0.3 if .pressed in self.state else hoverTime * 0.15))
				PaintLabelRect(info.label, self.body, GetColor(.buttonText), info.align.? or_else .middle, .middle)

				case .outlined:
				PaintRect(self.body, Fade(color, 0.2 if .pressed in self.state else hoverTime * 0.1))
				if .left in info.join {
					//PaintRect({self.body.x, self.body.y, 1, self.body.h}, color)
				} else {
					PaintRect({self.body.x, self.body.y, 1, self.body.h}, color)
				}
				if .right in info.join {
					//PaintRect({self.body.x + self.body.w - 1, self.body.y, 1, self.body.h}, color)
				} else {
					PaintRect({self.body.x + self.body.w - 1, self.body.y, 1, self.body.h}, color)
				}
				PaintRect({self.body.x, self.body.y, self.body.w, 1}, color)
				PaintRect({self.body.x, self.body.y + self.body.h - 1, self.body.w, 1}, color)
				
				PaintLabelRect(info.label, self.body, color, info.align.? or_else .middle, .middle)

				case .subtle:
				PaintRect(self.body, GetColor(.buttonBase, 0.2 if .pressed in self.state else hoverTime * 0.1))
				PaintLabelRect(info.label, self.body, color, info.align.? or_else .middle, .middle)
			}
		}
		// Result
		clicked = .clicked in self.state && self.clickButton == .left
	}
	return
}

// Square buttons that toggle something
ToggleButtonInfo :: struct {
	label: Label,
	state: bool,
	align: Maybe(Alignment),
	fitToLabel: bool,
}
ToggleButton :: proc(info: ToggleButtonInfo, loc := #caller_location) -> (clicked: bool) {
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
			if info.state {
				fillColor = StyleWidgetShaded(2 if .pressed in self.state else hoverTime)
			} else {
				fillColor = StyleBaseShaded(2 if .pressed in self.state else hoverTime)
			}
			PaintRect(self.body, fillColor)
			PaintRectLines(self.body, 1, GetColor(.widgetStroke if info.state else .baseStroke))
			PaintLabel(info.label, RectCenter(self.body), GetColor(.text), info.align.? or_else .middle, .middle)
		}
		// Result
		if .clicked in self.state && self.clickButton == .left {
			clicked = true
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
			center := linalg.round(RectCenter(self.body))
			PaintCircle(center, 12, 14, GetColor(.baseShade, (2 if self.state >= {.pressed} else hoverTime) * BASE_SHADE_ALPHA))
			PaintIconAligned(GetFontData(.default), icon, center, GetColor(.text, 0.5 + hoverTime * 0.5), .middle, .middle)
			PaintCircleOutlineTexture(center, 20, true, GetColor(.baseStroke))
		}
		// Result
		clicked = .clicked in self.state && self.clickButton == .left
	}
	return
}
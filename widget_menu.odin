package maui
import "core:runtime"
import "core:fmt"

AttachedLayerInfo :: struct {
	id: Id,
	rect: Rect,
	size: Vec2,
	layoutSize: Maybe(Vec2),
	side: RectSide,
	align: Maybe(Alignment),
	fillColor: Maybe(Color),
	strokeColor: Maybe(Color),
	layerOptions: LayerOptions,
}
AttachedLayerResult :: struct {
	dismissed: bool,
	self: ^LayerData,
}

// Main attached layer functionality
@private 
BeginAttachedLayer :: proc(info: AttachedLayerInfo) -> (result: AttachedLayerResult) {
	// Determine layout
	horizontal := info.side == .left || info.side == .right
	rect: Rect = AttachRect(info.rect, info.side, info.size.x if horizontal else info.size.y)

	rect.h = info.size.y

	if horizontal {
		if info.align == .middle {
			rect.y = info.rect.y + info.rect.h / 2 - info.size.y / 2
		} else if info.align == .far {
			rect.y = info.rect.y + info.rect.h - info.size.y
		}
	} else {
		if info.align == .middle {
			rect.x = info.rect.x + info.rect.w / 2 - info.size.x / 2
		} else if info.align == .far {
			rect.x = info.rect.x + info.rect.w - info.size.x
		}	
	}

	// Begin the new layer
	layer, active := BeginLayer({
		rect = rect, 
		id = info.id, 
		layoutSize = info.layoutSize.? or_else {},
		options = info.layerOptions + {.attached},
	})

	result.self = layer

	// Paint the fill color
	if info.fillColor != nil {
		PaintRect(layer.rect, info.fillColor.?)
	}

	// Check if the layer was dismissed by input
	if layer.bits >= {.dismissed} {
		result.dismissed = true
		return
	}

	return
}
@private
EndAttachedLayer :: proc(info: AttachedLayerInfo) {
	layer := CurrentLayer()
	if (.hovered not_in layer.state && .hovered not_in layer.parent.state && MousePressed(.left)) || KeyPressed(.escape) {
		layer.bits += {.dismissed}
	}

	// Paint stroke color
	if info.strokeColor != nil {
		PaintRectLines(layer.rect, 1, info.strokeColor.?)
	}

	// End the layer
	EndLayer(layer)
}

MenuInfo :: struct {
	label: Label,
	size: Vec2,
	align: Maybe(Alignment),
	menuAlign: Maybe(Alignment),
	side: Maybe(RectSide),
	layoutSize: Maybe(Vec2),
}
MenuResult :: struct {
	layerResult: AttachedLayerResult,
	active: bool,
}
// Menu starting point
@(deferred_out=_Menu)
Menu :: proc(info: MenuInfo, loc := #caller_location) -> (active: bool) {
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
			PaintLabelRect(info.label, body, GetColor(.text), info.align.? or_else .near, .middle)
		}

		// Expand/collapse on click
		if .gotPress in state {
			bits = bits ~ {.active}
		}


		// Begin layer if expanded
		if active {
			layerResult := BeginAttachedLayer({
				id = sharedId,
				rect = self.body,
				side = .bottom,
				size = info.size,
				layoutSize = info.layoutSize,
				align = info.menuAlign,
			})
			if layerResult.dismissed {
				//bits -= {.active}
			}
			if layerResult.self.state & {.hovered, .focused} == {} && .focused not_in state {
				bits -= {.active}
			}
			PushColor(.base, GetColor(.widget))
		}
	}
	return
}
@private 
_Menu :: proc(active: bool) {
	if active {
		EndAttachedLayer({
			strokeColor = GetColor(.baseStroke),
		})
		PopColor()
	}
}

// Options within menus
@(deferred_out=_SubMenu)
SubMenu :: proc(info: MenuInfo, loc := #caller_location) -> (active: bool) {
	sharedId := HashId(loc)
	if self, ok := Widget(sharedId, UseNextRect() or_else LayoutNext(CurrentLayout())); ok {
		using self
		active = .active in bits
		// Animation
		PushId(id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in state || active, 0.15)
		PopId()
		// Paint
		if .shouldPaint in bits {
			PaintRect(body, StyleWidgetShaded(hoverTime))
			PaintFlipArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, 0, GetColor(.text))
			PaintLabelRect(info.label, body, GetColor(.text), info.align.? or_else .near, .middle)
		}
		// Swap state when clicked
		if state & {.hovered, .lostHover} != {} {
			bits += {.active}
		} else if .hovered in self.layer.state && .gotHover not_in self.layer.state {
			bits -= {.active}
		}
		// Begin layer
		if active {
			layerResult := BeginAttachedLayer({
				id = sharedId,
				rect = self.body,
				side = .right,
				size = info.size,
				layoutSize = info.layoutSize,
				align = info.menuAlign,
				fillColor = GetColor(.widget),
			})
			if layerResult.self.state & {.hovered, .lostHover} != {} {
				bits += {.active}
			}
			if layerResult.dismissed {
				bits -= {.active}
			}
		}
	}
	return
}
@private
_SubMenu :: proc(active: bool) {
	if active {
		EndAttachedLayer({
			strokeColor = GetColor(.baseStroke),
		})
	}
}

AttachedMenuInfo :: struct {
	parent: ^WidgetData,
	size: Vec2,
	align: Alignment,
	side: RectSide,
	layerOptions: LayerOptions,
	showArrow: bool,
}
// Attach a menu to a widget (opens when focused)
@(deferred_out=_AttachMenu)
AttachMenu :: proc(info: AttachedMenuInfo) -> (ok: bool) {
	if info.parent != nil {
		if info.parent.bits >= {.menuOpen} {

			horizontal := info.side == .left || info.side == .right
			rect: Rect = AttachRect(info.parent.body, info.side, info.size.x if horizontal else info.size.y)

			rect.w = info.size.x
			rect.h = info.size.y

			if horizontal {
				if info.align == .middle {
					rect.y = info.parent.body.y + info.parent.body.h / 2 - info.size.y / 2
				} else if info.align == .far {
					rect.y = info.parent.body.y + info.parent.body.h - info.size.y
				}
			} else {
				if info.align == .middle {
					rect.x = info.parent.body.x + info.parent.body.w / 2 - info.size.x / 2
				} else if info.align == .far {
					rect.x = info.parent.body.x + info.parent.body.w - info.size.x
				}	
			}

			// Begin the new layer
			layer: ^LayerData
			layer, ok = BeginLayer({
				rect = rect, 
				id = info.parent.id, 
				layoutSize = info.size,
				options = info.layerOptions + {.attached},
			})
			
			if ok {
				if info.showArrow {
					switch info.side {
						case .bottom: Cut(.top, 15)
						case .right: Cut(.left, 15)
						case .left, .top:
					}
				}
				layoutRect := CurrentLayout().rect
				PaintRect(layoutRect, GetColor(.base))
				PaintRectLines(CurrentLayout().rect, 1, GetColor(.baseStroke))
				if info.showArrow {
					center := RectCenter(info.parent.body)
					switch info.side {
						case .bottom:
						a, b, c: Vec2 = {center.x, layoutRect.y - 9}, {center.x - 8, layoutRect.y + 1}, {center.x + 8, layoutRect.y + 1}
						PaintTriangle(a, b, c, GetColor(.base))
						PaintLine(a, b, 1, GetColor(.baseStroke))
						PaintLine(c, a, 1, GetColor(.baseStroke))
						case .right:
						a, b, c: Vec2 = {layoutRect.x - 9, center.y}, {layoutRect.x + 1, center.y - 8}, {layoutRect.x - 1, center.y + 8}
						PaintTriangle(a, b, c, GetColor(.base))
						PaintLine(a, b, 1, GetColor(.baseStroke))
						PaintLine(c, a, 1, GetColor(.baseStroke))
						case .left, .top:
					}
				}
				PushLayout(layoutRect)
			}
			if ctx.focusId != ctx.prevFocusId && ctx.focusId != info.parent.id && ctx.focusId not_in layer.contents {
				info.parent.bits -= {.menuOpen}
			}
		} else if info.parent.state >= {.gotFocus} {
			info.parent.bits += {.menuOpen}
		}
	}
	return 
}
@private 
_AttachMenu :: proc(ok: bool) {
	if ok {
		layer := CurrentLayer()
		PopLayout()
		EndLayer(layer)
	}
}

OptionInfo :: struct {
	label: Label,
	active: bool,
	align: Maybe(Alignment),
	noDismiss: bool,
}
Option :: proc(info: OptionInfo, loc := #caller_location) -> (clicked: bool) {
	if self, ok := Widget(HashId(loc), LayoutNext(CurrentLayout())); ok {
		// Animation
		PushId(self.id)
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in self.state, 0.1)
		PopId()
		// Painting
		if .shouldPaint in self.bits {
			PaintRect(self.body, StyleWidgetShaded(2 if .pressed in self.state else hoverTime))
			PaintLabelRect(info.label, self.body, GetColor(.text), info.align.? or_else .near, .middle)
			if info.active {
				PaintIconAligned(GetFontData(.header), .check, {self.body.x + self.body.w - self.body.h / 2, self.body.y + self.body.h / 2}, GetColor(.text), .middle, .middle)
			}
		}
		// Dismiss the root menu
		if .clicked in self.state && self.clickButton == .left {
			clicked = true
			layer := CurrentLayer()
			if !info.noDismiss {
				layer.bits += {.dismissed}
			}
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
			if Option({label = TextCapitalize(Format(member))}) {
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
			if Option({label = TextCapitalize(Format(member)), active = member in set}) {
				newSet = newSet ~ {member}
			}
		PopId()
	}
	return
}
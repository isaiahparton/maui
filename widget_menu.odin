package maui
import "core:runtime"
import "core:fmt"

Attached_Layer_Info :: struct {
	id: Id,
	box: Box,
	size: [2]f32,
	layout_size: Maybe([2]f32),
	side: Box_Side,
	align: Maybe(Alignment),
	fill_color: Maybe(Color),
	stroke_color: Maybe(Color),
	layer_options: Layer_Options,
}
Attached_Layer_Result :: struct {
	dismissed: bool,
	self: ^Layer,
}

// Main attached layer functionality
@private 
begin_attached_layer :: proc(info: Attached_Layer_Info) -> (result: Attached_Layer_Result) {
	// Determine layout
	horizontal := info.side == .left || info.side == .right
	box: Box = attach_box(info.box, info.side, info.size.x if horizontal else info.size.y)

	box.h = info.size.y

	if horizontal {
		if info.align == .middle {
			box.y = info.box.y + info.box.h / 2 - info.size.y / 2
		} else if info.align == .far {
			box.y = info.box.y + info.box.h - info.size.y
		}
	} else {
		if info.align == .middle {
			box.x = info.box.x + info.box.w / 2 - info.size.x / 2
		} else if info.align == .far {
			box.x = info.box.x + info.box.w - info.size.x
		}	
	}

	// Begin the new layer
	layer, active := begin_layer({
		box = box, 
		id = info.id, 
		layout_size = info.layout_size.? or_else {},
		options = info.layer_options + {.attached},
	})
	assert(layer != nil)
	result.self = layer

	// Paint the fill color
	if info.fill_color != nil {
		paint_box(layer.box, info.fill_color.?)
	}

	// Check if the layer was dismissed by input
	if layer.bits >= {.dismissed} {
		result.dismissed = true
		return
	}

	return
}
@private
end_attached_layer :: proc(info: Attached_Layer_Info) {
	layer := current_layer()
	if (.hovered not_in layer.state && .hovered not_in layer.parent.state && MousePressed(.left)) || KeyPressed(.escape) {
		layer.bits += {.dismissed}
	}	

	// Paint stroke color
	if info.stroke_color != nil {
		paint_box_stroke(layer.box, 1, info.stroke_color.?)
	}

	// End the layer
	end_layer(layer)
}

Menu_Info :: struct {
	label: Label,
	size: [2]f32,
	align: Maybe(Alignment),
	menu_align: Maybe(Alignment),
	side: Maybe(Box_Side),
	layout_size: Maybe([2]f32),
}
Menu_Result :: struct {
	layer_result: Attached_Layer_Result,
	active: bool,
}
// Menu starting point
@(deferred_out=_menu)
menu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	sharedId := hash(loc)
	if self, ok := Widget(sharedId, UseNextBox() or_else LayoutNext(current_layout())); ok {
		using self
		active = .active in bits
		// Animation
		push_id(id) 
			hoverTime := animate_bool(hash_int(0), .hovered in state, 0.15)
			stateTime := animate_bool(hash_int(2), active, 0.125)
		pop_id()
		// Painting
		if .shouldPaint in bits {
			paint_box(body, alpha_blend_colors(get_color(.widgetBackground), get_color(.widgetShade), 0.2 if .pressed in state else hoverTime * 0.1))
			paint_boxLines(body, 1, get_color(.baseStroke))
			paint_rotating_arrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, -1 + stateTime, get_color(.text))
			paint_label_box(info.label, body, get_color(.text), info.align.? or_else .near, .middle)
		}
		// Expand/collapse on click
		if .gotPress in state {
			bits = bits ~ {.active}
		}
		// Begin layer if expanded
		if active {
			layerResult := begin_attached_layer({
				id = sharedId,
				box = self.body,
				side = .bottom,
				size = info.size,
				layout_size = info.layout_size,
				align = info.menuAlign,
			})
			if layerResult.dismissed {
				bits -= {.active}
			} else if layerResult.self.state & {.hovered, .focused} == {} && .focused not_in state {
				bits -= {.active}
			}
			PushColor(.base, get_color(.widgetBackground))
		}
	}
	return
}
@private 
_menu :: proc(active: bool) {
	if active {
		EndAttachedLayer({
			stroke_color = get_color(.baseStroke),
		})
		PopColor()
	}
}

// Options within menus
@(deferred_out=_SubMenu)
SubMenu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	sharedId := hash(loc)
	if self, ok := Widget(sharedId, UseNextBox() or_else LayoutNext(current_layout())); ok {
		using self
		active = .active in bits
		// Animation
		hoverTime := animate_bool(self.id, .hovered in state || active, 0.15)
		// Paint
		if .shouldPaint in bits {
			paint_box(body, alpha_blend_colors(get_color(.widgetBackground), get_color(.widgetShade), 0.2 if .pressed in state else hoverTime * 0.1))
			PaintFlipArrow({body.x + body.w - body.h / 2, body.y + body.h / 2}, 8, 0, get_color(.text))
			paint_label_box(info.label, body, get_color(.text), info.align.? or_else .near, .middle)
		}
		// Swap state when clicked
		if state & {.hovered, .lostHover} != {} {
			bits += {.active}
		} else if .hovered in self.layer.state && .gotHover not_in self.layer.state {
			bits -= {.active}
		}
		// Begin layer
		if active {
			layerResult := begin_attached_layer({
				id = sharedId,
				box = self.body,
				side = .right,
				size = info.size,
				layout_size = info.layout_size,
				align = info.menuAlign,
				fill_color = get_color(.widgetBackground),
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
			stroke_color = get_color(.baseStroke),
		})
	}
}

AttachedMenu_Info :: struct {
	parent: ^Widget,
	size: [2]f32,
	align: Alignment,
	side: Box_Side,
	layer_options: Layer_Options,
	showArrow: bool,
}
// Attach a menu to a widget (opens when focused)
@(deferred_out=_AttachMenu)
AttachMenu :: proc(info: AttachedMenu_Info) -> (ok: bool) {
	if info.parent != nil {
		if info.parent.bits >= {.menuOpen} {

			horizontal := info.side == .left || info.side == .right
			box: Box = attach_box(info.parent.body, info.side, info.size.x if horizontal else info.size.y)

			box.w = info.size.x
			box.h = info.size.y

			if horizontal {
				if info.align == .middle {
					box.y = info.parent.body.y + info.parent.body.h / 2 - info.size.y / 2
				} else if info.align == .far {
					box.y = info.parent.body.y + info.parent.body.h - info.size.y
				}
			} else {
				if info.align == .middle {
					box.x = info.parent.body.x + info.parent.body.w / 2 - info.size.x / 2
				} else if info.align == .far {
					box.x = info.parent.body.x + info.parent.body.w - info.size.x
				}	
			}

			// Begin the new layer
			layer: ^Layer
			layer, ok = begin_layer({
				box = box, 
				id = info.parent.id, 
				layout_size = info.size,
				options = info.layer_options + {.attached},
			})
			
			if ok {
				if info.showArrow {
					switch info.side {
						case .bottom: Cut(.top, 15)
						case .right: Cut(.left, 15)
						case .left, .top:
					}
				}
				layoutBox := current_layout().box
				paint_box(layoutBox, get_color(.base))
				paint_boxLines(current_layout().box, 1, get_color(.baseStroke))
				if info.showArrow {
					center := BoxCenter(info.parent.body)
					switch info.side {
						case .bottom:
						a, b, c: [2]f32 = {center.x, layoutBox.y - 9}, {center.x - 8, layoutBox.y + 1}, {center.x + 8, layoutBox.y + 1}
						PaintTriangle(a, b, c, get_color(.base))
						PaintLine(a, b, 1, get_color(.baseStroke))
						PaintLine(c, a, 1, get_color(.baseStroke))
						case .right:
						a, b, c: [2]f32 = {layoutBox.x - 9, center.y}, {layoutBox.x + 1, center.y - 8}, {layoutBox.x - 1, center.y + 8}
						PaintTriangle(a, b, c, get_color(.base))
						PaintLine(a, b, 1, get_color(.baseStroke))
						PaintLine(c, a, 1, get_color(.baseStroke))
						case .left, .top:
					}
				}
				push_layout(layoutBox)
			}
			if core.focusId != core.prevFocusId && core.focusId != info.parent.id && core.focusId not_in layer.contents {
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
		layer := current_layer()
		pop_layout()
		end_layer(layer)
	}
}

OptionInfo :: struct {
	label: Label,
	active: bool,
	align: Maybe(Alignment),
	noDismiss: bool,
}
Option :: proc(info: OptionInfo, loc := #caller_location) -> (clicked: bool) {
	if self, ok := Widget(hash(loc), LayoutNext(current_layout())); ok {
		// Animation
		hoverTime := animate_bool(self.id, .hovered in self.state, 0.1)
		// Painting
		if .shouldPaint in self.bits {
			paint_box(self.body, alpha_blend_colors(get_color(.widgetBackground), get_color(.widgetShade), 0.2 if .pressed in self.state else hoverTime * 0.1))
			paint_label_box(info.label, self.body, get_color(.text), info.align.? or_else .near, .middle)
			if info.active {
				PaintIconAligned(GetFontData(.header), .check, {self.body.x + self.body.w - self.body.h / 2, self.body.y + self.body.h / 2}, get_color(.text), .middle, .middle)
			}
		}
		// Dismiss the root menu
		if .clicked in self.state && self.clickButton == .left {
			clicked = true
			layer := current_layer()
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
		push_id(hash_int(int(member)))
			if Option({label = TextCapitalize(Format(member))}) {
				newValue = member
			}
		pop_id()
	}
	return
}
BitSetMenuOptions :: proc(set: $S/bit_set[$E;$U], loc := #caller_location) -> (newSet: S) {
	newSet = set
	for member in E {
		push_id(hash_int(int(member)))
			if Option({label = TextCapitalize(Format(member)), active = member in set}) {
				newSet = newSet ~ {member}
			}
		pop_id()
	}
	return
}
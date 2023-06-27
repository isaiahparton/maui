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
		paint_box_fill(layer.box, info.fill_color.?)
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
	if (.hovered not_in layer.state && .hovered not_in layer.parent.state && mouse_pressed(.left)) || key_pressed(.escape) {
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
@(deferred_out=_do_menu)
do_menu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id, use_next_box() or_else layout_next(current_layout())); ok {
		using self
		active = .active in bits
		// Animation
		push_id(id) 
			hover_time := animate_bool(hash_int(0), .hovered in state, 0.15)
			state_time := animate_bool(hash_int(2), active, 0.125)
		pop_id()
		// Painting
		if .should_paint in bits {
			paint_box_fill(box, alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), 0.2 if .pressed in state else hover_time * 0.1))
			paint_box_stroke(box, 1, get_color(.base_stroke, 0.5 + 0.5 * hover_time))
			paint_rotating_arrow({box.x + box.w - box.h / 2, box.y + box.h / 2}, 6, -1 + state_time, get_color(.text))
			paint_label_box(info.label, shrink_box_separate(box, {box.h * 0.25, 0}), get_color(.text), {info.align.? or_else .near, .middle})
		}
		// Expand/collapse on click
		if .got_press in state {
			bits = bits ~ {.active}
		}
		// Begin layer if expanded
		if active {
			layer_result := begin_attached_layer({
				id = shared_id,
				box = self.box,
				side = .bottom,
				size = info.size,
				layout_size = info.layout_size,
				align = info.menu_align,
			})
			if layer_result.dismissed {
				bits -= {.active}
			} else if layer_result.self.state & {.hovered, .focused} == {} && .focused not_in state {
				bits -= {.active}
			}
			push_color(.base, get_color(.widget_bg))
		}
	}
	return
}
@private 
_do_menu :: proc(active: bool) {
	if active {
		end_attached_layer({
			stroke_color = get_color(.base_stroke),
		})
		pop_color()
	}
}

// Options within menus
@(deferred_out=_submenu)
submenu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id, use_next_box() or_else layout_next(current_layout())); ok {
		using self
		active = .active in bits
		// Animation
		hover_time := animate_bool(self.id, .hovered in state || active, 0.15)
		// Paint
		if .should_paint in bits {
			paint_box_fill(box, alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), 0.2 if .pressed in state else hover_time * 0.1))
			paint_flipping_arrow({box.x + box.w - box.h / 2, box.y + box.h / 2}, 8, 0, get_color(.text))
			paint_label_box(info.label, box, get_color(.text), {info.align.? or_else .near, .middle})
		}
		// Swap state when clicked
		if state & {.hovered, .lost_hover} != {} {
			bits += {.active}
		} else if .hovered in self.layer.state && .got_hover not_in self.layer.state {
			bits -= {.active}
		}
		// Begin layer
		if active {
			layer_result := begin_attached_layer({
				id = shared_id,
				box = self.box,
				side = .right,
				size = info.size,
				layout_size = info.layout_size,
				align = info.menu_align,
				fill_color = get_color(.widget_bg),
			})
			if layer_result.self.state & {.hovered, .lost_hover} != {} {
				bits += {.active}
			}
			if layer_result.dismissed {
				bits -= {.active}
			}
		}
	}
	return
}
@private
_submenu :: proc(active: bool) {
	if active {
		end_attached_layer({
			stroke_color = get_color(.base_stroke),
		})
	}
}

Attached_Menu_Info :: struct {
	parent: ^Widget,
	size: [2]f32,
	align: Alignment,
	side: Box_Side,
	layer_options: Layer_Options,
	show_arrow: bool,
}
// Attach a menu to a widget (opens when focused)
@(deferred_out=_attach_menu)
attach_menu :: proc(info: Attached_Menu_Info) -> (ok: bool) {
	if info.parent != nil {
		if info.parent.bits >= {.menu_open} {

			horizontal := info.side == .left || info.side == .right
			box: Box = attach_box(info.parent.box, info.side, info.size.x if horizontal else info.size.y)

			box.w = info.size.x
			box.h = info.size.y

			if horizontal {
				if info.align == .middle {
					box.y = info.parent.box.y + info.parent.box.h / 2 - info.size.y / 2
				} else if info.align == .far {
					box.y = info.parent.box.y + info.parent.box.h - info.size.y
				}
			} else {
				if info.align == .middle {
					box.x = info.parent.box.x + info.parent.box.w / 2 - info.size.x / 2
				} else if info.align == .far {
					box.x = info.parent.box.x + info.parent.box.w - info.size.x
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
				if info.show_arrow {
					switch info.side {
						case .bottom: cut(.top, 15)
						case .right: cut(.left, 15)
						case .left, .top:
					}
				}
				layout_box := current_layout().box
				paint_box_fill(layout_box, get_color(.base))
				paint_box_stroke(current_layout().box, 1, get_color(.base_stroke))
				if info.show_arrow {
					center := box_center(info.parent.box)
					switch info.side {
						case .bottom:
						a, b, c: [2]f32 = {center.x, layout_box.y - 9}, {center.x - 8, layout_box.y + 1}, {center.x + 8, layout_box.y + 1}
						paint_triangle_fill(a, b, c, get_color(.base))
						paint_line(a, b, 1, get_color(.base_stroke))
						paint_line(c, a, 1, get_color(.base_stroke))
						case .right:
						a, b, c: [2]f32 = {layout_box.x - 9, center.y}, {layout_box.x + 1, center.y - 8}, {layout_box.x - 1, center.y + 8}
						paint_triangle_fill(a, b, c, get_color(.base))
						paint_line(a, b, 1, get_color(.base_stroke))
						paint_line(c, a, 1, get_color(.base_stroke))
						case .left, .top:
					}
				}
				push_layout(layout_box)
			}
			if core.widget_agent.focus_id != core.widget_agent.last_focus_id && core.widget_agent.focus_id != info.parent.id && core.widget_agent.focus_id not_in layer.contents {
				info.parent.bits -= {.menu_open}
			}
		} else if info.parent.state >= {.got_focus} {
			info.parent.bits += {.menu_open}
		}
	}
	return 
}
@private 
_attach_menu :: proc(ok: bool) {
	if ok {
		layer := current_layer()
		pop_layout()
		end_layer(layer)
	}
}

Option_Info :: struct {
	label: Label,
	active: bool,
	align: Maybe(Alignment),
	no_dismiss: bool,
}
option :: proc(info: Option_Info, loc := #caller_location) -> (clicked: bool) {
	if self, ok := do_widget(hash(loc), layout_next(current_layout())); ok {
		// Animation
		hover_time := animate_bool(self.id, .hovered in self.state, 0.1)
		// Painting
		if .should_paint in self.bits {
			paint_box_fill(self.box, alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), 0.2 if .pressed in self.state else hover_time * 0.1))
			paint_label_box(info.label, shrink_box_separate(self.box, {self.box.h * 0.25, 0}), get_color(.text), {info.align.? or_else .near, .middle})
			if info.active {
				paint_aligned_icon(get_font_data(.header), .Check, {self.box.x + self.box.w - self.box.h / 2, self.box.y + self.box.h / 2}, 1, get_color(.text), {.middle, .middle})
			}
		}
		// Dismiss the root menu
		if widget_clicked(self, .left) {
			clicked = true
			layer := current_layer()
			if !info.no_dismiss {
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
enum_options :: proc(
	value: $T, 
	loc := #caller_location,
) -> (new_value: T) {
	new_value = value
	for member in T {
		push_id(hash_int(int(member)))
			if option({label = text_capitalize(format(member))}) {
				new_value = member
			}
		pop_id()
	}
	return
}
bit_set_options :: proc(set: $S/bit_set[$E;$U], loc := #caller_location) -> (newSet: S) {
	newSet = set
	for member in E {
		push_id(hash_int(int(member)))
			if option({label = text_capitalize(format(member)), active = member in set}) {
				newSet = newSet ~ {member}
			}
		pop_id()
	}
	return
}
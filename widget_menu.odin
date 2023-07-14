package maui
import "core:runtime"
import "core:fmt"

Attached_Layer_Parent :: union {
	Box,
	^Widget,
}

Attached_Layer_Info :: struct {
	id: Maybe(Id),
	parent: Attached_Layer_Parent,
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
begin_attached_layer :: proc(info: Attached_Layer_Info) -> (result: Attached_Layer_Result, ok: bool) {
	if widget, is_widget := info.parent.(^Widget); is_widget {
		ok = .menu_open in widget.bits
		if .got_press in widget.state {
			widget.bits ~= {.menu_open}
		}
	}
	if ok {
		// Determine layout
		horizontal := info.side == .left || info.side == .right
		anchor_box := info.parent.(Box) or_else info.parent.(^Widget).box

		box: Box = attach_box(anchor_box, info.side, info.size.x if horizontal else info.size.y)

		if horizontal {
			box.h = max(info.size.y, anchor_box.h)
			if info.align == .middle {
				box.y = anchor_box.y + anchor_box.h / 2 - info.size.y / 2
			} else if info.align == .far {
				box.y = anchor_box.y + anchor_box.h - info.size.y
			}
		} else {
			box.w = max(info.size.x, anchor_box.w)
			if info.align == .middle {
				box.x = anchor_box.x + anchor_box.w / 2 - info.size.x / 2
			} else if info.align == .far {
				box.x = anchor_box.x + anchor_box.w - info.size.x
			}	
		}

		// Begin the new layer
		result.self, ok = begin_layer({
			id = info.id.? or_else info.parent.(^Widget).id, 
			box = box, 
			layout_size = info.layout_size.? or_else {},
			options = info.layer_options + {.attached},
			shadow = Layer_Shadow_Info({
				offset = SHADOW_OFFSET,
			}),
		})

		if ok {
			// Paint the fill color
			if info.fill_color != nil {
				paint_box_fill(result.self.box, info.fill_color.?)
			}

			// Check if the layer was dismissed by input
			if widget, ok := info.parent.(^Widget); ok {
				if .dismissed in result.self.bits || (.focused not_in result.self.state && .focused not_in widget.state) {
					widget.bits -= {.menu_open}
					core.paint_next_frame = true
				}
			}
		}
	}
	return
}

@private
end_attached_layer :: proc(info: Attached_Layer_Info, layer: ^Layer) {
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

@(deferred_in_out=_do_attached_layer)
do_attached_layer :: proc(info: Attached_Layer_Info) -> (result: Attached_Layer_Result, ok: bool) {
	return begin_attached_layer(info)
}
_do_attached_layer :: proc(info: Attached_Layer_Info, result: Attached_Layer_Result, ok: bool) {
	if ok {
		end_attached_layer(info, result.self)
	}
}

Menu_Info :: struct {
	label: Label,
	title: Maybe(string),
	size: [2]f32,
	align: Maybe(Alignment),
	side: Maybe(Box_Side),
	layer_align: Maybe(Alignment),
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
		// Animation
		push_id(id) 
			hover_time := animate_bool(hash_int(0), .hovered in state, 0.15)
			state_time := animate_bool(hash_int(1), active, 0.125)
		pop_id()
		// Painting
		if .should_paint in bits {
			paint_box_fill(box, alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), 0.2 if .pressed in state else hover_time * 0.1))
			paint_labeled_widget_frame(box, info.title, WIDGET_TEXT_OFFSET, 1, get_color(.base_stroke, 0.5 + 0.5 * hover_time))
			paint_rotating_arrow({box.x + box.w - box.h / 2, box.y + box.h / 2}, 6, -1 + state_time, get_color(.text))
			paint_label_box(info.label, shrink_box_separate(box, {box.h * 0.25, 0}), get_color(.text), {info.align.? or_else .near, .middle})
		}
		// Begin layer if expanded
		result: Attached_Layer_Result
		result, active = begin_attached_layer({
			id = shared_id,
			parent = self,
			side = .bottom,
			size = info.size,
			layout_size = info.layout_size,
			align = info.layer_align,
		})
		if active {
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
		}, current_layer())
		pop_color()
	}
}

// Options within menus
@(deferred_out=_do_submenu)
do_submenu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
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
			layer_result, _ := begin_attached_layer({
				id = shared_id,
				parent = self.box,
				side = .right,
				size = info.size,
				layout_size = info.layout_size,
				align = info.layer_align,
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
_do_submenu :: proc(active: bool) {
	if active {
		end_attached_layer({
			stroke_color = get_color(.base_stroke),
		}, current_layer())
	}
}

Option_Info :: struct {
	label: Label,
	active: bool,
	align: Maybe(Alignment),
	no_dismiss: bool,
}

do_option :: proc(info: Option_Info, loc := #caller_location) -> (clicked: bool) {
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

do_enum_options :: proc(value: $T, loc := #caller_location) -> (result: Maybe(T)) {
	for member in T {
		push_id(hash_int(int(member)))
			if do_option({label = text_capitalize(format(member))}) {
				result = member
			}
		pop_id()
	}
	return
}

do_bit_set_options :: proc(set: $S/bit_set[$E;$U], loc := #caller_location) -> (newSet: S) {
	newSet = set
	for member in E {
		push_id(hash_int(int(member)))
			if do_option({label = text_capitalize(format(member)), active = member in set}) {
				newSet = newSet ~ {member}
			}
		pop_id()
	}
	return
}
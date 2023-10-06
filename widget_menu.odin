package maui
import "core:runtime"
import "core:math"
import "core:fmt"

Attached_Layer_Parent :: union {
	Box,
	^Widget,
}

Attached_Layer_Mode :: enum {
	Focus,
	Hover,
}

Attached_Layer_Info :: struct {
	id: Maybe(Id),
	mode: Attached_Layer_Mode,
	parent: Attached_Layer_Parent,
	size: [2]f32,
	layout_size: Maybe([2]f32),
	extend: Maybe(Box_Side),
	side: Maybe(Box_Side),
	align: Maybe(Alignment),
	fill_color: Maybe(Color),
	stroke_color: Maybe(Color),
	layer_options: Layer_Options,
	opacity: Maybe(f32),
}

Attached_Layer_Result :: struct {
	dismissed: bool,
	self: ^Layer,
}

// Main attached layer functionality
@private 
begin_attached_layer :: proc(info: Attached_Layer_Info) -> (result: Attached_Layer_Result, ok: bool) {
	if widget, is_widget := info.parent.(^Widget); is_widget {
		ok = .Menu_Open in widget.bits
		if .Menu_Open not_in widget.bits {
			switch info.mode {
				case .Focus:
				if .Focused in widget.state && .Menu_Open not_in widget.bits {
					widget.bits += {.Menu_Open}
				}
				case .Hover:
				if .Hovered in widget.state && .Menu_Open not_in widget.bits {
					widget.bits += {.Menu_Open}
				}
			}
		}
	}
	if ok {
		side := info.side.? or_else .Bottom
		// Determine layout
		horizontal := side == .Left || side == .Right
		anchor := info.parent.(Box) or_else info.parent.(^Widget).box

		box: Box = attach_box(anchor, side, info.size.x if horizontal else info.size.y)

		if horizontal {
			h := max(info.size.y, height(anchor))
			if info.extend == .Top {
				box.low.y += height(anchor)
			}
			if info.align == .Middle {
				box.low.y = (anchor.low.y + anchor.high.y) / 2 - info.size.y / 2
			} else if info.align == .Far {
				box.low.y = anchor.high.y - info.size.y
			}
			box.high.y = box.low.y + h
		} else {
			w := max(info.size.x, width(anchor))
			if info.extend == .Left {
				box.low.x += width(anchor)
			}
			if info.align == .Middle {
				box.low.x = (anchor.low.x + anchor.high.x) / 2 - info.size.x / 2
			} else if info.align == .Far {
				box.low.x = anchor.high.y - info.size.x
			}	
			box.high.x = box.low.x + w
		}
		if info.extend != nil {
			box.high.y = box.low.y
		}

		// Begin the new layer
		result.self, ok = begin_layer({
			id = info.id.? or_else info.parent.(^Widget).id, 
			box = box,
			layout_size = info.layout_size.? or_else {},
			extend = info.extend,
			options = info.layer_options,
			opacity = info.opacity,
			owner = info.parent.(^Widget) or_else nil,
			shadow = Layer_Shadow_Info({
				offset = SHADOW_OFFSET,
			}),
		})

		if ok {
			// Paint the fill color
			if info.fill_color != nil {
				paint_box_fill(result.self.box, info.fill_color.?)
			}
		}
	}
	return
}

@private
end_attached_layer :: proc(info: Attached_Layer_Info, layer: ^Layer) {
	// Check if the layer was dismissed by input
	if widget, ok := layer.owner.?; ok {
		dismiss: bool
		switch info.mode {
			case .Focus:
			dismiss = widget.state & {.Focused, .Lost_Focus} == {} && layer.next_state & {.Focused} == {} && layer.state & {.Focused} == {}
			case .Hover:
			dismiss = .Hovered not_in widget.state && layer.next_state & {.Hovered} == {} && layer.state & {.Hovered, .Lost_Hover} == {}
		}
		if .Dismissed in layer.bits || dismiss || key_pressed(.Escape) {
			widget.bits -= {.Menu_Open}
			core.paint_next_frame = true
			if dismiss {
				core.open_menus = false
			}
		}
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
	if self, ok := do_widget(shared_id); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update state
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		open_time := animate_bool(&self.timers[1], .Menu_Open in self.bits, 0.15)
		// Painting
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1))
			paint_labeled_widget_frame(self.box, info.title, WIDGET_TEXT_OFFSET, 1, get_color(.Base_Stroke, 0.5 + 0.5 * hover_time))
			paint_label_box(info.label, shrink_box_double(self.box, {WIDGET_TEXT_OFFSET, 0}), get_color(.Text), .Left, .Middle)
			paint_arrow_flip({self.box.high.x - height(self.box) * 0.5, center_y(self.box)}, height(self.box) * 0.25, 0, ICON_STROKE_THICKNESS, open_time, get_color(.Text))
		}
		// Begin layer if expanded
		_, active = begin_attached_layer({
			id = shared_id,
			parent = self,
			side = .Bottom,
			size = info.size,
			layout_size = info.layout_size,
			extend = .Bottom,
			align = info.layer_align,
			opacity = open_time,
		})
		// Push background color
		if active {
			push_color(.Base, get_color(.Widget_Back))
		}
		// Update hovered state
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
@private 
_do_menu :: proc(active: bool) {
	if active {
		end_attached_layer({
			stroke_color = get_color(.Base_Stroke),
		}, current_layer())
		pop_color()
	}
}

// Options within menus
@(deferred_out=_do_submenu)
do_submenu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id); ok {
		// Get box
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		open_time := animate_bool(&self.timers[1], .Menu_Open in self.bits, 0.15)
		// Paint
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1))
			label_box := self.box
			icon_box := cut_box_left(&label_box, height(label_box))
			paint_label_box(info.label, label_box, get_color(.Text), .Left, .Middle)
			paint_arrow_flip({self.box.high.x - height(self.box) * 0.5, center_y(self.box)}, height(self.box) * 0.25, -0.5 * math.PI, ICON_STROKE_THICKNESS, open_time, get_color(.Text))
		}
		// Begin layer
		_, active = begin_attached_layer({
			id = shared_id,
			mode = .Hover,
			parent = self,
			side = info.side.? or_else .Right,
			size = info.size,
			layout_size = info.layout_size,
			extend = .Bottom,
			align = info.layer_align,
			layer_options = {.Attached},
			opacity = open_time,
		})
		// Push background color
		if active {
			push_color(.Base, get_color(.Widget_Back))
		}
		// Update hover state with own box
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
@private
_do_submenu :: proc(active: bool) {
	if active {
		end_attached_layer({
			mode = .Hover,
			stroke_color = get_color(.Base_Stroke),
		}, current_layer())
		pop_color()
	}
}

Option_Info :: struct {
	label: Label,
	active: bool,
	align: Maybe(Alignment),
	no_dismiss: bool,
}

do_option :: proc(info: Option_Info, loc := #caller_location) -> (clicked: bool) {
	if self, ok := do_widget(hash(loc)); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		// Painting
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1))
			label_box := self.box
			icon_box := cut_box_left(&label_box, height(label_box))
			if info.active || true {
				// Paint check mark
				center := box_center(icon_box)
				scale: f32 = 5.5
				a, b, c: [2]f32 = {-1, -0.047} * scale, {-0.333, 0.619} * scale, {1, -0.713} * scale
				stroke_path({center + a, center + b, center + c}, false, ICON_STROKE_THICKNESS, get_color(.Text))
			}
			// Paint label
			paint_label_box(info.label, label_box, get_color(.Text), .Left, .Middle)
		}
		// Dismiss the root menu
		if widget_clicked(self, .Left) {
			clicked = true
			layer := current_layer()
			if !info.no_dismiss {
				layer.bits += {.Dismissed}
			}
			for layer.parent != nil && layer.options >= {.Attached} {
				layer = layer.parent
				layer.bits += {.Dismissed}
			}
		}
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
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
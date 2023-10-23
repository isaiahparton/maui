package maui_widgets
import "../"

import "core:runtime"
import "core:math"
import "core:fmt"

Menu_Info :: struct {
	label: maui.Label,
	title: Maybe(string),
	size: [2]f32,
	align: Maybe(maui.Alignment),
	side: Maybe(maui.Box_Side),
	layer_align: Maybe(maui.Alignment),
}

Menu_Result :: struct {
	layer_result: maui.Attached_Layer_Result,
	active: bool,
}

// Menu starting point
@(deferred_out=_do_menu)
do_menu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	using maui
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update state
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		open_time := animate_bool(&self.timers[2], .Menu_Open in self.bits, 0.175)
		// Painting
		if .Should_Paint in self.bits {
			inner_box := shrink_box(self.box, 1)
			// Body
			paint_shaded_box(inner_box, {style.color.extrusion_light, style.color.extrusion, style.color.extrusion_dark})
			// Outline
			paint_box_stroke(self.box, 1, alpha_blend_colors(style.color.base_stroke, style.color.status, press_time))
			// Interaction Shading
			paint_box_fill(inner_box, alpha_blend_colors(fade(255, hover_time * 0.1), style.color.status, press_time * 0.5))
			// Label
			paint_label_box(info.label, self.box, style.color.text, .Middle, .Middle)
		}
		// Begin layer if expanded
		if res, ok := begin_attached_layer({
			id = shared_id,
			parent = self,
			side = .Bottom,
			extend = .Bottom,
			size = info.size,
			align = info.layer_align,
			opacity = open_time,
		}); ok {
			paint_box_fill(res.self.box, style.color.base)
			active = true
		}
		// Update hovered state
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
@private 
_do_menu :: proc(active: bool) {
	using maui
	if active {
		end_attached_layer({
			stroke_color = style.color.base_stroke,
		}, current_layer())
	}
}
/*
// Options within menus
@(deferred_out=_do_submenu)
do_submenu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	using maui
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
			extend = .Bottom,
			size = info.size,
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
	using maui
	if active {
		end_attached_layer({
			mode = .Hover,
			stroke_color = get_color(.Base_Stroke),
		}, current_layer())
		pop_color()
	}
}
*/

Option_Info :: struct {
	label: maui.Label,
	active: bool,
	align: Maybe(maui.Alignment),
	no_dismiss: bool,
}

do_option :: proc(info: Option_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		// Painting
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, fade(style.color.status, hover_time))
			label_color := blend_colors(style.color.text, style.color.base_stroke, hover_time)
			label_box := self.box
			icon_box := cut_box_left(&label_box, height(label_box))
			if info.active {
				// Paint check mark
				center := box_center(icon_box)
				scale: f32 = 5.5
				a, b, c: [2]f32 = {-1, -0.047} * scale, {-0.333, 0.619} * scale, {1, -0.713} * scale
				stroke_path({center + a, center + b, center + c}, false, 1, label_color)
			}
			// Paint label
			paint_label_box(info.label, label_box, label_color, .Left, .Middle)
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

do_bit_set_options :: proc(set: $S/bit_set[$E;$U], loc := #caller_location) -> (new_set: S) {
	new_set = set
	for member in E {
		push_id(hash_int(int(member)))
			if do_option({label = text_capitalize(format(member)), active = member in set}) {
				new_set = new_set ~ {member}
			}
		pop_id()
	}
	return
}
package maui_widgets
import "../"

import "core:runtime"
import "core:math"
import "core:fmt"

Menu_Info :: struct {
	using info: maui.Widget_Info,
	label: maui.Label,
	title: Maybe(string),
	size: [2]f32,
	align: Maybe(maui.Text_Align),
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
		self.box = info.box.? or_else layout_next(current_layout())
		// Update state
		update_widget(self)
		if .Focused in self.state {
			ctx.widget_agent.will_auto_focus = true
		} else if .Hovered in self.state && ctx.widget_agent.auto_focus {
			ctx.widget_agent.press_id = self.id
			ctx.widget_agent.focus_id = self.id
		}
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		open_time := animate_bool(&self.timers[2], .Menu_Open in self.bits, 0.175)
		// Painting
		if .Hovered in self.state {
			ctx.cursor = .Hand
		}
		if .Should_Paint in self.bits {
			paint_rounded_box_corners_fill(self.box, ctx.style.rounding, ctx.style.rounded_corners, alpha_blend_colors(alpha_blend_colors(ctx.style.color.substance[1], ctx.style.color.substance_hover, hover_time), ctx.style.color.substance_click, press_time))
			paint_label_box(info.label, self.box, ctx.style.color.base_text[1], info.align.? or_else .Middle, .Middle)
		}
		// Begin layer if expanded
		if res, ok := begin_attached_layer({
			id = shared_id,
			parent = self,
			side = .Bottom,
			grow = .Top,
			size = info.size,
			align = info.layer_align,
			opacity = open_time,
			shadow = Layer_Shadow_Info{
				offset = 0,
				roundness = ctx.style.rounding,
			},
		}); ok {
			paint_rounded_box_fill(res.self.box, ctx.style.rounding, ctx.style.color.base[1])
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
		end_attached_layer({}, current_layer())
	}
}

// Options within menus
@(deferred_out=_do_submenu)
do_submenu :: proc(info: Menu_Info, loc := #caller_location) -> (active: bool) {
	using maui
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id); ok {
		// Get box
		self.box = info.box.? or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		open_time := animate_bool(&self.timers[1], .Menu_Open in self.bits, 0.15)
		// Paint
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, fade(ctx.style.color.accent[0], hover_time))
			// Paint label
			label_box := self.box
			cut_box_left(&label_box, height(label_box))
			label_color := blend_colors(ctx.style.color.base_text[0], ctx.style.color.accent[0], hover_time)
			paint_label_box(info.label, label_box, label_color, .Left, .Middle)
			paint_arrow_flip({label_box.high.x - height(label_box) * 0.5, center_y(label_box)}, height(label_box) * 0.25, -0.5 * math.PI, 1, open_time, label_color)
		}
		// Begin layer
		if res, ok := begin_attached_layer({
			id = shared_id,
			mode = .Hover,
			parent = self,
			side = info.side.? or_else .Right,
			grow = .Bottom,
			size = info.size,
			align = info.layer_align,
			layer_options = {.Attached},
			opacity = open_time,
		}); ok {
			paint_box_fill(res.self.box, ctx.style.color.base[1])
			active = true
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
			stroke_color = ctx.style.color.accent[1],
		}, current_layer())
	}
}

Option_Info :: struct {
	label: maui.Label,
	active: bool,
	align: Maybe(maui.Alignment),
	no_dismiss: bool,
}

do_option :: proc(info: Option_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		self.box = info.box.? or_else layout_next(current_layout())
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		// Painting
		if .Should_Paint in self.bits {
			paint_rounded_box_corners_fill(self.box, ctx.style.rounding, ctx.style.rounded_corners, fade(ctx.style.color.substance[1], hover_time))
			label_color := blend_colors(ctx.style.color.base_text[1], ctx.style.color.substance_text[1], hover_time)
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
			if parent, ok := layer.parent.?; ok {
				layer = parent
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
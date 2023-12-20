package maui_widgets
import "../"

import "core:intrinsics"
import "core:reflect"
import "core:runtime"
import "core:math"
import "core:fmt"

Strings_Menu_Info :: struct {
	index: int,
	items: []string,
}
do_strings_menu :: proc(info: Strings_Menu_Info, loc := #caller_location) -> (new_index: int, changed: bool) {
	using maui
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update state
		update_widget(self)
		if .Focused in self.state {
			ctx.widget_agent.will_auto_focus = true
		} else if .Hovered in self.state && ctx.widget_agent.auto_focus {
			ctx.widget_agent.press_id = self.id
			ctx.widget_agent.focus_id = self.id
		}
		option_height := height(self.box)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		open_time := animate_bool(&self.timers[2], .Menu_Open in self.bits, 0.15)
		// Painting
		if .Hovered in self.state {
			ctx.cursor = .Hand
		}
		if .Should_Paint in self.bits {
			paint_rounded_box_corners_fill(self.box, ctx.style.rounding, ctx.style.rounded_corners, alpha_blend_colors(alpha_blend_colors(ctx.style.color.substance[1], ctx.style.color.substance_hover, hover_time), ctx.style.color.substance_click, press_time))
			paint_label_box(info.items[info.index], self.box, ctx.style.color.base_text[1], .Middle, .Middle)
		}
		// Begin layer if expanded
		if .Menu_Open in self.bits {
			menu_top := self.box.low.y - f32(info.index) * option_height
			menu_height := f32(len(info.items)) * option_height
			menu_bottom := max(menu_top + menu_height, self.box.high.y)
			if layer, ok := do_layer({
				id = shared_id,
				placement = Box{{self.box.low.x, menu_top}, {self.box.high.x, menu_bottom}},
				space = [2]f32{0, menu_height},
				opacity = open_time,
				options = {.Attached, .No_Scroll_X, .No_Scroll_Y},
				shadow = Layer_Shadow_Info{
					offset = 0,
					roundness = ctx.style.rounding,
				},
			}); ok {
				paint_rounded_box_fill(layer.box, ctx.style.rounding, ctx.style.color.base[1])
				placement.side = .Top; placement.size = option_height
				push_id(self.id)
					for item, i in info.items {
						if do_combo_box_option(item, i) {
							new_index = i
							changed = true
							self.bits -= {.Menu_Open}
						}
					}
				pop_id()
				if ((self.state & {.Focused, .Lost_Focus} == {}) && (layer.state & {.Focused} == {})) {
					self.bits -= {.Menu_Open}
				}
			}
		}
		if .Got_Press in self.state {
			self.bits += {.Menu_Open}
		}
		// Update hovered state
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

Enum_Menu_Info :: struct($T: typeid) where intrinsics.type_is_enum(T) {
	value: T,
}
do_enum_menu :: proc(info: Enum_Menu_Info($T), loc := #caller_location) -> (new_value: T, changed: bool) {
	using maui
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update state
		update_widget(self)
		if .Focused in self.state {
			ctx.widget_agent.will_auto_focus = true
		} else if .Hovered in self.state && ctx.widget_agent.auto_focus {
			ctx.widget_agent.press_id = self.id
			ctx.widget_agent.focus_id = self.id
		}
		option_height := height(self.box)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		open_time := animate_bool(&self.timers[2], .Menu_Open in self.bits, 0.15)
		// Painting
		if .Hovered in self.state {
			ctx.cursor = .Hand
		}
		if .Should_Paint in self.bits {
			paint_rounded_box_corners_fill(self.box, ctx.style.rounding, ctx.style.rounded_corners, alpha_blend_colors(alpha_blend_colors(ctx.style.color.substance[1], ctx.style.color.substance_hover, hover_time), ctx.style.color.substance_click, press_time))
			paint_label_box(reflect.enum_string(info.value), self.box, ctx.style.color.base_text[1], .Middle, .Middle)
		}
		// Begin layer if expanded
		if .Menu_Open in self.bits {
			index: int
			if ei, ok := runtime.type_info_base(type_info_of(T)).variant.(runtime.Type_Info_Enum); ok {
				for v, i in ei.values {
					if v == runtime.Type_Info_Enum_Value(info.value) {
						index = i
					}
				}
			}
			menu_top := self.box.low.y - f32(index) * option_height
			menu_height := f32(len(T)) * option_height
			menu_bottom := max(menu_top + menu_height, self.box.high.y)
			if layer, ok := do_layer({
				id = shared_id,
				placement = Box{{self.box.low.x, menu_top}, {self.box.high.x, menu_bottom}},
				space = [2]f32{0, menu_height},
				opacity = open_time,
				options = {.Attached, .No_Scroll_X, .No_Scroll_Y},
				shadow = Layer_Shadow_Info{
					offset = 0,
					roundness = ctx.style.rounding,
				},
			}); ok {
				paint_rounded_box_fill(layer.box, ctx.style.rounding, ctx.style.color.base[1])
				placement.side = .Top; placement.size = option_height
				prev_rounded_corners := ctx.style.rounded_corners
				defer ctx.style.rounded_corners = prev_rounded_corners
				ctx.style.rounded_corners = ALL_CORNERS
				push_id(self.id)
					for member, i in T {
						if do_combo_box_option(tmp_print(member), i) {
							new_value = member
							changed = true
							self.bits -= {.Menu_Open}
						}
					}
				pop_id()
				if ((self.state & {.Focused, .Lost_Focus} == {}) && (layer.state & {.Focused} == {})) {
					self.bits -= {.Menu_Open}
				}
			}
		}
		if .Got_Press in self.state {
			self.bits += {.Menu_Open}
		}
		// Update hovered state
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

do_combo_box_option :: proc(text: string, index: int) -> (clicked: bool) {
	using maui
	if w, ok := do_widget(hash(index + 1)); ok {
		w.box = layout_next(current_layout())
		update_widget(w)
		// Animation
		hover_time := animate_bool(&w.timers[0], .Hovered in w.state, DEFAULT_WIDGET_HOVER_TIME)
		// Painting
		if .Should_Paint in w.bits {
			paint_rounded_box_corners_fill(w.box, ctx.style.rounding, ctx.style.rounded_corners, fade(ctx.style.color.substance[1], hover_time))
			// Paint label
			paint_label_box(text, w.box, blend_colors(ctx.style.color.base_text[1], ctx.style.color.substance_text[1], hover_time), .Middle, .Middle)
		}
		update_widget_hover(w, point_in_box(input.mouse_point, w.box))
		clicked = widget_clicked(w, .Left)
	}
	return
}
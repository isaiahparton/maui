package maui_widgets
import "../"

import "core:runtime"
import "core:math"
import "core:fmt"

Combo_Box_Info :: struct {
	index: int,
	items: []string,
}
do_combo_box :: proc(info: Combo_Box_Info, loc := #caller_location) -> (index: int, was_changed: bool) {
	using maui
	shared_id := hash(loc)
	if self, ok := do_widget(shared_id); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update state
		update_widget(self)
		if .Focused in self.state {
			core.widget_agent.will_auto_focus = true
		} else if .Hovered in self.state && core.widget_agent.auto_focus {
			core.widget_agent.press_id = self.id
			core.widget_agent.focus_id = self.id
		}
		option_height := height(self.box)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		open_time := animate_bool(&self.timers[2], .Menu_Open in self.bits, 0.15)
		// Painting
		if .Hovered in self.state {
			core.cursor = .Hand
		}
		if .Should_Paint in self.bits {
			paint_rounded_box_corners_fill(self.box, style.rounding, style.rounded_corners, alpha_blend_colors(alpha_blend_colors(style.color.substance[1], style.color.substance_hover, hover_time), style.color.substance_click, press_time))
			paint_label_box(info.items[info.index], self.box, style.color.base_text[1], .Middle, .Middle)
		}
		menu_top := self.box.low.y - f32(info.index) * option_height
		menu_height := f32(len(info.items)) * option_height
		menu_bottom := max(menu_top + menu_height, self.box.high.y)
		// Begin layer if expanded
		if .Menu_Open in self.bits {
			if layer, ok := do_layer({
				id = shared_id,
				placement = Box{{self.box.low.x, menu_top}, {self.box.high.x, menu_bottom}},
				space = [2]f32{0, menu_height},
				opacity = open_time,
				options = {.Attached, .No_Scroll_X, .No_Scroll_Y},
				shadow = Layer_Shadow_Info{
					offset = 0,
					roundness = style.rounding,
				},
			}); ok {
				paint_rounded_box_fill(layer.box, style.rounding, style.color.base[1])
				placement.side = .Top; placement.size = option_height
				push_id(self.id)
					for item, i in info.items {
						if w, ok := do_widget(hash(i + 1)); ok {
							w.box = layout_next(current_layout())
							update_widget(w)
							// Animation
							hover_time := animate_bool(&w.timers[0], .Hovered in w.state, DEFAULT_WIDGET_HOVER_TIME)
							// Painting
							if .Should_Paint in w.bits {
								paint_rounded_box_corners_fill(w.box, style.rounding, style.rounded_corners, fade(style.color.substance[1], hover_time))
								// Paint label
								paint_label_box(item, w.box, blend_colors(style.color.base_text[1], style.color.substance_text[1], hover_time), .Middle, .Middle)
							}
							update_widget_hover(w, point_in_box(input.mouse_point, w.box))
							if widget_clicked(w, .Left) {
								index = i
								was_changed = true
								self.bits -= {.Menu_Open}
							}
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

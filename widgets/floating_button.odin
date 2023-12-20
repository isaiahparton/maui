package maui_widgets
/*import "../"

import "core:math/linalg"

// Smol subtle buttons
Floating_Button_Info :: struct {
	icon: rune,
}
do_floating_button :: proc(info: Floating_Button_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		self.box = child_box(use_next_box() or_else layout_next(current_layout()), {40, 40}, {.Middle, .Middle})
		hover_time := animate_bool(&self.timers[0], self.state >= {.Hovered}, 0.1)
		update_widget(self)
		// Painting
		if self.bits >= {.Should_Paint} {
			center := linalg.round(box_center(self.box))
			paint_circle_fill_texture(center + {0, 5}, 40, get_color(.Base_Shade, 0.2))
			paint_circle_fill_texture(center, 40, alpha_blend_colors(get_color(.Button_Base), get_color(.Button_Shade), (2 if self.state >= {.Pressed} else hover_time) * 0.1))
			paint_aligned_rune(painter.ctx.style.button_font, painter.ctx.style.button_font_size, info.icon, center, get_color(.Button_Text), {.Middle, .Middle})
		}
		// Result
		clicked = widget_clicked(self, .Left)
	}
	return
}*/
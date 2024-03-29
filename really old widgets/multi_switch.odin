package maui_widgets
import "../"

import "core:fmt"

Multi_Switch_Info :: struct {
	using info: maui.Widget_Info,
	items: []maui.Label,
	index: int,
}
do_multi_switch :: proc(info: Multi_Switch_Info, loc := #caller_location) -> (new_index: int, changed: bool) {
	using maui
	box := info.box.? or_else layout_next(current_layout())

	paint_rounded_box_fill(box, style.rounding, style.color.substance[0])
	size := width(box) / f32(len(info.items))
	push_id(hash(loc))
		for item, i in info.items {
			if w, ok := do_widget(hash(i)); ok {
				w.box = shrink_box(cut_box_left(&box, size), 3)
				update_widget(w)

				hover_time := animate_bool(&w.timers[0], .Hovered in w.state, DEFAULT_WIDGET_HOVER_TIME)
				if info.index == i {
					paint_rounded_box_fill(w.box, style.rounding, alpha_blend_colors(style.color.substance[1], style.color.substance_hover, hover_time))
					paint_label_box(option, w.box, style.color.base_text[1], .Middle, .Middle)
				} else {
					paint_rounded_box_fill(w.box, style.rounding, fade(style.color.substance_hover, hover_time))
					paint_label_box(option, w.box, style.color.base_text[0], .Middle, .Middle)
				}

				if widget_clicked(w, .Left) {
					new_index = i
					changed = true
				}

				update_widget_hover(w, point_in_box(input.mouse_point, w.box))
			}
		}
	pop_id()
	return
}
package maui_widgets
import "../"

import "core:fmt"
import "core:math/linalg"

Button_Style :: enum {
	Filled,
	Outlined,
	Subtle,
}
Button_Shape :: enum {
	Rectangle,
	Pill,
	Left_Arrow,
	Right_Arrow,
}

// Square buttons
Button_Info :: struct {
	label: maui.Label,
	align: Maybe(maui.Alignment),
	color: Maybe(maui.Color),
	fit_to_label: Maybe(bool),
}
do_button :: proc(info: Button_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		// Colocate
		layout := current_layout()
		if next_box, ok := use_next_box(); ok {
			self.box = next_box
		} else if int(placement.side) > 1 && (info.fit_to_label.? or_else false) {
			size := get_size_for_label(layout, info.label)
			self.box = layout_next_of_size(layout, size)
		} else {
			self.box = layout_next(layout)
		}
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
		// Cursor
		if .Hovered in self.state {
			core.cursor = .Hand
		}
		if .Should_Paint in self.bits {
			inner_box := shrink_box(self.box, 1)
			color := alpha_blend_colors(info.color.? or_else style.color.status, {0, 0, 0, 255}, press_time * 0.15)
			paint_box_fill(self.box, fade(color, hover_time))
			paint_box_stroke(self.box, 1, color)
			// Label
			paint_label_box(info.label, self.box, blend_colors(color, style.color.base, hover_time), .Middle, .Middle)
		}
		// Result
		clicked = widget_clicked(self, .Left)
		// Update hover
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
package maui_widgets
import "../"

import "core:fmt"
import "core:math/linalg"

BUTTON_CORNER_AMOUNT :: 0.3

paint_button_shape_stroke :: proc(box: maui.Box, thickness: f32, color: maui.Color) {
	using maui
	c := height(box) * BUTTON_CORNER_AMOUNT
	paint_box_fill({{box.low.x + c, box.low.y}, {box.high.x, box.low.y + thickness}}, color)
	paint_box_fill({{box.low.x, box.high.y - thickness}, {box.high.x - c, box.high.y}}, color)
	paint_box_fill({{box.low.x, box.low.y + c}, {box.low.x + thickness, box.high.y}}, color)
	paint_box_fill({{box.high.x - thickness, box.low.y}, {box.high.x, box.high.y - c}}, color)
	paint_line({box.high.x - c, box.high.y}, {box.high.x, box.high.y - c}, thickness, color)
	paint_line({box.low.x, box.low.y + c}, {box.low.x + c, box.low.y}, thickness, color)
}
paint_button_shape_fill :: proc(box: maui.Box, color: maui.Color) {
	using maui
	c := height(box) * BUTTON_CORNER_AMOUNT
	paint_box_fill({{box.low.x + c, box.low.y}, {box.high.x - c, box.high.y}}, color)
	paint_quad_fill({box.low.x + c, box.low.y}, {box.low.x + c, box.high.y}, {box.low.x, box.high.y}, {box.low.x, box.low.y + c}, color)
	paint_quad_fill({box.high.x - c, box.low.y}, {box.high.x, box.low.y}, {box.high.x, box.high.y - c}, {box.high.x - c, box.high.y}, color)
}

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
	align: Maybe(maui.Text_Align),
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
			paint_rounded_box_corners_fill(self.box, style.button_rounding, style.rounded_corners, alpha_blend_colors(alpha_blend_colors(style.color.substance[1], style.color.substance_hover, hover_time), style.color.substance_click, press_time))
			paint_label_box(info.label, self.box, style.color.base_text[1], info.align.? or_else .Middle, .Middle)
		}
		// Result
		clicked = widget_clicked(self, .Left)
		// Update hover
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
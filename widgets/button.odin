package maui_widgets
import "../"
import "core:fmt"

get_button_fill_and_stroke :: proc(style: ^maui.Style, hover_time: f32, type: Button_Type) -> (fill_color, stroke_color, text_color: maui.Color) {
	switch type {
		case .Subtle:
		fill_color = maui.fade(style.color.substance[0], 0.55 * hover_time)
		stroke_color = maui.fade(style.color.substance[0], 0.6 + 0.4 * hover_time)
		text_color = maui.blend_colors(style.color.substance[0], style.color.base[0], hover_time)

		case .Normal:
		fill_color = maui.fade(style.color.substance[0], 0.2 + 0.8 * hover_time)
		stroke_color = style.color.substance[0]
		text_color = maui.blend_colors(style.color.substance[0], style.color.base[0], hover_time)
	}
	return
}

Rounded_Button_Shape :: distinct maui.Corners
Cut_Button_Shape :: distinct maui.Corners
Button_Shape :: union {
	Rounded_Button_Shape,
	Cut_Button_Shape,
}
Button_Type :: enum {
	Subtle,
	Normal,
}
Button_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	text: string,
	type: Button_Type,
	shape: Button_Shape,
}
button :: proc(ui: ^maui.UI, info: Button_Info, loc := #caller_location) -> maui.Generic_Widget_Result {
	using maui
	self, result := get_widget(ui, hash(ui, loc))
	// Place the widget
	self.box = info.box.? or_else layout_next(current_layout(ui))
	// Update the widget's state
	update_widget(ui, self)
	// Animations
	hover_time := animate_bool(ui, &self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
	press_time := animate_bool(ui, &self.timers[1], .Pressed in self.state, DEFAULT_WIDGET_PRESS_TIME)
	// Check if painting is needed
	if .Should_Paint in self.bits {
		fill_color, stroke_color, text_color := get_button_fill_and_stroke(&ui.style, hover_time, info.type)
		// Paint
		switch shape in info.shape {
			case nil:
			paint_box_fill(ui.painter, self.box, fill_color)
			paint_box_stroke(ui.painter, self.box, 1, stroke_color)

			case Rounded_Button_Shape:
			paint_rounded_box_corners_fill(ui.painter, self.box, ui.style.rounding, Corners(shape), fill_color)
			paint_rounded_box_corners_stroke(ui.painter, self.box, ui.style.rounding, 1, Corners(shape), stroke_color)

			case Cut_Button_Shape:
			if press_time > 0 {
				box := expand_box(self.box, press_time * 3)
				points, count := get_path_of_box_with_cut_corners(box, height(box) * 0.2, Corners(shape))
				paint_path_fill(ui.painter, points[:count], fade(ui.style.color.substance[0], 0.3 * press_time))
			}
			{
				points, count := get_path_of_box_with_cut_corners(self.box, height(self.box) * 0.2, Corners(shape))
				paint_path_fill(ui.painter, points[:count], fill_color)
				paint_path_stroke(ui.painter, points[:count], true, 1, 0, stroke_color)
			}
		}
		paint_text(ui.painter, center(self.box), {
			text = info.text, 
			font = ui.style.font.label, 
			size = ui.style.text_size.label, 
			align = .Middle, 
			baseline = .Middle,
		}, text_color)
	}
	// Whosoever hovereth with the mouse
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// We're done here
	return result
}
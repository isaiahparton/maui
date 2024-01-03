package maui_widgets
import "../"
import "core:fmt"

get_button_fill_and_stroke :: proc(style: ^maui.Style, hover_time: f32) -> (fill_color, stroke_color: maui.Color) {
	fill_color = maui.fade(style.color.substance[0], 0.2 + 0.4 * hover_time)
	stroke_color = maui.fade(style.color.substance[0], 0.75 + 0.25 * hover_time)
	return
}

Rounded_Button_Shape :: distinct maui.Corners
Cut_Button_Shape :: distinct maui.Corners
Button_Shape :: union #no_nil {
	Rounded_Button_Shape,
	Cut_Button_Shape,
}
Button_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	text: string,
	shape: Maybe(Button_Shape),
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
	// Check if painting is needed
	if .Should_Paint in self.bits {
		fill_color, stroke_color := get_button_fill_and_stroke(&ui.style, hover_time)
		// Paint
		switch shape in info.shape.? or_else Rounded_Button_Shape(ALL_CORNERS) {
			case Rounded_Button_Shape:
			paint_rounded_box_corners_fill(ui.painter, self.box, ui.style.rounding, Corners(shape), fill_color)
			paint_rounded_box_corners_stroke(ui.painter, self.box, ui.style.rounding, 1, Corners(shape), stroke_color)

			case Cut_Button_Shape:
			points, count := get_path_of_box_with_cut_corners(self.box, height(self.box) * 0.2, Corners(shape))
			paint_path_fill(ui.painter, points[:count], fill_color)
			paint_path_stroke(ui.painter, points[:count], true, 1, 0, stroke_color)
		}
		paint_text(ui.painter, center(self.box), {
			text = info.text, 
			font = ui.style.font.label, 
			size = ui.style.text_size.label, 
			align = .Middle, 
			baseline = .Middle,
		}, ui.style.color.substance_text[0])
	}
	// Whosoever hovereth with the mouse
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// We're done here
	return result
}
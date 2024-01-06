package maui_widgets
import "../"

Toggle_Button_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	text: string,
	on: bool,
	shape: Button_Shape,
}
toggle_button :: proc(ui: ^maui.UI, info: Toggle_Button_Info, loc := #caller_location) -> maui.Generic_Widget_Result {
	using maui
	self, result := get_widget(ui, hash(ui, loc))

	self.box = info.box.? or_else layout_next(current_layout(ui))

	// Update the widget's state
	update_widget(ui, self)
	// Animations
	hover_time := animate_bool(ui, &self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
	// Check if painting is needed
	if .Should_Paint in self.bits {
		fill_color := maui.fade(ui.style.color.substance[0], (0.2 if info.on else 0.0) + 0.4 * hover_time)
		stroke_color := maui.fade(ui.style.color.substance[0], 0.75 + 0.25 * hover_time)
		// Paint
		switch shape in info.shape {
			case nil:
			paint_box_fill(ui.painter, self.box, fill_color)
			paint_box_stroke(ui.painter, self.box, 1, stroke_color)

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
		}, ui.style.color.substance[0])
	}

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	return result
}
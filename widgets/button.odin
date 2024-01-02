package maui_widgets
import "../"
import "core:fmt"

Button_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	text: string,
	corners: Maybe(maui.Corners),
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
		// Paint
		paint_rounded_box_corners_fill(ui.painter, self.box, ui.style.rounding, info.corners.? or_else ALL_CORNERS, alpha_blend_colors(ui.style.color.substance[0], ui.style.color.substance_hover, hover_time))
		paint_text(ui.painter, center(self.box), {
			text = info.text, 
			font = ui.style.font.label, 
			size = ui.style.text_size.label, 
			align = .Middle, 
			baseline = .Middle,
		}, ui.style.color.substance_text[1])
	}
	// Whosoever hovereth with the mouse
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// We're done here
	return result
}
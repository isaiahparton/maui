package maui_widgets
import "../"
import "core:fmt"

Button_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	text: string,
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
		paint_box_fill(ui.painter, self.box, ui.style.color.substance[0])
		paint_rounded_box_fill(ui.painter, self.box, ui.style.rounding, ui.style.color.substance[0])
	}
	return result
}
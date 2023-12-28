package maui_widgets
import "../"

Button_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	text: string,
}
button :: proc(info: Button_Info, loc := #caller_location) -> bool {
	using maui
	wdg := get_widget(hash(loc)) or_return
	// Place the widget
	wdg.box = info.box.? or_else layout_next(current_layout())
	// Update the widget's state
	update_widget(wdg)
	// Animations
	hover_time := animate_bool(&wdg.timers[0], .Hovered in wdg.state, DEFAULT_WIDGET_HOVER_TIME)
	// Check if painting is needed
	if .Should_Paint in wdg.bits {
		// Paint
		paint_rounded_box_fill(wdg.box, style.rounding, style.color.substance[0])
	}

	
}
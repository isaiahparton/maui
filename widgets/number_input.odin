package maui_widgets
import "../"

Number_Input_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	value: f64,
}
Number_Input_Result :: struct {
	using generic: maui.Generic_Widget_Result,
	value: f64,
}
number_input :: proc(ui: ^maui.UI, info: Number_Input_Info, loc := #caller_location) -> Number_Input_Result {
	using maui

	self, generic_result := get_widget(ui, hash(ui, loc))
	result: Number_Input_Result = {
		generic = generic_result,
	}

	self.box = info.box.? or_else layout_next(current_layout(ui))

	buffer := get_scribe_buffer(&ui.scribe, self.id)

	return result
}
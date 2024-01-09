package maui_widgets
import "../"

Item_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	text: string,
}
item :: proc(ui: ^maui.UI, info: Item_Info, loc := #caller_location) -> maui.Generic_Widget_Result {
	using maui
	self, result := get_widget(ui, hash(ui, loc))

	
	
	return result
}
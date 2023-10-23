package maui_widgets
import "../"

Spin_Counter_Data :: struct {
	offsets: [16]f32,
}
Spin_Counter_Info :: struct($T: typeid) {
	digits: int,
	value: T,
}

do_spin_counter :: proc(info: Spin_Counter_Info($T), loc := #caller_location) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)

		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
}
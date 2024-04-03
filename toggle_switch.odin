package maui
import "core:math/ease"

Toggle_Switch_Info :: struct {
	using generic: Generic_Widget_Info,
	state: bool,
}
Toggle_Switch_Widget_Variant :: struct {
	hover_time,
	how_on: f32,
}

toggle_switch :: proc(ui: ^UI, info: Toggle_Switch_Info, loc := #caller_location) -> Generic_Widget_Result {
	self, result := get_widget(ui, info, loc)
	// Colocate
	self.box = info.box.? or_else child_box(layout_next(current_layout(ui)), {90, 24}, ui.layouts.current.align)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Toggle_Switch_Widget_Variant{}
	}
	data := &self.variant.(Toggle_Switch_Widget_Variant)
	// Update
	update_widget(ui, self)
	// Animate
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.how_on = animate(ui, data.how_on, 0.15, info.state)

	paint_rounded_box_fill(ui.painter, self.box, height(self.box) / 2, blend_colors(data.how_on, ui.style.color.button, ui.style.color.button_hovered))

	s := width(self.box) / 2
	slider_box := shrink_box(get_box_left(self.box, s), 2)
	slider_box = move_box(slider_box, {s * (1 - data.how_on), 0})
	paint_rounded_box_fill(ui.painter, slider_box, height(slider_box) / 2, blend_colors(data.how_on, ui.style.color.button_hovered,  ui.style.color.label_hovered))

	text_baseline := center_y(self.box)
	paint_text(ui.painter, {self.box.low.x + 6, text_baseline}, {
		font = ui.style.font.label,
		size = ui.style.text_size.label,
		text = "On",
		baseline = .Middle,
	}, blend_colors(data.how_on, ui.style.color.label, ui.style.color.label))
	paint_text(ui.painter, {self.box.high.x - 6, text_baseline}, {
		font = ui.style.font.label,
		size = ui.style.text_size.label,
		text = "Off",
		align = .Right,
		baseline = .Middle,
	}, ui.style.color.label_hovered)

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	return result
}
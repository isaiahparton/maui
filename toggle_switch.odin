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
	self.box = info.box.? or_else align_inner(next_box(ui), {40, 20}, ui.placement.align)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Toggle_Switch_Widget_Variant{}
	}
	data := &self.variant.(Toggle_Switch_Widget_Variant)
	// Update
	update_widget(ui, self)
	// Animate
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.how_on = animate(ui, data.how_on, 0.2, info.state)

	paint_rounded_box_fill(ui.painter, self.box, ui.style.rounding, blend_colors(data.how_on, ui.style.color.foreground, ui.style.color.accent))

	s := width(self.box) / 2
	slider_box := shrink_box(move_box(get_box_left(self.box, s), {s * ease.circular_in_out(data.how_on), 0}), 2)
	paint_rounded_box_fill(ui.painter, slider_box, ui.style.rounding, ui.style.color.substance)

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	return result
}
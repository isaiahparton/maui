package maui
import "../"

Slider_Info :: struct {
	using generic: Generic_Widget_Info,
	value,
 	low,
 	high: f32,
 	format: Maybe(string),
}
Slider_Result :: struct {
	using generic: Generic_Widget_Result,
	changed: bool,
	value: f32,
}
slider :: proc(ui: ^UI, info: Slider_Info, loc := #caller_location) -> Slider_Result {
	self, generic_result := get_widget(ui, info, loc)
	self.options += {.Draggable}
	result: Slider_Result = {
		generic = generic_result,
	}
	// Place the widget
	self.box = info.box.? or_else next_box(ui)
	// Update the widget's state
	update_widget(ui, self)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Button_Widget_Variant{}
	}
	data := &self.variant.(Button_Widget_Variant)
	// Update retained data
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	// Some values
	range := width(self.box)
	time := (info.value - info.low) / (info.high - info.low)
	// paint
	if .Should_Paint in self.bits {
		paint_box_fill(ui.painter, self.box, ui.style.color.backing)
		paint_box_fill(ui.painter, {self.box.low, {self.box.low.x + time * range, self.box.high.y}}, fade(blend_colors(data.hover_time, ui.style.color.substance, ui.style.color.accent), 0.5))
		paint_text(ui.painter, center(self.box), {
			text = tmp_printf(info.format.? or_else "%v", info.value),
			align = .Middle,
			baseline = .Middle,
			font = ui.style.font.label,
			size = ui.style.text_size.label,
		}, ui.style.color.text[0])
	}
	// Drag
	if .Pressed in self.state {
		time := clamp((ui.io.mouse_point.x - self.box.low.x) / range, 0, 1)
		result.changed = true
		result.value = info.low + time * (info.high - info.low)
	}
	// Hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// We're done here
	return result
}
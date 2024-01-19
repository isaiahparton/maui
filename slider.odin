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
	self.box = info.box.? or_else layout_next(current_layout(ui))
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
	radius: f32 = 8
	range := width(self.box) - radius * 2
	time := (info.value - info.low) / (info.high - info.low)
	thumb_center: [2]f32 = {self.box.low.x + range * time + radius, center_y(self.box)}
	// paint
	if .Should_Paint in self.bits {
		paint_rounded_box_fill(ui.painter, {{self.box.low.x, thumb_center.y - 2}, {self.box.high.x, thumb_center.y + 2}}, 2, ui.style.color.background[1])
		paint_circle_fill_texture(ui.painter, thumb_center, radius, alpha_blend_colors(ui.style.color.accent, {0, 0, 0, 255}, data.hover_time * 0.25))
	}
	if .Hovered in (self.state + self.last_state) {
		tooltip_result := tooltip(ui, self.id, tmp_printf(info.format.? or_else "%v", info.value), thumb_center + {0, -radius * 2}, {.Middle, .Far}, .Top)
		if layer, ok := tooltip_result.layer.?; ok {
			if .Hovered in layer.state {
				ui.widgets.next_hover_id = self.id
			}
		}
	}
	// Drag
	if .Pressed in self.state {
		time := clamp((ui.io.mouse_point.x - self.box.low.x - radius) / range, 0, 1)
		result.changed = true
		result.value = info.low + time * (info.high - info.low)
	}
	// Hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// We're done here
	return result
}
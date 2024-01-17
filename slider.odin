package maui
import "../"

Slider_Info :: struct {
	using generic: Generic_Widget_Info,
	value,
 	low,
 	high: f32,
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
	// Animations
	//hover_time := animate_bool(ui, &self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
	// Some values
	radius := height(self.box) / 2
	range := width(self.box) - radius * 2
	time := (info.value - info.low) / (info.high - info.low)
	thumb_center: [2]f32 = {self.box.low.x + range * time + radius, center_y(self.box)}
	thumb_box: Box = {
		{self.box.low.x + range * time, self.box.low.y},
		{self.box.low.x + range * time + radius * 2, self.box.high.y},
	}
	// paint
	if .Should_Paint in self.bits {
		paint_line(ui.painter, {self.box.low.x, thumb_center.y}, {thumb_box.low.x, thumb_center.y}, 2, {255, 255, 255, 255})
		paint_line(ui.painter, {thumb_box.high.x, thumb_center.y}, {self.box.high.x, thumb_center.y}, 2, {255, 255, 255, 255})
		paint_circle_fill_texture(ui.painter, thumb_center, radius, ui.style.color.button)
		paint_ring_fill_texture(ui.painter, thumb_center, radius - 1, radius, ui.style.color.text[0])
	}
	// Drag
	if .Pressed in self.state {
		if .Pressed not_in self.last_state {
			ui.widgets.drag_offset = thumb_box.low - ui.io.mouse_point
		}
		time := clamp(((ui.io.mouse_point + ui.widgets.drag_offset).x - self.box.low.x) / range, 0, 1)
		result.changed = true
		result.value = info.low + time * (info.high - info.low)
	}
	// Hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, thumb_box))
	// We're done here
	return result
}
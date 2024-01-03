package maui_widgets
import "../"

Slider_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	value,
 	low,
 	high: f32,
 	knob_size: Maybe(f32),
}
Slider_Result :: struct {
	using generic: maui.Generic_Widget_Result,
	changed: bool,
	value: f32,
}
slider :: proc(ui: ^maui.UI, info: Slider_Info, loc := #caller_location) -> Slider_Result {
	using maui
	self, generic_result := get_widget(ui, hash(ui, loc))
	self.options += {.Draggable}
	result: Slider_Result = {
		generic = generic_result,
	}
	// Place the widget
	self.box = info.box.? or_else layout_next(current_layout(ui))
	// Update the widget's state
	update_widget(ui, self)
	// Animations
	hover_time := animate_bool(ui, &self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
	// Some values
	knob_size := info.knob_size.? or_else height(self.box) * 2
	range := width(self.box) - knob_size
	time := (info.value - info.low) / (info.high - info.low)
	knob_box: Box = {
		{self.box.low.x + range * time, self.box.low.y},
		{self.box.low.x + range * time + knob_size, self.box.high.y},
	}
	// paint
	if .Should_Paint in self.bits {
		center := center(self.box)
		paint_line(ui.painter, {self.box.low.x, center.y}, {knob_box.low.x, center.y}, 1, ui.style.color.substance[1])
		paint_line(ui.painter, {knob_box.high.x, center.y}, {self.box.high.x, center.y}, 1, ui.style.color.substance[1])
		fill_color, stroke_color := get_button_fill_and_stroke(&ui.style, hover_time)
		paint_rounded_box_fill(ui.painter, knob_box, ui.style.rounding, fill_color)
		paint_rounded_box_stroke(ui.painter, knob_box, ui.style.rounding, 1, stroke_color)
	}
	// Drag
	if .Pressed in self.state {
		if .Pressed not_in self.last_state {
			ui.widgets.drag_offset = knob_box.low - ui.io.mouse_point
		}
		time := clamp(((ui.io.mouse_point + ui.widgets.drag_offset).x - self.box.low.x) / range, 0, 1)
		result.changed = true
		result.value = info.low + time * (info.high - info.low)
	}
	// Hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, knob_box))
	// We're done here
	return result
}
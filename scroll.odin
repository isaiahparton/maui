package maui
// Scroll bars for scrolling bars
Scrollbar_Info :: struct {
	using generic: Generic_Widget_Info,
	value,
	low,
	high,
	knob_size: f32,
	vertical: bool,
}
Scrollbar_Result :: struct {
	using generic: Generic_Widget_Result,
	changed: bool,
	value: f32,
}

scrollbar :: proc(ui: ^UI, info: Scrollbar_Info, loc := #caller_location) -> Scrollbar_Result {
	self, generic_result := get_widget(ui, info, loc)
	self.options += {.Draggable}
	result: Scrollbar_Result = {
		generic = generic_result,
	}
	// Colocate
	self.box = info.box.? or_else layout_next(current_layout(ui))
	// Update
	update_widget(ui, self)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Button_Widget_Variant{}
	}
	data := &self.variant.(Button_Widget_Variant)
	// Update retained data
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.disable_time = animate(ui, data.disable_time, DEFAULT_WIDGET_DISABLE_TIME, .Disabled in self.bits)
	// Vector component to modify
	i := int(info.vertical)
	// Control info
	size := self.box.high[i] - self.box.low[i]
	range := size - info.knob_size
	value_range := (info.high - info.low) if info.high > info.low else 1
	// Part dragged by user
	knob_box := self.box
	knob_size := knob_box.high[i] - knob_box.low[i]
	knob_box.low[i] += range * clamp((info.value - info.low) / value_range, 0, 1)
	knob_size = min(info.knob_size, knob_size)
	knob_box.high[i] = knob_box.low[i] + knob_size
	// Painting
	if .Should_Paint in self.bits {
		paint_box_fill(ui.painter, self.box, ui.style.color.background[0])
		paint_box_stroke(ui.painter, self.box, 1, fade(ui.style.color.substance, 0.5))
		paint_box_fill(ui.painter, knob_box, fade(ui.style.color.substance, 0.5 + 0.5 * data.hover_time))
		paint_box_stroke(ui.painter, knob_box, 1, fade(ui.style.color.substance, 0.5))
	}
	// Dragging
	if .Pressed in (self.state - self.last_state) {
		if point_in_box(ui.io.mouse_point, transmute(Box)knob_box) {
			ui.drag_anchor = ui.io.mouse_point - knob_box.low
		} else {
			normal := clamp((ui.io.mouse_point[i] - self.box.low[i]) / range, 0, 1)
			result.value = info.low + (info.high - info.low) * normal
			result.changed = true
		}
	}
	if .Pressed in self.state {
		normal := clamp(((ui.io.mouse_point[i] - ui.drag_anchor[i]) - self.box.low[i]) / range, 0, 1)
		result.value = info.low + (info.high - info.low) * normal
		result.changed = true
	}
	// Hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	return result
}
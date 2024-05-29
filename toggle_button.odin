package maui
/*import "core:fmt"

Toggle_Button_Type :: enum {
	Outlined,
	Subtle,
	Filled,
}
Toggle_Button_Info :: struct {
	using generic: Generic_Widget_Info,
	state: bool,
	text: string,
	font: Maybe(Font_Handle),
	text_align: Maybe(Text_Align),
	text_size: Maybe(f32),
	fit_text: bool,
	color: Maybe(Color),
}
Toggle_Button_Result :: struct {
	using generic: Generic_Widget_Result,
	min_width: f32,
}
toggle_button :: proc(ui: ^UI, info: Toggle_Button_Info, loc := #caller_location) -> Button_Result {
	// Get widget
	self, generic_result := get_widget(ui, info.generic, loc)
	result: Button_Result = {
		generic = generic_result,
	}
	layout := current_layout(ui)
	// Get minimum width
	if info.fit_text {
		ui.placement.size = measure_text(ui.painter, {
			text = info.text,
			font = info.font.? or_else ui.style.font.label, 
			size = info.text_size.? or_else ui.style.text_size.label,
		}).x + height(layout.box)
	}
	// Colocate the button
	self.box = info.box.? or_else next_box(ui)
	update_widget(ui, self)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Button_Widget_Variant{}
	}
	data := &self.variant.(Button_Widget_Variant)
	// Update retained data
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.disable_time = animate(ui, data.disable_time, DEFAULT_WIDGET_DISABLE_TIME, .Disabled in self.bits)
	if .Hovered in self.state {
		ui.cursor = .Hand
	}
	// Paint
	if .Should_Paint in self.bits {
		opacity: f32 = 1.0 - data.disable_time * 0.5
		base_color := info.color.? or_else ui.style.color.substance
		text_color: Color
		// Types
		fill_color := fade(base_color, (0.3 if info.state else 0.1) + 0.4 * data.hover_time)
		stroke_color := fade(base_color, 0.5 + 0.5 * data.hover_time)
		paint_box_fill(ui.painter, self.box, fill_color)
		paint_box_stroke(ui.painter, self.box, 1, stroke_color)
		text_color = ui.style.color.text[0]
		// Text title
		text_origin: [2]f32
		text_align := info.text_align.? or_else .Middle
		switch text_align {
			case .Left:
			text_origin = {self.box.low.x + ui.style.layout.widget_padding, (self.box.low.y + self.box.high.y) / 2}
			
			case .Middle:
			text_origin = center(self.box)
			
			case .Right:
			text_origin = {self.box.high.x - ui.style.layout.widget_padding, (self.box.low.y + self.box.high.y) / 2}
		}
		result.min_width = paint_text(ui.painter, text_origin, {
			text = info.text, 
			font = info.font.? or_else ui.style.font.label, 
			size = info.text_size.? or_else ui.style.text_size.label, 
			align = text_align, 
			baseline = .Middle,
		}, text_color).x + height(layout.box)
	}
	// Get next hover state
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// we're done here
	return result
}*/
package maui
import "core:fmt"

Button_Widget_Variant :: struct {
	hover_time,
	disable_time: f32,
}
Button_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
	subtle: bool,
	font: Maybe(Font_Handle),
	text_align: Maybe(Text_Align),
	text_size: Maybe(f32),
	fit_text: bool,
	color: Maybe(Color),
	corner_style: Box_Corner_Style,
}
Button_Result :: struct {
	using generic: Generic_Widget_Result,
	min_width: f32,
}
button :: proc(ui: ^UI, info: Button_Info, loc := #caller_location) -> Button_Result {
	// Get widget
	self, generic_result := get_widget(ui, info.generic, loc)
	result: Button_Result = {
		generic = generic_result,
	}
	layout := current_layout(ui)
	// Get minimum width
	if info.fit_text {
		layout.size.x = measure_text(ui.painter, {
			text = info.text,
			font = info.font.? or_else ui.style.font.label, 
			size = info.text_size.? or_else ui.style.text_size.label,
		}).x + height(layout.box)
	}
	// Colocate the button
	self.box = info.box.? or_else layout_next(layout)
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
		fill_color := fade(base_color, 0.1 + 0.9 * data.hover_time)
		stroke_color := fade(base_color, 0.5 * (1 - data.hover_time))
		text_color := blend_colors(data.hover_time, ui.style.color.substance, ui.style.color.foreground[0])
		corners: Corners = info.corners.? or_else {}
		// Shapes
		paint_fancy_box_fill(ui.painter, self.box, corners, info.corner_style, ui.style.rounding, fill_color)
		if !info.subtle {
			paint_fancy_box_stroke(ui.painter, self.box, corners, info.corner_style, ui.style.rounding, 1, stroke_color)
		}
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
}
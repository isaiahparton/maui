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
	outlined: bool,
	font: Maybe(Font_Handle),
	align: Maybe(Text_Align),
	text_size: Maybe(f32),
	fit_text: bool,
}
button :: proc(ui: ^UI, info: Button_Info, loc := #caller_location) -> Generic_Widget_Result {
	// Get widget
	self, result := get_widget(ui, info.generic, loc)
	if info.fit_text {
		layout := current_layout(ui)
		layout.size.x = measure_text(ui.painter, {
			text = info.text,
			font = info.font.? or_else ui.style.font.label, 
			size = info.text_size.? or_else ui.style.text_size.label,
		}).x + height(layout.box)
	}
	self.box = info.box.? or_else layout_next(current_layout(ui))
	update_widget(ui, self)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Button_Widget_Variant{}
	}
	data := &self.variant.(Button_Widget_Variant)
	// Update retained data
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.disable_time = animate(ui, data.disable_time, DEFAULT_WIDGET_DISABLE_TIME, .Disabled in self.bits)
	// Paint
	if .Should_Paint in self.bits {
		opacity: f32 = 1.0 - data.disable_time * 0.5
		fill_color := fade(blend_colors(data.hover_time + (1.0 if .Pressed in self.state else 0.0), ui.style.color.button, ui.style.color.button_hovered, ui.style.color.button_pressed), opacity)
		text_color := fade(ui.style.color.button_text, opacity)
		corners: Corners = info.corners.? or_else {}
		// Shapes
		paint_rounded_box_corners_fill(
			ui.painter, 
			self.box, 
			ui.style.rounding, 
			corners, 
			fill_color,
			)
		if info.outlined {
			paint_rounded_box_corners_stroke(
				ui.painter,
				self.box,
				ui.style.rounding,
				ui.style.stroke_width,
				corners,
				{92, 92, 96, 255},
				)
		}
		text_origin: [2]f32
		text_align := info.align.? or_else .Middle
		switch text_align {
			case .Left:
			text_origin = {self.box.low.x + ui.style.layout.widget_padding, (self.box.low.y + self.box.high.y) / 2}
			case .Middle:
			text_origin = center(self.box)
			case .Right:
			text_origin = {self.box.high.x - ui.style.layout.widget_padding, (self.box.low.y + self.box.high.y) / 2}
		}
		paint_text(ui.painter, text_origin, {
			text = info.text, 
			font = info.font.? or_else ui.style.font.label, 
			size = info.text_size.? or_else ui.style.text_size.label, 
			align = text_align, 
			baseline = .Middle,
		}, text_color)
	}
	// Get next hover state
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// we're done here
	return result
}
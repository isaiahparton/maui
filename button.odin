package maui
import "core:fmt"

Button_Widget_Variant :: struct {
	hover_time,
	disable_time: f32,
	flashes: [dynamic]f32,
}
destroy_button_widget_variant :: proc(variant: ^Button_Widget_Variant) {
	delete(variant.flashes)
}
Button_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
	subtle: bool,
	font: Maybe(Font_Handle),
}
button :: proc(ui: ^UI, info: Button_Info, loc := #caller_location) -> Generic_Widget_Result {
	// Get widget
	self, result := get_widget(ui, info.generic, loc)
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
	for &value, i in data.flashes {
		value += ui.delta_time * 2
		if value > 1 {
			ordered_remove(&data.flashes, i)
		}
		ui.painter.next_frame = true
	}
	// Paint
	if .Should_Paint in self.bits {
		opacity: f32 = 1.0 - data.disable_time * 0.5
		fill_color := fade(ui.style.color.substance, (data.hover_time * (0.5 if info.subtle else 1.0)) * opacity)
		stroke_color: Color = fade(ui.style.color.substance, (1 - data.hover_time) * opacity)
		text_color := fade(blend_colors(ui.style.color.substance, ui.style.color.base, data.hover_time), opacity)
		// Shapes
		paint_box_fill(ui.painter, self.box, fill_color)
		for value in data.flashes {
			paint_box_fill(ui.painter, expand_box(self.box, 5 * value), fade(ui.style.color.flash, 1 - value))
		}
		if !info.subtle {
			paint_box_stroke(ui.painter, self.box, ui.style.stroke_width + (1 - ui.style.stroke_width) * data.disable_time, stroke_color)
		}
		paint_text(ui.painter, center(self.box), {
			text = info.text, 
			font = info.font.? or_else ui.style.font.label, 
			size = ui.style.text_size.label, 
			align = .Middle, 
			baseline = .Middle,
		}, text_color)
	}
	if .Clicked in self.state {
		append(&data.flashes, f32(0))
	}
	// Get next hover state
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// we're done here
	return result
}
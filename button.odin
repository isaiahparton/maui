package maui
import "core:fmt"
import "core:math"

Button_Widget_Variant :: struct {
	hover_time,
	active_time,
	disable_time: f32,
}
Button_Type :: enum {
	Filled,
	Outlined,
	Subtle,
}
Button_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
	font: Maybe(Font_Handle),
	text_align: Maybe(Text_Align),
	text_size: Maybe(f32),
	active: bool,
	type: Button_Type,
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
	min_size: f32
	if ui.placement.side == .Left || ui.placement.side == .Right {
		min_size = math.floor(measure_text(ui.painter, {
			text = info.text,
			font = info.font.? or_else ui.style.font.label, 
			size = info.text_size.? or_else ui.style.text_size.label,
		}).x + height(layout.box))
	}
	// Colocate the button
	self.box = info.box.? or_else next_box(ui, min_size)
	update_widget(ui, self)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Button_Widget_Variant{}
	}
	data := &self.variant.(Button_Widget_Variant)
	// Update retained data
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.active_time = animate(ui, data.active_time, DEFAULT_WIDGET_HOVER_TIME, info.active)
	data.disable_time = animate(ui, data.disable_time, DEFAULT_WIDGET_DISABLE_TIME, .Disabled in self.bits)
	if .Hovered in self.state {
		ui.cursor = .Hand
	}
	// Paint
	if .Should_Paint in self.bits {
		opacity: f32 = 1.0 - data.disable_time * 0.5
		text_color: Color
		box := move_box(self.box, -3 * data.active_time)
		if data.active_time > 0 {
			paint_box_fill(ui.painter, self.box, {0, 0, 0, 120})
		}
		// Types
		switch info.type {
			
			case .Filled:
			fill_color := alpha_blend_colors(blend_colors(data.hover_time, ui.style.color.button, ui.style.color.button_hovered), {0, 0, 0, 255}, 0.15 * data.active_time)
			paint_rounded_box_corners_fill(ui.painter, box, ui.style.rounding, info.corners, fill_color)
			text_color = blend_colors(data.hover_time, ui.style.color.label, ui.style.color.label_hovered)
			
			case .Outlined:
			fill_color := fade(ui.style.color.button_hovered, data.hover_time)
			if data.hover_time < 1 {
				paint_rounded_box_corners_stroke(ui.painter, box, ui.style.rounding, 1, info.corners, ui.style.color.button)
			}
			paint_rounded_box_corners_fill(ui.painter, box, ui.style.rounding, info.corners, fill_color)
			text_color = blend_colors(data.hover_time, ui.style.color.button_hovered, ui.style.color.label_hovered)

			case .Subtle:
			fill_color := fade(ui.style.color.button_hovered, data.hover_time)
			paint_rounded_box_corners_fill(ui.painter, box, ui.style.rounding, info.corners, fill_color)
			text_color = blend_colors(data.hover_time, ui.style.color.button_hovered, ui.style.color.label_hovered)
		}
		// Text title
		text_origin: [2]f32
		text_align := info.text_align.? or_else .Middle
		switch text_align {
			case .Left:
			text_origin = {box.low.x + ui.style.layout.widget_padding, (box.low.y + box.high.y) / 2}
			case .Middle:
			text_origin = center(box)
			case .Right:
			text_origin = {box.high.x - ui.style.layout.widget_padding, (box.low.y + self.box.high.y) / 2}
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
	update_layer_content_bounds(ui.layers.current, self.box)
	// we're done here
	return result
}
package maui_widgets
import "../"

Number_Input_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	value: f64,
	prefix,
	suffix,
	placeholder: Maybe(string),
}
Number_Input_Result :: struct {
	using generic: maui.Generic_Widget_Result,
	value: f64,
}
number_input :: proc(ui: ^maui.UI, info: Number_Input_Info, loc := #caller_location) -> Number_Input_Result {
	using maui

	self, generic_result := get_widget(ui, hash(ui, loc))
	result: Number_Input_Result = {
		generic = generic_result,
	}
	// Colocate
	self.options += {.Draggable, .Can_Key_Select}
	self.box = info.box.? or_else layout_next(current_layout(ui))
	// Update
	update_widget(ui, self)
	// Text cursor
	if .Hovered in self.state {
		ui.cursor = .Beam
	}
	// Animate
	hover_time := animate_bool(ui, &self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
	focus_time := animate_bool(ui, &self.timers[1], .Focused in self.state, 0.15)

	buffer := get_scribe_buffer(&ui.scribe, self.id)

	inner_box: Box = {{self.box.low.x + ui.style.layout.widget_padding, self.box.low.y}, {self.box.high.x - ui.style.layout.widget_padding, self.box.high.y}}
	text_origin: [2]f32 = {inner_box.low.x, (inner_box.low.y + inner_box.high.y) / 2}

	if .Focused in self.state {
		escribe_text(&ui.scribe, ui.io, {
			array = buffer,
			allowed_runes = "0123456789.",
		})
	}

	if .Should_Paint in self.bits {
		if info.placeholder != nil {
			if len(buffer) == 0 {
				paint_text(
					ui.painter,
					text_origin, 
					{font = ui.style.font.label, size = ui.style.text_size.field, text = info.placeholder.?, baseline = .Middle}, 
					ui.style.color.base_text[1],
				)
			}
		}
		fill_color := fade(ui.style.color.substance[1], 0.2 * hover_time)
		stroke_color := ui.style.color.substance[0]
		points, point_count := get_path_of_box_with_cut_corners(self.box, height(self.box) * 0.2, {.Top_Right})
		paint_path_fill(ui.painter, points[:point_count], fill_color)
		scale := width(self.box) * 0.5 * focus_time
		center := center_x(self.box)
		paint_box_fill(ui.painter, {{center - scale, self.box.high.y - 2}, {center + scale, self.box.high.y}}, stroke_color)
		paint_path_stroke(ui.painter, points[:point_count], true, ui.style.stroke_width, 0, stroke_color)
	}

	paint_interact_text(ui, self, text_origin, {font = ui.style.font.label, size = ui.style.text_size.field, text = string(buffer[:]), baseline = .Middle}, {}, ui.style.color.base_text[0])

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	return result
}
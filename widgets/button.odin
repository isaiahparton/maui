package maui_widgets
import "../"
import "core:fmt"
import "core:runtime"

get_button_fill_and_stroke :: proc(style: ^maui.Style, hover_time: f32, type: Button_Type) -> (fill_color, stroke_color, text_color: maui.Color) {
	switch type {
		case .Subtle:
		fill_color = maui.fade(style.color.substance[0], 0.55 * hover_time)
		stroke_color = maui.fade(style.color.substance[0], 0.6 + 0.4 * hover_time)
		text_color = maui.blend_colors(style.color.substance[0], style.color.base[0], hover_time)

		case .Normal:
		fill_color = maui.fade(style.color.substance[0], 0.2 + 0.8 * hover_time)
		stroke_color = style.color.substance[0]
		text_color = maui.blend_colors(style.color.substance[0], style.color.base[0], hover_time)
	}
	return
}

Rounded_Button_Shape :: distinct maui.Corners
Cut_Button_Shape :: distinct maui.Corners
Button_Shape :: union {
	Rounded_Button_Shape,
	Cut_Button_Shape,
}
Button_Type :: enum {
	Subtle,
	Normal,
}
Button_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	text: string,
	type: Button_Type,
	shape: Button_Shape,
}
Button_State :: struct {
	hover_time: f32,
	click_times: [dynamic]f32,
}
update_button_state :: proc(ui: ^maui.UI, state: ^Button_State) {
	if state.click_times == nil {
		return
	}
	for &elem, i in state.click_times {
		elem += ui.delta_time * 2
		if elem > 1 {
			ordered_remove(&state.click_times, i)
		}
		ui.painter.next_frame = true
	}
}
destroy_button_state :: proc(data: rawptr) {
	state := (^Button_State)(data)
	delete(state.click_times)
}
button :: proc(ui: ^maui.UI, info: Button_Info, loc := #caller_location) -> maui.Generic_Widget_Result {
	using maui
	self, result := get_widget(ui, hash(ui, loc))
	// Place the widget
	self.box = info.box.? or_else layout_next(current_layout(ui))
	// Update the widget's state
	update_widget(ui, self)
	data := (^Button_State)(require_data(self, Button_State, destroy_button_state))
	update_button_state(ui, data)
	// Animations
	hover_time := animate_bool(ui, &self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
	// Check if painting is needed
	if .Should_Paint in self.bits {
		fill_color := fade(255, hover_time)
		stroke_color: Color = fade(255, 1 - hover_time)
		text_color := blend_colors(255, {0, 0, 0, 255}, hover_time)

		flash_color: Color = {255, 10, 100, 255}
		// Paint
		switch shape in info.shape {
			case nil:
			paint_box_fill(ui.painter, self.box, fill_color)
			for click_time in data.click_times {
				paint_box_fill(ui.painter, expand_box(self.box, 5 * click_time), fade(flash_color, 1 - click_time))
			}
			paint_box_stroke(ui.painter, self.box, ui.style.stroke_width, stroke_color)

			case Rounded_Button_Shape:
			rounding := height(self.box) * 0.2
			for click_time in data.click_times {
				box := expand_box(self.box, 5 * click_time)
				paint_rounded_box_corners_fill(ui.painter, box, height(box) * 0.2, Corners(shape), fade(flash_color, 1 - click_time))
			}
			paint_rounded_box_corners_fill(ui.painter, self.box, rounding, Corners(shape), fill_color)
			paint_rounded_box_corners_stroke(ui.painter, self.box, rounding, ui.style.stroke_width, Corners(shape), stroke_color)

			case Cut_Button_Shape:
			for click_time in data.click_times {
				box := expand_box(self.box, click_time * 5)
				points, count := get_path_of_box_with_cut_corners(box, height(box) * 0.2, Corners(shape))
				paint_path_fill(ui.painter, points[:count], fade(flash_color, 1 - click_time))
			}
			{
				points, count := get_path_of_box_with_cut_corners(self.box, height(self.box) * 0.2, Corners(shape))
				paint_path_fill(ui.painter, points[:count], fill_color)
				paint_path_stroke(ui.painter, points[:count], true, ui.style.stroke_width, 0, stroke_color)
			}
		}
		paint_text(ui.painter, center(self.box), {
			text = info.text, 
			font = ui.style.font.label, 
			size = ui.style.text_size.label, 
			align = .Middle, 
			baseline = .Middle,
		}, text_color)
	}
	if .Clicked in self.state {
		append(&data.click_times, 0.0)
	}
	// Whosoever hovereth with the mouse
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// We're done here
	return result
}
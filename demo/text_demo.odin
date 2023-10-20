package demo

import maui "../"
import maui_widgets "../widgets"

Box_Controls :: struct {
	drag_low,
	drag_high: bool,
	anchor: [2]f32,
}

do_box_controls :: proc(using self: ^Box_Controls, box: maui.Box, color: maui.Color) -> maui.Box {
	using maui, maui_widgets

	next_box := box 
	paint_box_stroke(box, 1, color)
	SIZE :: 16
	{
		widget_box: Box = {box.low, box.low + SIZE}
		paint_triangle_fill(box.low, {box.low.x, box.low.y + SIZE}, {box.low.x + SIZE, box.low.y}, color)
		if drag_low {
			next_box.low = input.mouse_point
			if mouse_released(.Left) {
				drag_low = false
			}
		} else if point_in_box(input.mouse_point, widget_box) && mouse_pressed(.Left) {
			drag_low = true
		}
	}
	{
		widget_box: Box = {box.high - SIZE, box.high}
		paint_triangle_fill({box.high.x - SIZE, box.high.y}, box.high, {box.high.x, box.high.y - SIZE}, color)
		if drag_high {
			next_box.high = input.mouse_point
			if mouse_released(.Left) {
				drag_high = false
			}
		} else if point_in_box(input.mouse_point, widget_box) && mouse_pressed(.Left) {
			drag_high = true
		}
	}
	return next_box 
}

Text_Demo :: struct {
	info: maui.Text_Info,
	paint_info: maui.Text_Paint_Info,

	clip_controls: Box_Controls,
}

do_text_demo :: proc(using self: ^Text_Demo) {
	using maui, maui_widgets
	
	if do_layout(.Left, Exact(200)) {
		space(Exact(20))
		placement.size = Exact(30)
		space(Exact(20))
		do_text_field({
			data = &info.text,
			title = "Text",
		})
		space(Exact(20))
		do_checkbox({state = &info.hidden, text = "Hidden"})
		space(Exact(20))
		if change, new_state := do_checkbox({state = bool(paint_info.clip != nil), text = "Enable Clipping"}); change {
			if new_state == false {
				paint_info.clip = nil
			} else {
				center := core.size / 2
				paint_info.clip = Box{center - 100, center + 100}
			}
		}
		space(Exact(20))
		placement.size = Exact(30)
		paint_info.align = do_enum_radio_buttons(paint_info.align)
		space(Exact(20))
		paint_info.baseline = do_enum_radio_buttons(paint_info.baseline)
		space(Exact(20))
		info.wrap = do_enum_radio_buttons(info.wrap)
		space(Exact(20))
		info.size = do_slider(Slider_Info(f32){
			value = info.size, 
			low = 8, 
			high = 48,
			format = "%.0f",
		})
		space(Exact(20))
		if change, new_state := do_checkbox({state = (info.limit.x != nil), text = "Horizontal Limit"}); change {
			if new_state && info.limit.x == nil {
				info.limit.x = 200
			} else {
				info.limit.x = nil
			}
		}
		if info.limit.x != nil {
			info.limit.x = do_slider(Slider_Info(f32){
				value = info.limit.x.?, 
				low = 0, 
				high = 500,
				format = "%.0f",
			})
		}
		space(Exact(20))
		if change, new_state := do_checkbox({state = (info.limit.y != nil), text = "Vertical Limit"}); change {
			if new_state && info.limit.y == nil {
				info.limit.y = 200
			} else {
				info.limit.y = nil
			}
		}
		if info.limit.y != nil {
			info.limit.y = do_slider(Slider_Info(f32){
				value = info.limit.y.?, 
				low = 0, 
				high = 500,
				format = "%.0f",
			})
		}
	}
	cut(.Left, Exact(30))

	box := current_layout().box 
	if result, ok := do_layer({
		placement = box,
	}); ok {
		paint_box_fill(box, get_color(.Widget_Back))
		paint_box_stroke(box, 2, get_color(.Widget_Stroke))
		paint_box_fill({{box.low.x, center_y(box)}, {box.high.x, center_y(box) + 1}}, {0, 100, 0, 255})
		paint_box_fill({{center_x(box), box.low.y}, {center_x(box) + 1, box.high.y}}, {0, 100, 0, 255})
		placement.size = Relative(1); placement.align = {.Middle, .Middle}
		do_interactable_text({
			text_info = info,
			paint_info = paint_info,
		})
		if clip, ok := paint_info.clip.?; ok {
			paint_info.clip = do_box_controls(&clip_controls, clip, {0, 100, 100, 255})
		}
	}
}
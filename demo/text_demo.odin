package demo

import ui "../"

Box_Controls :: struct {
	drag_start,
	drag_end: bool,
	anchor: [2]f32,
}

do_box_controls :: proc(using self: ^Box_Controls, box: ui.Box, color: ui.Color) -> ui.Box {
	using ui
	box := box 
	paint_box_stroke(box, 1, {0, 100, 100, 255})
	{
		box: Box = {box.x - 8, box.y - 8, 16, 16}
		paint_box_fill(box, {0, 100, 100, 255})
		if drag_start {
			box.x = input.mouse_point.x 
			box.y = input.mouse_point.y
			if mouse_released(.Left) {
				drag_start = false
			}
		} else if point_in_box(input.mouse_point, box) && mouse_pressed(.Left) {
			drag_start = true
		}
	}
	{
		box: Box = {box.x + box.w - 8, box.y + box.h - 8, 16, 16}
		paint_box_fill(box, {0, 100, 100, 255})
		if drag_end {
			box.w = input.mouse_point.x - box.x 
			box.h = input.mouse_point.y - box.y
			if mouse_released(.Left) {
				drag_end = false
			}
		} else if point_in_box(input.mouse_point, box) && mouse_pressed(.Left) {
			drag_end = true
		}
	}
	return box 
}

Text_Demo :: struct {
	info: ui.Text_Info,
	paint_info: ui.Text_Paint_Info,

	clip_controls: Box_Controls,
}

do_text_demo :: proc(using self: ^Text_Demo) {
	using ui
	paint_box_fill({0, core.size.y / 2, core.size.x, 1}, {0, 100, 0, 255})
	paint_box_fill({core.size.x / 2, 0, 1, core.size.y}, {0, 100, 0, 255})

	paint_text(core.size / 2, info, paint_info, {255, 255, 255, 255})
	if clip, ok := paint_info.clip.?; ok {
		paint_info.clip = do_box_controls(&clip_controls, clip, {0, 100, 100, 255})
	}
	
	space(Exact(20))
	placement.size = Exact(30)
	space(Exact(20))
	if do_layout(.Top, Exact(30)) {
		placement.size = Exact(300); placement.side = .Left 
		do_text_input({
			data = &info.text,
			title = "Text",
		})
	}
	space(Exact(20))
	paint_info.align = do_enum_radio_buttons(paint_info.align)
	space(Exact(20))
	paint_info.baseline = do_enum_radio_buttons(paint_info.baseline)
	space(Exact(20))
	info.wrap = do_enum_radio_buttons(info.wrap)
	space(Exact(20))
	if do_layout(.Top, Exact(30)) {
		placement.side = .Left; placement.size = Exact(200)
		if changed, new_value := do_slider(Slider_Info(f32){
			value = info.size, 
			low = 8, 
			high = 48,
			format = "%.0f",
		}); changed {
			info.size = new_value
		}
	}
	space(Exact(20))
	if do_layout(.Top, Exact(30)) {
		placement.side = .Left; placement.size = Exact(200)
		if info.limit.x != nil {
			if changed, new_value := do_slider(Slider_Info(f32){
				value = info.limit.x.?, 
				low = 0, 
				high = 500,
				format = "%.0f",
			}); changed {
				info.limit.x = new_value
			}
		}
	}
}
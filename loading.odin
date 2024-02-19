package maui
import "core:fmt"
import "core:math"
import "core:math/ease"

paint_box_loader :: proc(ui: ^UI, box: Box) {
	gradient_width := width(box)
	_time := ui.current_time * 0.85
	time: f32 = f32(_time - math.floor(_time))
	time = ease.cubic_in_out(time)
	range := width(box) + gradient_width
	bar_box: Box = {{box.low.x - gradient_width + range * time, box.low.y}, {0, box.high.y}}
	bar_box.high.x = bar_box.low.x + gradient_width
	paint_box_fill(ui.painter, box, ui.style.color.background[0])
	
	left_time := clamp((box.low.x - bar_box.low.x) / gradient_width, 0, 1)
	right_time := clamp((bar_box.high.x - box.high.x) / gradient_width, 0, 1)
	left_color := blend_colors(left_time, ui.style.color.background[0], ui.style.color.background[1])
	right_color := blend_colors(right_time, ui.style.color.background[1], ui.style.color.background[0])
	if bar_box.low.x <= box.high.x && bar_box.high.x >= box.low.x {
		paint_quad_vertices(ui.painter, 
			{point = {max(bar_box.low.x, box.low.x), bar_box.low.y}, color = left_color},
			{point = {max(bar_box.low.x, box.low.x), bar_box.high.y}, color = left_color},
			{point = {min(bar_box.high.x, box.high.x), bar_box.high.y}, color = right_color},
			{point = {min(bar_box.high.x, box.high.x), bar_box.low.y}, color = right_color},
			)
	}
	ui.painter.next_frame = true
}
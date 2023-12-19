package maui_widgets
import "../"

import "core:math"
import "core:math/linalg"

Progress_Bar_Info :: struct {
	time: f32,
	text: string,
}
do_progress_bar :: proc(info: Progress_Bar_Info, loc := #caller_location) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)

		if .Should_Paint in self.bits {
			size := self.box.high - self.box.low
			radius := math.floor(size.y / 2)
			if src, ok := atlas_get_ring(&painter.atlas, 0, radius); ok {
				half_size := math.trunc(width(src) / 2)
				half_width := min(half_size, size.x / 2)

				src_left: Box = {src.low, {src.low.x + half_width, src.high.y}}
				src_right: Box = {{src.high.x - half_width, src.low.y}, src.high}

				paint_textured_box(painter.atlas.texture, src_left, {self.box.low, {self.box.low.x + half_width, self.box.high.y}}, style.color.substance[0])
				paint_textured_box(painter.atlas.texture, src_right, {{self.box.high.x - half_width, self.box.low.y}, self.box.high}, style.color.substance[0])
				if self.box.high.x > self.box.low.x + size.y {
					paint_box_fill({{self.box.low.x + radius, self.box.low.y}, {self.box.high.x - radius, self.box.high.y}}, style.color.substance[0])
				}
			}
			progress_box: Box = {self.box.low, {self.box.low.x + width(self.box) * clamp(info.time, 0, 1), self.box.high.y}}
			paint_clipped_pill_fill_h(self.box, progress_box, style.color.accent[0])
		}

		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
}
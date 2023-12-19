package maui_widgets
import "../"

import "core:math"
import "core:math/linalg"

Chart_Member :: struct($T: typeid) {
	data: []T,
	colors: [2]maui.Color,
}
Area_Chart_Info :: struct($T: typeid) {
	members: []Chart_Member(T),
}
Area_Chart_State :: struct($T: typeid) {
	low, high: T,
}
do_area_chart :: proc(info: Area_Chart_Info($T), state: ^Area_Chart_State(T), loc := #caller_location) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)
		if .Should_Paint in self.bits {
			paint_rounded_box_corners_fill(self.box, style.rounding, style.rounded_corners, style.color.base[1])
			inner_box := self.box
			for &member in info.members {
				step := width(inner_box) / f32(len(member.data) - 1)
				inner_size := inner_box.high - inner_box.low
				if len(member.data) > 1 {
					offset: f32
					next_low: f32 = math.F32_MAX
					next_high: f32 = 0
					for i in 0..<(len(member.data) - 1) {
						x := member.data[i]
						y := member.data[i + 1]
						next_low = min(next_low, x, y)
						next_high = max(next_high, x, y)
						a := (x - state.low) / (state.high - state.low)
						b := (y - state.low) / (state.high - state.low)
						c := offset / inner_size.x
						d := (offset + step) / inner_size.x
						paint_quad_vertices(
							{
								point = {inner_box.high.x - offset, inner_box.high.y},
								color = blend_colors(member.colors[0], member.colors[1], c),
							},
							{
								point = {inner_box.high.x - (offset + step), inner_box.high.y},
								color = blend_colors(member.colors[0], member.colors[1], d),
							},
							{
								point = {inner_box.high.x - (offset + step), inner_box.high.y - inner_size.y * b},
								color = blend_colors(member.colors[0], member.colors[1], d),
							},
							{
								point = {inner_box.high.x - offset, inner_box.high.y - inner_size.y * a},
								color = blend_colors(member.colors[0], member.colors[1], c),
							},
						)
						offset += step
					}
					state.low = next_low
					state.high = next_high
				}
			}
		}
	}
}
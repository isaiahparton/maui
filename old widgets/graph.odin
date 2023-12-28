package maui_widgets
import "../"
import "core:math"
import "core:math/linalg"

/*Graph_Curve_Proc :: proc(f32) -> f32 
Graph_Info :: struct {
	using info: maui.Widget_Info,
	step: [2]f32,
	show_axes: bool,
}
Graph_State :: struct {
	offset: [2]f32,
	transform: linalg.Matrix3x3f32,
}
do_graph :: proc(info: Graph_Info, state: ^Graph_State, loc := #caller_location) -> (ok: bool) {
	using maui
	if self, _ok := do_widget(hash(loc), {.Draggable}); _ok {
		self.box = info.box.? or_else layout_next(current_layout())
		update_widget(self)

		view_box := self.box
		if .Should_Paint in self.bits {
			paint_rounded_box_fill(view_box, style.rounding, style.color.base[1])

		}

		if .Hovered in self.state {
			zoom := input.mouse_scroll.y
			if abs(zoom) > 0 {
				anchor := input.mouse_point - self.box.low
				scale := state.view.high - state.view.low
				time := (anchor - state.view.low) / scale

				new_scale := scale + zoom
				state.view.low = anchor - time * new_scale
				state.view.high = anchor + (1 - time) * new_scale
			}
		}

		if .Got_Press in self.state {
			ctx.drag_anchor = (input.mouse_point - view_box.low) - state.view.low
		} else if .Pressed in self.state {
			view_size := state.view.high - state.view.low
			state.view.low = (input.mouse_point - view_box.low) - ctx.drag_anchor
			state.view.high = state.view.low + view_size
		}

		state.view.high = linalg.max(state.view.high, state.view.low + info.step * 10)

		update_widget_hover(self, point_in_box(input.mouse_point, view_box))
	}
	return
}

graph_curve :: proc(curve_proc: Graph_Curve_Proc) {

}*/
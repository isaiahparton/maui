package maui_widgets
import "../"
import "core:math"
import "core:math/linalg"

Graph_Curve_Proc :: proc(f32) -> f32 
Graph_Info :: struct {
	step: [2]f32,
}
Graph_State :: struct {
	view: maui.Box,
}
do_graph :: proc(info: Graph_Info, state: ^Graph_State, loc := #caller_location) -> (ok: bool) {
	using maui
	if self, _ok := do_widget(hash(loc), {.Draggable}); _ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)

		if .Should_Paint in self.bits {
			paint_rounded_box_fill(self.box, style.rounding, style.color.base[1])

			// Grid
			for p := state.view.low.x; p < state.view.high.x; p += info.step.x {
				lp := p - state.view.low.x
				paint_line({p, self.box.low.y}, {p, self.box.high.y}, 1, style.color.substance[int(p == 0)])
			}

			paint_text(self.box.low, {text = tmp_print(state.view), font = style.font.label, size = style.text_size.label}, {}, style.color.base_text[1])
		}

		if .Hovered in self.state {
		}

		if .Got_Press in self.state {
			core.drag_anchor = input.mouse_point + state.view.low
		} else if .Pressed in self.state {
			view_size := state.view.high - state.view.low
			state.view.low = core.drag_anchor - input.mouse_point
			state.view.high = state.view.low + view_size
		}

		state.view.high = linalg.max(state.view.high, state.view.low + info.step)

		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

graph_curve :: proc(curve_proc: Graph_Curve_Proc) {

}
package maui_widgets

import maui "../"

import "core:math"
import "core:math/linalg"

/*
	A draggable is a layer that can be dragged from it's home
*/

Draggable_Result :: struct {
	dropped: Maybe([2]f32),
	layer: ^maui.Layer,
	widget: ^maui.Widget,
}
Draggable_Info :: struct {
	label: maui.Label,
}
@(deferred_out=_do_draggable)
do_draggable :: proc(info: Draggable_Info, loc := #caller_location) -> (res: Draggable_Result, ok: bool) {
	using maui
	if self, _ok := do_widget(hash(loc), {.Draggable}); _ok {
		home_box := use_next_box() or_else layout_next(current_layout())
		self.box = home_box
		// Relocate
		if .Active in self.bits {
			self.box.low = input.mouse_point + self.offset 
			self.box.high = self.box.low + (home_box.high - home_box.low)
		}
		// Update
		update_widget(self)
		// Dragging
		if .Got_Press in self.state {
			self.offset = input.mouse_point - self.box.low
			if linalg.length((self.box.low + self.offset) - input.mouse_point) > 10 {
				self.bits += {.Active}
			}
		}
		// Layer
		if .Active in self.bits {
			if layer, _ok := begin_layer({placement = self.box}); _ok {

				res.layer = layer
			}
		}
		// Drop
		if .Focused not_in self.state {
			self.bits -= {.Active}
			res.dropped = input.mouse_point
		}
		// Paint
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, get_color(.Widget))
		}
		push_layout(self.box)
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
		res.widget = self 
		ok = true
	}
	return
}
@private
_do_draggable :: proc(res: Draggable_Result, ok: bool) {
	using maui
	if ok {
		pop_layout()
		if .Focused in res.widget.state {
			end_layer(res.layer)
		}
	}
}
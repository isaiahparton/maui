package maui_widgets
import "../"
import "core:math"
import "core:math/linalg"
import "core:math/ease"

/*
	Combo box
*/
Tree_Node_Info :: struct{
	using info: maui.Widget_Info,
	text: string,
	size: f32,
	persistent: bool,
}

@(deferred_out=_do_tree_node)
do_tree_node :: proc(info: Tree_Node_Info, loc := #caller_location) -> (active: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		self.box = info.box.? or_else layout_next(current_layout())
		if self.state & {.Hovered} != {} {
			ctx.cursor = .Hand
		}
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		open_time := animate_bool(&self.timers[1], .Active in self.bits, 0.3, .Cubic_In_Out)
		update_widget(self)
		h := height(self.box)
		// Paint
		if .Should_Paint in self.bits {
			color := blend_colors(ctx.style.color.base_text[0], ctx.style.color.base_text[1], hover_time)
			paint_arrow(self.box.low + h / 2, 6, -math.PI * 0.5 * (1 - open_time), 1, color)
			paint_text({self.box.low.x + h, center_y(self.box)}, {text = info.text, font = ctx.style.font.title, size = ctx.style.text_size.label}, {align = .Left, baseline = .Middle}, color)
		}
		// Invert state on click
		if .Clicked in self.state {
			self.bits = self.bits ~ {.Active}
		}
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
		// Begin layer
		if open_time > 0 || info.persistent {
			// Deploy layer
			_, active = begin_layer({
				placement = Layer_Placement_Info{
					origin = {self.box.low.x + h, self.box.high.y},
					size = {width(self.box) - h, nil},
				},
				layout_align = {.Near, .Far},
				scale = [2]f32{1, open_time},
				grow = .Top,
				id = self.id,
				options = {.Attached, .Clip_To_Parent, .No_Scroll_Y},
			})
		}
	}
	return
}
@private 
_do_tree_node :: proc(active: bool) {
	using maui
	if active {
		layer := current_layer()
		end_layer(layer)
		layout_cut_or_grow(current_layout(), .Top, height(layer.box))
	}
}
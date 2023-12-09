package maui_widgets
import "../"
import "core:math"
import "core:math/linalg"
import "core:math/ease"

/*
	Combo box
*/
Tree_Node_Info :: struct{
	text: string,
	size: f32,
}

@(deferred_out=_do_tree_node)
do_tree_node :: proc(info: Tree_Node_Info, loc := #caller_location) -> (active: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		if self.state & {.Hovered} != {} {
			core.cursor = .Hand
		}
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		open_time := animate_bool(&self.timers[1], .Active in self.bits, 0.3, .Cubic_In_Out)
		update_widget(self)
		h := height(self.box)
		// Paint
		if .Should_Paint in self.bits {
			color := blend_colors(style.color.base_text[0], style.color.base_text[1], hover_time)
			paint_arrow(self.box.low + h / 2, 6, -math.PI * 0.5 * (1 - open_time), 1, color)
			paint_text({self.box.low.x + h, center_y(self.box)}, {text = info.text, font = style.font.title, size = style.text_size.title}, {align = .Left, baseline = .Middle}, color)
		}
		// Invert state on click
		if .Clicked in self.state {
			self.bits = self.bits ~ {.Active}
		}
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
		// Begin layer
		if open_time > 0 {
			layer: ^Layer
			// Prepare layer box
			layer_box := cut(.Top, info.size * open_time)
			layer_box.low.x += h
			// Deploy layer
			layer, active = begin_layer({
				placement = layer_box,
				space = [2]f32{0, info.size},
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
	}
}
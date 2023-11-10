package maui_widgets
import "../"

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
		using self
		self.box = use_next_box() or_else layout_next(current_layout())
		if state & {.Hovered} != {} {
			core.cursor = .Hand
		}

		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in state, 0.15)
		state_time := animate_bool(&self.timers[1], .Active in bits, 0.15)
		update_widget(self)
		// Paint
		if .Should_Paint in bits {
			//TODO: Replace with nice new arrow yes
			// paint_aligned_rune(painter.style.button_font, painter.style.button_font_size, .Chevron_Down if .Active in bits else .Chevron_Right, center(box), color, {.Middle, .Middle})
			paint_text({box.low.x + height(box), center_y(box)}, {text = info.text, font = style.font.title, size = style.text_size.title}, {align = .Left, baseline = .Middle}, style.color.base_text[0])
		}

		// Invert state on click
		if .Clicked in state {
			bits = bits ~ {.Active}
		}

		// Begin layer
		if state_time > 0 {
			box := cut(.Top, info.size * state_time)
			layer: ^Layer
			layer, active = begin_layer({
				placement = box, 
				space = [2]f32{0, info.size}, 
				id = id, 
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
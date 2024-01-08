package maui_widgets
import "../"
import "core:math"
import "core:runtime"

Tree_Node_Info :: struct {
	using generic: maui.Generic_Widget_Info,
	text: string,
}
Tree_Node_Result :: struct {
	using generic: maui.Generic_Widget_Result,
	layer: Maybe(^maui.Layer),
	layout: Maybe(^maui.Layout),
	expanded: bool,
}
@(deferred_in_out=_tree_node)
tree_node :: proc(ui: ^maui.UI, info: Tree_Node_Info, loc := #caller_location) -> Tree_Node_Result {
	using maui

	self, generic_result := get_widget(ui, hash(ui, loc))
	result: Tree_Node_Result = {
		generic = generic_result,
	}

	self.box = info.box.? or_else layout_next(current_layout(ui))

	update_widget(ui, self)

	hover_time := animate_bool(ui, &self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
	open_time := animate_bool(ui, &self.timers[1], .Active in self.bits, 0.2)

	my_height := height(self.box)
	if .Should_Paint in self.bits {
		fill_color := alpha_blend_colors(ui.style.color.substance[0], ui.style.color.substance_hover, hover_time)
		paint_box_fill(ui.painter, self.box, fill_color)
		paint_arrow(ui.painter, self.box.low + my_height / 2, my_height * 0.15, -math.PI * 0.5 * (1 - open_time), 2, ui.style.color.substance_text[0])
		paint_text(ui.painter, {self.box.low.x + my_height, self.box.low.y + my_height / 2}, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label, baseline = .Middle}, ui.style.color.substance_text[0])
	}

	if open_time > 0 {
		result.layer, _ = begin_layer(ui, {
			placement = Layer_Placement_Info{
				origin = {self.box.low.x + my_height, self.box.high.y},
				size = {width(self.box) - my_height, nil},
			},
			layout_align = {.Near, .Far},
			scale = [2]f32{1, open_time},
			grow = .Down,
			id = self.id,
			options = {.Attached, .Clip_To_Parent, .No_Scroll_Y},
			clip_sides = Box_Sides{.Top},
		})
		result.layout = current_layout(ui)
		result.expanded = true
	}

	if .Clicked in self.state {
		self.bits ~= {.Active}
	}

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	return result
}
@private
_tree_node :: proc(ui: ^maui.UI, _: Tree_Node_Info, _: runtime.Source_Code_Location, result: Tree_Node_Result) {
	using maui
	if result.expanded {
		end_layer(ui, result.layer.?)
		//NOTE: This is a temporary workaround
		layout_cut_or_grow(current_layout(ui), .Down, height(result.layer.?.box))
	}
}
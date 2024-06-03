package maui
import "../"
import "core:math"
import "core:math/ease"
import "core:runtime"

Tree_Node_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
}
Tree_Node_Result :: struct {
	using generic: Generic_Widget_Result,
	layer: Maybe(^Layer),
	layout: Maybe(^Layout),
	expanded: bool,
}
@(deferred_in_out=_tree_node)
tree_node :: proc(ui: ^UI, info: Tree_Node_Info, loc := #caller_location) -> Tree_Node_Result {
	self, generic_result := get_widget(ui, info, loc)
	result: Tree_Node_Result = {
		generic = generic_result,
	}

	self.box = info.box.? or_else next_box(ui)

	update_widget(ui, self)

	if self.variant == nil {
		self.variant = Menu_Widget_Variant{}
	}
	data := &self.variant.(Menu_Widget_Variant)
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.open_time = animate(ui, data.open_time, 0.2, data.is_open)

	my_height := height(self.box)
	if .Should_Paint in self.bits {
		hover_color := fade(ui.style.color.text[1], 0.5 + 0.5 * max(data.hover_time, data.open_time))
		baseline := center_y(self.box)
		paint_arrow(ui.painter, self.box.high - my_height * [2]f32{0.4, 0.5}, my_height * 0.2, math.PI * 0.5 * (1 - data.open_time), 2, hover_color)
		paint_text(ui.painter, {self.box.low.x, self.box.low.y + my_height / 2}, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label, baseline = .Middle}, hover_color)
		paint_box_fill(ui.painter, {{self.box.low.x, self.box.high.y - 1}, self.box.high}, hover_color)
	}

	if data.open_time > 0 {
		layer, _ := begin_layer(ui, {
			placement = Layer_Placement_Info{
				origin = {self.box.low.x, self.box.high.y},
				size = {width(self.box), nil},
			},
			layout_align = {.Near, .Far},
			scale = [2]f32{1, ease.quadratic_in_out(data.open_time)},
			grow = .Down,
			id = self.id,
			options = {.Attached, .Clip_To_Parent, .No_Scroll_Y},
			clip_sides = Box_Sides{.Top},
		})
		result.layer = layer
		result.layout = current_layout(ui)
		result.expanded = true
	}

	if .Clicked in self.state {
		data.is_open = !data.is_open
	}

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	return result
}
@private
_tree_node :: proc(ui: ^UI, _: Tree_Node_Info, _: runtime.Source_Code_Location, result: Tree_Node_Result) {
	if result.expanded {
		end_layer(ui, result.layer.?)
		update_layer_content_bounds(current_layer(ui), result.layer.?.box)
		//NOTE: This is a temporary workaround
		layout_cut_or_grow(current_layout(ui), .Top, height(result.layer.?.box))
	}
}
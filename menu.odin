package maui
import "core:runtime"

Menu_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
}
Menu_Result :: struct {
	using generic: Generic_Widget_Result,
	is_open: bool,
	layer: ^Layer,
}
Menu_Widget_Variant :: struct {
	is_open: bool,
	hover_time,
	open_time: f32,
}

@(deferred_in_out=_menu)
menu :: proc(ui: ^UI, info: Menu_Info, loc := #caller_location) -> (Menu_Result, bool) {
	self, generic_result := get_widget(ui, info, loc)
	result: Menu_Result = {
		generic = generic_result,
	}

	// Assert variant existence
	if self.variant == nil {
		self.variant = Menu_Widget_Variant{}
	}
	data := &self.variant.(Menu_Widget_Variant)
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.open_time = animate(ui, data.open_time, 0.1, data.is_open)

	layout := current_layout(ui)
	layout.size.x = measure_text(ui.painter, {
		text = info.text,
		font = ui.style.font.label, 
		size = ui.style.text_size.label,
	}).x + height(layout.box)

	self.box = info.box.? or_else layout_next(layout)
	update_widget(ui, self)

	if .Should_Paint in self.bits {
		paint_box_fill(ui.painter, self.box, blend_colors(data.hover_time + (1.0 if .Pressed in self.state else 0.0), ui.style.color.button, ui.style.color.button_hovered, ui.style.color.button_pressed))
		paint_box_fill(ui.painter, {{self.box.low.x, self.box.high.y - 4}, self.box.high}, fade(ui.style.color.accent, data.open_time))
		paint_text(ui.painter, center(self.box), {
			text = info.text,
			font = ui.style.font.label,
			size = ui.style.text_size.label,
			align = .Middle,
			baseline = .Middle,
		}, ui.style.color.text[0])
	}

	if .Clicked in self.state {
		data.is_open = true
	}

	if data.is_open {
		ui.keep_menus_open = true
		result.layer, result.is_open = begin_layer(ui, {
			id = self.id,
			placement = Layer_Placement_Info{
				origin = {self.box.low.x, self.box.high.y},
				size = {width(self.box), nil},
			},
			grow = .Down,
			options = {.Attached},
		})
	} else if ui.open_menus {
		if .Hovered in self.state {
			ui.widgets.focus_id = self.id
			ui.layers.focus_id = 0
			data.is_open = true
		}
	}

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	if result.is_open {
		layout := current_layout(ui)
		layout.direction = .Down
		paint_box_stroke(ui.painter, result.layer.box, 1, ui.style.color.text[1])
	}

	return result, result.is_open
}
@private
_menu :: proc(ui: ^UI, _: Menu_Info, _: runtime.Source_Code_Location, result: Menu_Result, open: bool) {
	if open {
		widget := result.self.?
		variant := &widget.variant.(Menu_Widget_Variant)
		if (.Focused not_in (widget.state | widget.last_state)) && (result.layer.state & {.Focused} == {}) {
			variant.is_open = false
		}
		end_layer(ui, result.layer)
	}
}
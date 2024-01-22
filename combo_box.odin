package maui
import "core:math/linalg"

Combo_Box_Info :: struct {
	using generic: Generic_Widget_Info,
	items: []string,
	index: int,
}
Combo_Box_Result :: struct {
	using generic: Generic_Widget_Result,
	index: int,
	changed: bool,
}
combo_box :: proc(ui: ^UI, info: Combo_Box_Info, loc := #caller_location) -> Combo_Box_Result {
	self, generic_result := get_widget(ui, info, loc)
	result: Combo_Box_Result = {
		generic = generic_result,
	}
	self.box = info.box.? or_else layout_next(current_layout(ui))
	if self.variant == nil {
		self.variant = Menu_Widget_Variant{}
	}
	data := &self.variant.(Menu_Widget_Variant)
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.open_time = animate(ui, data.open_time, 0.1, data.is_open)
	update_widget(ui, self)
	if .Should_Paint in self.bits {
		paint_box_fill(ui.painter, self.box, blend_colors(data.hover_time + (1.0 if .Pressed in self.state else 0.0), ui.style.color.button, ui.style.color.button_hovered, ui.style.color.button_pressed))
		paint_text(ui.painter, center(self.box), {
			text = info.items[info.index],
			font = ui.style.font.label,
			size = ui.style.text_size.label,
			align = .Middle,
			baseline = .Middle,
		}, ui.style.color.text[0])
	}
	if data.is_open {
		option_height := height(self.box)
		menu_top := self.box.low.y - f32(info.index) * option_height
		menu_height := f32(len(info.items)) * option_height
		menu_bottom := max(menu_top + menu_height, self.box.high.y)
		if layer, ok := do_layer(ui, {
			id = self.id,
			placement = Box{{self.box.low.x, menu_top}, {self.box.high.x, menu_bottom}},
			space = [2]f32{0, menu_height},
			opacity = data.open_time,
			options = {.Attached, .No_Scroll_X, .No_Scroll_Y},
		}); ok {
			paint_rounded_box_fill(ui.painter, layer.box, 0, ui.style.color.foreground[1])
			ui.layouts.current.direction = .Down; ui.layouts.current.size = option_height
			push_id(ui, self.id)
				for item, i in info.items {
					push_id(ui, i)
						if was_clicked(option(ui, {text = item})) {
							result.index = i
							result.changed = true
							data.is_open = false
						}
					pop_id(ui)
				}
			pop_id(ui)
			if ((self.state & {.Focused} == {}) && (layer.state & {.Focused} == {})) {
				data.is_open = false
			}
		}
	}
	if .Clicked in self.state {
		data.is_open = true
	}
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	return result
}
Option_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
}
option :: proc(ui: ^UI, info: Option_Info, loc := #caller_location) -> Generic_Widget_Result {
	self, result := get_widget(ui, info, loc)
	self.box = info.box.? or_else layout_next(current_layout(ui))
	update_widget(ui, self)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Button_Widget_Variant{}
	}
	data := &self.variant.(Button_Widget_Variant)
	// Update retained data
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.disable_time = animate(ui, data.disable_time, DEFAULT_WIDGET_DISABLE_TIME, .Disabled in self.bits)
	if .Should_Paint in self.bits {
		fill_color := blend_colors(data.hover_time, ui.style.color.text[0], ui.style.color.accent)
		paint_text(ui.painter, center(self.box), {
			text = info.text, 
			font = ui.style.font.label, 
			size = ui.style.text_size.label,
			align = .Middle,
			baseline = .Middle,
		}, fill_color)
	}
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	return result
}
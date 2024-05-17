package maui
import "core:math"
import "core:runtime"

Menu_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
	text_align: Maybe(Text_Align),
	width: f32,
	height: Maybe(f32),
	fit: bool,
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
	if info.fit {
		ui.placement.size = math.floor(measure_text(ui.painter, {
			text = info.text,
			font = ui.style.font.label, 
			size = ui.style.text_size.label,
		}).x + height(layout.box))
	}

	self.box = info.box.? or_else next_box(ui)
	update_widget(ui, self)

	if .Should_Paint in self.bits {
		paint_box_fill(ui.painter, self.box, fade(ui.style.color.button, 0.5 + 0.5 * data.hover_time))
		paint_box_fill(ui.painter, {{self.box.low.x, self.box.high.y - 1}, self.box.high}, ui.style.color.substance)
		text_align := info.text_align.? or_else .Middle
		text_origin: [2]f32
		switch text_align {
			case .Left:
			text_origin = {self.box.low.x + 4, (self.box.low.y + self.box.high.y) / 2}
			case .Middle:
			text_origin = center(self.box)
			case .Right:
			text_origin = {self.box.high.x - 4, (self.box.low.y + self.box.high.y) / 2}
		}
		paint_text(ui.painter, text_origin, {
			text = info.text,
			font = ui.style.font.label,
			size = ui.style.text_size.label,
			align = text_align,
			baseline = .Middle,
		}, ui.style.color.text[0])
	}

	if data.is_open {
		ui.keep_menus_open = true
		result.layer, result.is_open = begin_layer(ui, {
			id = self.id,
			placement = Layer_Placement_Info{
				origin = {math.floor(self.box.low.x), self.box.high.y - 1},
				size = {max(width(self.box), info.width), info.height},
			},
			scrollbar_padding = [2]f32{1, 1},
			grow = .Down,
			options = {.Attached},
		})
	} else {
		if .Clicked in self.state {
			data.is_open = true
		}
		if ui.open_menus {
			if .Hovered in self.state {
				ui.widgets.focus_id = self.id
				ui.layers.focus_id = self.id
				data.is_open = true
			}
		}
	}
	
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	if result.is_open {
		layout := current_layout(ui)
		ui.placement.side = .Top
		paint_box_fill(ui.painter, result.layer.box, ui.style.color.foreground[1])
	}

	return result, result.is_open
}
@private
_menu :: proc(ui: ^UI, _: Menu_Info, _: runtime.Source_Code_Location, result: Menu_Result, open: bool) {
	if open {
		paint_box_stroke(ui.painter, result.layer.box, 1, ui.style.color.substance)
		widget := result.self.?
		variant := &widget.variant.(Menu_Widget_Variant)
		if (.Focused not_in (widget.state | widget.last_state)) && (result.layer.state & {.Focused} == {}) {
			variant.is_open = false
		}
		end_layer(ui, result.layer)
	}
}

@(deferred_in_out=_submenu)
submenu :: proc(ui: ^UI, info: Menu_Info, loc := #caller_location) -> (Menu_Result, bool) {
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
	ui.placement.size = measure_text(ui.painter, {
		text = info.text,
		font = ui.style.font.label, 
		size = ui.style.text_size.label,
	}).x + height(layout.box)

	self.box = info.box.? or_else next_box(ui)
	update_widget(ui, self)

	if .Should_Paint in self.bits {
		text_color := blend_colors(data.hover_time, ui.style.color.substance, ui.style.color.foreground[0])
		fill_color := fade(ui.style.color.substance, data.hover_time)
		h := height(self.box)
		paint_box_fill(ui.painter, self.box, fill_color)
		paint_text(ui.painter, self.box.low + h * [2]f32{0.25, 0.5}, {
			text = info.text,
			font = ui.style.font.label,
			size = ui.style.text_size.label,
			baseline = .Middle,
		}, text_color)
		paint_arrow(ui.painter, self.box.high - h * 0.5, h * 0.2, math.PI * -0.5, 1, text_color)
	}

	if data.is_open {
		result.layer, result.is_open = begin_layer(ui, {
			id = self.id,
			placement = Layer_Placement_Info{
				origin = {self.box.high.x - 1, self.box.low.y},
				size = {max(width(self.box), info.width), nil},
			},
			grow = .Down,
			options = {.Attached},
		})
	} else if .Hovered in (self.state - self.last_state) {
		data.is_open = true
	}

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	if result.is_open {
		layout := current_layout(ui)
		ui.placement.side = .Top
		paint_box_fill(ui.painter, result.layer.box, ui.style.color.foreground[1])
		paint_box_stroke(ui.painter, result.layer.box, 1, ui.style.color.substance)
	}

	return result, result.is_open
}
@private
_submenu :: proc(ui: ^UI, _: Menu_Info, _: runtime.Source_Code_Location, result: Menu_Result, open: bool) {
	if open {
		widget := result.self.?
		variant := &widget.variant.(Menu_Widget_Variant)
		if (.Hovered not_in widget.state) && ((result.layer.state + result.layer.last_state) & {.Hovered} == {}) {
			variant.is_open = false
		}
		end_layer(ui, result.layer)
	}
}
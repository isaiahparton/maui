package maui

import "core:math/linalg"

import "vendor:nanovg"

Combo_Box_Info :: struct {
	using generic: Generic_Widget_Info,
	items: []string,
	index: int,
}
Combo_Box_Result :: struct {
	using generic: Generic_Widget_Result,
	index: Maybe(int),
}
combo_box :: proc(ui: ^UI, info: Combo_Box_Info, loc := #caller_location) -> Combo_Box_Result {
	self, generic_result := get_widget(ui, info, loc)
	result: Combo_Box_Result = {
		generic = generic_result,
	}
	self.box = info.box.? or_else next_box(ui)
	if self.variant == nil {
		self.variant = Menu_Widget_Variant{}
	}
	data := &self.variant.(Menu_Widget_Variant)
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.open_time = animate(ui, data.open_time, 0.1, data.is_open)
	update_widget(ui, self)
	
	if data.is_open {
		option_height := height(self.box)
		menu_height := f32(len(info.items)) * option_height
		menu_top := clamp(self.box.low.y - f32(info.index) * option_height, 0, ui.size.y - menu_height)
		menu_bottom := max(menu_top + menu_height, self.box.high.y)

		if layer, ok := do_layer(ui, {
			id = self.id,
			placement = Box{{self.box.low.x, menu_top}, {self.box.high.x, menu_bottom}},
			space = [2]f32{0, menu_height},
			options = {.Attached, .No_Scroll_X, .No_Scroll_Y},
		}); ok {
			nanovg.FillPaint(ui.ctx, nanovg.LinearGradient(self.box.low.x, self.box.low.y, self.box.low.x, layer.box.high.y, ui.style.color.background[1], ui.style.color.background[0]))
			nanovg.BeginPath(ui.ctx)
			nanovg.RoundedRect(ui.ctx, layer.box.low.x, layer.box.low.y, layer.box.high.x - layer.box.low.x, layer.box.high.y - layer.box.low.y, ui.style.rounding)
			nanovg.Fill(ui.ctx)

			ui.placement.side = .Top; ui.placement.size = option_height
			push_id(ui, self.id)
				for item, i in info.items {
					push_id(ui, i)
						if was_clicked(option(ui, {text = item, text_align = .Middle, active = i == info.index})) {
							result.index = i
							data.is_open = false
						}
					pop_id(ui)
				}
			pop_id(ui)

			nanovg.StrokeWidth(ui.ctx, 0.5)
			nanovg.StrokeColor(ui.ctx, ui.style.color.substance)
			nanovg.BeginPath(ui.ctx)
			nanovg.RoundedRect(ui.ctx, layer.box.low.x, layer.box.low.y, layer.box.high.x - layer.box.low.x, layer.box.high.y - layer.box.low.y, ui.style.rounding)
			nanovg.Stroke(ui.ctx)

			if ((self.state & {.Focused} == {}) && (layer.state & {.Focused} == {})) {
				data.is_open = false
			}
		}
	} else {
		if .Hovered in self.state {
			if ui.io.mouse_scroll.y != 0 {
				new_index := info.index - int(ui.io.mouse_scroll.y)
				if new_index >= 0 && new_index < len(info.items) {
					result.index = new_index
				}
			}
		}
		if .Should_Paint in self.bits {
			nanovg.FillPaint(ui.ctx, nanovg.LinearGradient(self.box.low.x, self.box.low.y, self.box.low.x, self.box.high.y, ui.style.color.background[1], ui.style.color.background[0]))
			nanovg.StrokeColor(ui.ctx, ui.style.color.substance)
			nanovg.StrokeWidth(ui.ctx, 0.5)
			nanovg.BeginPath(ui.ctx)
			nanovg.RoundedRect(ui.ctx, self.box.low.x, self.box.low.y, self.box.high.x - self.box.low.x, self.box.high.y - self.box.low.y, ui.style.rounding)
			nanovg.Fill(ui.ctx)
			nanovg.Stroke(ui.ctx)

			nanovg.FontFace(ui.ctx, "Default")
			nanovg.FontSize(ui.ctx, ui.style.text_size.label)
			nanovg.TextAlignHorizontal(ui.ctx, .CENTER)
			nanovg.TextAlignVertical(ui.ctx, .MIDDLE)
			nanovg.FillColor(ui.ctx, ui.style.color.text[0])
			nanovg.BeginPath(ui.ctx)
			nanovg.Text(ui.ctx, (self.box.low.x + self.box.high.x) / 2, (self.box.low.y + self.box.high.y) / 2, info.items[info.index])
			nanovg.Fill(ui.ctx)
		}
	}
	if .Pressed in (self.state - self.last_state) {
		data.is_open = true
	}
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	return result
}
Option_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
	text_align: Text_Align,
	active: bool,
}
option :: proc(ui: ^UI, info: Option_Info, loc := #caller_location) -> Generic_Widget_Result {
	self, result := get_widget(ui, info, loc)
	self.box = info.box.? or_else next_box(ui)
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
		text_color := blend_colors(data.hover_time, ui.style.color.label, ui.style.color.label_hovered)
		fill_color := blend_colors(data.hover_time, ui.style.color.button, ui.style.color.button_hovered)
		padding := height(self.box) * 0.25

		nanovg.StrokeWidth(ui.ctx, 2)
		nanovg.StrokeColor(ui.ctx, fade(ui.style.color.substance, data.hover_time))
		nanovg.BeginPath(ui.ctx)
		nanovg.RoundedRect(ui.ctx, self.box.low.x, self.box.low.y, self.box.high.x - self.box.low.x, self.box.high.y - self.box.low.y, ui.style.rounding)
		nanovg.Stroke(ui.ctx)

		nanovg.FontFaceId(ui.ctx, ui.style.font.label)
		nanovg.FontSize(ui.ctx, ui.style.text_size.label)
		nanovg.TextAlignHorizontal(ui.ctx, .CENTER)
		nanovg.TextAlignVertical(ui.ctx, .MIDDLE)
		nanovg.FillColor(ui.ctx, ui.style.color.text[0])
		nanovg.BeginPath(ui.ctx)
		nanovg.Text(ui.ctx, (self.box.low.x + self.box.high.x) / 2, (self.box.low.y + self.box.high.y) / 2, info.text)
		nanovg.Fill(ui.ctx)
	}
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	return result
}
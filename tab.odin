package maui
/*
Tab_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
	active: bool,
}
tab :: proc(ui: ^UI, info: Tab_Info, loc := #caller_location) -> Generic_Widget_Result {
	self, result := get_widget(ui, info, loc)
	self.box = info.box.? or_else next_box(ui)
	update_widget(ui, self)
	if self.variant == nil do self.variant = Button_Widget_Variant{}
	data := &self.variant.(Button_Widget_Variant)
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	if .Should_Paint in self.bits {
		origin := center(self.box)
		text_size := paint_text(ui.painter, origin, {
			text = info.text,
			font = ui.style.font.label,
			size = ui.style.text_size.label,
			align = .Middle,
			baseline = .Middle,
		}, ui.style.color.text[0])
		text_size.x *= ((1.0 if info.active else 0.7) + 0.3 * data.hover_time)
		paint_box_fill(ui.painter, {{origin.x - text_size.x / 2, self.box.high.y - 2}, {origin.x + text_size.x / 2, self.box.high.y}}, blend_colors(data.hover_time, fade(ui.style.color.substance, 0.5), ui.style.color.accent))
	}

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	return result
}*/
package maui

List_Item_Info :: struct {
	using generic: Generic_Widget_Info,
	text: []string,
	active: bool,
}
List_Item_Widget_Variant :: struct {
	hover_time: f32,
}
list_item :: proc(ui: ^UI, info: List_Item_Info, loc := #caller_location) -> Generic_Widget_Result {

	self, result := get_widget(ui, info, loc)

	self.box = info.box.? or_else layout_next(current_layout(ui))

	// Assert variant existence
	if self.variant == nil {
		self.variant = Button_Widget_Variant{}
	}
	data := &self.variant.(Button_Widget_Variant)
	// Update retained data
	data.hover_time = animate(ui, data.hover_time, 0, .Hovered in self.state)
	// data.disable_time = animate(ui, data.disable_time, DEFAULT_WIDGET_DISABLE_TIME, .Disabled in self.bits)

	update_widget(ui, self)

	if .Should_Paint in self.bits {
		if data.hover_time > 0 || info.active {
			fill_color := alpha_blend_colors(ui.style.color.accent, ui.style.color.substance, data.hover_time) if info.active else fade(ui.style.color.substance, data.hover_time)
			paint_box_fill(ui.painter, self.box, fill_color)
		}
		if len(info.text) > 0 {
			text_color := blend_colors(data.hover_time, ui.style.color.text[0], ui.style.color.base)
			box := self.box
			size := width(box) / f32(len(info.text))
			for elem, i in info.text {
				text_box := cut_box_left(&box, size)
				switch i {

					case 0:
					paint_text(ui.painter, {text_box.low.x, (text_box.low.y + text_box.high.y) / 2}, {
						text = elem, 
						font = ui.style.font.label, 
						size = ui.style.text_size.label, 
						baseline = .Middle,
					}, text_color)

					case len(info.text) - 1:
					paint_text(ui.painter, {text_box.high.x, (text_box.low.y + text_box.high.y) / 2}, {
						text = elem, 
						font = ui.style.font.label, 
						size = ui.style.text_size.label, 
						align = .Right, 
						baseline = .Middle,
					}, text_color)

					case:
					paint_text(ui.painter, center(text_box), {
						text = elem, 
						font = ui.style.font.label, 
						size = ui.style.text_size.label, 
						align = .Middle, 
						baseline = .Middle,
					}, text_color)
				}
			}
		}
	}

	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))

	return result
}
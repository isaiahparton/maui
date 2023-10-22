package maui_widgets
import "../"

Chip_Info :: struct {
	text: string,
	clip_box: Maybe(maui.Box),
}

/*do_chip :: proc(info: Chip_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		using self
		layout := current_layout()
		if placement.side == .Left || placement.side == .Right {
			self.box = layout_next_of_size(current_layout(), get_size_for_label(layout, info.text))
		} else {
			self.box = layout_next(current_layout())
		}
		hover_time := animate_bool(&self.timers[0], .Hovered in state, 0.1)
		update_widget(self)
		// Graphics
		if .Should_Paint in bits {
			fill_color: Color
			fill_color = style_widget_shaded(2 if .Pressed in self.state else hover_time)
			if clip, ok := info.clip_box.?; ok {
				paint_pill_fill_clipped_h(self.box, clip, fill_color)
				paint_text(center(box), {text = info.text, font = painter.style.title_font, size = painter.style.title_font_size}, {align = .Middle, baseline = .Middle}, get_color(.Text)) 
			} else {
				paint_pill_fill_h(self.box, fill_color)
				paint_text(center(box), {text = info.text, font = painter.style.title_font, size = painter.style.title_font_size}, {align = .Middle, baseline = .Middle}, get_color(.Text))
			}
		}
		clicked = .Clicked in state && click_button == .Left
	}
	return
}

Toggled_Chip_Info :: struct {
	text: string,
	state: bool,
	row_spacing: Maybe(f32),
}

do_toggled_chip :: proc(info: Toggled_Chip_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		using self
		// Layouteth
		layout := current_layout()
		text_info: Text_Info = {
			text = info.text, 
			font = painter.style.title_font, 
			size = painter.style.title_font_size,
		}
		state_time := animate_bool(&self.timers[0], info.state, 0.15)
		size: [2]f32
		if placement.side == .Left || placement.side == .Right {
			size = measure_text(text_info) + {get_layout_height(layout), 0}
			size.x += size.y * state_time
			if size.x > width(layout.box) {
				pop_layout()
				if info.row_spacing != nil {
					cut(.Top, info.row_spacing.?)
				}
				push_layout(cut(.Top, height(layout.box)))
				placement.side = .Left
			}
		}
		self.box = layout_next_of_size(layout, size.x)
		// Update thyself
		update_widget(self)
		// Hover thyselfest
		hover_time := animate_bool(&self.timers[1], .Hovered in state, 0.1)
		// Graphicseth
		if .Should_Paint in bits {
			color := blend_colors(get_color(.Widget_Stroke), get_color(.Accent), state_time)
			if info.state {
				paint_pill_fill_h(self.box, get_color(.Accent, 0.2 if .Pressed in state else 0.1))
			} else {
				paint_pill_fill_h(self.box, get_color(.Base_Shade, 0.2 if .Pressed in state else 0.1 * hover_time))
			}
			paint_pill_stroke_h(self.box, 2 if info.state else 1, color)
			if state_time > 0 {
				//paint_aligned_rune(painter.style.title_font, painter.style.title_font_size, .Check, {box.high.x + height(box) / 2, center_y(box)}, fade(color, state_time), {.Near, .Middle})
				paint_text({box.high.x - height(box) / 2, center_y(box)}, text_info, {align = .Middle, baseline = .Middle}, color) 
			} else {
				paint_text(center(box), text_info, {align = .Middle, baseline = .Middle}, color) 
			}
		}
		clicked = .Clicked in state && click_button == .Left
	}
	return
}*/
package maui_widgets
import "../"

Chip_Info :: struct {
	text: string,
	clip_box: Maybe(maui.Box),
}

do_chip :: proc(info: Chip_Info, loc := #caller_location) -> (clicked: bool) {
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
			paint_pill_fill_h(self.box, alpha_blend_colors(style.color.extrusion, {255, 255, 255, 40}, hover_time))
			paint_pill_stroke_h(self.box, 1, style.color.base_stroke)
			paint_text(center(box), {text = info.text, font = style.font.label, size = style.text_size.label}, {align = .Middle, baseline = .Middle}, style.color.text) 
		}
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
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
		// Layin
		layout := current_layout()
		text_info: Text_Info = {
			text = info.text, 
			font = style.font.label, 
			size = style.text_size.label,
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
		// Graphicly
		if .Should_Paint in bits {
			paint_pill_stroke_h(self.box, 2 if info.state else 1, style.color.base_stroke)
			if state_time > 0 {
				paint_text({box.high.x - height(box) / 2, center_y(box)}, text_info, {align = .Middle, baseline = .Middle}, style.color.text) 
			} else {
				paint_text(center(box), text_info, {align = .Middle, baseline = .Middle}, style.color.text) 
			}
		}
		clicked = .Clicked in state && click_button == .Left
	}
	return
}
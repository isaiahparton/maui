package maui
import "core:math/linalg"

Radio_Button_Info :: struct {
	using generic: Generic_Widget_Info,
	state: bool,
	text: string,
	text_side: Maybe(Box_Side),
}
radio_button :: proc(ui: ^UI, info: Radio_Button_Info, loc := #caller_location) -> Generic_Widget_Result {
	SIZE :: 22
	RADIUS :: SIZE / 2
	// Check if there is text
	has_text := len(info.text) > 0
	// Default orientation
	text_side := info.text_side.? or_else .Left
	// Determine total size
	size, text_size: [2]f32
	if has_text {
		text_size = measure_text(ui.painter, {font = ui.style.font.label, size = ui.style.text_size.label, text = info.text})
		if text_side == .Bottom || text_side == .Top {
			size.x = max(SIZE, text_size.x)
			size.y = SIZE + text_size.y
		} else {
			size.x = SIZE + text_size.x + ui.style.layout.widget_padding * 2
			size.y = SIZE
		}
	} else {
		size = SIZE
	}
	layout := current_layout(ui)
	// Create
	self, result := get_widget(ui, info.generic, loc)
	// Colocate
	self.box = info.box.? or_else align_inner(next_box(ui), size, ui.placement.align)
	// Update
	update_widget(ui, self)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Check_Box_Widget_Variant{}
	}
	data := &self.variant.(Check_Box_Widget_Variant)
	// Animate
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.disable_time = animate(ui, data.disable_time, DEFAULT_WIDGET_DISABLE_TIME, .Disabled in self.bits)
	// Painting
	if .Should_Paint in self.bits {
		icon_box: Box
		if has_text {
			switch text_side {
				case .Left:
				icon_box = {self.box.low, SIZE}
				case .Right:
				icon_box = {{self.box.high.x - SIZE, self.box.low.y}, SIZE}
				case .Top:
				icon_box = {{center_x(self.box) - RADIUS, self.box.high.y - SIZE}, SIZE}
				case .Bottom:
				icon_box = {{center_x(self.box) - RADIUS, self.box.low.y}, SIZE}
			}
			icon_box.low = linalg.floor(icon_box.low)
			icon_box.high += icon_box.low
		} else {
			icon_box = self.box
		}
		// Paint box
		opacity := 1 - 0.5 * data.disable_time
		fill_color := ui.style.color.foreground
		icon_center := center(icon_box)
		paint_ring_fill_texture(ui.painter, icon_center, RADIUS - 1, RADIUS, ui.style.color.substance)
		center := box_center(icon_box)
		if data.hover_time > 0 {
			paint_rounded_box_fill(ui.painter, self.box, height(self.box) / 2, fade(ui.style.color.substance, 0.5 * data.hover_time))
		}
		// Paint icon
		if info.state {
			paint_circle_fill_texture(ui.painter, icon_center, (RADIUS - 6), ui.style.color.content)
		}
		// Paint text
		if has_text {
			switch text_side {
				case .Left: 	
				paint_text(ui.painter, {icon_box.high.x + ui.style.layout.widget_padding, center.y - text_size.y / 2}, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label}, fade(ui.style.color.content, opacity))
				case .Right: 	
				paint_text(ui.painter, {icon_box.low.x - ui.style.layout.widget_padding, center.y - text_size.y / 2}, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label, align = .Right}, fade(ui.style.color.content, opacity))
				case .Top: 		
				paint_text(ui.painter, self.box.low, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label}, fade(ui.style.color.content, opacity))
				case .Bottom: 	
				paint_text(ui.painter, {self.box.low.x, self.box.high.y - text_size.y}, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label}, fade(ui.style.color.content, opacity))
			}
		}
	}
	//
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// We're done here
	return Generic_Widget_Result{self = self},
}
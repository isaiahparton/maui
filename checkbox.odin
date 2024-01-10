package maui
import "core:math/linalg"

Check_Box_Info :: struct {
	using generic: Generic_Widget_Info,
	value: bool,
	text: string,
	text_side: Maybe(Box_Side),
}
Check_Box_Widget_Variant :: struct {
	hover_time,
	disable_time: f32,
}
//#Info fields
// - `state` Either a `bool`, a `^bool` or one of `{.on, .off, .unknown}`
// - `text` If defined, the check box will display text on `text_side` of itself
// - `text_side` The side on which text will appear (defaults to left)
checkbox :: proc(ui: ^UI, info: Check_Box_Info, loc := #caller_location) -> Generic_Widget_Result {
	SIZE :: 22
	HALF_SIZE :: SIZE / 2
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
	self.box = info.box.? or_else layout_next_child(layout, size)
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
				icon_box = {{center_x(self.box) - HALF_SIZE, self.box.high.y - SIZE}, SIZE}
				case .Bottom: 	
				icon_box = {{center_x(self.box) - HALF_SIZE, self.box.low.y}, SIZE}
			}
			icon_box.low = linalg.floor(icon_box.low)
			icon_box.high += icon_box.low
		} else {
			icon_box = self.box
		}
		// Paint box
		opacity := 1 - 0.5 * data.disable_time
		fill_color := fade(alpha_blend_colors(ui.style.color.substance, ui.style.color.flash, data.hover_time * 0.25) if info.value else fade(ui.style.color.substance, 0.25 * data.hover_time), opacity)
		paint_box_fill(ui.painter, icon_box, fill_color)
		if !info.value {
			paint_box_stroke(ui.painter, icon_box, ui.style.stroke_width + (1 - ui.style.stroke_width) * data.disable_time, fade(ui.style.color.substance, opacity))
		}
		center := box_center(icon_box)
		// Paint icon
		if info.value {
			scale: f32 = HALF_SIZE * 0.5
			a, b, c: [2]f32 = {-1, -0.047} * scale, {-0.333, 0.619} * scale, {1, -0.713} * scale
			paint_path_stroke(ui.painter, {center + a, center + b, center + c}, false, 1, 1, ui.style.color.base)
		}
		// Paint text
		if has_text {
			switch text_side {
				case .Left: 	
				paint_text(ui.painter, {icon_box.high.x + ui.style.layout.widget_padding, center.y - text_size.y / 2}, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label}, fade(ui.style.color.text, opacity))
				case .Right: 	
				paint_text(ui.painter, {icon_box.low.x - ui.style.layout.widget_padding, center.y - text_size.y / 2}, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label, align = .Right}, fade(ui.style.color.text, opacity))
				case .Top: 		
				paint_text(ui.painter, self.box.low, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label}, fade(ui.style.color.text, opacity))
				case .Bottom: 	
				paint_text(ui.painter, {self.box.low.x, self.box.high.y - text_size.y}, {text = info.text, font = ui.style.font.label, size = ui.style.text_size.label}, fade(ui.style.color.text, opacity))
			}
		}
	}
	//
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// We're done here
	return Generic_Widget_Result{self = self},
}
package maui_widgets
import "../"

import "core:math/ease"

Check_Box_Status :: enum u8 {
	On,
	Off,
	Unknown,
}
Check_Box_State :: union {
	bool,
	^bool,
	Check_Box_Status,
}
Check_Box_Info :: struct {
	state: Check_Box_State,
	text: Maybe(string),
	text_side: Maybe(maui.Box_Side),
}

evaluate_checkbox_state :: proc(state: Check_Box_State) -> bool {
	active: bool
	switch v in state {
		case bool:
		active = v

		case ^bool:
		active = v^

		case Check_Box_Status:
		active = v != .Off
	}
	return active
}

//#Info fields
// - `state` Either a `bool`, a `^bool` or one of `{.on, .off, .unknown}`
// - `text` If defined, the check box will display text on `text_side` of itself
// - `text_side` The side on which text will appear (defaults to left)
do_checkbox :: proc(info: Check_Box_Info, loc := #caller_location) -> (change, new_state: bool) {
	using maui
	SIZE :: 22
	HALF_SIZE :: SIZE / 2

	// Check if there is text
	has_text := info.text != nil

	// Default orientation
	text_side := info.text_side.? or_else .Left

	// Determine total size
	size, text_size: [2]f32
	if has_text {
		text_size = measure_text({font = painter.style.default_font, size = painter.style.default_font_size, text = info.text.?})
		if text_side == .Bottom || text_side == .Top {
			size.x = max(SIZE, text_size.x)
			size.y = SIZE + text_size.y
		} else {
			size.x = SIZE + text_size.x + WIDGET_PADDING * 2
			size.y = SIZE
		}
	} else {
		size = SIZE
	}
	layout := current_layout()
	//placement.size = size.x if layout.side == .Left || layout.side == .Right else size.y

	// Widget
	if self, ok := do_widget(hash(loc)); ok {
		using self
		self.box = use_next_box() or_else layout_next_child(layout, size)
		update_widget(self)
		// Determine state
		active := evaluate_checkbox_state(info.state)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in state, 0.15)
		state_time := animate_bool(&self.timers[1], active, 0.3)
		// Painting
		if .Should_Paint in bits {
			icon_box: Box
			if has_text {
				switch text_side {
					case .Left: 	
					icon_box = {box.low, SIZE}
					case .Right: 	
					icon_box = {{box.high.x - SIZE, box.low.y}, SIZE}
					case .Top: 		
					icon_box = {{center_x(box) - HALF_SIZE, box.high.y - SIZE}, SIZE}
					case .Bottom: 	
					icon_box = {{center_x(box) - HALF_SIZE, box.low.y}, SIZE}
				}
				icon_box.high += icon_box.low
			} else {
				icon_box = box
			}

			// Paint box
			paint_rounded_box_fill(box, 5, get_color(.Base_Shade, 0.1 * hover_time))
			if active {
				paint_rounded_box_fill(icon_box, 5, alpha_blend_colors(get_color(.Intense), get_color(.Intense_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1))
			} else {
				paint_rounded_box_fill(icon_box, 5, blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), 0.1 if .Pressed in self.state else 0))
				paint_rounded_box_stroke(icon_box, 5, 2, blend_colors(get_color(.Widget), get_color(.Widget_Stroke), hover_time))
			}
			center := box_center(icon_box)

			// Paint icon
			if active || state_time == 1 {
				real_state := info.state.(Check_Box_Status) or_else .On
				center := box_center(icon_box)
				scale := ease.back_out(state_time) * HALF_SIZE * 0.5
				#partial switch real_state {
					case .Unknown: 
					a, b: [2]f32 = {-1, 0} * scale, {1, 0} * scale
					paint_line(center + a, center + b, 2, get_color(.Widget_Back))
					case .On: 
					a, b, c: [2]f32 = {-1, -0.047} * scale, {-0.333, 0.619} * scale, {1, -0.713} * scale
					stroke_path({center + a, center + b, center + c}, false, ICON_STROKE_THICKNESS, get_color(.Widget_Back))
				}
			}

			// Paint text
			if has_text {
				switch text_side {
					case .Left: 	
					paint_text({icon_box.high.x + WIDGET_PADDING, center.y - text_size.y / 2}, {text = info.text.?, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text))
					case .Right: 	
					paint_text({icon_box.low.x - WIDGET_PADDING, center.y - text_size.y / 2}, {text = info.text.?, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text))
					case .Top: 		
					paint_text(box.low, {text = info.text.?, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text))
					case .Bottom: 	
					paint_text({box.low.x, box.high.y - text_size.y}, {text = info.text.?, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text))
				}
			}
		}
		// Result
		if .Clicked in state && click_button == .Left {
			switch state in info.state {
				case bool:
				new_state = !state

				case ^bool:
				state^ = !state^
				new_state = state^

				case Check_Box_Status:
				if state != .On {
					new_state = true
				}
			}
			change = true
		}
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

do_checkbox_bit_set :: proc(set: ^$S/bit_set[$E;$U], bit: E, text: string, loc := #caller_location) -> bool {
	if set == nil {
		return false
	}
	if change, _ := do_checkbox({
		state = .on if bit in set else .off, 
		text = text,
	}, loc); change {
		set^ = set^ ~ {bit}
		return true
	}
	return false
}

do_checkbox_bit_set_header :: proc(set: ^$S/bit_set[$E;$U], text: string, loc := #caller_location) -> bool {
	if set == nil {
		return false
	}
	state := Check_Box_Status.off
	elementCount := card(set^)
	if elementCount == len(E) {
		state = .on
	} else if elementCount > 0 {
		state = .unknown
	}
	if change, new_value := do_checkbox({state = state, text = text}, loc); change {
		if new_value {
			for element in E {
				incl(set, element)
			}
		} else {
			set^ = {}
		}
		return true
	}
	return false
}
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
	using info: maui.Widget_Info,
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
		text_size = measure_text({font = ui.style.font.label, size = ui.style.text_size.label, text = info.text.?})
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
	layout := current_layout()

	// Widget
	if self, ok := do_widget(hash(loc)); ok {
		using self
		self.box = info.box.? or_else layout_next_child(layout, size)
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
			paint_rounded_box_fill(icon_box, ui.style.rounding, fade(ui.style.color.substance[1], 0.1 + 0.1 * hover_time))
			paint_rounded_box_stroke(icon_box, ui.style.rounding, 2, fade(ui.style.color.substance[1], 0.5 + 0.5 * hover_time))
			
			center := box_center(icon_box)

			// Paint icon
			if active || state_time == 1 {
				real_state := info.state.(Check_Box_Status) or_else .On
				center := box_center(icon_box)
				scale := ease.back_out(state_time) * HALF_SIZE * 0.5
				#partial switch real_state {
					case .Unknown: 
					a, b: [2]f32 = {-1, 0} * scale, {1, 0} * scale
					paint_line(center + a, center + b, 2, ui.style.color.accent[0])
					case .On: 
					a, b, c: [2]f32 = {-1, -0.047} * scale, {-0.333, 0.619} * scale, {1, -0.713} * scale
					stroke_path({center + a, center + b, center + c}, false, 1, ui.style.color.accent[0])
				}
			}

			// Paint text
			if has_text {
				switch text_side {
					case .Left: 	
					paint_text({icon_box.high.x + ui.style.layout.widget_padding, center.y - text_size.y / 2}, {text = info.text.?, font = ui.style.font.label, size = ui.style.text_size.label}, {align = .Left}, ui.style.color.base_text[1])
					case .Right: 	
					paint_text({icon_box.low.x - ui.style.layout.widget_padding, center.y - text_size.y / 2}, {text = info.text.?, font = ui.style.font.label, size = ui.style.text_size.label}, {align = .Left}, ui.style.color.base_text[1])
					case .Top: 		
					paint_text(box.low, {text = info.text.?, font = ui.style.font.label, size = ui.style.text_size.label}, {align = .Left}, ui.style.color.base_text[1])
					case .Bottom: 	
					paint_text({box.low.x, box.high.y - text_size.y}, {text = info.text.?, font = ui.style.font.label, size = ui.style.text_size.label}, {align = .Left}, ui.style.color.base_text[1])
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
		state = .On if bit in set else .Off, 
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
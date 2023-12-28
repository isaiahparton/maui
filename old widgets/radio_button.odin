package maui_widgets
import "../"

import "core:math"
import "core:math/ease"
import "core:math/linalg"

// Radio buttons
Radio_Button_Info :: struct {
	using info: maui.Widget_Info,
	on: bool,
	text: string,
	text_side: Maybe(maui.Box_Side),
}

do_radio_button :: proc(info: Radio_Button_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	SIZE :: 24
	RADIUS :: SIZE / 2
	// Determine total size
	text_side := info.text_side.? or_else .Left
	text_size := measure_text({text = info.text, font = ctx.style.font.label, size = ctx.style.text_size.label})
	size: [2]f32
	if text_side == .Bottom || text_side == .Top {
		size.x = max(SIZE, text_size.x)
		size.y = SIZE + text_size.y
	} else {
		size.x = SIZE + text_size.x + ctx.style.layout.widget_padding * 2
		size.y = SIZE
	}
	// The widget
	if self, ok := do_widget(hash(loc)); ok {
		// Colocate
		self.box = info.box.? or_else layout_next_child(current_layout(), size)
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		how_on := animate_bool(&self.timers[1], info.on, 0.24)
		// Graphics
		if .Should_Paint in self.bits {
			center: [2]f32
			switch text_side {
				
				case .Left: 	
				center = {self.box.low.x + RADIUS, self.box.low.y + RADIUS}

				case .Right: 	
				center = {self.box.high.x - RADIUS, self.box.low.y + RADIUS}

				case .Top: 		
				center = {center_x(self.box), self.box.high.y - RADIUS}

				case .Bottom: 	
				center = {center_x(self.box), self.box.low.y + RADIUS}
			}
			// Glowy thing
			paint_circle_fill(center, RADIUS * (0.2 + 0.3 * ease.circular_out(how_on)), 12, fade(ctx.style.color.accent[1], how_on))
			paint_circle_fill_texture(center, RADIUS, fade(ctx.style.color.substance[1], 0.1 + 0.1 * hover_time))
			paint_ring_fill_texture(center, RADIUS - 2, RADIUS, fade(ctx.style.color.substance[1], 0.5 + 0.5 * hover_time))
			// Paint text
			switch text_side {

				case .Left: 	
				paint_text({self.box.low.x + SIZE + ctx.style.layout.widget_padding, center.y - text_size.y / 2}, {text = info.text, font = ctx.style.font.label, size = ctx.style.text_size.label}, {align = .Left}, ctx.style.color.base_text[1])

				case .Right: 	
				paint_text({self.box.low.x, center.y - text_size.y / 2}, {text = info.text, font = ctx.style.font.label, size = ctx.style.text_size.label}, {align = .Left}, ctx.style.color.base_text[1])

				case .Top: 		
				paint_text(self.box.low, {text = info.text, font = ctx.style.font.label, size = ctx.style.text_size.label}, {align = .Left}, ctx.style.color.base_text[1])

				case .Bottom: 	
				paint_text({self.box.low.x, self.box.high.y - text_size.y}, {text = info.text, font = ctx.style.font.label, size = ctx.style.text_size.label}, {align = .Left}, ctx.style.color.base_text[1])
			}
		}
		// Click result
		clicked = !info.on && widget_clicked(self, .Left)
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

// Helper functions
do_enum_radio_buttons :: proc(
	value: $T, 
	text_side: maui.Box_Side = .Left, 
	loc := #caller_location,
) -> (new_value: T) {
	using maui
	new_value = value
	push_id(hash(loc))
	for member in T {
		push_id(hash_int(int(member)))
			if do_radio_button({
				on = member == value, 
				text = tmp_print(member), 
				text_side = text_side,
			}) {
				new_value = member
			}
		pop_id()
	}
	pop_id()
	return
}
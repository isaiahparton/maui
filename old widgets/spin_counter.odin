package maui_widgets
import "../"

import "core:fmt"
import "core:math"
import "core:strconv"
import "core:intrinsics"

MAX_SPIN_COUNTER_DIGITS :: 10

Spin_Counter_Info :: struct($T: typeid) where intrinsics.type_is_integer(T) && intrinsics.type_is_unsigned(T) {
	using info: maui.Widget_Info,
	digits: int,
	digit_width: f32,
	value: T,
}
Spin_Counter_State :: struct {
	offsets: [MAX_SPIN_COUNTER_DIGITS]f64,
}
do_spin_counter :: proc(info: Spin_Counter_Info($T), state: ^Spin_Counter_State, loc := #caller_location) {
	using maui
	//
	if self, ok := do_widget(hash(loc)); ok {
		parent_box := info.box.? or_else layout_next(current_layout())

		digit_count := min(info.digits, MAX_SPIN_COUNTER_DIGITS)
		digit_size: [2]f32 = {info.digit_width, height(parent_box)}

		self.box = child_box(parent_box, {f32(digit_count) * digit_size.x, digit_size.y}, placement.align)
		update_widget(self)

		if .Should_Paint in self.bits {
			paint_rounded_box_fill(self.box, ui.style.rounding, ui.style.color.substance[0])

			digits_box := self.box
			text := tmp_print(info.value)
			for i in 0..<info.digits {
				// Some math
				p := T(math.pow(10, f64(i)))
				a := info.value / p
				// The box in which this digit is displayed
				digit_box := cut_box_right(&digits_box, info.digit_width)
				// The desired offset
				target_offset := f64(a if i < len(text) else 0) * f64(digit_size.y)
				// Difference of desired offset
				diff := (target_offset - state.offsets[i])
				mod_offset := math.mod(state.offsets[i], f64(digit_size.y))// - math.floor(state.offsets[i] / digit_size.y) * digit_size.y
				// Display the digits above and below in addition to the desired digit
				for j in -1..<2 {
					r: rune
					if i < len(text) {
						r = (rune(text[len(text) - (i + 1)]) if i < len(text) else '0') - rune(j)
						r -= rune(math.floor(diff / f64(digit_size.y))) % 10
						if r < '0' {
							r = '9'
						} if r > '9' {
							r = '0'
						}
					} else {
						r = '0'
					}
					// Paint a rune clipped to this box
					paint_clipped_aligned_rune(
						ui.style.font.monospace, 
						ui.style.text_size.label, 
						r, 
						center(digit_box) + {0, f32(mod_offset) + f32(j - 1) * digit_size.y}, 
						ui.style.color.base_text[int(i < len(text) && a > 0)], 
						{.Middle, .Middle},
						digit_box,
					)
				}
				// Lerp to desired offset
				state.offsets[i] += diff * 10 * f64(ctx.delta_time)
				// Make sure to repaint if needed
				if abs(diff) > 0.1 {
					ctx.painter.next_frame = true
				}
			}
		}
		//
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
}
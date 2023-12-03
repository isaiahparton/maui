package maui_widgets
import "../"

import "core:fmt"
import "core:math"
import "core:strconv"
import "core:intrinsics"

MAX_SPIN_COUNTER_DIGITS :: 10

Spin_Counter_Info :: struct($T: typeid) where intrinsics.type_is_integer(T) {
	digits: int,
	digit_width: f32,
	value: T,
}
Spin_Counter_State :: struct {
	offsets: [MAX_SPIN_COUNTER_DIGITS]f32,
}

do_spin_counter :: proc(info: Spin_Counter_Info($T), state: ^Spin_Counter_State, loc := #caller_location) {
	using maui
	//
	if self, ok := do_widget(hash(loc)); ok {
		parent_box := use_next_box() or_else layout_next(current_layout())

		digit_count := min(info.digits, MAX_SPIN_COUNTER_DIGITS)
		digit_size: [2]f32 = {info.digit_width, height(parent_box)}

		self.box = child_box(parent_box, {f32(digit_count) * digit_size.x, digit_size.y}, placement.align)
		update_widget(self)

		if .Should_Paint in self.bits {
			paint_rounded_box_fill(self.box, style.rounding, style.color.substance[0])

			digits_box := self.box
			text := tmp_print(info.value)
			for i in 0..<info.digits {
				p := T(math.pow(10, f32(i)))
				a := info.value / p
				digit_box := cut_box_right(&digits_box, info.digit_width)
				target_offset := f32(a if i < len(text) else 0) * -digit_size.y
				for j in -1..<2 {
					r: rune
					if i < len(text) {
						r = rune(text[len(text) - (i + 1)]) + rune(j)
						if r < '0' {
							r = '9'
						} else if r > '9' {
							r = '0'
						}
					} else {
						r = '0'
					}
					paint_clipped_aligned_rune(style.font.monospace, style.text_size.label, r, center(digit_box) + {0, state.offsets[i] + f32(j + a) * digit_size.y}, style.color.base_text[int(i < len(text) && a > 0)], {.Middle, .Middle}, self.box)
				}
				diff := (target_offset - state.offsets[i])
				if abs(diff) > digit_size.y * 2 {
					state.offsets[i] = target_offset
				} else {
					state.offsets[i] += diff * 15 * core.delta_time
				}
				if abs(diff) > 0.1 {
					painter.next_frame = true
				}
			}
		}

		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
}
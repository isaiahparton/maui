package maui_widgets
import "../"

import "core:math"
import "core:intrinsics"

Orientation :: enum {
	Horizontal,
	Vertical,
}

// Integer spinner (compound widget)
Spinner_Info :: struct($T: typeid) where intrinsics.type_is_numeric(T) {
	value: T,
	low,
	high,
	increment: Maybe(T),
	orientation: Orientation,
	trim_decimal: bool,
}

do_spinner :: proc(info: Spinner_Info($T), loc := #caller_location) -> (new_value: T) {
	using maui
	loc := loc
	new_value = info.value
	prev_rounded_corners := ui.style.rounded_corners
	// Sub-widget boxes
	box := layout_next(current_layout())
	increase_box, decrease_box: Box
	box_size := box.high - box.low
	if info.orientation == .Horizontal {
		buttons_box := cut_box_right(&box, box_size.y)
		increase_box = get_box_top(buttons_box, box_size.y / 2)
		decrease_box = get_box_bottom(buttons_box, box_size.y / 2)
		ui.style.rounded_corners = prev_rounded_corners & {.Top_Left, .Bottom_Left}
	} else {
		increase_box = cut_box_top(&box, box_size.x / 2)
		decrease_box = cut_box_bottom(&box, box_size.x / 2)
		ui.style.rounded_corners = {}
	}
	increment := info.increment.? or_else T(1)
	// Number input
	set_next_box(box)
	// Number field
	new_value = do_number_input(Number_Input_Info(T){
		value = info.value,
		text_align = .Middle if info.orientation == .Vertical else nil,
		trim_decimal = info.trim_decimal,
	}, loc)
	loc.column += 1
	// Decrease button
	set_next_box(decrease_box)
	if info.orientation == .Horizontal {
		ui.style.rounded_corners = prev_rounded_corners & {.Bottom_Right}
	} else {
		ui.style.rounded_corners = prev_rounded_corners & {.Bottom_Left, .Bottom_Right}
	}
	if do_button({
		align = .Middle,
	}, loc) {
		new_value -= increment
	}
	paint_arrow(box_center(ctx.last_box), 5, 0, 1, ui.style.color.substance_text[1])
	loc.column += 1
	// Increase button
	set_next_box(increase_box)
	if info.orientation == .Horizontal {
		ui.style.rounded_corners = prev_rounded_corners & {.Top_Right}
	} else {
		ui.style.rounded_corners = prev_rounded_corners & {.Top_Left, .Top_Right}
	}
	if do_button({
		align = .Middle,
	}, loc) {
		new_value += increment
	}
	// Draw up arrow
	ui.style.rounded_corners = prev_rounded_corners
	paint_arrow(box_center(ctx.last_box), 5, -math.PI, 1, ui.style.color.substance_text[1])
	// Clamp value
	if new_value != info.value {
		if low, ok := info.low.?; ok {
			new_value = max(new_value, low)
		}
		if high, ok := info.high.?; ok {
			new_value = min(new_value, high)
		}
	}
	return
}
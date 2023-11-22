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
	value,
	low,
	high: T,
	increment: Maybe(T),
	orientation: Orientation,
	trim_decimal: bool,
}

do_spinner :: proc(info: Spinner_Info($T), loc := #caller_location) -> (new_value: T) {
	using maui
	loc := loc
	new_value = info.value
	// Sub-widget boxes
	box := layout_next(current_layout())
	increase_box, decrease_box: Box
	box_size := box.high - box.low
	if info.orientation == .Horizontal {
		buttons_box := cut_box_right(&box, box_size.y)
		increase_box = get_box_top(buttons_box, box_size.y / 2)
		decrease_box = get_box_bottom(buttons_box, box_size.y / 2)
	} else {
		increase_box = get_box_top(box, box_size.x / 2)
		decrease_box = get_box_bottom(box, box_size.x / 2)
	}
	increment := info.increment.? or_else T(1)
	prev_rounded_corners := style.rounded_corners
	// Number input
	set_next_box(box)
	style.rounded_corners = prev_rounded_corners & {.Top_Left, .Bottom_Left}
	new_value = clamp(do_number_input(Number_Input_Info(T){
		value = info.value,
		text_align = ([2]Alignment){
			.Middle, 
			.Middle,
		} if info.orientation == .Vertical else nil,
		trim_decimal = info.trim_decimal,
	}, loc), info.low, info.high)
	// Step buttons
	loc.column += 1
	set_next_box(decrease_box)
	style.rounded_corners = prev_rounded_corners & {.Bottom_Right}
	if do_button({
		align = .Middle,
	}, loc) {
		new_value = max(info.low, info.value - increment)
	}
	paint_arrow(box_center(core.last_box), 5, 0, 1, style.color.substance_text[1])
	loc.column += 1
	set_next_box(increase_box)
	style.rounded_corners = prev_rounded_corners & {.Top_Right}
	if do_button({
		align = .Middle,
	}, loc) {
		new_value = min(info.high, info.value + increment)
	}
	style.rounded_corners = prev_rounded_corners
	paint_arrow(box_center(core.last_box), 5, -math.PI, 1, style.color.substance_text[1])
	return
}
package maui

import "core:time"

// Text input que size
MAX_INPUT_RUNES :: 32
// Max compound clicks
MAX_CLICK_COUNT :: 3

Mouse_Button :: enum {
	left,
	middle,
	right,
}
Mouse_Bits :: bit_set[Mouse_Button]
Mouse_Button_State :: enum {
	// Just pressed down (was not down before)
	pressed,
	// Is down
	down,
	// Just released (unpressed) (not down anymore)
	released,
	// Pressed and released over the widget
	clicked,
}

Key :: enum {
	alt,
	escape,
	control,
	shift,
	tab,
	backspace,
	enter,
	left,
	right,
	up,
	down,
	a,
	x,
	c,
	v,
}
Key_Bits :: bit_set[Key]

Input :: struct {
	last_mouse_point, mouse_point, mouse_scroll: [2]f32,
	mouse_bits, last_mouse_bits: Mouse_Bits,
	last_mouse_button: Mouse_Button,
	last_click_time: [Mouse_Button]time.Time,
	this_click_time: [Mouse_Button]time.Time,

	key_bits, last_key_bits: Key_Bits,
	last_key: Key,

	runes: [MAX_INPUT_RUNES]rune,
	rune_count: int,

	key_hold_timer,
	key_pulse_timer: f32,
	key_pulse: bool,
}

input_step :: proc(using self: ^Input) {
	rune_count = 0

	// Repeating keys when held
	new_keys := key_bits - last_key_bits
	old_key := last_key
	for key in Key {
		if key in new_keys && key != last_key {
			last_key = key
			break
		}
	}
	if last_key != old_key {
		key_hold_timer = 0
	}

	key_pulse = false
	if last_key in key_bits {
		key_hold_timer += core.delta_time
	} else {
		key_hold_timer = 0
	}
	if key_hold_timer >= KEY_REPEAT_DELAY {
		if key_pulse_timer > 0 {
			key_pulse_timer -= core.delta_time
		} else {
			key_pulse_timer = 1.0 / KEY_REPEAT_RATE
			key_pulse = true
		}
	}
}
mouse_pressed :: proc(button: Mouse_Button) -> bool {
	using input
	return (button in mouse_bits) && (button not_in last_mouse_bits)
}
mouse_released :: proc(button: Mouse_Button) -> bool {
	using input
	return (button not_in mouse_bits) && (button in last_mouse_bits)
}
mouse_down :: proc(button: Mouse_Button) -> bool {
	using input
	return button in mouse_bits
}
key_pressed :: proc(key: Key) -> bool {
	using input
	return (key in key_bits) && ((key not_in last_key_bits) || (last_key == key && key_pulse))
}
key_released :: proc(key: Key) -> bool {
	using input
	return (key not_in key_bits) && (key in last_key_bits)
}
key_down :: proc(key: Key) -> bool {
	using input
	return key in key_bits
}

// Backend use
set_mouse_scroll :: proc(x, y: f32) {
	input.mouse_scroll = {x, y}
}
set_mouse_point :: proc(x, y: f32) {
	input.mouse_point = {x, y}
}
input_add_char :: proc(char: rune) {
	input.runes[input.rune_count] = char
	input.rune_count += 1
}
set_mouse_bit :: proc(button: Mouse_Button, value: bool) {
	if value {
		input.mouse_bits += {button}
		input.last_click_time[button] = input.this_click_time[button]
		input.this_click_time[button] = time.now()
		input.last_mouse_button = button
	} else {
		input.mouse_bits -= {button}
	}
}
set_key_bit :: proc(key: Key, value: bool) {
	if value {
		input.key_bits += {key}
	} else {
		input.key_bits -= {key}
	}
}

input: Input
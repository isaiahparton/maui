package maui

Mouse_Button :: enum {
	left,
	right,
	middle,
}
Mouse_Bits :: bit_set[Mouse_Button]
Key :: enum {
	alt,
	control,
	shift,
	tab,
	backspace,
	enter,
}
Key_Bits :: bit_set[Key]

Input :: struct {
	mouse_pos: Vector,
	mouse_bits, prev_mouse_bits: Mouse_Bits,
	key_bits, prev_key_bits: Key_Bits,
}

mouse_pressed :: proc(b: Mouse_Button) -> bool {
	using input
	return (b in mouse_bits) && (b not_in prev_mouse_bits)
}
mouse_released :: proc(b: Mouse_Button) -> bool {
	using input
	return (b not_in mouse_bits) && (b in prev_mouse_bits)
}
mouse_down :: proc(b: Mouse_Button) -> bool {
	using input
	return b in mouse_bits
}
key_pressed :: proc(k: Key) -> bool {
	using input
	return (k in key_bits) && (k not_in prev_key_bits)
}
key_released :: proc(k: Key) -> bool {
	using input
	return (k not_in key_bits) && (k in prev_key_bits)
}
key_down :: proc(k: Key) -> bool {
	using input
	return k in key_bits
}

set_mouse_position :: proc(x, y: i32) {
	input.mouse_pos = {x, y}
}
set_mouse_bit :: proc(b: Mouse_Button, v: bool) {
	if v {
		input.mouse_bits += {b}
	} else {
		input.mouse_bits -= {b}
	}
}

@private
input: Input
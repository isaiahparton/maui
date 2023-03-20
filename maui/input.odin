package maui

MouseButton :: enum {
	left,
	right,
	middle,
}
MouseBits :: bit_set[MouseButton]
Key :: enum {
	alt,
	control,
	shift,
	tab,
	backspace,
	enter,
}
KeyBits :: bit_set[Key]

Input :: struct {
	prevMousePos, mousePos: Vector,
	mouseBits, prevMouseBits: MouseBits,
	keyBits, prevKeyBits: KeyBits,
}


@private MousePressed :: proc(b: MouseButton) -> bool {
	using input
	return (b in mouseBits) && (b not_in prevMouseBits)
}
@private MouseReleased :: proc(b: MouseButton) -> bool {
	using input
	return (b not_in mouseBits) && (b in prevMouseBits)
}
@private MouseDown :: proc(b: MouseButton) -> bool {
	using input
	return b in mouseBits
}
@private KeyPressed :: proc(k: Key) -> bool {
	using input
	return (k in keyBits) && (k not_in prevKeyBits)
}
@private KeyReleased :: proc(k: Key) -> bool {
	using input
	return (k not_in keyBits) && (k in prevKeyBits)
}
@private KeyDown :: proc(k: Key) -> bool {
	using input
	return k in keyBits
}

SetMousePosition :: proc(x, y: f32) {
	input.mousePos = {x, y}
}
SetMouseBit :: proc(button: MouseButton, value: bool) {
	if value {
		input.mouseBits += {button}
	} else {
		input.mouseBits -= {button}
	}
}

@private input: Input
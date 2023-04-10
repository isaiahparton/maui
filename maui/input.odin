package maui

MAX_INPUT_RUNES :: 32

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
	left,
	right,
	up,
	down,
	a,
	x,
	c,
	v,
}
KeyBits :: bit_set[Key]

Input :: struct {
	prevMousePoint, mousePoint: Vec2,
	mouseBits, prevMouseBits: MouseBits,
	keyBits, prevKeyBits: KeyBits,
	lastKey: Key,

	runes: [MAX_INPUT_RUNES]rune,
	runeCount: int,

	keyHoldTimer,
	keyPulseTimer: f32,
	keyPulse: bool,
}

@private MousePressed :: proc(button: MouseButton) -> bool {
	using input
	return (button in mouseBits) && (button not_in prevMouseBits)
}
@private MouseReleased :: proc(button: MouseButton) -> bool {
	using input
	return (button not_in mouseBits) && (button in prevMouseBits)
}
@private MouseDown :: proc(button: MouseButton) -> bool {
	using input
	return button in mouseBits
}
@private KeyPressed :: proc(key: Key) -> bool {
	using input
	return (key in keyBits) && ((key not_in prevKeyBits) || (lastKey == key && keyPulse))
}
@private KeyReleased :: proc(key: Key) -> bool {
	using input
	return (key not_in keyBits) && (key in prevKeyBits)
}
@private KeyDown :: proc(key: Key) -> bool {
	using input
	return key in keyBits
}

SetMousePosition :: proc(x, y: f32) {
	input.mousePoint = {x, y}
}
InputAddCharPress :: proc(char: rune) {
	input.runes[input.runeCount] = char
	input.runeCount += 1
}
SetMouseBit :: proc(button: MouseButton, value: bool) {
	if value {
		input.mouseBits += {button}
	} else {
		input.mouseBits -= {button}
	}
}
SetKeyBit :: proc(key: Key, value: bool) {
	if value {
		input.keyBits += {key}
	} else {
		input.keyBits -= {key}
	}
}

@private input: Input
package maui

import "core:time"

import "vendor:glfw"

MAX_KEYBOARD_KEYS :: 512
// Text input que size
MAX_INPUT_RUNES :: 32
// Max compound clicks
MAX_CLICK_COUNT :: 3
IO :: struct {
	last_mouse_point, mouse_point, mouse_scroll: [2]f32,
	mouse_bits, last_mouse_bits: Mouse_Bits,
	last_mouse_button: Mouse_Button,
	last_click_time: [Mouse_Button]time.Time,
	this_click_time: [Mouse_Button]time.Time,

	key_set, last_key_set: Key_Set,
	last_key: Key,

	runes: [MAX_INPUT_RUNES]rune,
	rune_count: int,

	size: [2]i32,

	cursors: [Cursor_Type]glfw.CursorHandle,

	set_cursor_type: proc(Cursor_Type),
	set_cursor_position: proc(x, y: f32),
	get_clipboard_string: proc() -> string,
	set_clipboard_string: proc(string),
}
Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}
Mouse_Bits :: bit_set[Mouse_Button]
Mouse_Button_State :: enum {
	// Just pressed down (was not down before) (but is now)
	Pressed,
	// Is down
	Down,
	// Just released (unpressed) (not down anymore) (but was before)
	Released,
	// Pressed and released over the widget
	Clicked,
}
Key :: enum {
	Apostrophe      = 39,             // Key: '
	Comma           = 44,             // Key: ,
	Minus           = 45,             // Key: -
	Period          = 46,             // Key: .
	Slash           = 47,             // Key: /
	Zero            = 48,             // Key: 0
	One             = 49,             // Key: 1
	Two             = 50,             // Key: 2
	Three           = 51,             // Key: 3
	Four            = 52,             // Key: 4
	Five            = 53,             // Key: 5
	Six             = 54,             // Key: 6
	Seven           = 55,             // Key: 7
	Eight           = 56,             // Key: 8
	Nine            = 57,             // Key: 9
	Semicolon       = 59,             // Key: ;
	Equal           = 61,             // Key: =
	A               = 65,             // Key: A | a
	B               = 66,             // Key: B | b
	C               = 67,             // Key: C | c
	D               = 68,             // Key: D | d
	E               = 69,             // Key: E | e
	F               = 70,             // Key: F | f
	G               = 71,             // Key: G | g
	H               = 72,             // Key: H | h
	I               = 73,             // Key: I | i
	J               = 74,             // Key: J | j
	K               = 75,             // Key: K | k
	L               = 76,             // Key: L | l
	M               = 77,             // Key: M | m
	N               = 78,             // Key: N | n
	O               = 79,             // Key: O | o
	P               = 80,             // Key: P | p
	Q               = 81,             // Key: Q | q
	R               = 82,             // Key: R | r
	S               = 83,             // Key: S | s
	T               = 84,             // Key: T | t
	U               = 85,             // Key: U | u
	V               = 86,             // Key: V | v
	W               = 87,             // Key: W | w
	X               = 88,             // Key: X | x
	Y               = 89,             // Key: Y | y
	Z               = 90,             // Key: Z | z
	Left_Bracket    = 91,             // Key: [
	Backslash       = 92,             // Key: '\'
	Right_Bracket   = 93,             // Key: ]
	Grave           = 96,             // Key: `
	// Function keys
	Space           = 32,             // Key: Space
	Escape          = 256,            // Key: Esc
	Enter           = 257,            // Key: Enter
	Tab             = 258,            // Key: Tab
	Backspace       = 259,            // Key: Backspace
	Insert          = 260,            // Key: Ins
	Delete          = 261,            // Key: Del
	Right           = 262,            // Key: Cursor right
	Left            = 263,            // Key: Cursor left
	Down            = 264,            // Key: Cursor down
	Up              = 265,            // Key: Cursor up
	Page_Up         = 266,            // Key: Page up
	Page_Down       = 267,            // Key: Page down
	Home            = 268,            // Key: Home
	End             = 269,            // Key: End
	Caps_Lock       = 280,            // Key: Caps lock
	Scroll_Lock     = 281,            // Key: Scroll down
	Num_Lock        = 282,            // Key: Num lock
	Print_Screen    = 283,            // Key: Print screen
	Pause           = 284,            // Key: Pause
	F1              = 290,            // Key: F1
	F2              = 291,            // Key: F2
	F3              = 292,            // Key: F3
	F4              = 293,            // Key: F4
	F5              = 294,            // Key: F5
	F6              = 295,            // Key: F6
	F7              = 296,            // Key: F7
	F8              = 297,            // Key: F8
	F9              = 298,            // Key: F9
	F10             = 299,            // Key: F10
	F11             = 300,            // Key: F11
	F12             = 301,            // Key: F12
	Left_Shift      = 340,            // Key: Shift left
	Left_Control    = 341,            // Key: Control left
	Left_Alt        = 342,            // Key: Alt left
	Left_Super      = 343,            // Key: Super left
	Right_Shift     = 344,            // Key: Shift right
	Right_Control   = 345,            // Key: Control right
	Right_Alt       = 346,            // Key: Alt right
	Right_Super     = 347,            // Key: Super right
	Menu         		= 348,            // Key: KB menu
	// Keypad keys
	Keypad_Zero            		= 320,            // Key: Keypad 0
	Keypad_One            		= 321,            // Key: Keypad 1
	Keypad_Two            		= 322,            // Key: Keypad 2
	Keypad_Three            	= 323,            // Key: Keypad 3
	Keypad_Four           	 	= 324,            // Key: Keypad 4
	Keypad_Five            		= 325,            // Key: Keypad 5
	Keypad_Six            		= 326,            // Key: Keypad 6
	Keypad_Seven            	= 327,            // Key: Keypad 7
	Keypad_Eight            	= 328,            // Key: Keypad 8
	Keypad_Nine            		= 329,            // Key: Keypad 9
	Keypad_Decimal      			= 330,            // Key: Keypad .
	Keypad_Divide       			= 331,            // Key: Keypad /
	Keypad_Multiply     			= 332,            // Key: Keypad *
	Keypad_Minus     					= 333,            // Key: Keypad -
	Keypad_Add          			= 334,            // Key: Keypad +
	Keypad_Enter        			= 335,            // Key: Keypad Enter
	Keypad_Equal        			= 336,            // Key: Keypad =
	// Android key buttons
	Android_Back            	= 4,              // Key: Android back button
	Android_Menu            	= 82,             // Key: Android menu button
	Android_Volume_Up       	= 24,             // Key: Android volume up button
	Android_Volume_Down     	= 25,             // Key: Android volume down button
}
Key_Set :: [MAX_KEYBOARD_KEYS]bool
update_io :: proc(io: ^IO) {
	io.rune_count = 0
	io.last_mouse_bits = io.mouse_bits
}
// Mouse buttons
mouse_pressed :: proc(io: ^IO, button: Mouse_Button) -> bool {
	return (button in io.mouse_bits) && (button not_in io.last_mouse_bits)
}
mouse_released :: proc(io: ^IO, button: Mouse_Button) -> bool {
	return (button not_in io.mouse_bits) && (button in io.last_mouse_bits)
}
mouse_down :: proc(io: ^IO, button: Mouse_Button) -> bool {
	return button in io.mouse_bits
}
// Keys
key_pressed :: proc(io: ^IO, key: Key) -> bool {
	return io.key_set[key] && !io.last_key_set[key]
}
key_released :: proc(io: ^IO, key: Key) -> bool {
	return io.last_key_set[key] && !io.key_set[key]
}
key_down :: proc(io: ^IO, key: Key) -> bool {
	return io.key_set[key]
}
// Clipboard
get_clipboard_string :: proc(io: ^IO) -> string {
	assert(io.get_clipboard_string != nil)
	return io.get_clipboard_string()
}
set_clipboard_string :: proc(io: ^IO, str: string) {
	assert(io.set_clipboard_string != nil)
	io.set_clipboard_string(str)
}
// Backend use
set_mouse_bit :: proc(io: ^IO, button: Mouse_Button, value: bool) {
	if value {
		io.mouse_bits += {button}
		io.last_click_time[button] = io.this_click_time[button]
		io.this_click_time[button] = time.now()
		io.last_mouse_button = button
	} else {
		io.mouse_bits -= {button}
	}
}
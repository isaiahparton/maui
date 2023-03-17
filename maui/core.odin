package maui

import "core:fmt"
import "core:runtime"

MAX_CONTROLS :: 128
MAX_PANELS :: 64
LAYOUT_STACK_SIZE :: 64
COMMAND_STACK_SIZE :: 64 * 1024

Absolute :: i32
Relative :: f32
Value :: union {
	Absolute,
	Relative,
}
Vector :: [2]f32
AnyVector :: [2]Value

vec_vs_rect :: proc(v: Vector, r: Rect) -> bool {
	return (v.x >= r.x) && (v.x <= r.x + r.w) && (v.y >= r.y) && (v.y <= r.y + r.h)
}
rect_vs_rect :: proc(a, b: Rect) -> bool {
	return (a.x + a.w >= b.x) && (a.x <= b.x + b.w) && (a.y + a.h >= b.y) && (a.y <= b.y + b.h)
}
// A contains B
rect_contains_rect :: proc(a, b: Rect) -> bool {
	return (b.x >= a.x) && (b.x + b.w <= a.x + a.w) && (b.y >= a.y) && (b.y + b.h <= a.y + a.h)
}

Color :: distinct [4]u8 
color :: proc(index: int, alpha: f32) -> Color {
	c := state.colors[index]
	return {c.r, c.g, c.b, u8(f32(c.a) * alpha)}
}
color_normalize :: proc(c: Color) -> [4]f32 {
    return {f32(c.r) / 255, f32(c.g) / 255, f32(c.b) / 255, f32(c.a) / 255}
}
color_brightness :: proc(c: Color, v: f32) -> Color {
	b := clamp(i32(255.0 * v), -255, 255)
	return {
		cast(u8)clamp(i32(c.r) + b, 0, 255),
		cast(u8)clamp(i32(c.g) + b, 0, 255),
		cast(u8)clamp(i32(c.b) + b, 0, 255),
		c.a,
	}
}

/*
	Rectangles
*/
Rect :: struct {
	x, y, w, h: f32,
}
rect_translate :: proc(r: Rect, v: Vector) -> Rect {
	return {r.x + v.x, r.y + v.y, r.w, r.h}
}

/*
	A hashed id to uniquely identify stuff
*/
Id :: distinct u32

hash_id :: proc {
	hash_id_string,
	hash_id_bytes,
	hash_id_rawptr,
	hash_id_uintptr,
	hash_id_loc,
}
hash_id_string :: #force_inline proc(str: string) -> Id { 
	return hash_id_bytes(transmute([]byte) str) 
}
hash_id_rawptr :: #force_inline proc(data: rawptr, size: int) -> Id { 
	return hash_id_bytes(([^]u8)(data)[:size])  
}
hash_id_uintptr :: #force_inline proc(ptr: uintptr) -> Id { 
	ptr := ptr
	return hash_id_bytes(([^]u8)(&ptr)[:size_of(ptr)])  
}
hash_id_bytes :: proc(bytes: []byte) -> Id {
	/* 32bit fnv-1a hash */
	hash :: proc(hash: ^Id, data: []byte) {
		size := len(data)
		cptr := ([^]u8)(raw_data(data))
		for ; size > 0; size -= 1 {
			hash^ = Id(u32(hash^) ~ u32(cptr[0])) * 16777619
			cptr = cptr[1:]
		}
	}
	id := Id(2166136261)
	hash(&id, bytes)
	return id
}
hash_id_loc :: proc(loc: runtime.Source_Code_Location) -> Id {
	loc := loc
	return hash_id(rawptr(&loc), size_of(loc))
}

/*
	Containers are clipped parts of a layout that extend left/down as far as needed
	they can be scrolled horizontally and vertically and thus, must store their state
*/
ContainerBit :: enum {
	no_horizontal,
	no_vertical,
}
ContainerBits :: bit_set[ContainerBit]
Container :: struct {
	body: Rect,
	bits: ContainerBits,
	scroll: Vector,
}

/*
	The global state

	TODO(isaiah): Add manual state swapping
*/
State :: struct {
	allocator: runtime.Allocator,

	time: f32,
	delta_time: f32,
	
	render, disabled: bool,
	size: Vector,
	colors: [5]Color,

	// Retained control data
	control_exists: [MAX_CONTROLS]bool,
	controls: [MAX_CONTROLS]Control,

	// Retained panel data
	panel_pool: map[Id]i32,
	panel_exists: [MAX_PANELS]bool,
	panels: [MAX_PANELS]Panel,
	// Current panel state
	panel_idx: i32,
	hovered_panel: i32,
	focused_panel: i32,

	// Layout
	layouts: [LAYOUT_STACK_SIZE]Layout,
	layout_count: i32,

	// Next control options
	next_size: f32,
	next_rect: Rect,
	set_next: bool,

	prev_hover_id, next_hover_id, hover_id: Id,
	prev_press_id, press_id: Id,
	focus_id: Id,

	glyphs: []Glyph,

	// render commands
	commands: [COMMAND_STACK_SIZE]byte,
	command_offset: i32,
}



control_size :: proc(size: f32) {
	state.next_size = size
}
use_next_size :: proc() -> (size: f32, ok: bool) {
	size = state.next_size
	ok = state.next_size != 0
	return
}

control_rect :: proc(rect: Rect) {
	using state
	set_next = true
	next_rect = rect
}
use_next_rect :: proc() -> (rect: Rect, ok: bool) {
	using state
	rect = next_rect
	ok = set_next
	return
}

fill :: proc() {
	using state
	control_rect(get_layout().rect)
}
screen_point :: proc(h, v: f32) -> Vector {
	return {h * f32(state.size.x), v * f32(state.size.y)}
}
set_size :: proc(w, h: f32) {
	state.size = {w, h}
}


init :: proc() {
	state = new(State)

	state.colors = {
		{255, 255, 255, 255},
		{10, 10, 10, 255},
		{15, 235, 90, 255},
		{255, 0, 180, 255},
		{0, 255, 180, 255},
	}
}
refresh :: proc() {
	using state

	// sort commands

	assert(layout_count == 0)

	command_offset = 0

	prev_hover_id = hover_id
	prev_press_id = press_id
	hover_id = next_hover_id
	next_hover_id = 0

	input.prev_key_bits = input.key_bits
	input.prev_mouse_bits = input.mouse_bits

	free_all(allocator)
}
should_render :: proc() -> bool {
	return state.render
}

SCRIBE_BUFFER_COUNT :: 16
SCRIBE_BUFFER_SIZE :: 128
Scribe :: struct {
	buffers: [SCRIBE_BUFFER_COUNT][SCRIBE_BUFFER_SIZE]u8,
	index: u8,
}
@private scribe := Scribe{}
format_string :: proc(text: string, args: ..any) -> string {
	str := fmt.bprintf(scribe.buffers[scribe.index][:], text, ..args)
	scribe.index = (scribe.index + 1) % SCRIBE_BUFFER_COUNT
	return str
}
write :: proc(args: ..any) -> string {
	str := fmt.bprint(scribe.buffers[scribe.index][:], ..args)
	scribe.index = (scribe.index + 1) % SCRIBE_BUFFER_COUNT
	return str
}

//@private
state : ^State
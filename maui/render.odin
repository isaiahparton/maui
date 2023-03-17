package maui

import "core:fmt"

Glyph :: struct {
	source: Rect,
	offset: Vector,
}

Command_Glyph :: struct {
	using command: Command,
	src: Rect,
	origin: Vector,
	color: Color,
}
Command_Rect :: struct {
	using command: Command,
	rect: Rect,
	color: Color,
}
Command_Rect_Lines :: struct {
	using command: Command,
	rect: Rect,
	color: Color,
	thickness: i32,
}
Command_Quad :: struct {
	using command: Command,
	points: [4]Vector,
	color: Color,
}
Command_Triangle :: struct {
	using command: Command,
	points: [3]Vector,
	color: Color,
}
Command_Jump :: struct {
	using command: Command,
	dst: rawptr,
}
Command_Clip :: struct {
	using command: Command,
	rect: Rect,
}

Command_Variant :: union {
	^Command_Clip,
	^Command_Glyph,
	^Command_Rect,
	^Command_Rect_Lines,
	^Command_Quad,
	^Command_Triangle,
	^Command_Jump,
}
Command :: struct {
	variant: Command_Variant,
	size: i32,
}

push_command :: proc($Type: typeid, extra_size := 0) -> ^Type {
	size := i32(size_of(Type) + extra_size)
	cmd := transmute(^Type) &state.commands[state.command_offset]
	assert(state.command_offset + size < COMMAND_STACK_SIZE)
	state.command_offset += size
	cmd.variant = cmd
	cmd.size = size
	return cmd
}
next_command :: proc(pcmd: ^^Command) -> bool {
	using state

	cmd := pcmd^
	defer pcmd^ = cmd
	if cmd != nil { 
		cmd = (^Command)(uintptr(cmd) + uintptr(cmd.size)) 
	} else {
		cmd = (^Command)(&commands)
	}
	invalid_command :: #force_inline proc() -> ^Command {
		using state
		return (^Command)(&commands[command_offset])
	}
	for cmd != invalid_command() {
		if jmp, ok := cmd.variant.(^Command_Jump); ok {
			cmd = (^Command)(jmp.dst)
			continue
		}
		return true
	}
	return false
}
next_command_iterator :: proc(pcm: ^^Command) -> (Command_Variant, bool) {
	if next_command(pcm) {
		return pcm^.variant, true
	}
	return nil, false
}

/*
	Drawing procedures
*/
draw_quad :: proc(p1, p2, p3, p4: Vector, c: Color) {
	cmd := push_command(Command_Quad)
	cmd.points = {p1, p2, p3, p4}
	cmd.color = c
}
draw_triangle :: proc(p1, p2, p3: Vector, c: Color) {
	cmd := push_command(Command_Triangle)
	cmd.points = {p1, p2, p3}
	cmd.color = c
}
draw_rect :: proc(r: Rect, c: Color) {
	cmd := push_command(Command_Rect)
	cmd.rect = r
	cmd.color = c
}
draw_rect_lines :: proc(r: Rect, t: i32, c: Color) {
	cmd := push_command(Command_Rect_Lines)
	cmd.rect = r
	cmd.color = c
	cmd.thickness = t
}
measure_text :: proc(str: string) -> Vector {
	s := Vector{}
	for r in str {
		i := i32(r) - 32
		s.x += state.glyphs[i].source.w + 1
	}
	s.y = 24
	return s
}
draw_text :: proc(str: string, origin: Vector, color: Color) {
	v := origin
	for r in str {
		i := i32(r) - 32
		glyph := state.glyphs[i]
		cmd := push_command(Command_Glyph)
		cmd.src = glyph.source
		cmd.origin = v + glyph.offset
		cmd.color = color
		v.x += glyph.source.w + 1
	}
}
Alignment :: enum {
	near,
	middle,
	far,
}
draw_aligned_text :: proc(str: string, origin: Vector, color: Color, align_x, align_y: Alignment) {
	origin := origin
	if align_x == .middle {
		origin.x -= measure_text(str).x / 2
	}
	if align_y == .middle {
		origin.y -= measure_text(str).y / 2
	}
	draw_text(str, origin, color)
}
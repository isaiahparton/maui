package maui

import "core:fmt"
import "core:math"

Icon_Index :: enum {
	plus,
	archive,
	down,
	undo,
	redo,
	left,
	right,
	up,
	chart,
	calendar,
	check,
	close,
	delete,
	download,
	eye_line,
	eye,
	file,
	flder,
	heart,
	history,
	home,
	keyboard,
	list,
	menu,
	palette,
	edit,
	pie_chart,
	pin,
	search,
	cog,
	basket,
	star,
	minus,
	upload,
}
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
Command_Icon :: struct {
	using command: Command,
	src, dst: Rect,
	color: Color,
}
Command_Rect_Lines :: struct {
	using command: Command,
	rect: Rect,
	color: Color,
	thickness: i32,
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
	^Command_Rect_Lines,
	^Command_Triangle,
	^Command_Jump,
	^Command_Icon,
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
	draw_triangle(p1, p2, p4, c)
	draw_triangle(p4, p2, p3, c)
}
draw_triangle :: proc(p1, p2, p3: Vector, c: Color) {
	cmd := push_command(Command_Triangle)
	cmd.points = {p1, p2, p3}
	cmd.color = c
}
draw_rect :: proc(r: Rect, c: Color) {
	draw_quad(
		{f32(r.x), f32(r.y)},
		{f32(r.x), f32(r.y + r.h)},
		{f32(r.x + r.w), f32(r.y + r.h)},
		{f32(r.x + r.w), f32(r.y)},
		c,
	)
}
draw_triangle_strip :: proc(p: []Vector, c: Color) {
    if len(p) < 4 {
    	return
    }
    for i in 0 ..< len(p) {
        if i % 2 == 0 {
            draw_triangle(
            	{p[i].x, p[i].y},
            	{p[i - 2].x, p[i - 2].y},
            	{p[i - 1].x, p[i - 1].y},
            	c,
            )
        } else {
        	draw_triangle(
           	 	{p[i].x, p[i].y},
            	{p[i - 1].x, p[i - 1].y},
            	{p[i - 2].x, p[i - 2].y},
            	c,
            )
        }
    }
}
draw_line :: proc(p1, p2: Vector, t: i32, c: Color) {
	delta := p2 - p1
    length := math.sqrt(f32(delta.x * delta.x + delta.y * delta.y))

    if length > 0 && t > 0 {
        scale := f32(t) / (2 * length)
        radius := Vector{ -scale * delta.y, scale * delta.x }
        draw_triangle_strip({
            { p1.x - radius.x, p1.y - radius.y },
            { p1.x + radius.x, p1.y + radius.y },
            { p2.x - radius.x, p2.y - radius.y },
            { p2.x + radius.x, p2.y + radius.y },
        }, c)
    }
}
draw_rect_lines :: proc(r: Rect, t: i32, c: Color) {
	cmd := push_command(Command_Rect_Lines)
	cmd.rect = r
	cmd.color = c
	cmd.thickness = t
}
draw_circle :: proc(v: Vector, r: f32, c: Color) {
	step := f32(math.TAU / 30)
	for a := f32(0); a < math.TAU; a += step {
		draw_triangle(v, v + {math.cos(a + step) * r, math.sin(a + step) * r}, v + {math.cos(a) * r, math.sin(a) * r}, c)
	}
}
draw_circle_sector :: proc(center: Vector, radius, start, end: f32, segments: i32, color: Color) {
	step := (end - start) / f32(segments)
	angle := start
	for i in 0..<segments {
        draw_triangle(
        	center, 
        	center + {math.cos(angle + step) * radius, math.sin(angle + step) * radius}, 
        	center + {math.cos(angle) * radius, math.sin(angle) * radius}, 
        	color,
        	)
        angle += step;
    }
}
draw_ring :: proc(center: Vector, inner, outer: f32, segments: i32, color: Color) {
	segments := 60
	step := math.TAU / f32(segments)
	angle := f32(0)
	for i in 0..<segments {
        draw_quad(
        	center + {math.cos(angle) * outer, math.sin(angle) * outer},
        	center + {math.cos(angle) * inner, math.sin(angle) * inner},
        	center + {math.cos(angle + step) * inner, math.sin(angle + step) * inner},
        	center + {math.cos(angle + step) * outer, math.sin(angle + step) * outer},
        	color,
        	)
        angle += step;
    }
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
	v.y -= 1
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

ICON_SIZE :: 24
draw_icon :: proc(icon: Icon_Index, origin: Vector, color: Color) {
	draw_icon_ex(icon, origin, 1, .near, .near, color)
}
draw_icon_ex :: proc(icon: Icon_Index, origin: Vector, scale: f32, align_x, align_y: Alignment, color: Color) {
	offset := Vector{}
	if align_x == .middle {
		offset.x -= ICON_SIZE / 2
	} else if align_x == .far {
		offset.x -= ICON_SIZE
	}
	if align_y == .middle {
		offset.y -= ICON_SIZE / 2
	} else if align_y == .far {
		offset.y -= ICON_SIZE
	}
	cmd := push_command(Command_Icon)
	cmd.src = {(f32(i32(icon) % 10)) * ICON_SIZE, (f32(i32(icon) / 10)) * ICON_SIZE, ICON_SIZE, ICON_SIZE}
	cmd.dst = {0, 0, f32(ICON_SIZE * scale), f32(ICON_SIZE * scale)}
	cmd.dst.x = origin.x - cmd.dst.w / 2
	cmd.dst.y = origin.y - cmd.dst.h / 2
	cmd.color = color
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

/*
	Advanced stuff
*/
draw_rect_sweep :: proc(r: Rect, t: f32, c: Color) {
	if t >= 1 {
		draw_rect(r, c)
		return
	}
	a := (r.w + r.h) * t - r.h
	draw_rect({r.x, r.y, a, r.h}, c)
	draw_quad(
		{r.x + max(a, 0), r.y}, 
		{r.x + max(a, 0), r.y + clamp(a + r.h, 0, r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y + max(0, a - r.w + r.h)}, 
		{r.x + clamp(a + r.h, 0, r.w), r.y}, 
		c,
	)
}
package maui

// place a rect in a nother rect
child_rect :: proc(r: Rect, size: Vector, align_x, align_y: Alignment) -> Rect {
	c := Rect{0, 0, size.x, size.y}
	if align_x == .near {
		c.x = r.x
	} else if align_x == .middle {
		c.x = r.x + r.w / 2 - c.w / 2
	} else if align_x == .far {
		c.x = r.x + r.w - c.w
	}
	if align_y == .near {
		c.y = r.y
	} else if align_y == .middle {
		c.y = r.y + r.h / 2 - c.h / 2
	} else if align_y == .far {
		c.y = r.y + r.h - c.h
	}
	return c
}
// shrink a rect to its center
shrink_rect :: proc(b: Rect, a: f32) -> Rect {
	return {b.x + a, b.y + a, b.w - a * 2, b.h - a * 2}
}
// cut a rect and return the cut piece
cut_rect_left :: proc(b: ^Rect, a: f32) -> (r: Rect) {
	a := min(b.w, a)
	r = {b.x, b.y, a, b.h}
	b.x += a
	b.w -= a
	return
}
cut_rect_top :: proc(b: ^Rect, a: f32) -> (r: Rect) {
	a := min(b.h, a)
	r = {b.x, b.y, b.w, a}
	b.y += a
	b.h -= a
	return
}
cut_rect_right :: proc(b: ^Rect, a: f32) -> (r: Rect) {
	a := min(b.w, a)
	b.w -= a
	r = {b.x + b.w, b.y, a, b.h}
	return
}
cut_rect_bottom :: proc(b: ^Rect, a: f32) -> (r: Rect) {
	a := min(b.h, a)
	b.h -= a
	r = {b.x, b.y + b.h, b.w, a}
	return
}
cut_rect :: proc(r: ^Rect, s: Side, a: f32) -> Rect {
	switch s {
		case .bottom: 	return cut_rect_bottom(r, a)
		case .top: 		return cut_rect_top(r, a)
		case .left: 	return cut_rect_left(r, a)
		case .right: 	return cut_rect_right(r, a)
	}
	return {}
}
// get a cut piece of a rect
get_rect_left :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y, a, b.h}
}
get_rect_top :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y, b.w, a}
}
get_rect_right :: proc(b: Rect, a: f32) -> Rect {
	return {b.x + b.w - a, b.y, a, b.h}
}
get_rect_bottom :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y + b.h - a, b.w, a}
}
// attach a rect
attach_rect_left :: proc(b: Rect, a: f32) -> Rect {
	return {b.x - a, b.y, a, b.h}
}
attach_rect_top :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y - a, b.w, a}
}
attach_rect_right :: proc(b: Rect, a: f32) -> Rect {
	return {b.x + b.w, b.y, a, b.h}
}
attach_rect_bottom :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y + b.h, b.w, a}
}



/*
	Layout
*/
Side :: enum {
	top,
	bottom,
	left,
	right,
}
Layout :: struct {
	rect: Rect,
	side: Side,
	size: f32,
}
push_layout :: proc(r: Rect) {
	using state
	layouts[layout_count] = {
		rect = r,
	}
	layout_count += 1
}
pop_layout :: proc() {
	using state
	layout_count -= 1
}
get_layout :: proc() -> ^Layout {
	using state
	return &layouts[layout_count - 1]
}
cut_size :: proc(size: f32, relative := false) {
	l := get_layout()
	if relative {
		if l.side == .top || l.side == .bottom {
			l.size = size * l.rect.h
		} else {
			l.size =size * l.rect.w
		}
		return
	}
	l.size = size
}
cut_side :: proc(side: Side) {
	get_layout().side = side
}
space :: proc(a: f32) {
	l := get_layout()
	cut_rect(&l.rect, l.side, a)
}

shrink :: proc(a: f32) {
	l := get_layout()
	l.rect = shrink_rect(l.rect, a)
}
next_control_rect :: proc() -> Rect {
	l := get_layout()
	return use_next_rect() or_else cut_rect(&l.rect, l.side, use_next_size() or_else l.size)
}

@(deferred_out=_scoped_pop_layout)
layout :: proc(r: Rect) -> (ok: bool) {
	push_layout(r)
	return true
}
_scoped_pop_layout :: proc(ok: bool) {
	if ok {
		pop_layout()
	}
}
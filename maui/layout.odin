package maui

// place a rect in a nother rect
ChildRect :: proc(parent: Rect, size: Vector, alignX, alignY: Alignment) -> Rect {
	rect := Rect{0, 0, size.x, size.y}
	if alignX == .near {
		rect.x = parent.x
	} else if alignX == .middle {
		rect.x = parent.x + parent.w / 2 - rect.w / 2
	} else if alignX == .far {
		rect.x = parent.x + parent.w - rect.w
	}
	if alignY == .near {
		rect.y = parent.y
	} else if alignY == .middle {
		rect.y = parent.y + parent.h / 2 - rect.h / 2
	} else if alignY == .far {
		rect.y = parent.y + parent.h - rect.h
	}
	return rect
}
// shrink a rect to its center
ShrinkRect :: proc(b: Rect, a: f32) -> Rect {
	return {b.x + a, b.y + a, b.w - a * 2, b.h - a * 2}
}
// cut a rect and return the cut piece
CutRectLeft :: proc(b: ^Rect, a: f32) -> (r: Rect) {
	a := min(b.w, a)
	r = {b.x, b.y, a, b.h}
	b.x += a
	b.w -= a
	return
}
CutRectTop :: proc(b: ^Rect, a: f32) -> (r: Rect) {
	a := min(b.h, a)
	r = {b.x, b.y, b.w, a}
	b.y += a
	b.h -= a
	return
}
CutRectRight :: proc(b: ^Rect, a: f32) -> (r: Rect) {
	a := min(b.w, a)
	b.w -= a
	r = {b.x + b.w, b.y, a, b.h}
	return
}
CutRectBottom :: proc(b: ^Rect, a: f32) -> (r: Rect) {
	a := min(b.h, a)
	b.h -= a
	r = {b.x, b.y + b.h, b.w, a}
	return
}
CutRect :: proc(r: ^Rect, s: Side, a: f32) -> Rect {
	switch s {
		case .bottom: 	return CutRectBottom(r, a)
		case .top: 		return CutRectTop(r, a)
		case .left: 	return CutRectLeft(r, a)
		case .right: 	return CutRectRight(r, a)
	}
	return {}
}
// get a cut piece of a rect
GetRectLeft :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y, a, b.h}
}
GetRectTop :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y, b.w, a}
}
GetRectRight :: proc(b: Rect, a: f32) -> Rect {
	return {b.x + b.w - a, b.y, a, b.h}
}
GetRectBottom :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y + b.h - a, b.w, a}
}
// attach a rect
AttachRectLeft :: proc(b: Rect, a: f32) -> Rect {
	return {b.x - a, b.y, a, b.h}
}
AttachRectTop :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y - a, b.w, a}
}
AttachRectRight :: proc(b: Rect, a: f32) -> Rect {
	return {b.x + b.w, b.y, a, b.h}
}
AttachRectBottom :: proc(b: Rect, a: f32) -> Rect {
	return {b.x, b.y + b.h, b.w, a}
}


Cut :: proc(side: Side, amount: f32) -> Rect {
	assert(ctx.layoutDepth > 0)
	layout := GetCurrentLayout()
	return CutRect(&layout.rect, side, amount)
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
LayoutData :: struct {
	rect: Rect,
	side: Side,
	size: f32,
}
PushLayout :: proc(r: Rect) {
	using ctx
	layouts[layoutDepth] = {
		rect = r,
	}
	layoutDepth += 1
}
PopLayout :: proc() {
	using ctx
	layoutDepth -= 1
}
GetCurrentLayout :: proc() -> ^LayoutData {
	using ctx
	return &layouts[layoutDepth - 1]
}
CutSize :: proc(size: f32, relative := false) {
	l := GetCurrentLayout()
	if relative {
		if l.side == .top || l.side == .bottom {
			l.size = size * l.rect.h
		} else {
			l.size = size * l.rect.w
		}
		return
	}
	l.size = size
}
CutSide :: proc(side: Side) {
	GetCurrentLayout().side = side
}
Space :: proc(a: f32) {
	l := GetCurrentLayout()
	CutRect(&l.rect, l.side, a)
}

Shrink :: proc(a: f32) {
	l := GetCurrentLayout()
	l.rect = ShrinkRect(l.rect, a)
}
GetNextRect :: proc() -> Rect {
	layout := GetCurrentLayout()
	return UseNextRect() or_else CutRect(&layout.rect, layout.side, layout.size)
}
GetNextRectEx :: proc(size: Vector, alignX, alignY: Alignment) -> Rect {
	layout := GetCurrentLayout()
	layout.size = max(layout.size, size.x)
	return ChildRect(UseNextRect() or_else CutRect(&layout.rect, layout.side, layout.size), size, alignX, alignY)
}

@(deferred_out=_Layout)
Layout :: proc(r: Rect) -> (ok: bool) {
	PushLayout(r)
	return true
}
@private _Layout :: proc(ok: bool) {
	if ok {
		PopLayout()
	}
}
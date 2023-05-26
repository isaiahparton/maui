package maui

Rect :: struct {
	x, y, w, h: f32,
}
RectSide :: enum {
	top,
	bottom,
	left,
	right,
}
RectSides :: bit_set[RectSide;u8]
RectCorner :: enum {
	topLeft,
	topRight,
	bottomRight,
	bottomLeft,
}
RectCorners :: bit_set[RectCorner;u8]

RectCenter :: proc(rect: Rect) -> Vec2 {
	return {rect.x + rect.w / 2, rect.y + rect.h / 2}
}
// Rect manip
// Move the side of a rectangle
SquishRectLeft :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x + amount, rect.y, rect.w - amount, rect.h}
}
SquishRectRight :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x, rect.y, rect.w - amount, rect.h}
}
SquishRectTop :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x, rect.y + amount, rect.w, rect.h - amount}
}
SquishRectBottom :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x, rect.y, rect.w, rect.h - amount}
}
SquishRect :: proc(rect: Rect, side: RectSide, amount: f32) -> (result: Rect) {
	switch side {
		case .bottom: 	result = SquishRectBottom(rect, amount)
		case .top: 		result = SquishRectTop(rect, amount)
		case .left: 	result = SquishRectLeft(rect, amount)
		case .right: 	result = SquishRectRight(rect, amount)
	}
	return
}
// place a rect in a nother rect
ChildRect :: proc(parent: Rect, size: Vec2, alignX, alignY: Alignment) -> Rect {
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
CutRectLeft :: proc(rect: ^Rect, amount: f32) -> (result: Rect) {
	amount := min(rect.w, amount)
	result = {rect.x, rect.y, amount, rect.h}
	rect.x += amount
	rect.w -= amount
	return
}
CutRectTop :: proc(rect: ^Rect, amount: f32) -> (result: Rect) {
	amount := min(rect.h, amount)
	result = {rect.x, rect.y, rect.w, amount}
	rect.y += amount
	rect.h -= amount
	return
}
CutRectRight :: proc(rect: ^Rect, amount: f32) -> (result: Rect) {
	amount := min(rect.w, amount)
	rect.w -= amount
	result = {rect.x + rect.w, rect.y, amount, rect.h}
	return
}
CutRectBottom :: proc(rect: ^Rect, amount: f32) -> (result: Rect) {
	amount := min(rect.h, amount)
	rect.h -= amount
	result = {rect.x, rect.y + rect.h, rect.w, amount}
	return
}
CutRect :: proc(rect: ^Rect, side: RectSide, amount: f32) -> Rect {
	switch side {
		case .bottom: 	return CutRectBottom(rect, amount)
		case .top: 		return CutRectTop(rect, amount)
		case .left: 	return CutRectLeft(rect, amount)
		case .right: 	return CutRectRight(rect, amount)
	}
	return {}
}
CutLayout :: proc(using layout: ^LayoutData) -> (result: Rect) {
	if layout.grow {
		switch side {
			case .bottom: 	result = AttachRectTop(rect, size)
			case .top: 		result = AttachRectBottom(rect, size)
			case .left: 	result = AttachRectRight(rect, size)
			case .right: 	result = AttachRectLeft(rect, size)
		}
		layout.rect = result
	} else {
		switch side {
			case .bottom: 	result = CutRectBottom(&rect, size)
			case .top: 		result = CutRectTop(&rect, size)
			case .left: 	result = CutRectLeft(&rect, size)
			case .right: 	result = CutRectRight(&rect, size)
		}
	}
	return
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
AttachRectLeft :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x - amount, rect.y, amount, rect.h}
}
AttachRectTop :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x, rect.y - amount, rect.w, amount}
}
AttachRectRight :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x + rect.w, rect.y, amount, rect.h}
}
AttachRectBottom :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x, rect.y + rect.h, rect.w, amount}
}
AttachRect :: proc(rect: Rect, side: RectSide, size: f32) -> Rect {
	switch side {
		case .bottom: 	return AttachRectTop(rect, size)
		case .top: 		return AttachRectBottom(rect, size)
		case .left: 	return AttachRectRight(rect, size)
		case .right: 	return AttachRectLeft(rect, size)
	}
	return {}
}
SideCorners :: proc(sides: RectSides) -> RectCorners {
	corners: RectCorners = ALL_CORNERS
	if .top in sides {
		corners -= {.topLeft, .topRight}
	}
	if .bottom in sides {
		corners -= {.bottomLeft, .bottomRight}
	}
	if .left in sides {
		corners -= {.topLeft, .bottomLeft}
	}
	if .right in sides {
		corners -= {.topRight, .bottomRight}
	}
	return corners
}
VecVsRect :: proc(v: Vec2, r: Rect) -> bool {
	return (v.x >= r.x) && (v.x <= r.x + r.w) && (v.y >= r.y) && (v.y <= r.y + r.h)
}
RectVsRect :: proc(a, b: Rect) -> bool {
	return (a.x + a.w >= b.x) && (a.x <= b.x + b.w) && (a.y + a.h >= b.y) && (a.y <= b.y + b.h)
}
// B is contained entirely within A
RectContainsRect :: proc(a, b: Rect) -> bool {
	return (b.x >= a.x) && (b.x + b.w <= a.x + a.w) && (b.y >= a.y) && (b.y + b.h <= a.y + a.h)
}
ExpandRect :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x - amount, rect.y - amount, rect.w + amount * 2, rect.h + amount * 2}
}
TranslateRect :: proc(r: Rect, v: Vec2) -> Rect {
	return {r.x + v.x, r.y + v.y, r.w, r.h}
}
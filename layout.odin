package maui
import "core:fmt"

//TODO(isaiah): Rethink, how layouts work, add functionality for unknown layout size

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


Cut :: proc(side: RectSide, amount: f32) -> Rect {
	assert(ctx.layoutDepth > 0)
	layout := GetCurrentLayout()
	return CutRect(&layout.rect, side, amount)
}
CutEx :: proc(side: RectSide, amount: f32, relative := false) -> Rect {
	assert(ctx.layoutDepth > 0)
	layout := GetCurrentLayout()
	amount := amount
	if relative {
		if layout.side == .left || layout.side == .right {
			amount *= layout.rect.w
		} else {
			amount *= layout.rect.h
		}
	}
	return CutRect(&layout.rect, side, amount)
}


/*
	Layout
*/
LayoutData :: struct {
	rect: Rect,
	side: RectSide,
	size, margin: f32,
	// control alignment
	alignX, alignY: Alignment,
	grow: bool,
}
PushLayout :: proc(rect: Rect) -> (layout: ^LayoutData) {
	using ctx
	layout = &layouts[layoutDepth]
	layout^ = {
		rect = rect,
	}
	layoutDepth += 1
	when ODIN_DEBUG {
		if .showLayouts in ctx.options && layerDepth > 0 {
			PaintRectLines(rect, 1, {255, 255, 0, 255})
		}
	}
	return
}
PopLayout :: proc() {
	using ctx
	layoutDepth -= 1
}

/*
	Current layout control
*/
SetNextRect :: proc(rect: Rect) {
	ctx.setNextRect = true
	ctx.nextRect = rect
}
UseNextRect :: proc() -> (rect: Rect, ok: bool) {
	rect = ctx.nextRect
	ok = ctx.setNextRect
	ctx.setNextRect = false
	return
}
Align :: proc(align: Alignment) {
	layout := GetCurrentLayout()
	layout.alignX = align
	layout.alignY = align
}
AlignX :: proc(align: Alignment) {
	GetCurrentLayout().alignX = align
}
AlignY :: proc(align: Alignment) {
	GetCurrentLayout().alignY = align
}
SetMargin :: proc(margin: f32) {
	GetCurrentLayout().margin = margin
}
SetSize :: proc(size: f32, relative := false) {
	layout := GetCurrentLayout()
	if relative {
		if layout.side == .top || layout.side == .bottom {
			layout.size = layout.rect.h * size
		} else {
			layout.size = layout.rect.w * size
		}
		return
	}
	layout.size = size
}
SetSide :: proc(side: RectSide) {
	GetCurrentLayout().side = side
}
Space :: proc(amount: f32) {
	layout := GetCurrentLayout()
	CutRect(&layout.rect, layout.side, amount)
}
Shrink :: proc(amount: f32) {
	layout := GetCurrentLayout()
	layout.rect = ShrinkRect(layout.rect, amount)
}

GetCurrentLayout :: proc() -> ^LayoutData {
	using ctx
	return &layouts[layoutDepth - 1]
}

LayoutNext :: proc(layout: ^LayoutData) -> Rect {
	assert(layout != nil)

	ctx.lastRect = CutLayout(layout)
	if layout.margin > 0 {
		ctx.lastRect = ShrinkRect(ctx.lastRect, layout.margin)
	}
	return ctx.lastRect
}
LayoutNextEx :: proc(layout: ^LayoutData, size: Vec2) -> Rect {
	assert(layout != nil)

	return ChildRect(LayoutNext(layout), size, layout.alignX, layout.alignY)
}
LayoutFitControl :: proc(layout: ^LayoutData, size: Vec2) {
	if layout.side == .left || layout.side == .right {
		layout.size = size.x
	} else {
		layout.size = size.y
	}
}

@(deferred_out=_LayoutEx)
LayoutEx :: proc(rect: Rect) -> (layout: ^LayoutData, ok: bool) {
	layout = PushLayout(rect)
	ok = layout != {}
	return
}
@private _LayoutEx :: proc(_: ^LayoutData, ok: bool) {
	if ok {
		PopLayout()
	}
}

/*
	Manual layouts
*/
@(deferred_out=_Layout)
Layout :: proc(side: RectSide, size: f32, relative := false) -> (ok: bool) {
	rect := CutEx(side, size, relative)
	PushLayout(rect)
	ok = true
	return
}
@private _Layout :: proc(ok: bool) {
	if ok {
		PopLayout()
	}
}
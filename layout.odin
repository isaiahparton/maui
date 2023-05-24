package maui

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
LayoutFitWidget :: proc(layout: ^LayoutData, size: Vec2) {
	if layout.side == .left || layout.side == .right {
		layout.size = size.x
	} else {
		layout.size = size.y
	}
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
		if side == .left || side == .right {
			amount *= layout.rect.w
		} else {
			amount *= layout.rect.h
		}
	}
	return CutRect(&layout.rect, side, amount)
}

// User procs
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
package maui

Alignment :: enum {
	near,
	middle,
	far,
}

LayoutData :: struct {
	rect: Rect,
	side: RectSide,
	size, margin: f32,
	// control alignment
	alignX, alignY: Alignment,
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
	layout := CurrentLayout()
	layout.alignX = align
	layout.alignY = align
}
AlignX :: proc(align: Alignment) {
	CurrentLayout().alignX = align
}
AlignY :: proc(align: Alignment) {
	CurrentLayout().alignY = align
}
SetMargin :: proc(margin: f32) {
	CurrentLayout().margin = margin
}
SetSize :: proc(size: f32, relative := false) {
	layout := CurrentLayout()
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
	CurrentLayout().side = side
}
Space :: proc(amount: f32) {
	layout := CurrentLayout()
	CutRect(&layout.rect, layout.side, amount)
}
Shrink :: proc(amount: f32) {
	layout := CurrentLayout()
	layout.rect = ShrinkRect(layout.rect, amount)
}
CurrentLayout :: proc() -> ^LayoutData {
	using ctx
	return &layouts[layoutDepth - 1]
}

LayoutNext :: proc(using self: ^LayoutData) -> (result: Rect) {
	assert(self != nil)

	switch side {
		case .bottom: 	result = CutRectBottom(&rect, size)
		case .top: 		result = CutRectTop(&rect, size)
		case .left: 	result = CutRectLeft(&rect, size)
		case .right: 	result = CutRectRight(&rect, size)
	}

	if margin > 0 {
		result = ShrinkRect(result, margin)
	}
	
	ctx.lastRect = result
	return
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
LayoutFitLabel :: proc(layout: ^LayoutData, label: Label) {
	if layout.side == .left || layout.side == .right {
		layout.size = MeasureLabel(label).x + layout.rect.h / 2 + layout.margin * 2
	} else {
		layout.size = MeasureLabel(label).y + layout.rect.h / 2 + layout.margin * 2
	}
}
Cut :: proc(side: RectSide, amount: f32) -> Rect {
	assert(ctx.layoutDepth > 0)
	layout := CurrentLayout()
	return CutRect(&layout.rect, side, amount)
}
CutEx :: proc(side: RectSide, amount: f32, relative := false) -> Rect {
	assert(ctx.layoutDepth > 0)
	layout := CurrentLayout()
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
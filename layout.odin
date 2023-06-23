package maui

Alignment :: enum {
	near,
	middle,
	far,
}

Layout :: struct {
	box: Box,
	side: Box_Side,
	size, margin: f32,
	// control alignment
	align: [2]Alignment,
}
push_layout :: proc(rect: Box) -> (layout: ^Layout) {
	using ctx
	layout = &layouts[layoutDepth]
	layout^ = {
		rect = rect,
	}
	layoutDepth += 1
	return
}
pop_layout :: proc() {
	using ctx
	layoutDepth -= 1
}

/*
	Current layout control
*/
set_next_box :: proc(rect: Box) {
	core.setNextBox = true
	core.nextBox = rect
}
use_next_box :: proc() -> (rect: Box, ok: bool) {
	rect = core.nextBox
	ok = core.setNextBox
	core.setNextBox = false
	return
}
set_align :: proc(align: Alignment) {
	layout := current_layout()
	layout.alignX = align
	layout.alignY = align
}
set_align_x :: proc(align: Alignment) {
	current_layout().alignX = align
}
set_align_y :: proc(align: Alignment) {
	current_layout().alignY = align
}
set_margin :: proc(margin: f32) {
	current_layout().margin = margin
}
set_size :: proc(size: f32, relative := false) {
	layout := current_layout()
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
set_side :: proc(side: Box_Side) {
	current_layout().side = side
}
space :: proc(amount: f32) {
	layout := current_layout()
	box_cut(&layout.rect, layout.side, amount)
}
shrink :: proc(amount: f32) {
	layout := current_layout()
	layout.rect = ShrinkBox(layout.rect, amount)
}
current_layout :: proc() -> ^Layout {
	using ctx
	return &layouts[layoutDepth - 1]
}

layout_next :: proc(using self: ^Layout) -> (result: Box) {
	assert(self != nil)
	switch side {
		case .bottom: 	result = box_cutBottom(&rect, size)
		case .top: 		result = box_cutTop(&rect, size)
		case .left: 	result = box_cutLeft(&rect, size)
		case .right: 	result = box_cutRight(&rect, size)
	}

	if margin > 0 {
		result = ShrinkBox(result, margin)
	}
	
	core.lastBox = result
	return
}
layout_next_child :: proc(using self: ^Layout, size: [2]f32) -> Box {
	assert(self != nil)
	return ChildBox(LayoutNext(self), size, alignX, alignY)
}
layout_fit :: proc(layout: ^Layout, size: [2]f32) {
	if layout.side == .left || layout.side == .right {
		layout.size = size.x
	} else {
		layout.size = size.y
	}
}
layout_fit_label :: proc(using self: ^Layout, label: Label) {
	if side == .left || side == .right {
		size = measure_label(label).x + rect.h / 2 + margin * 2
	} else {
		size = measure_label(label).y + rect.h / 2 + margin * 2
	}
}
cut :: proc(side: Box_Side, amount: f32, relative := false) -> Box {
	assert(core.layoutDepth > 0)
	layout := current_layout()
	amount := amount
	if relative {
		if side == .left || side == .right {
			amount *= layout.rect.w
		} else {
			amount *= layout.rect.h
		}
	}
	return box_cut(&layout.rect, side, amount)
}

// User procs
@(deferred_out=_layout)
layout :: proc(side: Box_Side, size: f32, relative := false) -> (ok: bool) {
	rect := cut(side, size, relative)
	push_layout(rect)
	return true
}
@(deferred_out=_layout)
layout_box :: proc(box: Box) -> (ok: bool) {
	push_layout(box)
	return true
}
@private 
_layout :: proc(ok: bool) {
	if ok {
		pop_layout()
	}
}
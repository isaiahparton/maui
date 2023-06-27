package maui

import "core:fmt"

Alignment :: enum {
	near,
	middle,
	far,
}

// A `Layout` is a context for placing widgets and other layouts
Layout :: struct {
	box: Box,
	side: Box_Side,
	size: f32,
	// control margin
	margin: [2]f32,
	// control alignment
	align: [2]Alignment,
}

LAYOUT_STACK_SIZE :: 32

Layout_Agent :: struct {
	stack: Stack(Layout, LAYOUT_STACK_SIZE),
	current_layout: ^Layout,
}
layout_agent_push :: proc(using self: ^Layout_Agent, layout: Layout) -> ^Layout {
	stack_push(&stack, layout)
	current_layout = stack_top_ref(&stack)
	return current_layout
}
layout_agent_pop :: proc(using self: ^Layout_Agent) {
	stack_pop(&stack)
	current_layout = stack_top_ref(&stack)
}

push_layout :: proc(box: Box) -> (layout: ^Layout) {
	return layout_agent_push(&core.layout_agent, Layout({
		box = box,
	}))
}
pop_layout :: proc() {
	layout_agent_pop(&core.layout_agent)
}
current_layout :: proc() -> ^Layout {
	assert(core.layout_agent.current_layout != nil)
	return core.layout_agent.current_layout
}

/*
	Current layout control
*/
set_next_box :: proc(box: Box) {
	core.next_box = box
}
use_next_box :: proc() -> (box: Box, ok: bool) {
	box, ok = core.next_box.?
	if ok {
		core.next_box = nil
	}
	return
}
set_align :: proc(align: Alignment) {
	current_layout().align = {align, align}
}
set_align_x :: proc(align: Alignment) {
	current_layout().align.x = align
}
set_align_y :: proc(align: Alignment) {
	current_layout().align.y = align
}
set_margin :: proc(margin: f32) {
	current_layout().margin = {margin, margin}
}
set_margin_x :: proc(margin: f32) {
	current_layout().margin.x = margin
}
set_margin_y :: proc(margin: f32) {
	current_layout().margin.y = margin
}
set_size :: proc(size: f32, relative := false) {
	layout := current_layout()
	if relative {
		if layout.side == .top || layout.side == .bottom {
			layout.size = layout.box.h * size
		} else {
			layout.size = layout.box.w * size
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
	box_cut(&layout.box, layout.side, amount)
}
shrink :: proc(amount: f32) {
	layout := current_layout()
	layout.box = shrink_box(layout.box, amount)
}

layout_next :: proc(using self: ^Layout) -> (result: Box) {
	assert(self != nil)
	switch side {
		case .bottom: 	result = box_cut_bottom(&box, size)
		case .top: 		result = box_cut_top(&box, size)
		case .left: 	result = box_cut_left(&box, size)
		case .right: 	result = box_cut_right(&box, size)
	}

	if margin != {} {
		result = shrink_box(result, margin)
	}
	
	core.last_box = result
	return
}
layout_next_child :: proc(self: ^Layout, size: [2]f32) -> Box {
	assert(self != nil)
	return child_box(layout_next(self), size, self.align)
}
layout_fit :: proc(self: ^Layout, size: [2]f32) {
	assert(self != nil)
	if self.side == .left || self.side == .right {
		self.size = size.x
	} else {
		self.size = size.y
	}
}
layout_fit_label :: proc(using self: ^Layout, label: Label) {
	assert(self != nil)
	if side == .left || side == .right {
		size = measure_label(label).x + box.h / 2 + margin.x * 2
	} else {
		size = measure_label(label).y + box.h / 2 + margin.y * 2
	}
}
cut :: proc(side: Box_Side, amount: f32, relative := false) -> Box {
	layout := current_layout()
	amount := amount
	if relative {
		if side == .left || side == .right {
			amount *= layout.box.w
		} else {
			amount *= layout.box.h
		}
	}
	return box_cut(&layout.box, side, amount)
}
fake_cut :: proc(side: Box_Side, amount: f32, relative := false) -> Box {
	layout := current_layout()
	amount := amount
	if relative {
		if side == .left || side == .right {
			amount *= layout.box.w
		} else {
			amount *= layout.box.h
		}
	}
	return get_box_cut(layout.box, side, amount)
}

// User procs
@(deferred_out=_do_layout)
do_layout :: proc(side: Box_Side, size: f32, relative := false) -> (ok: bool) {
	box := cut(side, size, relative)
	push_layout(box)
	return true
}
@(deferred_out=_do_layout)
do_layout_box :: proc(box: Box) -> (ok: bool) {
	push_layout(box)
	return true
}
@private 
_do_layout :: proc(ok: bool) {
	if ok {
		pop_layout()
	}
}
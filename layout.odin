package maui

import "core:fmt"

// One point is currently equal to one pixel
Points :: f32
Pt :: Points
// One percent is currently equal to one percent of whatever it is a percent of
Percent :: distinct f32

Unit :: union #no_nil {
	Points,
	Percent,
}

Alignment :: enum {
	Near,
	Middle,
	Far,
}

Layout_Mode :: enum {
	Fixed,
	Extending,
}

Placement_Info :: struct {
	side: Box_Side,
	size: [2]Unit,
	align: [2]Alignment,
	margin: [Box_Side]Unit,
}

// A `Layout` is a context for placing widgets and other layouts
Layout :: struct {
	// Mode
	mode: Layout_Mode,
	// State
	box: Box,
	// The side from which the layout was created (if any)
	side: Maybe(Box_Side),
	ignore_parent: bool,
	// Placement settings
	placement: Placement_Info,
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

push_layout :: proc(box: Box, mode: Layout_Mode = .Fixed) -> (layout: ^Layout) {
	placement: Placement_Info
	if core.layout_agent.stack.height > 0 {
		placement = current_layout().placement
	}
	return layout_agent_push(&core.layout_agent, Layout({
		box = box,
		mode = mode,
		placement = placement,
	}))
}
pop_layout :: proc() {
	last_layout := current_layout()
	layout_agent_pop(&core.layout_agent)
	if !last_layout.ignore_parent && core.layout_agent.stack.height > 0 {
		layout := current_layout()
		if last_layout.mode == .Extending {
			if side, ok := last_layout.side.?; ok {
				layout_cut_or_extend(layout, side, Pt(last_layout.box.w if int(side) > 1 else last_layout.box.h))	
			}
		}
	}
}
// Get the current layout (asserts that there be one)
current_layout :: proc(loc := #caller_location) -> ^Layout {
	assert(core.layout_agent.current_layout != nil, "No current layout", loc)
	return core.layout_agent.current_layout
}
// Set the next box to be used instead of `layout_next()`
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
// Set alignment for placement
set_align :: proc(align: Alignment) {
	current_layout().placement.align = {align, align}
}
set_align_x :: proc(align: Alignment) {
	current_layout().placement.align.x = align
}
set_align_y :: proc(align: Alignment) {
	current_layout().placement.align.y = align
}
// Set margin(s) for placement settings
set_margin_all :: proc(margin: Unit) {
	current_layout().placement.margin = {
		.Top = margin, 
		.Bottom = margin, 
		.Left = margin, 
		.Right = margin,
	}
}
set_margin_side :: proc(side: Box_Side, margin: Unit) {
	current_layout().placement.margin[side] = margin
}
set_margin_any :: proc(margin: [Box_Side]Unit) {
	current_layout().placement.margin = margin
}
set_margin_x :: proc(margin: Unit) {
	layout := current_layout()
	layout.placement.margin[.Left] = margin
	layout.placement.margin[.Right] = margin
}
set_margin_y :: proc(margin: Unit) {
	layout := current_layout()
	layout.placement.margin[.Top] = margin
	layout.placement.margin[.Bottom] = margin
}
set_margin :: proc {
	set_margin_all,
	set_margin_side,
	set_margin_any,
}
get_layout_margin :: proc(layout: ^Layout, side: Box_Side) -> Pt {
	return (layout.placement.margin[side].(Points) or_else Pt(f32(layout.placement.margin[side].(Percent)) * 0.01 * (layout.box.w if int(side) > 1 else layout.box.h)))
}
get_layout_width :: proc(layout: ^Layout) -> Pt {
	return layout.box.w - get_layout_margin(layout, .Left) - get_layout_margin(layout, .Right)
}
get_layout_height :: proc(layout: ^Layout) -> Pt {
	return layout.box.h - get_layout_margin(layout, .Top) - get_layout_margin(layout, .Bottom)
}
// Set size for placement settings
set_size :: proc(size: [2]Unit) {
	current_layout().placement.size = size
}
set_width :: proc(width: Unit) {
	current_layout().placement.size.x = width
}
set_height :: proc(height: Unit) {
	current_layout().placement.size.y = height
}
// Set side/direction for placement settings
set_side :: proc(side: Box_Side) {
	current_layout().placement.side = side
}
// Add space
space :: proc(amount: Pt) {
	layout := current_layout()
	cut_box(&layout.box, layout.placement.side, amount)
}
// Shrink the current layout (apply margin on all sides)
shrink :: proc(amount: f32, loc := #caller_location) {
	layout := current_layout(loc)
	layout.box = shrink_box(layout.box, amount)
}
// Uh
layout_cut_or_extend :: proc(layout: ^Layout, side: Box_Side, size: Unit) -> (result: Box) {
	// Get the base box
	switch layout.mode {
		case .Fixed:
		// In this case we cut a piece out of the layout
		switch side {
			case .Bottom: 	result = cut_box_bottom(&layout.box, size)
			case .Top: 			result = cut_box_top(&layout.box, size)
			case .Left: 		result = cut_box_left(&layout.box, size)
			case .Right: 		result = cut_box_right(&layout.box, size)
		}
		case .Extending:
		// In this case we grow the layout in the given direction
		switch layout.side {
			case .Bottom: 	result = extend_box_bottom(&layout.box, size.(Points) or_else 0)
			case .Top: 			result = extend_box_top(&layout.box, size.(Points) or_else 0)
			case .Left: 		result = extend_box_left(&layout.box, size.(Points) or_else 0)
			case .Right: 		result = extend_box_right(&layout.box, size.(Points) or_else 0)
		}
	}
	return
}
// Get a box from a layout
layout_next_of_size :: proc(using self: ^Layout, size: Unit) -> (result: Box) {
	result = layout_cut_or_extend(self, placement.side, size)

	margins: [Box_Side]Pt = {
		.Top = 			placement.margin[.Top].(Pt) 		or_else Pt(f32(placement.margin[.Top].(Percent)) * 0.01 * box.h),
		.Bottom = 	placement.margin[.Bottom].(Pt) 	or_else Pt(f32(placement.margin[.Bottom].(Percent)) * 0.01 * box.h),
		.Left = 		placement.margin[.Left].(Pt) 		or_else Pt(f32(placement.margin[.Left].(Percent)) * 0.01 * box.w),
		.Right = 		placement.margin[.Right].(Pt) 	or_else Pt(f32(placement.margin[.Right].(Percent)) * 0.01 * box.w),
	}
	// Apply margins
	result = {
		result.x + margins[.Left],
		result.y + margins[.Top],
		result.w - margins[.Left] - margins[.Right],
		result.h - margins[.Top] - margins[.Bottom],
	}
	return
}
// Get the next box from a layout, according to the current placement settings
layout_next :: proc(using self: ^Layout) -> (result: Box) {
	assert(self != nil)
	result = layout_next_of_size(self, placement.size.x if int(placement.side) > 1 else placement.size.y)
	// Set the last box
	core.last_box = result
	return
}
layout_next_child :: proc(using self: ^Layout, size: [2]f32) -> Box {
	assert(self != nil)
	return child_box(layout_next(self), size, placement.align)
}
layout_fit :: proc(layout: ^Layout, size: [2]f32) {
	if layout.placement.side == .Left || layout.placement.side == .Right {
		layout.placement.size = size.x
	} else {
		layout.placement.size = size.y
	}
}
cut :: proc(side: Box_Side, amount: Unit) -> Box {
	layout := current_layout()
	return cut_box(&layout.box, side, amount)
}
fake_cut :: proc(side: Box_Side, amount: Unit) -> Box {
	layout := current_layout()
	return get_cut_box(layout.box, side, amount)
}

// User procs
@(deferred_out=_do_layout)
do_layout :: proc(side: Box_Side, size: Unit, mode: Layout_Mode = .Fixed) -> (ok: bool) {
	box := cut(side, size)
	layout := push_layout(box, mode)
	if mode == .Extending {
		layout.side = side
	}
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
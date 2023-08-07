package maui

import "core:fmt"

/*
	These are user settings
		* No user called procedure shall change them
*/
placement: Placement_Info

Exact :: f32 
Relative :: distinct f32

Unit :: union #no_nil {
	Exact,
	Relative,
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
	size: Unit,
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
	// Temporary placement settings
	last_placement: Placement_Info,
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
	if core.layout_agent.stack.height > 0 {
		current_layout().last_placement = placement
	}
	return layout_agent_push(&core.layout_agent, Layout({
		box = box,
		mode = mode,
		last_placement = placement,
	}))
}
pop_layout :: proc() {
	last_layout := current_layout()
	layout_agent_pop(&core.layout_agent)
	if core.layout_agent.stack.height > 0 {
		layout := current_layout()
		// Update placement settings
		placement = layout.last_placement
		// Apply extending layout cut
		if !last_layout.ignore_parent && core.layout_agent.stack.height > 0 {
			if last_layout.mode == .Extending {
				if side, ok := last_layout.side.?; ok {
					layout_cut_or_extend(layout, side, Exact(last_layout.box.w if int(side) > 1 else last_layout.box.h))	
				}
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
get_exact_margin :: proc(layout: ^Layout, side: Box_Side) -> Exact {
	return (placement.margin[side].(Exact) or_else Exact(f32(placement.margin[side].(Relative)) * (layout.box.w if int(side) > 1 else layout.box.h)))
}
get_layout_width :: proc(layout: ^Layout) -> Exact {
	return layout.box.w - get_exact_margin(layout, .Left) - get_exact_margin(layout, .Right)
}
get_layout_height :: proc(layout: ^Layout) -> Exact {
	return layout.box.h - get_exact_margin(layout, .Top) - get_exact_margin(layout, .Bottom)
}
// Add space
space :: proc(amount: Unit) {
	layout := current_layout()
	cut_box(&layout.box, placement.side, amount)
}
// Shrink the current layout (apply margin on all sides)
shrink :: proc(amount: Exact, loc := #caller_location) {
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
			case .Bottom: 	result = extend_box_bottom(&layout.box, size)
			case .Top: 			result = extend_box_top(&layout.box, size)
			case .Left: 		result = extend_box_left(&layout.box, size)
			case .Right: 		result = extend_box_right(&layout.box, size)
		}
	}
	return
}
// Get a box from a layout
layout_next_of_size :: proc(using self: ^Layout, size: Unit) -> (result: Box) {
	result = layout_cut_or_extend(self, placement.side, size)

	top := placement.margin[.Top].(Exact) 		or_else Exact(f32(placement.margin[.Top].(Relative)) * box.h)
	left := placement.margin[.Left].(Exact) 	or_else Exact(f32(placement.margin[.Left].(Relative)) * box.w)
	// Apply margins
	result = {
		result.x + left,
		result.y + top,
		result.w - left - (placement.margin[.Right].(Exact) or_else Exact(f32(placement.margin[.Right].(Relative)) * box.w)),
		result.h - top - (placement.margin[.Bottom].(Exact) or_else Exact(f32(placement.margin[.Bottom].(Relative)) * box.h)),
	}
	return
}
// Get the next box from a layout, according to the current placement settings
layout_next :: proc(using self: ^Layout) -> (result: Box) {
	assert(self != nil)
	result = layout_next_of_size(self, placement.size)
	// Set the last box
	core.last_box = result
	return
}
layout_next_child :: proc(using self: ^Layout, size: [2]f32) -> Box {
	assert(self != nil)
	return child_box(layout_next(self), size, placement.align)
}
layout_fit :: proc(layout: ^Layout, size: [2]f32) {
	if placement.side == .Left || placement.side == .Right {
		placement.size = size.x
	} else {
		placement.size = size.y
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
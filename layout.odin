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
	// Growing?
	grow: Maybe(Box_Side),
	// State
	box: Box,
	// Temporary placement settings
	last_placement: Placement_Info,
}

LAYOUT_STACK_SIZE :: 64

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
	if core.layout_agent.stack.height > 0 {
		current_layout().last_placement = placement
	}
	return layout_agent_push(&core.layout_agent, Layout({
		box = box,
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
	}
}
/*
	This creates a growing layout that cuts/grows the one below after use
*/
push_growing_layout :: proc(box: Box, side: Box_Side) -> ^Layout {
	layout := push_layout(box)
	layout.grow = side
	return layout
}
pop_growing_layout :: proc() {
	last_layout := current_layout()
	paint_box_stroke(last_layout.box, 1, {255, 0, 130, 255})
	layout_agent_pop(&core.layout_agent)
	if core.layout_agent.stack.height > 0 {
		layout := current_layout()
		// Update placement settings
		placement = layout.last_placement
		// Apply growing layout cut
		if grow, ok := last_layout.grow.?; ok {
			i := 1 - int(grow) / 2
			layout_cut_or_grow(layout, grow, Exact(last_layout.box.high[i] - last_layout.box.low[i]))	
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
get_exact_margin :: proc(l: ^Layout, side: Box_Side) -> Exact {
	return (placement.margin[side].(Exact) or_else Exact(f32(placement.margin[side].(Relative)) * ((l.box.high.x - l.box.low.x) if int(side) > 1 else (l.box.high.y - l.box.low.y))))
}
get_layout_width :: proc(l: ^Layout) -> Exact {
	return (l.box.high.x - l.box.low.x) - get_exact_margin(l, .Left) - get_exact_margin(l, .Right)
}
get_layout_height :: proc(l: ^Layout) -> Exact {
	return (l.box.high.y - l.box.low.y) - get_exact_margin(l, .Top) - get_exact_margin(l, .Bottom)
}
// Add space
space :: proc(amount: Unit) {
	layout_cut_or_grow(current_layout(), placement.side, amount)
}
// Shrink the current layout (apply margin on all sides)
shrink :: proc(amount: Exact, loc := #caller_location) {
	layout := current_layout(loc)
	if grow, ok := layout.grow.?; ok {
		#partial switch grow {
			case .Bottom: layout.box.high.y += amount * 2
		}
	} else {
		layout.box = shrink_box(layout.box, amount)
	}
}
/*
	Cut or grow if the layout permits
*/
layout_cut_or_grow :: proc(lt: ^Layout, side: Box_Side, amount: Unit) -> (result: Box) {
	// Get the base box
	if grow, ok := lt.grow.?; ok {
		if side == grow {
			result = grow_box(&lt.box, side, amount)
		} else {
			result = cut_box(&lt.box, side, amount)
		}
	} else {
		switch side {
			case .Bottom:		result = cut_box_bottom(&lt.box, amount)
			case .Top:			result = cut_box_top(&lt.box, amount)
			case .Left:			result = cut_box_left(&lt.box, amount)
			case .Right:		result = cut_box_right(&lt.box, amount)
		}
	}
	return
}
// Get a box from a layout
layout_next_of_size :: proc(lt: ^Layout, size: Unit) -> (res: Box) {
	res = layout_cut_or_grow(lt, placement.side, size)
	res.low += {get_exact_margin(lt, .Left), get_exact_margin(lt, .Top)}
	res.high -= {get_exact_margin(lt, .Right), get_exact_margin(lt, .Bottom)}
	return
}
// Get the next box from a layout, according to the current placement settings
layout_next :: proc(lt: ^Layout) -> (result: Box) {
	assert(lt != nil)
	result = layout_next_of_size(lt, placement.size)
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
/*
	Cut from the current layout and return the result
*/
cut :: proc(side: Box_Side, amount: Unit) -> (res: Box) {
	layout := current_layout()
	res = layout_cut_or_grow(layout, side, amount)
	return
}
/*
	Return what would be cut from the current layout
*/
fake_cut :: proc(side: Box_Side, amount: Unit) -> Box {
	layout := current_layout()
	return get_cut_box(layout.box, side, amount)
}

/*
	Context procedures
*/
@(deferred_out=_do_layout)
do_layout :: proc(side: Box_Side, size: Unit) -> (ok: bool) {
	box := layout_cut_or_grow(current_layout(), side, size)
	layout := push_layout(box)
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

@(deferred_out=_do_horizontal)
do_horizontal :: proc(size: Unit) -> (ok: bool) {
	box := cut(placement.side, size)
	layout := push_layout(box)
	placement.side = .Left
	return true
}
@private 
_do_horizontal :: proc(ok: bool) {
	if ok {
		pop_layout()
	}
}
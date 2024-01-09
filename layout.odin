package maui
import "core:fmt"

LAYOUT_STACK_SIZE :: 64
Alignment :: enum {
	Near,
	Middle,
	Far,
}
Direction :: enum {
	Down,
	Up,
	Right,
	Left,
}
Layout_Mode :: enum {
	Fixed,
	Extending,
}
Placement_Size :: union {
	f32,
	enum {
		Automatic,
		Fill,
	},
}
Placement_Info :: struct {
	direction: Direction,
	size: f32,
	align: [2]Alignment,
	margin: [Box_Side]f32,
}
// A `Layout` is a context for placing widgets and other layouts
Layout :: struct {
	using placement: Placement_Info,
	// Growing?
	grow: Maybe(Direction),
	// State
	original_box,
	box: Box,
}
Layout_Agent :: struct {
	stack: Stack(Layout, LAYOUT_STACK_SIZE),
	current_layout: ^Layout,
}
layout_agent_push :: proc(using self: ^Layout_Agent, layout: Layout) -> ^Layout {
	layout := layout
	layout.original_box = layout.box
	stack_push(&stack, layout)
	current_layout = &stack.items[stack.height - 1] if stack.height > 0 else nil
	return current_layout
}
layout_agent_pop :: proc(using self: ^Layout_Agent) {
	stack_pop(&stack)
	current_layout = &stack.items[stack.height - 1] if stack.height > 0 else nil
}

push_layout :: proc(ui: ^UI, box: Box) -> (layout: ^Layout) {
	return layout_agent_push(&ui.layouts, Layout({
		box = box,
		placement = current_layout(ui).placement if ui.layouts.stack.height > 0 else {},
	}))
}
pop_layout :: proc(ui: ^UI) {
	layout_agent_pop(&ui.layouts)
}
/*
	This creates a growing layout that cuts/grows the one below after use
*/
push_growing_layout :: proc(ui: ^UI, box: Box, direction: Direction) -> ^Layout {
	layout := push_layout(ui, box)
	layout.grow = direction
	return layout
}
pop_growing_layout :: proc(ui: ^UI) {
	last_layout := current_layout(ui)
	layout_agent_pop(&ui.layouts)
	if ui.layouts.stack.height > 0 {
		layout := current_layout(ui)
		// Apply growing layout cut
		if grow, ok := last_layout.grow.?; ok {
			i := 1 - int(grow) / 2
			layout_cut_or_grow(layout, grow, last_layout.box.high[i] - last_layout.box.low[i])	
		}
	}
}
// Get the current layout (asserts that there be one)
current_layout :: proc(ui: ^UI, loc := #caller_location) -> ^Layout {
	assert(ui.layouts.current_layout != nil, "No current layout", loc)
	return ui.layouts.current_layout
}
get_layout_width :: proc(layout: ^Layout) -> f32 {
	return (layout.box.high.x - layout.box.low.x) - layout.placement.margin[.Left] - layout.placement.margin[.Right]
}
get_layout_height :: proc(layout: ^Layout) -> f32 {
	return (layout.box.high.y - layout.box.low.y) - layout.placement.margin[.Top] - layout.placement.margin[.Bottom]
}
// Add space
space :: proc(ui: ^UI, amount: f32) {
	layout := current_layout(ui)
	layout_cut_or_grow(layout, layout.placement.direction, amount)
}
// Shrink the current layout (apply margin on all sides)
shrink :: proc(ui: ^UI, amount: f32, loc := #caller_location) {
	layout := current_layout(ui, loc)
	if grow, ok := layout.grow.?; ok {
		#partial switch grow {
			case .Down, .Up: 
			layout.box.low.y += amount
			layout.box.high.y += amount * 2
			case .Left, .Right:
			layout.box.low.x += amount
			layout.box.high.x += amount * 2
		}
	} else {
		layout.box = shrink_box(layout.box, amount)
	}
}
/*
	Cut or grow if the layout permits
*/
layout_cut_or_grow :: proc(layout: ^Layout, direction: Direction, amount: f32) -> (result: Box) {
	// Get the base box
	if grow, ok := layout.grow.?; ok && grow == direction {
		switch direction {
			case .Up:	
			layout.box.low.y = min(layout.box.low.y, layout.box.high.y - amount)
			case .Down:	
			layout.box.high.y = max(layout.box.high.y, layout.box.low.y + amount)
			case .Left:	
			layout.box.low.x = min(layout.box.low.x, layout.box.high.x - amount)
			case .Right:	
			layout.box.high.x = max(layout.box.high.x, layout.box.low.x + amount)
		}
	}
	switch direction {
		case .Down:		result = cut_box_top(&layout.box, amount)
		case .Up:			result = cut_box_bottom(&layout.box, amount)
		case .Left:		result = cut_box_right(&layout.box, amount)
		case .Right:	result = cut_box_left(&layout.box, amount)
	}
	return
}
// Get a box from a layout
layout_next_of_size :: proc(layout: ^Layout, size: f32) -> (res: Box) {
	res = layout_cut_or_grow(layout, layout.placement.direction, size)
	res.low += {layout.placement.margin[.Left], layout.placement.margin[.Top]}
	res.high -= {layout.placement.margin[.Right], layout.placement.margin[.Bottom]}
	return
}
// Get the next box from a layout, according to the current placement settings
layout_next :: proc(layout: ^Layout) -> Box {
	return layout_next_of_size(layout, layout.placement.size)
}
layout_next_child :: proc(layout: ^Layout, size: [2]f32) -> Box {
	return child_box(layout_next(layout), size, layout.placement.align)
}
layout_fit :: proc(layout: ^Layout, size: [2]f32) {
	if layout.placement.direction == .Left || layout.placement.direction == .Right {
		layout.placement.size = size.x
	} else {
		layout.placement.size = size.y
	}
}
/*
	Cut from the current layout and return the result
*/
cut :: proc(ui: ^UI, direction: Direction, amount: f32) -> (res: Box) {
	layout := current_layout(ui)
	res = layout_cut_or_grow(layout, direction, amount)
	return
}

/*
	Context procedures
*/
@(deferred_in_out=_do_layout)
do_layout :: proc(ui: ^UI, box: Box) -> (layout: ^Layout, ok: bool) {
	layout, ok = push_layout(ui, box), true
	return
}
@private 
_do_layout :: proc(ui: ^UI, _: Box, _: ^Layout, ok: bool) {
	if ok {
		pop_layout(ui)
	}
}

@(deferred_in_out=_do_growing_layout)
do_growing_layout :: proc(ui: ^UI, direction: Direction) -> (ok: bool) {
	layout := current_layout(ui)
	push_growing_layout(ui, layout.box, direction)
	return true
}
@private
_do_growing_layout :: proc(ui: ^UI, _: Direction, ok: bool) {
	if ok {
		pop_growing_layout(ui)
	}
}

@(deferred_in_out=_do_row)
do_row :: proc(ui: ^UI, divisions: int, spacing: f32 = 0) -> (ok: bool) {
	last_layout := current_layout(ui)
	box := cut(ui, last_layout.placement.direction, last_layout.placement.size)
	layout := push_layout(ui, box)
	layout.placement.direction = .Right
	layout.placement.size = width(layout.box) / max(f32(divisions), 1) - (spacing * f32(divisions - 1))
	return true
}
@private 
_do_row :: proc(ui: ^UI, _: int, _: f32, ok: bool) {
	if ok {
		pop_layout(ui)
	}
}
/*
	Generic getter of next box in the current layout based on the current placement info
*/
next_box :: proc(ui: ^UI, loc := #caller_location) -> Box {
	return layout_next(current_layout(ui, loc))
}
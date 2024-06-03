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

Placement :: struct {
	side: Box_Side,
	size: f32,
	align: [2]Alignment,
	margin: [Box_Side]f32,
}
Placement_Agent :: struct {
	stack: Stack(Placement, PLACEMENT_STACK_HEIGHT),
	current: ^Placement,
}

// A `Layout` is a context for placing widgets and other layouts
Layout :: struct {
	original_box,
	box: Box,
	direction: Maybe(Direction),
}
/*
	Agent for handling layouts
*/
Layout_Agent :: struct {
	stack: Stack(Layout, LAYOUT_STACK_SIZE),
	current: ^Layout,
}
push_layout :: proc(ui: ^UI, layout: Layout) -> ^Layout {
	push_placement(ui, ui.placement)
	layout := layout
	layout.original_box = layout.box
	stack_push(&ui.layouts.stack, layout)
	ui.layouts.current = &ui.layouts.stack.items[ui.layouts.stack.height - 1] if ui.layouts.stack.height > 0 else nil
	return ui.layouts.current
}

push_dividing_layout :: proc(ui: ^UI, box: Box) -> ^Layout {
	new_layout: Layout = {
		box = box,
	}
	return push_layout(ui, new_layout)
}

/*
	This creates a growing layout that cuts/grows the one below after use
*/
push_growing_layout :: proc(ui: ^UI, box: Box, direction: Direction) -> ^Layout {
	new_layout: Layout = {
		box = box,
		direction = direction,
	}
	return push_layout(ui, new_layout)
}
pop_layout :: proc(ui: ^UI) {
	if ui.layouts.current == nil {
		return
	}
	last_layout := ui.layouts.current
	if direction, ok := ui.layouts.current.direction.?; ok {
		layout := current_layout(ui)
		// Apply growing layout cut
		i := 1 - int(direction) / 2
		side: Box_Side
		switch direction {
			case .Down: side = .Top
			case .Left: side = .Right
			case .Right: side = .Left
			case .Up: side = .Bottom
		}
		layout_cut_or_grow(layout, side, last_layout.box.high[i] - last_layout.box.low[i])
	}
	pop_placement(ui)
	stack_pop(&ui.layouts.stack)
	ui.layouts.current = &ui.layouts.stack.items[ui.layouts.stack.height - 1] if ui.layouts.stack.height > 0 else nil
}
// Get the current layout (asserts that there be one)
current_layout :: proc(ui: ^UI, loc := #caller_location) -> ^Layout {
	assert(ui.layouts.current != nil, "No current layout", loc)
	return ui.layouts.current
}
// Add space
space :: proc(ui: ^UI, amount: f32) {
	layout := current_layout(ui)
	layout_cut_or_grow(layout, ui.placement.side, amount)
}
// Shrink the current layout (apply margin on all sides)
shrink :: proc(ui: ^UI, amount: f32, loc := #caller_location) {
	layout := current_layout(ui, loc)
	if direction, ok := layout.direction.?; ok {
		#partial switch direction {
			case .Up, .Down: 
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
layout_cut_or_grow :: proc(layout: ^Layout, side: Box_Side, amount: f32) -> (result: Box) {
	// Get the base box
	if direction, ok := layout.direction.?; ok && int(direction) == int(side) {
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
	switch side {
		case .Top:			result = cut_box_top(&layout.box, amount)
		case .Bottom:		result = cut_box_bottom(&layout.box, amount)
		case .Right:		result = cut_box_right(&layout.box, amount)
		case .Left:			result = cut_box_left(&layout.box, amount)
	}
	return
}
/*
	Cut from the current layout and return the result
*/
cut :: proc(ui: ^UI, side: Box_Side, amount: f32) -> (res: Box) {
	layout := current_layout(ui)
	res = layout_cut_or_grow(layout, side, amount)
	return
}
get_centered_box_x :: proc(ui: ^UI, width: f32) -> Box {
	box := current_layout(ui).box
	c := center_x(box)
	return {{c - width / 2, box.low.y}, {c + width / 2, box.high.y}}
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
		pop_layout(ui)
	}
}

@(deferred_in_out=_row)
row :: proc(ui: ^UI, divisions: int, spacing: f32 = 0) -> (ok: bool) {
	last_layout := current_layout(ui)
	box := cut(ui, ui.placement.side, ui.placement.size)
	layout := push_dividing_layout(ui, box)
	ui.placement.side = .Left
	ui.placement.size = width(layout.box) / max(f32(divisions), 1) - (spacing * f32(divisions - 1))
	return true
}
@private 
_row :: proc(ui: ^UI, _: int, _: f32, ok: bool) {
	if ok {
		pop_layout(ui)
	}
}

begin_row :: proc(ui: ^UI, side: Box_Side, size: f32, contents_side: Box_Side) {
	push_dividing_layout(ui, cut(ui, side, size))
	ui.placement.side = contents_side
}
end_row :: proc(ui: ^UI) {
	pop_layout(ui)
}
/*
	Generic getter of next box in the current layout based on the current placement info
*/
next_box :: proc(ui: ^UI) -> (box: Box) {
	assert(ui.layouts.current != nil)
	layout := ui.layouts.current

	box = layout_cut_or_grow(layout, ui.placement.side, ui.placement.size)
	box.low += {ui.placement.margin[.Left], ui.placement.margin[.Top]}
	box.high -= {ui.placement.margin[.Right], ui.placement.margin[.Bottom]}
	return
}
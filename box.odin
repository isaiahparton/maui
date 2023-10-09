package maui

import "core:math/linalg"

Box :: struct {
	low, high: [2]f32,
}

//NOTE: Never change order!
Box_Side :: enum {
	Top,
	Bottom,
	Left,
	Right,
}

Box_Sides :: bit_set[Box_Side;u8]

Box_Corner :: enum {
	Top_Left,
	Top_Right,
	Bottom_Right,
	Bottom_Left,
}

Box_Corners :: bit_set[Box_Corner;u8]

Clip :: enum {
	None,				// completely visible
	Partial,		// partially visible
	Full,				// hidden
}

width :: proc(box: Box) -> f32 {
	return box.high.x - box.low.x
}
height :: proc(box: Box) -> f32 {
	return box.high.y - box.low.y
}
center_x :: proc(box: Box) -> f32 {
	return (box.low.x + box.high.x) * 0.5
}
center_y :: proc(box: Box) -> f32 {
	return (box.low.y + box.high.y) * 0.5
}

// If `a` is inside of `b`
point_in_box :: proc(a: [2]f32, b: Box) -> bool {
	return (a.x >= b.low.x) && (a.x < b.high.x) && (a.y >= b.low.y) && (a.y < b.high.y)
}

// If `a` is touching `b`
box_vs_box :: proc(a, b: Box) -> bool {
	return (a.high.x >= b.low.x) && (a.low.x <= b.high.x) && (a.high.y >= b.low.y) && (a.low.y <= b.high.y)
}

// If `a` is contained entirely in `b`
box_in_box :: proc(a, b: Box) -> bool {
	return (b.low.x >= a.low.x) && (b.high.x <= a.high.x) && (b.low.y >= a.low.y) && (b.high.y <= a.high.y)
}

// Get the clip status of `b` inside `a`
get_clip :: proc(a, b: Box) -> Clip {
	if a.low.x > b.high.x || a.high.x < b.low.x ||
	   a.low.y > b.high.y || a.high.y < b.low.y { 
		return .Full 
	}
	if a.low.x >= b.low.x && a.high.x <= b.high.x &&
	   a.low.y >= b.low.y && a.high.y <= b.high.y { 
		return .None
	}
	return .Partial
}

// Updates `a` to fit `b` inside it
update_bounding_box :: proc(a, b: Box) -> Box {
	a := a
	a.low = linalg.min(a.low, b.low)
	a.high = linalg.max(a.high, b.high)
	return a
}

// Clamps `a` inside `b`
clamp_box :: proc(a, b: Box) -> Box {
	return {
		linalg.clamp(a.low, b.low, b.high),
		linalg.clamp(a.high, b.low, b.high),
	}
}

box_center :: proc(a: Box) -> [2]f32 {
	return {(a.low.x + a.high.x) * 0.5, (a.low.y + a.high.y) * 0.5}
}

center :: proc(box: Box) -> [2]f32 {
	return {(box.low.x + box.high.x) * 0.5, (box.low.y + box.high.y) * 0.5}
}

// Shrink a box by pushing one of its sides
squish_box_left :: proc(box: Box, amount: f32) -> Box {
	box := box 
	box.low.x += amount
	return box
}
squish_box_right :: proc(box: Box, amount: f32) -> Box {
	box := box 
	box.high.x -= amount
	return box
}
squish_box_top :: proc(box: Box, amount: f32) -> Box {
	box := box 
	box.low.y += amount
	return box
}
squish_box_bottom :: proc(box: Box, amount: f32) -> Box {
	box := box 
	box.high.y -= amount
	return box
}
squish_box :: proc(box: Box, side: Box_Side, amount: f32) -> (result: Box) {
	switch side {
		case .Bottom: result = squish_box_bottom(box, amount)
		case .Top: 		result = squish_box_top(box, amount)
		case .Left: 	result = squish_box_left(box, amount)
		case .Right: 	result = squish_box_right(box, amount)
	}
	return
}

child_box :: proc(b: Box, size: [2]f32, align: [2]Alignment) -> Box {
	a: Box
	switch align.x {
		case .Far:
		a.high.x = b.high.x
		a.low.x = b.high.x - size.x 
		case .Middle: 
		c := (b.low.x + b.high.x) * 0.5
		d := size.x * 0.5
		a.low.x = c - d
		a.high.x = c + d
		case .Near: 
		a.low.x = b.low.x
		a.high.x = b.low.x + size.x
	}
	switch align.y {
		case .Far:
		a.high.y = b.high.y
		a.low.y = b.high.y - size.y 
		case .Middle: 
		c := (b.low.y + b.high.y) * 0.5
		d := size.y * 0.5
		a.low.y = c - d
		a.high.y = c + d
		case .Near: 
		a.low.y = b.low.y
		a.high.y = b.low.y + size.y
	}
	return a
}

shrink_box_single :: proc(a: Box, amount: f32) -> Box {
	return {a.low + amount, a.high - amount}
}
shrink_box_double :: proc(a: Box, amount: [2]f32) -> Box {
	return {a.low + amount, a.high - amount}
}
shrink_box :: proc {
	shrink_box_single,
	shrink_box_double,
}

grow_box :: proc(a: Box, amount: f32) -> Box {
	return {a.low - amount, a.high + amount}
}

move_box :: proc(a: Box, delta: [2]f32) -> Box {
	return {a.low + delta, a.high + delta}
}

// cut a box and return the cut piece
cut_box_left :: proc(box: ^Box, amount: Unit) -> (res: Box) {
	w := box.high.x - box.low.x
	a := min(w, amount.(Exact) or_else Exact(f32(amount.(Relative)) * w))
	res = {box.low, {box.low.x + a, box.high.y}}
	box.low.x += a
	return
}
cut_box_top :: proc(box: ^Box, amount: Unit) -> (res: Box) {
	h := box.high.y - box.low.y
	a := min(h, amount.(Exact) or_else Exact(f32(amount.(Relative)) * h))
	res = {box.low, {box.high.x, box.low.y + a}}
	box.low.y += a
	return
}
cut_box_right :: proc(box: ^Box, amount: Unit) -> (res: Box) {
	w := box.high.x - box.low.x
	a := min(w, amount.(Exact) or_else Exact(f32(amount.(Relative)) * w))
	res = {{box.high.x - a, box.low.y}, box.high}
	box.high.x -= a
	return
}
cut_box_bottom :: proc(box: ^Box, amount: Unit) -> (res: Box) {
	h := box.high.y - box.low.y
	a := min(h, amount.(Exact) or_else Exact(f32(amount.(Relative)) * h))
	res = {{box.high.x, box.low.y - a}, box.high}
	box.high.y += a
	return
}
cut_box :: proc(box: ^Box, side: Box_Side, amount: Unit) -> Box {
	switch side {
		case .Bottom: 	return cut_box_bottom(box, amount)
		case .Top: 			return cut_box_top(box, amount)
		case .Left: 		return cut_box_left(box, amount)
		case .Right: 		return cut_box_right(box, amount)
	}
	return {}
}

// extend a box and return the attached piece
extend_box_left :: proc(box: ^Box, amount: Unit) -> (res: Box) {
	a := amount.(Exact) or_else Exact(f32(amount.(Relative)) * (box.high.x - box.low.x))
	box.low.x -= a
	res = {box.low, {box.low.x + a, box.high.y}}
	return
}
extend_box_top :: proc(box: ^Box, amount: Unit) -> (res: Box) {
	a := amount.(Exact) or_else Exact(f32(amount.(Relative)) * (box.high.y - box.low.y))
	box.low.y -= a
	res = {box.low, {box.high.x, box.low.y + a}}
	return
}
extend_box_right :: proc(box: ^Box, amount: Unit) -> (res: Box) {
	a := amount.(Exact) or_else Exact(f32(amount.(Relative)) * (box.high.x - box.low.x))
	box.high.x -= a 
	res = {{box.high.x - a, box.low.y}, box.high}
	return
}
extend_box_bottom :: proc(box: ^Box, amount: Unit) -> (res: Box) {
	a := amount.(Exact) or_else Exact(f32(amount.(Relative)) * (box.high.y - box.low.y))
	res = {{box.low.x, box.high.y}, {box.high.x, box.high.y + a}}
	box.high.y += a 
	return
}
extend_box :: proc(box: ^Box, side: Box_Side, amount: Unit) -> Box {
	switch side {
		case .Top: 			return extend_box_top(box, amount)
		case .Bottom: 	return extend_box_bottom(box, amount)
		case .Left: 		return extend_box_left(box, amount)
		case .Right: 		return extend_box_right(box, amount)
	}
	return {}
}

// get a cut piece of a box
get_box_left :: proc(b: Box, a: Unit) -> Box {
	return {b.low, {b.low.x + (a.(Exact) or_else Exact(f32(a.(Relative)) * (b.high.x - b.low.x))), b.high.y}}
}
get_box_top :: proc(b: Box, a: Unit) -> Box {
	return {b.low, {b.high.y, b.low.x + (a.(Exact) or_else Exact(f32(a.(Relative)) * (b.high.x - b.low.x)))}}
}
get_box_right :: proc(b: Box, a: Unit) -> Box {
	return {{b.high.x - (a.(Exact) or_else Exact(f32(a.(Relative)) * (b.high.x - b.low.x))), b.low.y}, b.high}
}
get_box_bottom :: proc(b: Box, a: Unit) -> Box {
	return {{b.low.x, b.high.y - (a.(Exact) or_else Exact(f32(a.(Relative)) * (b.high.y - b.low.y)))}, b.high}
}
get_cut_box :: proc(box: Box, side: Box_Side, amount: Unit) -> Box {
	switch side {
		case .Bottom: return get_box_bottom(box, amount)
		case .Top: 		return get_box_top(box, amount)
		case .Left: 	return get_box_left(box, amount)
		case .Right: 	return get_box_right(box, amount)
	}
	return {}
}

// attach a box
attach_box_left :: proc(box: Box, size: f32) -> Box {
	return {{box.low.x - size, box.low.y}, {box.low.x, box.high.y}}
}
attach_box_top :: proc(box: Box, size: f32) -> Box {
	return {{box.low.x, box.low.y - size}, {box.high.x, box.low.y}}
}
attach_box_right :: proc(box: Box, size: f32) -> Box {
	return {{box.high.x, box.low.y}, {box.high.x + size, box.high.y}}
}
attach_box_bottom :: proc(box: Box, size: f32) -> Box {
	return {{box.low.x, box.high.y}, {box.high.x, box.high.y + size}}
}
attach_box :: proc(box: Box, side: Box_Side, size: f32) -> Box {
	switch side {
		case .Bottom: 	return attach_box_bottom(box, size)
		case .Top: 			return attach_box_top(box, size)
		case .Left: 		return attach_box_left(box, size)
		case .Right: 		return attach_box_right(box, size)
	}
	return {}
}
side_corners :: proc(side: Box_Side) -> Box_Corners {
	switch side {
		case .Bottom:  	return {.Top_Left, .Top_Right}
		case .Top:  		return {.Bottom_Left, .Bottom_Right}
		case .Left:  		return {.Top_Right, .Bottom_Right}
		case .Right:  	return {.Top_Left, .Bottom_Left}
	}
	return ALL_CORNERS
}
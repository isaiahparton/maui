package maui
import "core:fmt"
Box :: struct {
	x, y, w, h: f32,
}
Box_Side :: enum {
	top,
	bottom,
	left,
	right,
}
Box_Sides :: bit_set[Box_Side;u8]
Box_Corner :: enum {
	top_left,
	top_right,
	bottom_right,
	bottom_left,
}
Box_Corners :: bit_set[Box_Corner;u8]

// Clamps a box to fit inside another
clamp_box :: proc(box, inside: Box) -> Box {
	box := box
	box.x = clamp(box.x, inside.x, inside.x + inside.w)
	box.y = clamp(box.y, inside.y, inside.y + inside.h)
	box.w = clamp(box.w, 0, inside.w - (box.x - inside.x))
	box.h = clamp(box.h, 0, inside.h - (box.y - inside.y))
	return box
}
box_center :: proc(box: Box) -> [2]f32 {
	return {box.x + box.w / 2, box.y + box.h / 2}
}
// Box manip
// Move the side of a boxangle
squish_box_left :: proc(box: Box, amount: f32) -> Box {
	return {box.x + amount, box.y, box.w - amount, box.h}
}
squish_box_right :: proc(box: Box, amount: f32) -> Box {
	return {box.x, box.y, box.w - amount, box.h}
}
squish_box_top :: proc(box: Box, amount: f32) -> Box {
	return {box.x, box.y + amount, box.w, box.h - amount}
}
squish_box_bottom :: proc(box: Box, amount: f32) -> Box {
	return {box.x, box.y, box.w, box.h - amount}
}
squish_box :: proc(box: Box, side: Box_Side, amount: f32) -> (result: Box) {
	switch side {
		case .bottom: 	result = squish_box_bottom(box, amount)
		case .top: 		result = squish_box_top(box, amount)
		case .left: 	result = squish_box_left(box, amount)
		case .right: 	result = squish_box_right(box, amount)
	}
	return
}
// place a box in a nother box
child_box :: proc(parent: Box, size: [2]f32, align: [2]Alignment) -> Box {
	box := Box{0, 0, size.x, size.y}
	if alignX == .near {
		box.x = parent.x
	} else if alignX == .middle {
		box.x = parent.x + parent.w / 2 - box.w / 2
	} else if alignX == .far {
		box.x = parent.x + parent.w - box.w
	}
	if alignY == .near {
		box.y = parent.y
	} else if alignY == .middle {
		box.y = parent.y + parent.h / 2 - box.h / 2
	} else if alignY == .far {
		box.y = parent.y + parent.h - box.h
	}
	return box
}
// shrink a box to its center
shrink_box :: proc(b: Box, a: f32) -> Box {
	return {b.x + a, b.y + a, b.w - a * 2, b.h - a * 2}
}
// cut a box and return the cut piece
box_cut_left :: proc(box: ^Box, amount: f32) -> (result: Box) {
	amount := min(box.w, amount)
	result = {box.x, box.y, amount, box.h}
	box.x += amount
	box.w -= amount
	return
}
box_cut_top :: proc(box: ^Box, amount: f32) -> (result: Box) {
	amount := min(box.h, amount)
	result = {box.x, box.y, box.w, amount}
	box.y += amount
	box.h -= amount
	return
}
box_cut_right :: proc(box: ^Box, amount: f32) -> (result: Box) {
	amount := min(box.w, amount)
	box.w -= amount
	result = {box.x + box.w, box.y, amount, box.h}
	return
}
box_cut_bottom :: proc(box: ^Box, amount: f32) -> (result: Box) {
	amount := min(box.h, amount)
	box.h -= amount
	result = {box.x, box.y + box.h, box.w, amount}
	return
}
box_cut :: proc(box: ^Box, side: Box_Side, amount: f32) -> Box {
	switch side {
		case .bottom: 	return box_cut_bottom(box, amount)
		case .top: 		return box_cut_top(box, amount)
		case .left: 	return box_cut_left(box, amount)
		case .right: 	return box_cut_right(box, amount)
	}
	return {}
}
// get a cut piece of a box
get_box_left :: proc(b: Box, a: f32) -> Box {
	return {b.x, b.y, a, b.h}
}
get_box_top :: proc(b: Box, a: f32) -> Box {
	return {b.x, b.y, b.w, a}
}
get_box_right :: proc(b: Box, a: f32) -> Box {
	return {b.x + b.w - a, b.y, a, b.h}
}
get_box_bottom :: proc(b: Box, a: f32) -> Box {
	return {b.x, b.y + b.h - a, b.w, a}
}
// attach a box
attach_box_left :: proc(box: Box, amount: f32) -> Box {
	return {box.x - amount, box.y, amount, box.h}
}
attach_box_top :: proc(box: Box, amount: f32) -> Box {
	return {box.x, box.y - amount, box.w, amount}
}
attach_box_right :: proc(box: Box, amount: f32) -> Box {
	return {box.x + box.w, box.y, amount, box.h}
}
attach_box_bottom :: proc(box: Box, amount: f32) -> Box {
	return {box.x, box.y + box.h, box.w, amount}
}
attach_box :: proc(box: Box, side: Box_Side, size: f32) -> Box {
	switch side {
		case .bottom: 	return attach_box_bottom(box, size)
		case .top: 		return attach_box_top(box, size)
		case .left: 	return attach_box_left(box, size)
		case .right: 	return attach_box_right(box, size)
	}
	return {}
}
side_corners :: proc(side: Box_Side) -> BoxCorners {
	switch side {
		case .bottom:  	return {.top_left, .top_right}
		case .top:  	return {.bottom_left, .bottom_right}
		case .left:  	return {.top_right, .bottom_right}
		case .right:  	return {.top_left, .bottom_left}
	}
	return ALL_CORNERS
}
point_in_box :: proc(v: [2]f32, r: Box) -> bool {
	return (v.x >= r.x) && (v.x <= r.x + r.w) && (v.y >= r.y) && (v.y <= r.y + r.h)
}
box_vs_box :: proc(a, b: Box) -> bool {
	return (a.x + a.w >= b.x) && (a.x <= b.x + b.w) && (a.y + a.h >= b.y) && (a.y <= b.y + b.h)
}
// B is contained entirely within A
box_in_box :: proc(a, b: Box) -> bool {
	return (b.x >= a.x) && (b.x + b.w <= a.x + a.w) && (b.y >= a.y) && (b.y + b.h <= a.y + a.h)
}
grow_box :: proc(box: Box, amount: f32) -> Box {
	return {box.x - amount, box.y - amount, box.w + amount * 2, box.h + amount * 2}
}
move_box :: proc(r: Box, v: [2]f32) -> Box {
	return {r.x + v.x, r.y + v.y, r.w, r.h}
}
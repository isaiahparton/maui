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

Clip :: enum {
	none,		// completely visible
	partial,	// partially visible
	full,		// hidden
}

get_clip :: proc(clip, subject: Box) -> Clip {
	if subject.x > clip.x + clip.w || subject.x + subject.w < clip.x ||
	   subject.y > clip.y + clip.h || subject.y + subject.h < clip.y { 
		return .full 
	}
	if subject.x >= clip.x && subject.x + subject.w <= clip.x + clip.w &&
	   subject.y >= clip.y && subject.y + subject.h <= clip.y + clip.h { 
		return .none
	}
	return .partial
}

update_bounding_box :: proc(bounds, subject: Box) -> Box {
	bounds := bounds
	bounds.x = min(bounds.x, subject.x)
	bounds.y = min(bounds.y, subject.y)
	bounds.w = max(bounds.w, (subject.x + subject.w) - bounds.x)
	bounds.h = max(bounds.h, (subject.y + subject.h) - bounds.y)
	return bounds
}

clamp_box :: proc(box, inside: Box) -> Box {
	box := box
	box.x = clamp(box.x, inside.x, inside.x + inside.w)
	box.y = clamp(box.y, inside.y, inside.y + inside.h)
	box.w = clamp(box.w, 0, inside.w - (box.x - inside.x))
	box.h = clamp(box.h, 0, inside.h - (box.y - inside.y))
	return box
}

clip_box :: proc(box, clip: Box) -> Box {
	box := box
	if box.x < clip.x {
    	delta := clip.x - box.x
    	box.w -= delta
    	box.x += delta
    }
    if box.y < clip.y {
    	delta := clip.y - box.y
    	box.h -= delta
    	box.y += delta
    }
    if box.x + box.w > clip.x + clip.w {
    	box.w = (clip.x + clip.w) - box.x
    }
    if box.y + box.h > clip.y + clip.h {
    	box.h = (clip.y + clip.h) - box.y
    }
    box.w = max(box.w, 0)
    box.h = max(box.h, 0)
    return box
}

box_center :: proc(box: Box) -> [2]f32 {
	return {box.x + box.w / 2, box.y + box.h / 2}
}

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

child_box :: proc(parent: Box, size: [2]f32, align: [2]Alignment) -> Box {
	box := Box{0, 0, size.x, size.y}
	if align.x == .near {
		box.x = parent.x
	} else if align.x == .middle {
		box.x = parent.x + parent.w / 2 - box.w / 2
	} else if align.x == .far {
		box.x = parent.x + parent.w - box.w
	}
	if align.y == .near {
		box.y = parent.y
	} else if align.y == .middle {
		box.y = parent.y + parent.h / 2 - box.h / 2
	} else if align.y == .far {
		box.y = parent.y + parent.h - box.h
	}
	return box
}

shrink_box_uniform :: proc(box: Box, amount: f32) -> Box {
	return {box.x + amount, box.y + amount, box.w - amount * 2, box.h - amount * 2}
}
shrink_box_separate :: proc(box: Box, amount: [2]f32) -> Box {
	return {box.x + amount.x, box.y + amount.y, box.w - amount.x * 2, box.h - amount.y * 2}
}
shrink_box :: proc {
	shrink_box_separate,
	shrink_box_uniform,
}
box_padding :: proc(box: Box, padding: [2]f32) -> Box {
	return {box.x + padding.x, box.y + padding.y, box.w - padding.x * 2, box.h - padding.y * 2}
}

grow_box :: proc(box: Box, amount: f32) -> Box {
	return {box.x - amount, box.y - amount, box.w + amount * 2, box.h + amount * 2}
}

move_box :: proc(box: Box, delta: [2]f32) -> Box {
	return {box.x + delta.x, box.y + delta.y, box.w, box.h}
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
get_box_cut :: proc(box: Box, side: Box_Side, amount: f32) -> Box {
	switch side {
		case .bottom: 	return get_box_bottom(box, amount)
		case .top: 		return get_box_top(box, amount)
		case .left: 	return get_box_left(box, amount)
		case .right: 	return get_box_right(box, amount)
	}
	return {}
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
side_corners :: proc(side: Box_Side) -> Box_Corners {
	switch side {
		case .bottom:  	return {.top_left, .top_right}
		case .top:  	return {.bottom_left, .bottom_right}
		case .left:  	return {.top_right, .bottom_right}
		case .right:  	return {.top_left, .bottom_left}
	}
	return ALL_CORNERS
}
point_in_box :: proc(point: [2]f32, box: Box) -> bool {
	return (point.x >= box.x) && (point.x <= box.x + box.w) && (point.y >= box.y) && (point.y <= box.y + box.h)
}
box_vs_box :: proc(box_a, box_b: Box) -> bool {
	return (box_a.x + box_a.w >= box_b.x) && (box_a.x <= box_b.x + box_b.w) && (box_a.y + box_a.h >= box_b.y) && (box_a.y <= box_b.y + box_b.h)
}
// B is contained entirely within A
box_in_box :: proc(box_a, box_b: Box) -> bool {
	return (box_b.x >= box_a.x) && (box_b.x + box_b.w <= box_a.x + box_a.w) && (box_b.y >= box_a.y) && (box_b.y + box_b.h <= box_a.y + box_a.h)
}
package maui
import "core:fmt"

Box :: struct {
	x, y, w, h: f32,
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
	None,		// completely visible
	Partial,	// partially visible
	Full,		// hidden
}

get_clip :: proc(clip, subject: Box) -> Clip {
	if subject.x > clip.x + clip.w || subject.x + subject.w < clip.x ||
	   subject.y > clip.y + clip.h || subject.y + subject.h < clip.y { 
		return .Full 
	}
	if subject.x >= clip.x && subject.x + subject.w <= clip.x + clip.w &&
	   subject.y >= clip.y && subject.y + subject.h <= clip.y + clip.h { 
		return .None
	}
	return .Partial
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
		case .Bottom: result = squish_box_bottom(box, amount)
		case .Top: 		result = squish_box_top(box, amount)
		case .Left: 	result = squish_box_left(box, amount)
		case .Right: 	result = squish_box_right(box, amount)
	}
	return
}

child_box :: proc(parent: Box, size: [2]f32, align: [2]Alignment) -> Box {
	box := Box{0, 0, size.x, size.y}
	if align.x == .Near {
		box.x = parent.x
	} else if align.x == .Middle {
		box.x = parent.x + parent.w / 2 - box.w / 2
	} else if align.x == .Far {
		box.x = parent.x + parent.w - box.w
	}
	if align.y == .Near {
		box.y = parent.y
	} else if align.y == .Middle {
		box.y = parent.y + parent.h / 2 - box.h / 2
	} else if align.y == .Far {
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
cut_box_left :: proc(box: ^Box, amount: Unit) -> (result: Box) {
	a := min(box.w, amount.(Points) or_else Pt(f32(amount.(Percent)) * 0.01 * box.w))
	result = {box.x, box.y, a, box.h}
	box.x += a
	box.w -= a
	return
}
cut_box_top :: proc(box: ^Box, amount: Unit) -> (result: Box) {
	a := min(box.h, amount.(Points) or_else Pt(f32(amount.(Percent)) * 0.01 * box.h))
	result = {box.x, box.y, box.w, a}
	box.y += a
	box.h -= a
	return
}
cut_box_right :: proc(box: ^Box, amount: Unit) -> (result: Box) {
	a := min(box.w, amount.(Points) or_else Pt(f32(amount.(Percent)) * 0.01 * box.w))
	box.w -= a
	result = {box.x + box.w, box.y, a, box.h}
	return
}
cut_box_bottom :: proc(box: ^Box, amount: Unit) -> (result: Box) {
	a := min(box.h, amount.(Points) or_else Pt(f32(amount.(Percent)) * 0.01 * box.h))
	box.h -= a
	result = {box.x, box.y + box.h, box.w, a}
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

// cut a box and return the cut piece
extend_box_left :: proc(box: ^Box, amount: f32) -> (result: Box) {
	box.x -= amount
	box.w += amount
	result = {box.x, box.y, amount, box.h}
	return
}
extend_box_top :: proc(box: ^Box, amount: f32) -> (result: Box) {
	box.y -= amount
	box.h += amount
	result = {box.x, box.y, box.w, amount}
	return
}
extend_box_right :: proc(box: ^Box, amount: f32) -> (result: Box) {
	result = {box.x + box.w, box.y, amount, box.h}
	box.w += amount
	return
}
extend_box_bottom :: proc(box: ^Box, amount: f32) -> (result: Box) {
	result = {box.x, box.y + box.h, box.w, amount}
	box.h += amount
	return
}
extend_box :: proc(box: ^Box, side: Box_Side, amount: f32) -> Box {
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
	return {b.x, b.y, a.(Points) or_else Pt(f32(a.(Percent)) * 0.01 * b.w), b.h}
}
get_box_top :: proc(b: Box, a: Unit) -> Box {
	return {b.x, b.y, b.w, a.(Points) or_else Pt(f32(a.(Percent)) * 0.01 * b.h)}
}
get_box_right :: proc(b: Box, a: Unit) -> Box {
	t := a.(Points) or_else Pt(f32(a.(Percent)) * 0.01 * b.w)
	return {b.x + b.w - t, b.y, t, b.h}
}
get_box_bottom :: proc(b: Box, a: Unit) -> Box {
	t := a.(Points) or_else Pt(f32(a.(Percent)) * 0.01 * b.h)
	return {b.x, b.y + b.h - t, b.w, t}
}
get_cut_box :: proc(box: Box, side: Box_Side, amount: Unit) -> Box {
	switch side {
		case .Bottom: 	return get_box_bottom(box, amount)
		case .Top: 		return get_box_top(box, amount)
		case .Left: 	return get_box_left(box, amount)
		case .Right: 	return get_box_right(box, amount)
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
		case .Bottom: 	return attach_box_bottom(box, size)
		case .Top: 		return attach_box_top(box, size)
		case .Left: 	return attach_box_left(box, size)
		case .Right: 	return attach_box_right(box, size)
	}
	return {}
}
side_corners :: proc(side: Box_Side) -> Box_Corners {
	switch side {
		case .Bottom:  	return {.Top_Left, .Top_Right}
		case .Top:  	return {.Bottom_Left, .Bottom_Right}
		case .Left:  	return {.Top_Right, .Bottom_Right}
		case .Right:  	return {.Top_Left, .Bottom_Left}
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
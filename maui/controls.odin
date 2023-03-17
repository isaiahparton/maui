package maui

import "core:fmt"
import "core:math"

/*
	Anything clickable/interactable
*/
Control_Bit :: enum {
	stayalive,
	active,
}
Control_Bits :: bit_set[Control_Bit]

Control_Option :: enum {
	hold_focus,
	draggable,
}
Control_Options :: bit_set[Control_Option]

Control_Status :: enum {
	hovered,
	focused,
	pressed,
	down,
	released,
	active,			// toggled state (combo box is expanded)
}
Control_State :: bit_set[Control_Status]

Control :: struct {
	id: Id,
	body: Rect,
	bits: Control_Bits,
	opts: Control_Options,
	state: Control_State,

	// animation
	t_hover, t_press, t_active: f32,
}

begin_control :: proc(id: Id, rect: Rect) -> (c: ^Control, ok: bool) {
	using state
	
	panel := current_panel()

	idx, found := panel.contents[id]
	if !found {
		idx = -1
		for i in 0 ..< MAX_CONTROLS {
			if !control_exists[i] {
				control_exists[i] = true
				controls[i] = {}
				idx = i32(i)
				panel.contents[id] = idx
				break
			}
		}
	}
	ok = idx >= 0
	if ok {
		c = &state.controls[idx]
		c.id = id
		c.body = rect
		c.state = {}
		c.bits += {.stayalive}
	}

	return
}
end_control :: proc() {

}

update_control :: proc(c: ^Control) {
	if state.disabled {
		return
	}

	// request hover status
	if vec_vs_rect(input.mouse_pos, c.body) {
		state.next_hover_id = c.id
		if state.panels[state.panel_idx].index >= state.panels[state.hovered_panel].index {
			// uh...
		}
	}

	// if hovered
	if state.hover_id == c.id {
		c.state += {.hovered}
		if mouse_pressed(.left) {
			state.press_id = c.id
		}
	} else if state.press_id == c.id {
		if .draggable in c.opts {
			if mouse_released(.left) {
				state.press_id = 0
			}
			//state.dragging = true
		} else if (.hold_focus not_in c.opts) {
			state.press_id = 0
		}
	}

	// focusing
	if state.press_id == c.id {
		if state.prev_press_id != c.id {
			c.state += {.pressed}
		}
		if mouse_released(.left) {
			c.state += {.released}
			state.press_id = 0
		} else {
			c.state += {.down}
		}
	}

	return
}

// Primitives??
//
//	| basic text 			| editable text 		| clickable

// Basic controls
//
// 	| button				| checkbox				| switch
// 	| text field			| spinner				| menu
// 	| slider				| range slider			| scroll bar

// Advanced controls
//
// 	| calendar			| color picker

@(deferred_out=_scoped_end_widget)
widget :: proc(loc := #caller_location) -> (ok: bool) {
	c, k := begin_control(hash_id(loc), next_control_rect())
	if !k {
		return
	}
	update_control(c)

	if vec_vs_rect(input.mouse_pos, c.body) {
		c.t_hover = min(1, c.t_hover + 7 * state.delta_time)
	} else {
		c.t_hover = max(0, c.t_hover - 7 * state.delta_time)
	}
	if .down in c.state {
		c.t_press = min(1, c.t_press + 9 * state.delta_time)
	} else {
		c.t_press = max(0, c.t_press - 9 * state.delta_time)
	}

	offset := -7 * c.t_hover
	if offset != 0 {
		draw_rect(c.body, color(1, 1))
	}
	c.body = rect_translate(c.body, {offset, offset})
	draw_rect(c.body, color(0, 1))
	draw_rect_lines(c.body, 2, color(1, 1))

	end_control()
	ok = true
	push_layout(c.body)

	return
}
_scoped_end_widget :: proc(ok: bool) {
	if ok {
		pop_layout()
	}
}

button :: proc(text: string, alt: bool, loc := #caller_location) -> (s: Control_State) {
	c, ok := begin_control(hash_id(loc), next_control_rect())
	if !ok {
		return
	}
	update_control(c)

	if .hovered in c.state {
		c.t_hover = min(1, c.t_hover + 6 * state.delta_time)
	} else {
		c.t_hover = max(0, c.t_hover - 6 * state.delta_time)
	}
	if .down in c.state {
		c.t_press = min(1, c.t_press + 9 * state.delta_time)
	} else {
		c.t_press = max(0, c.t_press - 9 * state.delta_time)
	}

	//a := i32(c.t_hover * 5)
	//c.body.x += a
	//c.body.w -= a * 2
	draw_rect(c.body, color(1 if alt else 0, 1))
	if c.t_hover > 0 {
		draw_rect_sweep(c.body, c.t_hover, color(3 if alt else 2, 1))
		draw_rect(c.body, color(1, 0.15 * c.t_press))
	}
	if !alt {
		draw_rect_lines(c.body, 2, color(1, 1))
	}
	draw_aligned_text(text, {c.body.x + c.body.w / 2, c.body.y + c.body.h / 2}, color(0 if alt else 1, 1), .middle, .middle)

	end_control()
	return
}

checkbox :: proc(value: ^bool, text: string, loc := #caller_location) -> (s: Control_State) {
	c, ok := begin_control(hash_id(loc), child_rect(next_control_rect(), {30, 30}, .near, .middle))
	if !ok {
		return
	}
	update_control(c)

	if .hovered in c.state {
		c.t_hover = min(1, c.t_hover + 6 * state.delta_time)
	} else {
		c.t_hover = max(0, c.t_hover - 6 * state.delta_time)
	}
	if .down in c.state {
		c.t_press = min(1, c.t_press + 9 * state.delta_time)
	} else {
		c.t_press = max(0, c.t_press - 9 * state.delta_time)
	}
	if value^ {
		c.t_active = min(1, c.t_active + 9 * state.delta_time)
	} else {
		c.t_active = max(0, c.t_active - 9 * state.delta_time)
	}

	//draw_rect(c.body, color(0, 1))
	if value^ {
		draw_rect(c.body, color(2, 1))
	}
	if c.t_hover > 0 {
		draw_rect(c.body, color(1, 0.15 * (c.t_hover + c.t_press)))
	}
	if c.t_active > 0 {
		draw_icon_ex(.check, {c.body.x + 15, c.body.y + 15}, c.t_active if value^ else (1 + (1 - c.t_active)), .middle, .middle, color(1, 1 if value^ else c.t_active))
	}
	draw_rect_lines(c.body, 2, color(1, 1))
	draw_aligned_text(text, {c.body.x + c.body.w + 5, c.body.y + c.body.h / 2}, color(1, 1), .near, .middle)

	if .released in c.state {
		value^ = !value^
	}

	end_control()
	return
}

toggle :: proc(value: ^bool, loc := #caller_location) -> (s: Control_State) {
	c, ok := begin_control(hash_id(loc), child_rect(next_control_rect(), {60, 30}, .near, .middle))
	if !ok {
		return
	}
	update_control(c)

	if .hovered in c.state {
		c.t_hover = min(1, c.t_hover + 6 * state.delta_time)
	} else {
		c.t_hover = max(0, c.t_hover - 6 * state.delta_time)
	}
	if .down in c.state {
		c.t_press = min(1, c.t_press + 9 * state.delta_time)
	} else {
		c.t_press = max(0, c.t_press - 9 * state.delta_time)
	}
	if value^ {
		c.t_active = min(1, c.t_active + 9 * state.delta_time)
	} else {
		c.t_active = max(0, c.t_active - 9 * state.delta_time)
	}

	baseline := c.body.y + 15
	thumb_center := Vector{c.body.x + 15 + c.t_active * 30, baseline}

	// body
	draw_rect({c.body.x + 15, c.body.y, c.body.w - 30, c.body.h}, color(2, 1))
	draw_circle_sector({c.body.x + 15, baseline}, 15, math.PI * 0.5, math.PI * 1.5, 6, color(2, 1))
	draw_circle_sector({c.body.x + 45, baseline}, 15, math.PI * 1.5, math.PI * 2.5, 6, color(2, 1))

	// thumb (switch part thingy)
	draw_circle(thumb_center, 15, color(0, 1))
	draw_ring(thumb_center, 13, 15, 12, color(1, 1))
	draw_ring(thumb_center, 6, 8, 12, color(1, 1))

	if .released in c.state {
		value^ = !value^
	}

	end_control()
	return
}

@(deferred_out=_scoped_end_menu)
menu :: proc(text: string, loc := #caller_location) -> (active: bool) {
	c, ok := begin_control(hash_id(loc), next_control_rect())
	if !ok {
		return
	}
	update_control(c)

	if .hovered in c.state {
		c.t_hover = min(1, c.t_hover + 6 * state.delta_time)
	} else {
		c.t_hover = max(0, c.t_hover - 6 * state.delta_time)
	}
	if .down in c.state {
		c.t_press = min(1, c.t_press + 9 * state.delta_time)
	} else {
		c.t_press = max(0, c.t_press - 9 * state.delta_time)
	}

	draw_rect(c.body, color(0, 1))
	if c.t_hover > 0 {
		draw_rect_sweep(c.body, c.t_hover, color(2, 1))
	}
	draw_rect_lines(c.body, 2, color(1, 1))
	draw_aligned_text(text, {c.body.x + c.body.w / 2, c.body.y + c.body.h / 2}, color(1, 1), .middle, .middle)

	end_control()
	return .active in c.bits
}
_scoped_end_menu :: proc(active: bool) {
	if active {
		end_panel()
	}
}
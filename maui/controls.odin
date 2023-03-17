package maui

import "core:fmt"

/*
	Anything clickable/interactable
*/
Control_Bit :: enum {
	stayalive,
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
	t_hover, t_press: f32,
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

buddy :: proc(text: string) -> (s: Control_State) {
	c, ok := begin_control(hash_id(text), next_control_rect())
	if !ok {
		return
	}
	update_control(c)

	if .hovered in c.state {
		c.t_hover = min(1, c.t_hover + 7 * state.delta_time)
	} else {
		c.t_hover = max(0, c.t_hover - 7 * state.delta_time)
	}
	if .down in c.state {
		c.t_press = min(1, c.t_press + 9 * state.delta_time)
	} else {
		c.t_press = max(0, c.t_press - 9 * state.delta_time)
	}

	offset := i32(f32(-5) * max(c.t_hover - c.t_press * c.t_hover, 0))
	if offset != 0 {
		draw_rect(c.body, color(1, 1))
	}
	draw_rect(rect_translate(c.body, {offset, offset}), color(2, 1))
	draw_aligned_text(text, {c.body.x + c.body.w / 2 + offset, c.body.y + c.body.h / 2 + offset}, color(1, 1), .middle, .middle)

	end_control()
	return
}

button :: proc(text: string) -> (s: Control_State) {
	c, ok := begin_control(hash_id(text), next_control_rect())
	if !ok {
		return
	}
	update_control(c)

	if .hovered in c.state {
		c.t_hover = min(1, c.t_hover + 5 * state.delta_time)
	} else {
		c.t_hover = max(0, c.t_hover - 5 * state.delta_time)
	}
	if .down in c.state {
		c.t_press = min(1, c.t_press + 9 * state.delta_time)
	} else {
		c.t_press = max(0, c.t_press - 9 * state.delta_time)
	}

	draw_rect(c.body, color(0, 1))
	draw_rect_lines(c.body, 2, color(1, 1))
	a := i32(f32(c.body.w) * c.t_hover)
	b := a + 20
	draw_quad(
		{clamp()}
	)

	//size := i32(c.t_hover * f32(c.body.h / 2))
	//draw_triangle({c.body.x, c.body.y}, {c.body.x, c.body.y + size}, {c.body.x + size, c.body.y}, color(1, 1))
	draw_aligned_text(text, {c.body.x + c.body.w / 2, c.body.y + c.body.h / 2}, color(1, 1), .middle, .middle)

	end_control()
	return
}

@(deferred_out=_scoped_end_menu)
menu :: proc(text: string, loc := #caller_location) -> (active: bool) {
	return
}
_scoped_end_menu :: proc(active: bool) {
	if active {
		end_panel()
	}
}
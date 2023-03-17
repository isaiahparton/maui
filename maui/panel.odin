package maui
/*
	Panels are the root of all gui

	Panels can be windows or just the entire screen, but you need a panel before anything else
	setup will look something like this:

	if panel("color_picker") {
		if layout(cut_top(50)) {
			cut_side(.left)
			if button("!#", .check) {
				
			}
		}
	}
*/
Panel_Bit :: enum {
	title,
	resizable,
	moveable,
	floating,
	stayalive,
}
Panel_Bits :: bit_set[Panel_Bit]
Panel :: struct {
	bits: Panel_Bits,
	index: i32,
	id: Id,
	body: Rect,
	contents: map[Id]i32,
}

Panel_Options :: struct {
	origin, size: AnyVector,
}

current_panel :: proc() -> ^Panel {
	using state
	return &panels[panel_idx]
}
get_panel :: proc(name: string) -> ^Panel {
	using state
	idx, ok := panel_pool[hash_id(name)]
	if ok {
		return &panels[idx]
	}
	return nil
}
create_or_get_panel :: proc(id: Id) -> ^Panel {
	using state
	idx, ok := panel_pool[id]
	if !ok {
		idx = -1
		for i in 0..<MAX_PANELS {
			if !panel_exists[i] {
				panel_exists[i] = false
				panels[i] = {}
				idx = i32(i)
				panel_pool[id] = idx
			}
		}
	}
	if idx >= 0 {
		return &panels[idx]
	}
	return nil
}
define_panel :: proc(name: string, opts: Panel_Options) {
	using state

	id := hash_id(name)
	panel := create_or_get_panel(id)
	if panel == nil {
		return
	}

	panel.body = {
		to_absolute(opts.origin.x, f32(size.x)),
		to_absolute(opts.origin.y, f32(size.y)),
		to_absolute(opts.size.x, f32(size.x)),
		to_absolute(opts.size.y, f32(size.y)),
	}
}
to_absolute :: proc(v: Value, f: f32 = 0) -> i32 {
	switch t in v {
		case Absolute:
		return t
		case Relative:
		return i32(t * f)
	}
	return 0
}

begin_panel :: proc(name: string) -> bool {
	using state

	id := hash_id(name)
	idx, ok := panel_pool[id]
	if !ok {
		for i in 0 ..< MAX_PANELS {
			if !panel_exists[i] {
				panel_exists[i] = true
				panels[i] = {}
			}
		}
	}

	panel_idx = idx
	panel := &panels[idx]

	push_layout(panel.body)
	draw_rect(panel.body, color(0, 1))
	draw_rect_lines(panel.body, 2, color(1, 1))

	return true
}
end_panel :: proc() {
	using state

	panel := current_panel()
	pop_layout()
}

@(deferred_out=_scoped_end_panel)
panel :: proc(name: string, closed: bool) -> (ok: bool) {
	return begin_panel(name)
}
@private
_scoped_end_panel :: proc(ok: bool) {
	if ok {
		end_panel()
	}
}
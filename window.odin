package maui
import "core:fmt"
import "core:math"

Window_Bit :: enum {
	stay_alive,
	initialized,
	resizing,
	moving,
	should_close,
	should_collapse,
	collapsed,
	// If the window has an extra layer for decoration
	decorated,
}
Window_Bits :: bit_set[Window_Bit]
Window_Option :: enum {
	// Removes all decoration
	undecorated,
	// Gives the window a title bar to move it
	title,
	// Lets the user resize the window
	resizable,
	// Disallows dragging
	static,
	// Shows a close button on the title bar
	closable,
	// Allows collapsing by right-click
	collapsable,
	// The window can't resize below its layout size
	fit_to_layout,
}
Window_Options :: bit_set[Window_Option]
Window :: struct {
	// Native stuff
	title: string,
	id: Id,
	options: Window_Options,
	bits: Window_Bits,
	// for resizing
	drag_side: Box_Side,
	drag_anchor: f32,
	// minimum layout size
	min_layout_size: [2]f32,

	// Main layer
	layer: ^Layer,
	// Decoration layer
	decor_layer: ^Layer,

	// Current occupying boxangle
	box, draw_box: Box,
	// Collapse
	how_collapsed: f32,
}

Window_Agent :: struct {
	list: 			[dynamic]^Window,
	pool: 			map[Id]^Window,
	// Window context stack
	stack: 			[WINDOW_STACK_SIZE]^Window,
	stack_height: 	int,
	// Current window
	current_window:	^Window,
}
current_window :: proc() -> ^Window {
	assert(core.window_agent.current_window != nil)
	return core.window_agent.current_window
}
window_agent_assert :: proc(using self: ^Window_Agent, id: Id) -> (window: ^Window, ok: bool) {
	window, ok = pool[id]
	if !ok {
		window, ok = window_agent_create(self, id)
	}
	assert(ok)
	assert(window != nil)
	return
}
window_agent_create :: proc(using self: ^Window_Agent, id: Id) -> (window: ^Window, ok: bool) {
	window = new(Window)
	window^ = {
		id = id,
	}
	append(&list, window)
	pool[id] = window
	ok = true
	return
}
window_agent_push :: proc(using self: ^Window_Agent, window: ^Window) {
	stack[stack_height] = window
	stack_height += 1
	current_window = window
}
window_agent_pop :: proc(using self: ^Window_Agent) {
	stack_height -= 1
	if stack_height > 0 {
		current_window = stack[stack_height - 1]
	} else {
		current_window = nil
	}
}
window_agent_step :: proc(using self: ^Window_Agent) {
	for window, i in &list {
		if .stay_alive in window.bits {
			window.bits -= {.stay_alive}
		} else {
			ordered_remove(&list, i)
			delete_key(&pool, window.id)
			free(window)
		}
	}
}
window_agent_destroy :: proc(using self: ^Window_Agent) {
	for entry in list {
		free(entry)
	}
	delete(list)
	delete(pool)
}

Window_Info :: struct {
	id: Maybe(Id),
	title: string,
	box: Box,
	layout_size: Maybe([2]f32),
	min_size: Maybe([2]f32),
	options: Window_Options,
	layer_options: Layer_Options,
}
@(deferred_out=_do_window)
do_window :: proc(info: Window_Info, loc := #caller_location) -> (ok: bool) {
	self: ^Window
	id := info.id.? or_else hash(loc)
	if self, ok = window_agent_assert(&core.window_agent, id); ok {
		window_agent_push(&core.window_agent, self)

		self.bits += {.stay_alive}
		
		// Initialize self
		if .initialized not_in self.bits {
			if info.box != {} {
				self.box = info.box
			}
		}
		self.options = info.options
		self.title = info.title
		self.min_layout_size = info.layout_size.? or_else self.min_layout_size
		
		if .should_collapse in self.bits {
			self.how_collapsed = min(1, self.how_collapsed + core.delta_time * 5)
		} else {
			self.how_collapsed = max(0, self.how_collapsed - core.delta_time * 5)
		}
		if self.how_collapsed >= 1 {
			self.bits += {.collapsed}
		} else {
			self.bits -= {.collapsed}
		}

		// Layer body
		self.draw_box = self.box
		self.draw_box.h -= ((self.draw_box.h - WINDOW_TITLE_SIZE) if .title in self.options else self.draw_box.h) * self.how_collapsed

		// Decoration layer
		if self.decor_layer, ok = begin_layer({
			box = self.draw_box,
			id = hash(rawptr(&self.id), size_of(Id)),
			order = .floating,
			shadow = Layer_Shadow_Info({
				offset = SHADOW_OFFSET,
				roundness = WINDOW_ROUNDNESS,
			}),
			options = {.no_scroll_y},
		}); ok {
			// Body
			if .collapsed not_in self.bits {
				paint_rounded_box_fill(self.draw_box, WINDOW_ROUNDNESS, get_color(.base))
			}
			// Draw title bar and get movement dragging
			if .title in self.options {
				title_box := cut(.top, WINDOW_TITLE_SIZE)
				// Draw title boxangle
				if .collapsed in self.bits {
					paint_rounded_box_fill(title_box, WINDOW_ROUNDNESS, get_color(.intense))
				} else {
					paint_rounded_box_corners_fill(title_box, WINDOW_ROUNDNESS, {.top_left, .top_right}, get_color(.intense))
				}
				// Title bar decoration
				baseline := title_box.y + title_box.h / 2
				text_offset := title_box.h * 0.25
				can_collapse := .collapsable in self.options || .collapsed in self.bits
				if can_collapse {
					paint_rotating_arrow({title_box.x + title_box.h / 2, baseline}, 8, self.how_collapsed, get_color(.base))
					text_offset = title_box.h
				}
				paint_aligned_string(get_font_data(.default), self.title, {title_box.x + text_offset, baseline}, get_color(.base), {.near, .middle})
				if .closable in self.options {
					set_next_box(child_box(get_box_right(title_box, title_box.h), {24, 24}, {.middle, .middle}))
					if do_button({
						label = Icon.Close, 
						align = .middle,
					}) {
						self.bits += {.should_close}
					}
				}
				if .resizing not_in self.bits && core.layer_agent.hover_id == self.decor_layer.id && point_in_box(input.mouse_point, title_box) {
					if .static not_in self.options && core.widget_agent.hover_id == 0 && mouse_pressed(.left) {
						self.bits += {.moving}
						core.drag_anchor = ([2]f32){self.decor_layer.box.x, self.decor_layer.box.y} - input.mouse_point
					}
					if can_collapse && mouse_pressed(.right) {
						if .should_collapse in self.bits {
							self.bits -= {.should_collapse}
						} else {
							self.bits += {.should_collapse}
						}
					}
				}
			} else {
				self.bits -= {.should_collapse}
			}
		}
		
		inner_box := self.draw_box
		box_cut(&inner_box, .top, WINDOW_TITLE_SIZE)

		if .initialized not_in self.bits {
			self.min_layout_size = {inner_box.w, inner_box.h}
			self.bits += {.initialized}
		}

		layer_options := info.layer_options + {.attached}
		if (self.how_collapsed > 0 && self.how_collapsed < 1) || (self.how_collapsed == 1 && .should_collapse not_in self.bits) {
			layer_options += {.force_clip, .no_scroll_y}
			core.paint_next_frame = true
		}

		// Push layout if necessary
		if .collapsed in self.bits {
			ok = false
		} else {
			self.layer, ok = begin_layer({
				box = inner_box,
				inner_box = shrink_box(inner_box, 10),
				id = id, 
				options = layer_options,
				layout_size = self.min_layout_size,
				order = .background,
			})
		}

		// Get resize click
		if .resizable in self.options && self.decor_layer.state >= {.hovered} && .collapsed not_in self.bits {
			RESIZE_MARGIN :: 5
			top_hover 		:= point_in_box(input.mouse_point, get_box_top(self.box, RESIZE_MARGIN))
			left_hover 		:= point_in_box(input.mouse_point, get_box_left(self.box, RESIZE_MARGIN))
			bottom_hover 	:= point_in_box(input.mouse_point, get_box_bottom(self.box, RESIZE_MARGIN))
			right_hover 	:= point_in_box(input.mouse_point, get_box_right(self.box, RESIZE_MARGIN))
			if top_hover || bottom_hover {
				core.cursor = .resize_NS
				core.widget_agent.hover_id = 0
			}
			if left_hover || right_hover {
				core.cursor = .resize_EW
				core.widget_agent.hover_id = 0
			}
			if mouse_pressed(.left) {
				if top_hover {
					self.bits += {.resizing}
					self.drag_side = .top
					self.drag_anchor = self.box.y + self.box.h
				} else if left_hover {
					self.bits += {.resizing}
					self.drag_side = .left
					self.drag_anchor = self.box.x + self.box.w
				} else if bottom_hover {
					self.bits += {.resizing}
					self.drag_side = .bottom
				} else if right_hover {
					self.bits += {.resizing}
					self.drag_side = .right
				}
			}
		}
	}
	return
}
@private
_do_window :: proc(ok: bool) {
	if true {
		using self := current_window()
		window_agent_pop(&core.window_agent)
		// End main layer
		if .collapsed not_in bits {
			// Outline
			paint_rounded_box_stroke(self.draw_box, WINDOW_ROUNDNESS, true, get_color(.base_stroke))
			end_layer(layer)
		}
		paint_rounded_box_stroke(self.draw_box, WINDOW_ROUNDNESS, true, get_color(.base_stroke))
		// End decor layer
		end_layer(decor_layer)
		// Handle movement
		if .moving in bits {
			core.cursor = .resize_all
			new_origin := input.mouse_point + core.drag_anchor
			box.x = clamp(new_origin.x, 0, core.fullscreen_box.w - box.w)
			box.y = clamp(new_origin.y, 0, core.fullscreen_box.h - box.h)
			if mouse_released(.left) {
				bits -= {.moving}
			}
		}
		// Handle resizing
		WINDOW_SNAP_DISTANCE :: 10
		if .resizing in bits {
			min_size: [2]f32 = self.min_layout_size if .fit_to_layout in self.options else {180, 240}
			switch drag_side {
				case .bottom:
				anchor := input.mouse_point.y
				for other in &core.window_agent.list {
					if other != self {
						if abs(input.mouse_point.y - other.box.y) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.y
						}
					}
				}
				self.box.h = anchor - box.y
				core.cursor = .resize_NS

				case .left:
				anchor := input.mouse_point.x
				for other in &core.window_agent.list {
					if other != self {
						if abs(input.mouse_point.x - (other.box.x + other.box.w)) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.x + other.box.w
						}
					}
				}
				self.box.x = min(anchor, self.drag_anchor - min_size.x)
				self.box.w = self.drag_anchor - anchor
				core.cursor = .resize_EW

				case .right:
				anchor := input.mouse_point.x
				for other in &core.window_agent.list {
					if other != self {
						if abs(input.mouse_point.x - other.box.x) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.x
						}
					}
				}
				self.box.w = anchor - box.x
				core.cursor = .resize_EW

				case .top:
				anchor := input.mouse_point.y
				for other in &core.window_agent.list {
					if other != self {
						if abs(input.mouse_point.y - (other.box.y + other.box.h)) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.y + other.box.h
						}
					}
				}
				self.box.y = min(anchor, self.drag_anchor - min_size.y)
				self.box.h = self.drag_anchor - anchor
				core.cursor = .resize_NS
			}
			self.box.w = max(self.box.w, min_size.x)
			self.box.h = max(self.box.h, min_size.y)
			if mouse_released(.left) {
				self.bits -= {.resizing}
			}
		}
	}
}
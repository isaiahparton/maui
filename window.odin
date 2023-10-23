package maui

import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"

Window_Bit :: enum {
	Stay_Alive,
	Initialized,
	Resizing,
	Moving,
	Should_Close,
	Should_Collapse,
	Collapsed,
	// If the window has an extra layer for decoration
	Decorated,
}
Window_Bits :: bit_set[Window_Bit]
Window_Option :: enum {
	// Removes all decoration
	Undecorated,
	// Gives the window a title bar to move it
	Title,
	// Lets the user resize the window
	Resizable,
	// Disallows dragging
	Static,
	// Shows a close button on the title bar
	Closable,
	// Allows collapsing by right-click
	Collapsable,
	// The window can't resize below its layout size
	Fit_To_Layout,
}
Window_Options :: bit_set[Window_Option]
Window :: struct {
	// Native stuff
	title: string,
	id: Id,
	options: Window_Options,
	bits: Window_Bits,
	// for Resizing
	drag_side: Box_Side,
	// minimum layout size
	min_layout_size: [2]f32,

	// Main layer
	layer: ^Layer,
	// Decoration layer
	decor_layer: ^Layer,

	// Current occupying boxangle
	box, draw_box: Box,
	// Collapse
	opacity,
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
		if .Stay_Alive in window.bits {
			window.bits -= {.Stay_Alive}
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

		self.bits += {.Stay_Alive}
		
		// Initialize self
		if .Initialized not_in self.bits {
			if info.box != {} {
				self.box = info.box
			}
		}
		self.options = info.options
		self.title = info.title
		self.min_layout_size = info.layout_size.? or_else self.min_layout_size
		
		if .Should_Collapse in self.bits {
			self.how_collapsed = min(1, self.how_collapsed + core.delta_time * 5)
		} else {
			self.how_collapsed = max(0, self.how_collapsed - core.delta_time * 5)
		}
		if self.how_collapsed >= 1 {
			self.bits += {.Collapsed}
		} else {
			self.bits -= {.Collapsed}
		}

		// Layer body
		self.draw_box = self.box
		self.draw_box.high.y -= ((height(self.draw_box) - style.layout.title_size) if .Title in self.options else height(self.draw_box)) * ease.quadratic_in(self.how_collapsed)

		// Decoration layer
		if self.decor_layer, ok = begin_layer({
			placement = self.draw_box,
			id = hash(rawptr(&self.id), size_of(Id)),
			order = .Floating,
			options = {.No_Scroll_Y},
			opacity = self.opacity,
		}); ok {
			// Draw title bar and get movement dragging
			if .Title in self.options {
				title_box := cut(.Top, Exact(style.layout.title_size))
				// Draw title
				paint_shaded_box(shrink_box(title_box, 1), {style.color.extrusion_light, style.color.extrusion, style.color.extrusion_dark})
				if .Closable in self.options {
					// Close button
					if self, _ok := do_widget(hash(&self.id, size_of(Id))); _ok {
						self.box = get_box_right(title_box, height(title_box))
						update_widget(self)
						hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
						paint_box_fill(self.box, fade({230, 56, 65, 255}, hover_time))
						paint_cross(box_center(self.box), 7, math.PI * 0.25, 2, style.color.base_stroke)
						update_widget_hover(self, point_in_box(input.mouse_point, self.box))
					}
				}
				// Title bar decoration
				baseline := center_y(title_box)
				text_offset := height(title_box) * 0.25
				can_collapse := (.Collapsable in self.options) || (.Collapsed in self.bits)
				// Collapsing arrow
				if can_collapse {
					paint_arrow({title_box.low.x + height(title_box) / 2, baseline}, 6, math.PI * -0.5 * self.how_collapsed, 1, style.color.base_stroke)
					text_offset = height(title_box)
				}
				paint_text(
					{title_box.low.x + text_offset, baseline}, 
					{text = self.title, font = style.font.label, size = style.text_size.label}, 
					{align = .Left, baseline = .Middle}, 
					color = style.color.text,
				)
				if (.Hovered in self.decor_layer.state) && (.Resizing not_in self.bits) && point_in_box(input.mouse_point, title_box) {
					if (.Static not_in self.options) && (core.widget_agent.hover_id == 0) && mouse_pressed(.Left) {
						self.bits += {.Moving}
						core.drag_anchor = self.decor_layer.box.low - input.mouse_point
					}
					if can_collapse && mouse_pressed(.Right) {
						if .Should_Collapse in self.bits {
							self.bits -= {.Should_Collapse}
						} else {
							self.bits += {.Should_Collapse}
						}
					}
				}
				paint_box_stroke(title_box, 1, style.color.base_stroke)
			} else {
				self.bits -= {.Should_Collapse}
			}
		}
		
		inner_box := self.draw_box
		cut_box(&inner_box, .Top, Exact(style.layout.title_size))

		if .Initialized not_in self.bits {
			self.min_layout_size = inner_box.high - inner_box.low
			self.bits += {.Initialized}
		}

		layer_options := info.layer_options + {.Attached}
		if (self.how_collapsed > 0 && self.how_collapsed < 1) || (self.how_collapsed == 1 && .Should_Collapse not_in self.bits) {
			layer_options += {.Force_Clip, .No_Scroll_Y}
			core.paint_next_frame = true
		}

		// Push layout if necessary
		if .Collapsed in self.bits {
			ok = false
		} else {
			self.layer, ok = begin_layer({
				placement = inner_box,
				id = id, 
				options = layer_options,
				space = self.min_layout_size,
				order = .Background,
				opacity = self.opacity,
			})
			paint_shaded_box(shrink_box(self.layer.box, 1), {style.color.base_light, style.color.base, style.color.base_dark})
		}

		if .Moving in self.bits {
			self.opacity += (0.75 - self.opacity) * core.delta_time * 10
		} else {
			self.opacity += (1 - self.opacity) * core.delta_time * 10
		}
		if self.opacity > 0 && self.opacity < 1 {
			core.paint_next_frame = true
		}

		// Get resize click
		if .Resizable in self.options && self.decor_layer.state >= {.Hovered} && .Collapsed not_in self.bits {
			RESIZE_MARGIN :: 5
			top_hover 		:= point_in_box(input.mouse_point, get_box_top(self.box, Exact(RESIZE_MARGIN)))
			left_hover 		:= point_in_box(input.mouse_point, get_box_left(self.box, Exact(RESIZE_MARGIN)))
			bottom_hover 	:= point_in_box(input.mouse_point, get_box_bottom(self.box, Exact(RESIZE_MARGIN)))
			right_hover 	:= point_in_box(input.mouse_point, get_box_right(self.box, Exact(RESIZE_MARGIN)))
			if top_hover || bottom_hover {
				core.cursor = .Resize_NS
				core.widget_agent.hover_id = 0
			}
			if left_hover || right_hover {
				core.cursor = .Resize_EW
				core.widget_agent.hover_id = 0
			}
			if mouse_pressed(.Left) {
				if top_hover {
					self.bits += {.Resizing}
					self.drag_side = .Top
				} else if left_hover {
					self.bits += {.Resizing}
					self.drag_side = .Left
				} else if bottom_hover {
					self.bits += {.Resizing}
					self.drag_side = .Bottom
				} else if right_hover {
					self.bits += {.Resizing}
					self.drag_side = .Right
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
		if .Collapsed not_in bits {
			// Outline
			paint_box_stroke(layer.box, 1, style.color.base_stroke)
			end_layer(layer)
		}
		// End decor layer
		end_layer(decor_layer)
		// Handle movement
		if .Moving in bits {
			core.cursor = .Resize
			origin := input.mouse_point + core.drag_anchor
			size := box.high - box.low
			box.low = linalg.clamp(origin, 0, core.size - size)
			box.high = box.low + size
			if mouse_released(.Left) {
				bits -= {.Moving}
			}
		}
		// Handle Resizing
		WINDOW_SNAP_DISTANCE :: 10
		if .Resizing in bits {
			min_size: [2]f32 = self.min_layout_size if .Fit_To_Layout in self.options else {180, 240}
			switch drag_side {
				case .Bottom:
				anchor := input.mouse_point.y
				for other in &core.window_agent.list {
					if other != self {
						if abs(input.mouse_point.y - other.box.low.y) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.low.y
						}
					}
				}
				self.box.high.y = anchor
				core.cursor = .Resize_NS

				case .Left:
				anchor := input.mouse_point.x
				for other in &core.window_agent.list {
					if other != self {
						if abs(input.mouse_point.x - other.box.high.x) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.high.x
						}
					}
				}
				self.box.low.x = anchor
				core.cursor = .Resize_EW

				case .Right:
				anchor := input.mouse_point.x
				for other in &core.window_agent.list {
					if other != self {
						if abs(input.mouse_point.x - other.box.low.x) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.low.x
						}
					}
				}
				self.box.high.x = anchor
				core.cursor = .Resize_EW

				case .Top:
				anchor := input.mouse_point.y
				for other in &core.window_agent.list {
					if other != self {
						if abs(input.mouse_point.y - other.box.high.y) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.high.y
						}
					}
				}
				self.box.low.y = anchor
				core.cursor = .Resize_NS
			}
			self.box.high = linalg.max(self.box.high, self.box.low + min_size)
			if mouse_released(.Left) {
				self.bits -= {.Resizing}
			}
		}
	}
}
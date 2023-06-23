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
	options: Window_Optionss,
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

	// Current occupying rectangle
	box, draw_box: Box,
	// Collapse
	how_collapsed: f32,
}

Window_Info :: struct {
	title: string,
	rect: Box,
	layout_size: Maybe([2]f32),
	min_size: Maybe([2]f32),
	options: Window_Optionss,
	layer_options: Layer_Options,
}
@(deferred_out=_window)
window :: proc(info: Window_Info, loc := #caller_location) -> (ok: bool) {
	self: ^Window
	id := hash(loc)
	if self, ok = create_or_get_window(id); ok {
		core.current_window = self
		self.bits += {.stayAlive}
		
		// Initialize self
		if .initialized not_in self.bits {
			if info.rect != {} {
				self.rect = info.rect
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
		self.draw_box = self.rect
		self.draw_box.h -= ((self.draw_box.h - WINDOW_TITLE_SIZE) if .title in self.options else self.draw_box.h) * self.how_collapsed

		// Decoration layer
		if self.decor_layer, ok = begin_layer({
			rect = self.draw_box,
			id = hash(rawptr(&self.id), size_of(Id)),
			order = .floating,
			options = {.shadow},
		}); ok {
			// Body
			if .collapsed not_in self.bits {
				paint_rounded_box_fill(self.draw_box, WINDOW_ROUNDNESS, get_color(.base))
			}
			// Draw title bar and get movement dragging
			if .title in self.options {
				title_box := Cut(.top, WINDOW_TITLE_SIZE)
				// Draw title rectangle
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
				paint_aligned_string(GetFontData(.default), self.title, {title_box.x + text_offset, baseline}, get_color(.base), {.near, .middle})
				if .closable in self.options {
					set_next_box(child_box(get_box_right(title_box, title_box.h), {24, 24}, .middle, .middle))
					if button({
						label = Icon.close, 
						align = .middle,
					}) {
						self.bits += {.should_close}
					}
				}
				if .resizing not_in self.bits && core.hovered_layer == self.decor_layer.id && point_in_box(input.mouse_point, title_box) {
					if .static not_in self.options && core.hover_id == 0 && mouse_pressed(.left) {
						self.bits += {.moving}
						core.drag_anchor = ([2]f32){self.decor_layer.rect.x, self.decor_layer.rect.y} - input.mouse_point
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
				rect = inner_box,
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
			top_hover 		:= point_in_box(input.mouse_point, get_box_top(self.rect, RESIZE_MARGIN))
			left_hover 		:= point_in_box(input.mouse_point, get_box_left(self.rect, RESIZE_MARGIN))
			bottom_hover 	:= point_in_box(input.mouse_point, get_box_bottom(self.rect, RESIZE_MARGIN))
			right_hover 	:= point_in_box(input.mouse_point, get_box_right(self.rect, RESIZE_MARGIN))
			if top_hover || bottom_hover {
				core.cursor = .resize_ns
				core.hover_id = 0
			}
			if left_hover || right_hover {
				core.cursor = .resize_ew
				core.hover_id = 0
			}
			if mouse_pressed(.left) {
				if top_hover {
					self.bits += {.resizing}
					self.drag_side = .top
					self.drag_anchor = self.rect.y + self.rect.h
				} else if left_hover {
					self.bits += {.resizing}
					self.drag_side = .left
					self.drag_anchor = self.rect.x + self.rect.w
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
_window :: proc(ok: bool) {
	if true {
		using self := core.current_window
		// End main layer
		if .collapsed not_in bits {
			// Outline
			paint_rounded_box_stroke(self.draw_box, WINDOW_ROUNDNESS, true, get_color(.baseStroke))
			end_layer(layer)
		}
		paint_rounded_box_stroke(self.draw_box, WINDOW_ROUNDNESS, true, get_color(.baseStroke))
		// End decor layer
		end_layer(decor_layer)
		// Handle movement
		if .moving in bits {
			core.cursor = .resize_all
			new_origin := input.mouse_point + core.drag_anchor
			rect.x = new_origin.x
			rect.y = new_origin.y
			if mouse_released(.left) {
				bits -= {.moving}
			}
		}
		// Handle resizing
		WINDOW_SNAP_DISTANCE :: 10
		if .resizing in bits {
			minSize: [2]f32 = self.min_layout_size if .fitToLayout in self.options else {180, 240}
			switch drag_side {
				case .bottom:
				anchor := input.mouse_point.y
				for other in &core.windows {
					if other != self {
						if abs(input.mouse_point.y - other.rect.y) < WINDOW_SNAP_DISTANCE {
							anchor = other.rect.y
						}
					}
				}
				self.rect.h = anchor - rect.y
				core.cursor = .resize_ns

				case .left:
				anchor := input.mouse_point.x
				for other in &core.windows {
					if other != self {
						if abs(input.mouse_point.x - (other.rect.x + other.rect.w)) < WINDOW_SNAP_DISTANCE {
							anchor = other.rect.x + other.rect.w
						}
					}
				}
				self.rect.x = min(anchor, self.drag_anchor - minSize.x)
				self.rect.w = self.drag_anchor - anchor
				core.cursor = .resize_ew

				case .right:
				anchor := input.mouse_point.x
				for other in &core.windows {
					if other != self {
						if abs(input.mouse_point.x - other.rect.x) < WINDOW_SNAP_DISTANCE {
							anchor = other.rect.x
						}
					}
				}
				self.rect.w = anchor - rect.x
				core.cursor = .resize_ew

				case .top:
				anchor := input.mouse_point.y
				for other in &core.windows {
					if other != self {
						if abs(input.mouse_point.y - (other.rect.y + other.rect.h)) < WINDOW_SNAP_DISTANCE {
							anchor = other.rect.y + other.rect.h
						}
					}
				}
				self.rect.y = min(anchor, self.drag_anchor - minSize.y)
				self.rect.h = self.drag_anchor - anchor
				core.cursor = .resize_ns
			}
			self.rect.w = max(self.rect.w, minSize.x)
			self.rect.h = max(self.rect.h, minSize.y)
			if mouse_released(.left) {
				self.bits -= {.resizing}
			}
		}
	}
}


current_window :: proc() -> ^Window {
	return core.current_window
}
create_or_get_window :: proc(id: Id) -> (self: ^Window, ok: bool) {
	self, ok = core.window_map[id]
	if !ok {
		self, ok = create_window(id)
	}
	return
}
create_window :: proc(id: Id) -> (self: ^Window, ok: bool) {
	self = new(Window)
	self^ = {
		id = id,
	}
	append(&core.windows, self)
	core.window_map[id] = self
	ok = true
	return
}
window_destroy :: proc(self: ^Window) {
	free(self)
}
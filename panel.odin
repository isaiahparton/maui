package maui

import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:runtime"

Panel_Bit :: enum {
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
Panel_Bits :: bit_set[Panel_Bit]

Panel_Option :: enum {
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
Panel_Options :: bit_set[Panel_Option]

Panel :: struct {
	// Unique hashed identifier
	id: Id,
	// Options
	options: Panel_Options,
	// Bits
	bits: Panel_Bits,
	// For resizing
	drag_side: Box_Side,
	// minimum layout size
	min_layout_size: [2]f32,
	// Position
	origin, size: [2]f32,
	// Layers
	root_layer,
	content_layer: Maybe(^Layer),
	// Uncollapsed box
	real_box,
	// Current occupied box
	box: Box,
	// Collapse
	how_collapsed: f32,
	// Attachments
	attachments: [Box_Side]Maybe(Id),
}

MAX_PANELS :: 128
PANEL_STACK_SIZE :: 64

Panel_Handle :: ^Maybe(Panel)

Panel_Agent :: struct {
	arena: 		Arena(Panel, MAX_PANELS),
	pool: 		map[Id]Panel_Handle,
	// Panel context stack
	stack: 		Stack(Panel_Handle, PANEL_STACK_SIZE),
	// Current window
	current:	Maybe(Panel_Handle),
	// Attachment box
	attach_box: Maybe(Box),
	attach_display_box: Maybe(Box),
}
current_panel :: proc(ui: ^UI, loc := #caller_location) -> ^Panel {
	handle, ok := ui.panels.current.?
	assert(ok, "No current panel to speak of", loc)
	panel, k := &handle.?
	assert(k, "The current panel is invalid", loc)
	return panel
}
get_panel :: proc(ui: ^UI, id: Id) -> (handle: Panel_Handle, ok: bool) {
	handle = ui.panels.pool[id] or_else create_panel(ui, id) or_return
	ok = true
	return
}
create_panel :: proc(ui: ^UI, id: Id) -> (handle: Panel_Handle, ok: bool) {
	handle = arena_allocate(&ui.panels.arena) or_return
	if panel, ok := &handle.?; ok {
		panel.id = id
	}
	ui.panels.pool[id] = handle
	ok = true
	return
}
push_panel :: proc(ui: ^UI, handle: Panel_Handle) {
	stack_push(&ui.panels.stack, handle)
	ui.panels.current = handle
}
pop_panel :: proc(ui: ^UI) {
	stack_pop(&ui.panels.stack)
	ui.panels.current = ui.panels.stack.items[ui.panels.stack.height - 1] if ui.panels.stack.height > 0 else nil
}
update_panels :: proc(ui: ^UI) {
	for id, handle in ui.panels.pool {
		if panel, ok := handle.?; ok {
			if .Stay_Alive in panel.bits {
				panel.bits -= {.Stay_Alive}
			} else {
				handle^ = nil
				delete_key(&ui.panels.pool, panel.id)
			}
		}
	}
}
destroy_panel_agent :: proc(using self: ^Panel_Agent) {
	delete(pool)
	self^ = {}
}

Panel_Placement_Info :: struct {
	origin,
	size: [2]f32,
	align: [2]Alignment,
}
/*
	Placement info for a panel
*/
Panel_Placement :: union {
	Box,
	Panel_Placement_Info,
}
/*
	Info required for manifesting a panel
*/
Panel_Info :: struct {
	id: Maybe(Id),
	title: string,
	placement: Panel_Placement,
	layout_size: Maybe([2]f32),
	min_size: Maybe([2]f32),
	options: Panel_Options,
	layer_options: Layer_Options,
}
@(deferred_in_out=_do_panel)
do_panel :: proc(ui: ^UI, info: Panel_Info, loc := #caller_location) -> (ok: bool) {
	id := info.id.? or_else hash(ui, loc)
	handle := get_panel(ui, id) or_return
	push_panel(ui, handle)
	self := &handle.?
	ok = true
	self.bits += {.Stay_Alive}

	// Initialize self
	if .Initialized not_in self.bits {
		switch v in info.placement {
			case Box: 
			self.real_box = v
			case Panel_Placement_Info:
			switch v.align.x {
				case .Near: 		self.real_box.low.x = v.origin.x
				case .Far: 			self.real_box.low.x = v.origin.x - v.size.x
				case .Middle: 	self.real_box.low.x = v.origin.x - v.size.x / 2
			}
			switch v.align.y {
				case .Near: 		self.real_box.low.y = v.origin.y
				case .Far: 			self.real_box.low.y = v.origin.y - v.size.y
				case .Middle: 	self.real_box.low.y = v.origin.y - v.size.y / 2
			}
			self.real_box.high = self.real_box.low + v.size
		}
	}
	self.options = info.options
	self.min_layout_size = info.layout_size.? or_else self.min_layout_size
	
	if .Should_Collapse in self.bits {
		self.how_collapsed = min(1, self.how_collapsed + ui.delta_time * 5)
	} else {
		self.how_collapsed = max(0, self.how_collapsed - ui.delta_time * 5)
	}
	if self.how_collapsed >= 1 {
		self.bits += {.Collapsed}
	} else {
		self.bits -= {.Collapsed}
	}

	// Layer body
	self.box = {ui.size, 0}

	inner_box := self.real_box
	title_box: Box 
	root_layer_box := inner_box
	if .Title in self.options {
		title_box = cut_box_top(&inner_box, ui.style.layout.title_size)
		self.box.low = linalg.min(self.box.low, title_box.low)
		self.box.high = linalg.max(self.box.high, title_box.high)
	}
	inner_box.high.y -= height(inner_box) * ease.quadratic_in_out(self.how_collapsed)
	root_layer_box.high.y = inner_box.high.y

	self.box.low = linalg.min(self.box.low, inner_box.low)
	self.box.high = linalg.max(self.box.high, inner_box.high)

	// Decoration
	if self.root_layer, ok = begin_layer(ui, {
		placement = root_layer_box,
		id = hash(ui, rawptr(&self.id), size_of(Id)),
		order = .Floating,
		options = {.No_Scroll_Y},
	}); ok {
		if .Collapsed not_in self.bits {
			box := inner_box
			// Compensate for title bar rounding
			box.low.y -= ui.style.panel_rounding
			when false {
				// Capture paint target
				prev_target := painter.target
				// Prepare a new mesh
				painter.target = get_draw_target()
				painter.meshes[painter.target].material = Gradient_Material{
					corners = {
						.Top_Left = ui.style.color.base[0],
						.Bottom_Left = ui.style.color.base[1],
						.Top_Right = ui.style.color.base[1],
						.Bottom_Right = ui.style.color.base[0],
					},
				}
				inject_at(&self.root_layer.?.meshes, 0, painter.target)
				// Paint the shader mask
				paint_rounded_box_mask(box, ui.style.panel_rounding, 255)
				// Set previous paint target
				painter.target = prev_target
				// Paint overlay
				paint_rounded_box_fill(ui.painter, box, ui.style.panel_rounding, fade(ui.style.color.base[1], 0.2))
			} else {
				paint_rounded_box_fill(ui.painter, box, ui.style.panel_rounding, fade(ui.style.color.base[0], 0.9))
				//paint_rounded_box_stroke(box, ui.style.panel_rounding, 2, ui.style.color.base[1])
			}
		}
		// Draw title bar and get movement dragging
		if .Title in self.options {
			// Draw title
			paint_rounded_box_fill(ui.painter, title_box, ui.style.panel_rounding, ui.style.color.substance[1])
			// Close button
			/*
			if .Closable in self.options {
				if w, _ok := do_widget(ui, hash(ui, &self.id, size_of(Id))); _ok {
					w.box = cut_box_right(&title_box, height(title_box))
					update_widget(w)
					hover_time := animate_bool(ui, &w.timers[0], .Hovered in w.state, DEFAULT_WIDGET_HOVER_TIME)
					paint_rounded_box_corners_fill(ui.painter, w.box, ui.style.panel_rounding, {.Top_Right, .Bottom_Right} if w.box.high.y == self.box.high.y else {}, fade(ui.style.color.accent[1], hover_time * 0.1))
					paint_cross(ui.painter, box_center(w.box), 5, math.PI * 0.25, 2, blend_colors(ui.style.color.substance_text[0], ui.style.color.substance_text[1], hover_time))
					update_widget_hover(w, point_in_box(ui.io.mouse_point, w.box))
				}
			}
			if .Collapsable in self.options {
				push_id(ui, int(1))
				if w, _ok := do_widget(ui, hash(ui, &self.id, size_of(Id))); _ok {
					w.box = cut_box_right(&title_box, height(title_box))
					update_widget(w)
					hover_time := animate_bool(ui.painter, &w.timers[0], .Hovered in w.state, DEFAULT_WIDGET_HOVER_TIME)
					paint_rounded_box_corners_fill(ui.painter, w.box, ui.style.panel_rounding, {.Top_Right, .Bottom_Right} if w.box.high.y == self.box.high.y else {}, fade(ui.style.color.accent[1], hover_time * 0.1))
					paint_arrow_flip(ui.painter, box_center(w.box), 5, 0, 1, self.how_collapsed, blend_colors(ui.style.color.substance_text[0], ui.style.color.substance_text[1], hover_time))
					if widget_clicked(w, .Left) {
						self.bits ~= {.Should_Collapse}
					}
					update_widget_hover(w, point_in_box(ui.io.mouse_point, w.box))
				}
				pop_id(ui)
			}
			*/
			// Title bar positional decoration
			baseline := center_y(title_box)
			text_offset := height(title_box) * 0.25
			can_collapse := (.Collapsable in self.options) || (.Collapsed in self.bits)
			// Draw title
			//TODO: Make sure the text doesn't overflow
			paint_text(
				ui.painter,
				{title_box.low.x + text_offset, baseline}, 
				{text = info.title, font = ui.style.font.title, size = ui.style.text_size.label, align = .Left, baseline = .Middle}, 
				color = ui.style.color.text,
			)
			// Moving 
			if (.Hovered in self.root_layer.?.state) && point_in_box(ui.io.mouse_point, title_box) {
				if (.Static not_in self.options) && (ui.widgets.hover_id == 0) && mouse_pressed(ui.io, .Left) {
					self.bits += {.Moving}
					ui.drag_anchor = self.root_layer.?.box.low - ui.io.mouse_point
				}
				if can_collapse && mouse_pressed(ui.io, .Right) {
					self.bits ~= {.Should_Collapse}
				}
			}
		} else {
			self.bits -= {.Should_Collapse}
		}
	}

	if .Initialized not_in self.bits {
		self.min_layout_size = inner_box.high - inner_box.low
		self.bits += {.Initialized}
	}

	layer_options := info.layer_options + {.Attached}
	if (self.how_collapsed > 0 && self.how_collapsed < 1) || (self.how_collapsed == 1 && .Should_Collapse not_in self.bits) {
		layer_options += {.Force_Clip, .No_Scroll_Y}
		ui.painter.next_frame = true
	}

	// Push layout if necessary
	if .Collapsed in self.bits {
		ok = false
	} else {
		self.content_layer, ok = begin_layer(ui, {
			placement = inner_box,
			id = id, 
			options = layer_options,
			space = self.min_layout_size,
			order = .Background,
		})
	}
	return
}
@private
_do_panel :: proc(ui: ^UI, _: Panel_Info, _: runtime.Source_Code_Location, ok: bool) {
	self := current_panel(ui)
	pop_panel(ui)
	// End main layer
	if .Collapsed not_in self.bits {
		box := self.content_layer.?.box
		// Resize handle
		if .Resizable in self.options {
			/*if w, ok := do_widget(ui, hash(ui, &self.id, size_of(Id)), {.Draggable}); ok {
				w.box = {box.high - 20, box.high}
				update_widget(w)
				hover_time := animate_bool(ui, &w.timers[0], .Hovered in w.state, DEFAULT_WIDGET_HOVER_TIME)
				paint_triangle_fill(ui.painter, {w.box.low.x, w.box.high.y}, w.box.high, {w.box.high.x, w.box.low.y}, fade(ui.style.color.substance[1], 0.1 + 0.1 * hover_time))
				paint_triangle_stroke(ui.painter, {w.box.low.x, w.box.high.y}, w.box.high, {w.box.high.x, w.box.low.y}, 1, fade(ui.style.color.substance[1], 0.5 + 0.5 * hover_time))
				if .Pressed in (w.state - w.last_state) {
					self.bits += {.Resizing}
				}
				update_widget_hover(ui, w, point_in_box(ui.io.mouse_point, w.box))
			}*/
		}
		// Done with main layer
		end_layer(ui, self.content_layer.?)
	}
	// End decor layer
	end_layer(ui, self.root_layer.?)
	// Handle movement
	if .Moving in self.bits {
		ui.cursor = .Resize

		origin := ui.io.mouse_point + ui.drag_anchor.?

		real_size := self.real_box.high - self.real_box.low
		size := self.box.high - self.box.low

		self.real_box.low = linalg.clamp(origin, 0, ui.size - size)
		self.real_box.high = self.real_box.low + real_size
		if mouse_released(ui.io, .Left) {
			self.bits -= {.Moving}
		}
	}
	// Handle Resizing
	WINDOW_SNAP_DISTANCE :: 10
	if .Resizing in self.bits {
		ui.widgets.hover_id = 0
		min_size: [2]f32 = self.min_layout_size if .Fit_To_Layout in self.options else {180, 240}
		ui.cursor = .Resize_NWSE
		self.real_box.high = linalg.max(ui.io.mouse_point, self.real_box.low + {240, 120})
		if mouse_released(ui.io, .Left) {
			self.bits -= {.Resizing}
		}
	}
}
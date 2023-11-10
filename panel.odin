package maui

import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"

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
	// Native stuff
	id: Id,
	options: Panel_Options,
	bits: Panel_Bits,
	// For resizing
	drag_side: Box_Side,
	// minimum layout size
	min_layout_size: [2]f32,
	// Position
	origin, size: [2]f32,
	// Main layer
	layer: ^Layer,
	// Decoration layer
	decor_layer: ^Layer,
	// Uncollapsed box
	real_box,
	// Current occupied box
	box: Box,
	// Collapse
	opacity,
	how_collapsed: f32,
}

Panel_Agent :: struct {
	list: 					[dynamic]^Panel,
	pool: 					map[Id]^Panel,
	// Panel context stack
	stack: 					Stack(^Panel, WINDOW_STACK_SIZE),
	// Current window
	current:				^Panel,
}
current_panel :: proc() -> ^Panel {
	assert(core.panel_agent.current != nil)
	return core.panel_agent.current
}
assert_panel :: proc(using self: ^Panel_Agent, id: Id) -> (p: ^Panel, ok: bool) {
	p, ok = pool[id]
	if !ok {
		p, ok = create_panel(self, id)
	}
	assert(ok)
	assert(p != nil)
	return
}
create_panel :: proc(using self: ^Panel_Agent, id: Id) -> (p: ^Panel, ok: bool) {
	p = new(Panel)
	p^ = {
		id = id,
	}
	append(&list, p)
	pool[id] = p
	ok = true
	return
}
push_panel :: proc(using self: ^Panel_Agent, p: ^Panel) {
	stack_push(&stack, p)
	current = p
}
pop_panel :: proc(using self: ^Panel_Agent) {
	stack_pop(&stack)
	if stack.height > 0 {
		current = stack.items[stack.height - 1]
	} else {
		current = nil
	}
}
update_panel_agent :: proc(using self: ^Panel_Agent) {
	for p, i in &list {
		if .Stay_Alive in p.bits {
			p.bits -= {.Stay_Alive}
		} else {
			ordered_remove(&list, i)
			delete_key(&pool, p.id)
			free(p)
		}
	}
}
destroy_panel_agent :: proc(using self: ^Panel_Agent) {
	for entry in list {
		free(entry)
	}
	delete(list)
	delete(pool)
}

/*
	Placement info for a window
*/
Panel_Placement :: union {
	Box,
}
/*
	Info required for manifesting a window
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
@(deferred_out=_do_panel)
do_panel :: proc(info: Panel_Info, loc := #caller_location) -> (ok: bool) {
	self: ^Panel
	id := info.id.? or_else hash(loc)
	if self, ok = assert_panel(&core.panel_agent, id); ok {
		push_panel(&core.panel_agent, self)

		self.bits += {.Stay_Alive}
		
		// Initialize self
		if .Initialized not_in self.bits {
			switch placement in info.placement {
				case Box: 
				self.real_box = placement
			}
		}
		self.options = info.options
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
		collapsable_height := height(self.real_box)
		if .Title in self.options {
			collapsable_height -= style.layout.title_size
		}
		self.box = self.real_box
		self.box.high.y -= collapsable_height * ease.quadratic_in(self.how_collapsed)

		// Get resize click
		resize_hover := false
		if self.decor_layer != nil && .Hovered in self.decor_layer.state {
			if (.Resizable in self.options) && (self.bits & {.Collapsed, .Moving} == {}) {
				RESIZE_MARGIN :: 5
				top_hover 		:= point_in_box(input.mouse_point, get_box_top(self.box, Exact(RESIZE_MARGIN)))
				left_hover 		:= point_in_box(input.mouse_point, get_box_left(self.box, Exact(RESIZE_MARGIN)))
				bottom_hover 	:= point_in_box(input.mouse_point, get_box_bottom(self.box, Exact(RESIZE_MARGIN)))
				right_hover 	:= point_in_box(input.mouse_point, get_box_right(self.box, Exact(RESIZE_MARGIN)))
				if top_hover || bottom_hover {
					core.cursor = .Resize_NS
					resize_hover = true
				}
				if left_hover || right_hover {
					core.cursor = .Resize_EW
					resize_hover = true
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

		// Decoration
		if self.decor_layer, ok = begin_layer({
			placement = self.box,
			id = hash(rawptr(&self.id), size_of(Id)),
			order = .Floating,
			options = {.No_Scroll_Y},
			opacity = self.opacity,
		}); ok {
			last_target := painter.target
			painter.target = get_draw_target()
			painter.meshes[painter.target].material = Acrylic_Material{amount = 4}
			inject_at(&self.decor_layer.meshes, 0, painter.target)
			mesh := &painter.meshes[painter.target]
			paint_indices(mesh, 
				mesh.indices_offset,
				mesh.indices_offset + 1,
				mesh.indices_offset + 2,
				mesh.indices_offset,
				mesh.indices_offset + 2,
				mesh.indices_offset + 3,
			)
			src_box: Box = {self.box.low / core.size, self.box.high / core.size}
			src_box.low.y = 1 - src_box.low.y
			src_box.high.y = 1 - src_box.high.y
			paint_vertices(mesh,
				{point = self.box.low, uv = src_box.low, color = style.color.glass},
				{point = {self.box.low.x, self.box.high.y}, uv = {src_box.low.x, src_box.high.y}, color = style.color.glass},
				{point = self.box.high, uv = src_box.high, color = style.color.glass},
				{point = {self.box.high.x, self.box.low.y}, uv = {src_box.high.x, src_box.low.y}, color = style.color.glass},
			)
			painter.target = last_target
			// Draw title bar and get movement dragging
			if .Title in self.options {
				title_box := cut(.Top, Exact(style.layout.title_size))
				// Draw title
				{
					h := height(title_box) / 3
					paint_quad_fill({title_box.high.x - h, title_box.low.y}, {title_box.high.x, title_box.low.y}, {title_box.high.x, title_box.high.y - h}, {title_box.high.x - h, title_box.high.y}, style.color.substance[1])
					paint_box_fill({title_box.low, {title_box.high.x - h, title_box.high.y}}, style.color.substance[1])
				}
				layout_box := title_box
				// Close button
				if .Closable in self.options {
					if w, _ok := do_widget(hash(&self.id, size_of(Id))); _ok {
						w.box = cut_box_right(&layout_box, height(layout_box))
						update_widget(w)
						hover_time := animate_bool(&w.timers[0], .Hovered in w.state, DEFAULT_WIDGET_HOVER_TIME)
						paint_cross(box_center(w.box), 7, math.PI * 0.25, 1 + hover_time, style.color.substance_text[1])
						update_widget_hover(w, point_in_box(input.mouse_point, w.box))
					}
				}
				if .Collapsable in self.options {
					push_id(int(1))
					if w, _ok := do_widget(hash(&self.id, size_of(Id))); _ok {
						w.box = cut_box_right(&layout_box, height(layout_box))
						update_widget(w)
						hover_time := animate_bool(&w.timers[0], .Hovered in w.state, DEFAULT_WIDGET_HOVER_TIME)
						paint_arrow_flip(box_center(w.box), 7, 0, 0.5 + (0.5 * hover_time), self.how_collapsed, style.color.substance_text[1])
						if widget_clicked(w, .Left) {
							self.bits ~= {.Should_Collapse}
						}
						update_widget_hover(w, point_in_box(input.mouse_point, w.box))
					}
					pop_id()
				}
				// Title bar positional decoration
				baseline := center_y(layout_box)
				text_offset := height(title_box) * 0.25
				can_collapse := (.Collapsable in self.options) || (.Collapsed in self.bits)
				// Draw title
				//TODO: Make sure the text doesn't overflow
				paint_text(
					{title_box.low.x + text_offset, baseline}, 
					{text = info.title, font = style.font.label, size = style.text_size.label}, 
					{align = .Left, baseline = .Middle}, 
					color = style.color.substance_text[1],
				)
				// Moving 
				if (.Hovered in self.decor_layer.state) && !resize_hover && point_in_box(input.mouse_point, title_box) {
					if (.Static not_in self.options) && (core.widget_agent.hover_id == 0) && mouse_pressed(.Left) {
						self.bits += {.Moving}
						core.drag_anchor = self.decor_layer.box.low - input.mouse_point
					}
					if can_collapse && mouse_pressed(.Right) {
						self.bits ~= {.Should_Collapse}
					}
				}
			} else {
				self.bits -= {.Should_Collapse}
			}
		}
		
		inner_box := self.box
		inner_box.low.y += style.layout.title_size

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
		}
		self.opacity = 1
		// last_opacity := self.opacity
		// if .Moving in self.bits {
		// 	self.opacity += (0.75 - self.opacity) * core.delta_time * 10
		// } else {
		// 	self.opacity += (1 - self.opacity) * core.delta_time * 10
		// }
		// if last_opacity != self.opacity {
		// 	core.paint_next_frame = true
		// }
	}
	return
}
@private
_do_panel :: proc(ok: bool) {
	if true {
		using self := current_panel()
		pop_panel(&core.panel_agent)
		// End main layer
		if .Collapsed not_in bits {
			// Outline
			A, B, C, D :: 1, 4, 8, 12
			paint_box_fill({{layer.box.low.x, layer.box.low.y + B}, {layer.box.low.x + A, layer.box.high.y - D}}, style.color.substance[0])
			paint_box_fill({{layer.box.high.x - A, layer.box.low.y + B}, {layer.box.high.x, layer.box.high.y - D}}, style.color.substance[0])
			paint_box_fill({{layer.box.low.x + D, layer.box.high.y - A}, {layer.box.high.x - D, layer.box.high.y}}, style.color.substance[0])
			// Bottom left
			paint_box_fill({{layer.box.low.x, layer.box.high.y - C}, {layer.box.low.x + A, layer.box.high.y}}, style.color.substance[1])
			paint_box_fill({{layer.box.low.x, layer.box.high.y - A}, {layer.box.low.x + C, layer.box.high.y}}, style.color.substance[1])
			// Bottom right
			paint_box_fill({{layer.box.high.x - A, layer.box.high.y - C}, {layer.box.high.x, layer.box.high.y}}, style.color.substance[1])
			paint_box_fill({{layer.box.high.x - C, layer.box.high.y - A}, {layer.box.high.x, layer.box.high.y}}, style.color.substance[1])
			// Done with main layer
			end_layer(layer)
		}
		// End decor layer
		end_layer(decor_layer)
		// Handle movement
		if .Moving in bits {
			core.cursor = .Resize
			origin := input.mouse_point + core.drag_anchor
			size := box.high - box.low
			real_size := real_box.high - real_box.low
			real_box.low = linalg.clamp(origin, 0, core.size - size)
			real_box.high = real_box.low + real_size
			if mouse_released(.Left) {
				bits -= {.Moving}
			}
		}
		// Handle Resizing
		WINDOW_SNAP_DISTANCE :: 10
		if .Resizing in self.bits {
			core.widget_agent.hover_id = 0
			min_size: [2]f32 = self.min_layout_size if .Fit_To_Layout in self.options else {180, 240}
			switch self.drag_side {
				case .Bottom:
				anchor := input.mouse_point.y
				for other in &core.panel_agent.list {
					if other != self {
						if abs(input.mouse_point.y - other.box.low.y) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.low.y
						}
					}
				}
				self.real_box.high.y = max(anchor, self.real_box.low.y + min_size.y)
				core.cursor = .Resize_NS

				case .Left:
				anchor := input.mouse_point.x
				for other in &core.panel_agent.list {
					if other != self {
						if abs(input.mouse_point.x - other.box.high.x) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.high.x
						}
					}
				}
				self.real_box.low.x = min(anchor, self.real_box.high.x - min_size.x)
				core.cursor = .Resize_EW

				case .Right:
				anchor := input.mouse_point.x
				for other in &core.panel_agent.list {
					if other != self {
						if abs(input.mouse_point.x - other.box.low.x) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.low.x
						}
					}
				}
				self.real_box.high.x = max(anchor, self.real_box.low.x + min_size.x)
				core.cursor = .Resize_EW

				case .Top:
				anchor := input.mouse_point.y
				for other in &core.panel_agent.list {
					if other != self {
						if abs(input.mouse_point.y - other.box.high.y) < WINDOW_SNAP_DISTANCE {
							anchor = other.box.high.y
						}
					}
				}
				self.real_box.low.y = min(anchor, self.real_box.high.y - min_size.y)
				core.cursor = .Resize_NS
			}
			if mouse_released(.Left) {
				self.bits -= {.Resizing}
			}
		}
	}
}
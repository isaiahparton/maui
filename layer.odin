package maui
import "core:fmt"
import "core:math/linalg"
/*
	Layers are the root of all gui
*/

SCROLL_SPEED :: 16
SCROLL_STEP :: 20
SCROLL_BAR_SIZE :: 16
SCROLL_BAR_PADDING :: 2

// Layer interaction state
Layer_Status :: enum {
	Got_Hover,
	Hovered,
	Lost_Hover,
	Focused,
	Lost_Focus,
}
Layer_State :: bit_set[Layer_Status]

// General purpose booleans
Layer_Bit :: enum {
	// If the layer should stay alive
	Stay_Alive,
	// If the layer requires clipping
	Clipped,
	// If the layer requires scrollbars on either axis
	Scroll_X,
	Scroll_Y,
	// If the layer was dismissed by an input
	Dismissed,
	// If the layer pushed to the id stack this frame
	Did_Push_ID,
}
Layer_Bits :: bit_set[Layer_Bit]

// Options
Layer_Option :: enum {
	// If the layer is attached (fixed) to it's parent
	Attached,
	// If the layer is spawned with 0 or 1 opacity
	Invisible,
	// Disallow scrolling on either axis
	No_Scroll_X,
	No_Scroll_Y,
	// Scroll bars won't affect layout size
	No_Scroll_Margin_X,
	No_Scroll_Margin_Y,
	// Doesn't push the layers's id to the stack
	No_ID,
	// Forces the layer to always clip its contents
	Force_Clip,
	// Forces the layer to fit inside its parent
	Clip_To_Parent,
	// The layer does not move
	No_Sorting,
	// Steal focus
	Steal_Focus,
	// Trap key navigation
	Trap_Key_Navigation,
	// No layout
	No_Layout,
}
Layer_Options :: bit_set[Layer_Option]

/*
	Layers for layers
*/
Layer_Order :: enum {
	// Allways in the background, fixed order
	Background,
	// Free floating layers, dynamic order
	Floating,
	// Allways in the foreground, fixed order
	Tooltip,
	// Special layer for debug drawing
	Debug,
}

// A layer's own data
Layer :: struct {
	// Reserved in data table
	reserved: bool,
	// Owner widget
	owner: Maybe(^Widget),
	// Relations
	parent: ^Layer,
	children: [dynamic]^Layer,
	// Base Data
	id: Id,
	// Internal state
	bits: Layer_Bits,
	// User options
	options: Layer_Options,
	// The layer's own state
	state,
	next_state: Layer_State,
	// Painting settings
	opacity: f32,
	// Viewport box
	box: Box,
	// Boxangle on which scrollbars are anchored
	inner_box: Box,
	// Bounding box of all content to be drawn
	// for clipping purposes
	content_box: Box,
	// Space for scrolling
	space: [2]f32,
	// Scrolling
	scroll, 
	scroll_target: [2]f32,
	// draw order
	order: Layer_Order,
	// list index
	index: int,
	// controls on this self
	contents: map[Id]^Widget,
	// Scroll bar interpolation
	x_scroll_time,
	y_scroll_time: f32,
	// Draw command
	draws: [dynamic]int,
}

Layer_Agent :: struct {
	root_layer: 	^Layer,
	// Fixed memory arena
	arena:  		[LAYER_ARENA_SIZE]Layer,
	// Internal layer data
	list: 			[dynamic]^Layer,
	pool: 			map[Id]^Layer,
	// Layer context stack
	stack: 			Stack(^Layer, LAYER_STACK_SIZE),
	// Layer ordering helpers
	should_sort:	bool,
	last_top_id, 
	top_id: 		Id,
	current_layer: 	^Layer,
	// Current layer being drawn (used only by 'NextCommand')
	paint_index: 	int,
	// Current layer state
	hover_id,
	last_hover_id,
	focus_id,
	last_focus_id,
	debug_id: 		Id,
	// If a layer is stealing focus
	exclusive_id: Maybe(Id),
}

layer_draw_target :: proc(using self: ^Layer) -> int {
	assert(len(draws) > 0)
	return draws[len(draws) - 1]
}

layer_agent_destroy :: proc(using self: ^Layer_Agent) {
	for entry in list {
		layer_destroy(entry)
	}
	delete(pool)
	delete(list)
	self^ = {}
}

layer_agent_begin_root :: proc(using self: ^Layer_Agent) -> (ok: bool) {
	root_layer, ok = begin_layer({
		id = 0,
		placement = core.fullscreen_box, 
		options = {.No_ID},
	})
	return
}

layer_agent_end_root :: proc(using self: ^Layer_Agent) {
	end_layer(root_layer)
}

layer_agent_step :: proc(using self: ^Layer_Agent) {
	sorted_layer: ^Layer
	last_focus_id = focus_id
	last_hover_id = hover_id
	hover_id = 0
	for layer, i in list {
		if .Stay_Alive in layer.bits {
			layer.bits -= {.Stay_Alive}
			if point_in_box(input.mouse_point, layer.box) {
				hover_id = layer.id
				if mouse_pressed(.Left) {
					focus_id = layer.id
					if .No_Sorting not_in layer.options {
						sorted_layer = layer
					}
				}
			}
		} else {
			when ODIN_DEBUG {
				fmt.printf("Deleted layer %i\n", layer.id)
			}

			delete_key(&pool, layer.id)
			if layer.parent != nil {
				for child, j in layer.parent.children {
					if child == layer {
						ordered_remove(&layer.parent.children, j)
						break
					}
				}
			}
			layer_destroy(layer)
			should_sort = true
		}
	}
	// If a sorted layer was selected, then find it's root attached parent
	if sorted_layer != nil {
		child := sorted_layer
		for child.parent != nil {
			top_id = child.id
			sorted_layer = child
			if child.options >= {.Attached} {
				child = child.parent
			} else {
				break
			}
		}
	}
	// Then reorder it with it's siblings
	if top_id != last_top_id {
		for child in sorted_layer.parent.children {
			if child.order == sorted_layer.order {
				if child.id == top_id {
					child.index = len(sorted_layer.parent.children)
				} else {
					child.index -= 1
				}
			}
		}
		should_sort = true
		last_top_id = top_id
	}
	// Sort the layers
	if should_sort {
		should_sort = false

		clear(&list)
		sort_layer(&list, root_layer)
	}
	// Reset rendered layer
	paint_index = 0
	if id, ok := exclusive_id.?; ok {
		hover_id = id
		exclusive_id = nil
	}
}

layer_agent_allocate :: proc(using self: ^Layer_Agent) -> (layer: ^Layer, ok: bool) {
	for i in 0..<LAYER_ARENA_SIZE {
		if !arena[i].reserved {
			layer = &arena[i]
			ok = true
			break
		}
	}
	return
}

layer_agent_create :: proc(using self: ^Layer_Agent, id: Id, options: Layer_Options) -> (layer: ^Layer, ok: bool) {
	layer, ok = layer_agent_allocate(self)
	if !ok {
		return
	}
	// Initiate the layer
	layer^ = {
		reserved = true,
		id = id,
		opacity = 0 if .Invisible in options else 1,
	}
	// Append the new layer
	append(&list, layer)
	pool[id] = layer
	if stack.height > 0 {
		parent := current_layer if .Attached in options else root_layer
		append(&parent.children, layer)
		layer.parent = parent
		layer.index = len(parent.children)
	}
	// Will sort layers this frame
	should_sort = true

	when ODIN_DEBUG {
		fmt.printf("Created layer %i\n", id)
	}

	return
}

layer_agent_assert :: proc(using self: ^Layer_Agent, id: Id, options: Layer_Options) -> (layer: ^Layer, ok: bool) {
	layer, ok = pool[id]
	if !ok {
		layer, ok = layer_agent_create(self, id, options)
	}
	assert(ok)
	assert(layer != nil)
	return
}

layer_agent_push :: proc(using self: ^Layer_Agent, layer: ^Layer) {
	stack_push(&stack, layer)
	current_layer = stack_top(&stack)
}

layer_agent_pop :: proc(using self: ^Layer_Agent) {
	stack_pop(&stack)
	current_layer = stack_top(&stack)
}

layer_destroy :: proc(self: ^Layer) {
	delete(self.contents)
	delete(self.draws)
	delete(self.children)
	self.reserved = false
}

// Frame info
Frame_Info :: struct {
	options: Layer_Options,
	fill_color: Maybe(Color),
	scrollbar_padding: Maybe(f32),
}

@(deferred_out=_do_frame)
do_frame :: proc(info: Frame_Info, loc := #caller_location) -> (ok: bool) {
	self: ^Layer
	box := use_next_box() or_else layout_next(current_layout())
	self, ok = begin_layer({
		placement = box,
		scrollbar_padding = info.scrollbar_padding.? or_else 0,
		id = hash(loc), 
		options = info.options + {.Clip_To_Parent, .Attached, .No_Sorting},
	})
	if ok {
		paint_box_fill(self.box, info.fill_color.? or_else style.color.base)
	}
	return
}

@private
_do_frame :: proc(ok: bool) {
	if ok {
		assert(core.layer_agent.current_layer != nil)
		paint_box_stroke(core.layer_agent.current_layer.box, 1, style.color.base_stroke)
		end_layer(core.layer_agent.current_layer)
	}
}

Layer_Shadow_Info :: struct {
	offset,
	roundness: f32,
}

Layer_Placement_Info :: struct {
	origin: [2]f32,
	size: [2]Maybe(f32), 
	align: [2]Alignment,
}

Layer_Placement :: union {
	Box,
	Layer_Placement_Info,
}

Layer_Info :: struct {
	// Explicit id assignment
	id: Maybe(Id),
	// Placement
	placement: Layer_Placement,
	// Scrollbar padding
	scrollbar_padding: Maybe([2]f32),
	// Extending layout?
	extend: Maybe(Box_Side),
	// Defined space or the layer size whichever is larger
	space: Maybe([2]f32),
	// Sorting order
	order: Maybe(Layer_Order),
	// Optional shadow
	shadow: Maybe(Layer_Shadow_Info),
	// Optional options
	options: Layer_Options,
	// bruh
	owner: Maybe(^Widget),
	// Opacity
	opacity: Maybe(f32),
}

@(deferred_out=_do_layer)
do_layer :: proc(info: Layer_Info, loc := #caller_location) -> (self: ^Layer, ok: bool) {
	info := info
	info.id = info.id.? or_else hash(loc)
	return begin_layer(info)
}

@private
_do_layer :: proc(self: ^Layer, ok: bool) {
	if ok {
		end_layer(self)
	}
}

current_layer :: proc() -> ^Layer {
	assert(core.layer_agent.current_layer != nil)
	return core.layer_agent.current_layer
}
// Begins a new layer, the layer is created if it doesn't exist
// and is managed internally
//@private 
begin_layer :: proc(info: Layer_Info, loc := #caller_location) -> (self: ^Layer, ok: bool) {
	agent := &core.layer_agent

	if self, ok = layer_agent_assert(
		self = agent,
		id = info.id.? or_else panic("Must define a layer id", loc),
		options = info.options,
	); ok {
		// Push layer stack
		layer_agent_push(&core.layer_agent, self)

		// Set sort order
		self.order = info.order.? or_else self.order

		// Update user options
		self.options = info.options

		self.owner = info.owner

		if .Steal_Focus in self.options {
			agent.exclusive_id = self.id
		}

		// Begin id context for layer contents
		if .No_ID not_in self.options {
			push_id(self.id)
			self.bits += {.Did_Push_ID}
		} else {
			self.bits -= {.Did_Push_ID}
		}

		// Stay alive
		self.bits += {.Stay_Alive}

		// Reset draw command
		clear(&self.draws)

		// Uh yeah
		if agent.exclusive_id == self.id {
			paint_box_fill(core.fullscreen_box, {0, 0, 0, 100})
		}
		// Shadows
		if shadow, ok := info.shadow.?; ok {
			painter.target = get_draw_target()
			append(&self.draws, painter.target)
			paint_rounded_box_shadow(move_box(self.box, shadow.offset), shadow.roundness, style.color.shadow)
		}

		painter.target = get_draw_target()
		append(&self.draws, painter.target)

		// Get box
		switch placement in info.placement {
			case Box: 
			self.box = placement
			case Layer_Placement_Info: 
			// Use space if size is not provided
			size: [2]f32 = {
				placement.size.x.? or_else self.space.x,
				placement.size.y.? or_else self.space.y,
			}
			// Align x
			switch placement.align.x {
				case .Far: 
				self.box.high.x = placement.origin.x 
				self.box.low.x = self.box.high.x - size.x 
				case .Middle: 
				self.box.low.x = placement.origin.x - size.x / 2 
				self.box.high.x = placement.origin.x + size.x / 2
				case .Near: 
				self.box.low.x = placement.origin.x 
				self.box.high.x = self.box.low.x + size.x
			}
			// Align y
			switch placement.align.y {
				case .Far: 
				self.box.high.y = placement.origin.y 
				self.box.low.y = self.box.high.y - size.y 
				case .Middle: 
				self.box.low.y = placement.origin.y - size.y / 2 
				self.box.high.y = placement.origin.y + size.y / 2
				case .Near: 
				self.box.low.y = placement.origin.y 
				self.box.high.y = self.box.low.y + size.y
			}
		}
		// Apply inner padding
		self.inner_box = shrink_box(self.box, info.scrollbar_padding.? or_else 0)

		// Hovering and stuff
		self.state = self.next_state
		self.next_state = {}
		if agent.hover_id == self.id {
			self.state += {.Hovered}
			if agent.last_hover_id != self.id {
				self.state += {.Got_Hover}
			}
		} else if agent.last_hover_id == self.id {
			self.state += {.Lost_Hover}
		}
		if agent.focus_id == self.id {
			self.state += {.Focused}
		} else if agent.last_focus_id == self.id {
			self.state += {.Lost_Focus}
		}

		// Attachment
		if .Attached in self.options {
			assert(self.parent != nil)
			self.opacity = self.parent.opacity
			if self.state != {} {
				parent := self.parent
				for parent != nil {
					parent.next_state += self.state
					if .Attached not_in parent.options {
						break
					}
					parent = parent.parent
				}
			}
		}

		// Update clip status
		self.bits -= {.Clipped}
		if .Clip_To_Parent in self.options && self.parent != nil && !box_in_box(self.parent.box, self.box) {
			self.box = clamp_box(self.box, self.parent.box)
		}
		
		self.opacity = info.opacity.? or_else self.opacity

		// Get layout size
		self.space = info.space.? or_else 0

		SCROLL_LERP_SPEED :: 7

		// Horizontal scrolling
		if (self.space.x > width(self.box)) && (.No_Scroll_X not_in self.options) {
			self.bits += {.Scroll_X}
			self.x_scroll_time = min(1, self.x_scroll_time + core.delta_time * SCROLL_LERP_SPEED)
		} else {
			self.bits -= {.Scroll_X}
			self.x_scroll_time = max(0, self.x_scroll_time - core.delta_time * SCROLL_LERP_SPEED)
		}
		if .No_Scroll_Margin_Y not_in self.options && self.space.y <= height(self.box) {
			self.space.y -= self.x_scroll_time * SCROLL_BAR_SIZE
		}
		if self.x_scroll_time > 0 && self.x_scroll_time < 1 {
			core.paint_next_frame = true
		}

		// Vertical scrolling
		if (self.space.y > height(self.box)) && (.No_Scroll_Y not_in self.options) {
			self.bits += {.Scroll_Y}
			self.y_scroll_time = min(1, self.y_scroll_time + core.delta_time * SCROLL_LERP_SPEED)
		} else {
			self.bits -= {.Scroll_Y}
			self.y_scroll_time = max(0, self.y_scroll_time - core.delta_time * SCROLL_LERP_SPEED)
		}
		if .No_Scroll_Margin_X not_in self.options && self.space.x <= width(self.box) {
			self.space.x -= self.y_scroll_time * SCROLL_BAR_SIZE
		}
		if self.y_scroll_time > 0 && self.y_scroll_time < 1 {
			core.paint_next_frame = true
		}
		self.content_box = {self.box.high, self.box.low}

		// Get space
		self.space = linalg.max(self.space, self.box.high - self.box.low)
		// Copy box
		layout_box := self.box 
		// Apply scroll offset
		layout_box.low -= self.scroll
		layout_box.high -= self.scroll
		// Push layout
		layout := push_layout(layout_box)
		// Extending layout
		if side, ok := info.extend.?; ok {
			#partial switch side {
				case .Bottom: 
				layout.box.high.y = layout.box.low.y
				case .Top: 
				layout.box.low.y = layout.box.high.y 
				case .Left: 
				layout.box.low.x = layout.box.high.x 
				case .Right: 
				layout.box.high.x = layout.box.low.x
			}
			layout.mode = .Extending
			layout.side = side
		} else {
			layout.box.high = layout.box.low + self.space
		}
	}
	return
}
// Called for every 'BeginLayer' that is called
//@private 
end_layer :: proc(self: ^Layer) {
	if self != nil {
		// Pop layout
		layout := current_layout()
		if layout.mode == .Extending {
			self.space = layout.box.high - layout.box.low
		}
		pop_layout()
		// Detect clipping
		if (self.box != core.fullscreen_box && !box_in_box(self.content_box, self.box)) || (.Force_Clip in self.options) {
			self.bits += {.Clipped}
			painter.draws[painter.target].clip = self.box
		}
		// Maximum scroll offset
		max_scroll: [2]f32 = {
			max(self.space.x - (self.box.high.x - self.box.low.x), 0),
			max(self.space.y - (self.box.high.y - self.box.low.y), 0),
		}
		// Mouse wheel input
		if .Hovered in self.state {
			self.scroll_target -= input.mouse_scroll * SCROLL_STEP
		}
		// Clamp scrolling
		self.scroll_target.x = clamp(self.scroll_target.x, 0, max_scroll.x)
		self.scroll_target.y = clamp(self.scroll_target.y, 0, max_scroll.y)
		// Repaint if scrolling with wheel
		if linalg.floor(self.scroll_target - self.scroll) != {} {
			core.paint_next_frame = true
		}
		// Interpolate scrolling
		self.scroll += (self.scroll_target - self.scroll) * SCROLL_SPEED * core.delta_time
		// Manifest scroll bars
		if self.x_scroll_time > 0 {
			// Horizontal scrolling
			box := get_box_bottom(self.inner_box, self.x_scroll_time * SCROLL_BAR_SIZE)
			box.high.x -= self.y_scroll_time * SCROLL_BAR_SIZE + SCROLL_BAR_PADDING * 2
			box.high.y -= SCROLL_BAR_PADDING
			box.low.x += SCROLL_BAR_PADDING
			set_next_box(box)
			if changed, new_value := do_scrollbar({
				value = self.scroll.x, 
				low = 0, 
				high = max_scroll.x, 
				knob_size = max(SCROLL_BAR_SIZE * 2, width(box) * width(self.box) / self.space.x),
			}); changed {
				self.scroll.x = new_value
				self.scroll_target.x = new_value
			}
		}
		if self.y_scroll_time > 0 {
			// Vertical scrolling
			box := get_box_right(self.inner_box, self.y_scroll_time * SCROLL_BAR_SIZE)
			box.high.y -= self.x_scroll_time * SCROLL_BAR_SIZE + SCROLL_BAR_PADDING * 2
			box.high.x -= SCROLL_BAR_PADDING
			box.low.y += SCROLL_BAR_PADDING
			set_next_box(box)
			if change, new_value := do_scrollbar({
				value = self.scroll.y, 
				low = 0, 
				high = max_scroll.y, 
				knob_size = max(SCROLL_BAR_SIZE * 2, height(box) * height(self.box) / self.space.y), 
				vertical = true,
			}); change {
				self.scroll.y = new_value
				self.scroll_target.y = new_value
			}
		}
		// Handle content clipping
		if .Clipped in self.bits {
			// Apply clipping
			self.box.high = linalg.max(self.box.low, self.box.high)
		}
		// Update parent content bounds if
		if .Attached in self.options {
			self.parent.content_box = update_bounding_box(self.parent.content_box, self.inner_box)
		}
		// End id context
		if .Did_Push_ID in self.bits {
			pop_id()
		}
	}
	layer_agent_pop(&core.layer_agent)
	if core.layer_agent.stack.height > 0 {
		layer := current_layer()
		painter.target = layer.draws[len(layer.draws) - 1]
	}
}
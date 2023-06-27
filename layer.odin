package maui
import "core:fmt"
import "core:math/linalg"
/*
	Layers are the root of all gui

	Each self contains a command buffer for draw calls made in that self.
*/

// Layer interaction state
Layer_Status :: enum {
	got_hover,
	hovered,
	lost_hover,
	focused,
}
Layer_State :: bit_set[Layer_Status]
// General purpose booleans
Layer_Bit :: enum {
	// If the layer should stay alive
	stay_alive,
	// If the layer requires clipping
	clipped,
	// If the layer requires scrollbars on either axis
	scroll_x,
	scroll_y,
	// If the layer was dismissed by an input
	dismissed,
	// If the layer pushed to the id stack this frame
	did_push_id,
}
Layer_Bits :: bit_set[Layer_Bit]
// Options
Layer_Option :: enum {
	// If the layer is attached (fixed) to it's parent
	attached,
	// Shadows for windows (must be drawn before clip command)
	shadow,
	// If the layer is spawned with 0 or 1 opacity
	invisible,
	// Disallow scrolling on either axis
	no_scroll_x,
	no_scroll_y,
	// Scroll bars won't affect layout size
	no_scroll_margin_x,
	no_scroll_margin_y,
	// Doesn't push the layers's id to the stack
	no_id,
	// Forces the self to always clip its contents
	force_clip,
	// Forces the self to fit inside its parent
	clip_to_parent,
	// The layer does not move
	no_sort,
}
Layer_Options :: bit_set[Layer_Option]
/*
	Layers for layers
*/
Layer_Order :: enum {
	// Allways in the background, fixed order
	background,
	// Free floating layers, dynamic order
	floating,
	// Allways in the foreground, fixed order
	tooltip,
	// Spetial self for debug drawing
	debug,
}
/*
	Each self's data
*/
Layer :: struct {
	reserved: bool,
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

	// Inner layout size
	layout_size: [2]f32,

	// Content bounding box
	content_box: Box,

	// Negative content offset
	scroll, 
	scroll_target: [2]f32,

	// draw order
	order: Layer_Order,

	// list index
	index: int,

	// controls on this self
	contents: map[Id]^Widget,

	// draw commands for this self
	commands: [COMMAND_BUFFER_SIZE]u8,
	command_offset: int,

	// Clip command stored for use after
	// contents are already drawn
	clip_command: ^Command_Clip,

	// Scroll bars
	x_scroll_time,
	y_scroll_time: f32,
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
	debug_id: 		Id,
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
		box = core.fullscreen_box, 
		options = {.no_id},
	})
	return
}
layer_agent_end_root :: proc(using self: ^Layer_Agent) {
	end_layer(root_layer)
}
layer_agent_step :: proc(using self: ^Layer_Agent) {
	sorted_layer: ^Layer
	last_hover_id = hover_id
	hover_id = 0
	for layer, i in list {
		if .stay_alive in layer.bits {
			layer.bits -= {.stay_alive}
			if point_in_box(input.mouse_point, layer.box) {
				hover_id = layer.id
				if mouse_pressed(.left) {
					focus_id = layer.id
					if .no_sort not_in layer.options {
						sorted_layer = layer
					}
				}
			}
		} else {
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
			if child.options >= {.attached} {
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
		opacity = 0 if .invisible in options else 1,
	}
	// Append the new layer
	append(&list, layer)
	pool[id] = layer
	if stack.height > 0 {
		parent := current_layer if .attached in options else root_layer
		append(&parent.children, layer)
		layer.parent = parent
		layer.index = len(parent.children)
	}
	// Will sort layers this frame
	should_sort = true

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
	delete(self.children)
	self.reserved = false
}

// Frame info
Frame_Info :: struct {
	layout_size: [2]f32,
	options: Layer_Options,
	fill_color: Maybe(Color),
	scrollbar_padding: Maybe(f32),
}
@(deferred_out=_do_frame)
do_frame :: proc(info: Frame_Info, loc := #caller_location) -> (ok: bool) {
	self: ^Layer
	box := layout_next(current_layout())
	self, ok = begin_layer({
		box = box,
		inner_box = shrink_box(box, info.scrollbar_padding.? or_else 0),
		layout_size = info.layout_size, 
		id = hash(loc), 
		options = info.options + {.clip_to_parent, .attached},
	})
	return
}
@private
_do_frame :: proc(ok: bool) {
	if ok {
		assert(core.layer_agent.current_layer != nil)
		paint_box_stroke(core.layer_agent.current_layer.box, 1, get_color(.base_stroke))
		end_layer(core.layer_agent.current_layer)
	}
}

Layer_Info :: struct {
	box: Maybe(Box),
	inner_box: Maybe(Box),
	layout_size: Maybe([2]f32),
	order: Maybe(Layer_Order),
	options: Layer_Options,
	id: Maybe(Id),
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
@private 
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

		// Begin id context for layer contents
		if .no_id not_in self.options {
			push_id(self.id)
			self.bits += {.did_push_id}
		} else {
			self.bits -= {.did_push_id}
		}

		// Reset stuff
		self.bits += {.stay_alive}
		self.command_offset = 0

		// Get box
		self.box = info.box.? or_else self.box
		self.inner_box = info.inner_box.? or_else self.box

		// Hovering and stuff
		self.state = self.next_state
		self.next_state = {}
		if agent.hover_id == self.id {
			self.state += {.hovered}
			if agent.last_hover_id != self.id {
				self.state += {.got_hover}
			}
		} else if agent.last_hover_id == self.id {
			self.state += {.lost_hover}
		}
		if agent.focus_id == self.id {
			self.state += {.focused}
		}

		// Attachment
		if .attached in self.options {
			assert(self.parent != nil)
			parent := self.parent
			for parent != nil {
				parent.next_state += self.state
				if .attached not_in parent.options {
					break
				}
				parent = parent.parent
			}
		}

		// Update clip status
		self.bits -= {.clipped}
		if .clip_to_parent in self.options && self.parent != nil && !box_in_box(self.parent.box, self.box) {
			self.box = clamp_box(self.box, self.parent.box)
		}

		// Shadows
		if .shadow in self.options {
			paint_rounded_box_fill(move_box(self.box, SHADOW_OFFSET), WINDOW_ROUNDNESS, get_color(.shadow))
		}
		self.clip_command = push_command(self, Command_Clip)
		self.clip_command.box = core.fullscreen_box

		// Get layout size
		self.layout_size = info.layout_size.? or_else self.layout_size
		self.layout_size = {
			max(self.layout_size.x, self.box.w),
			max(self.layout_size.y, self.box.h),
		}

		// Detect scrollbar necessity
		SCROLL_LERP_SPEED :: 7

		// Horizontal scrolling
		if self.layout_size.x > self.box.w && .no_scroll_x not_in self.options {
			self.bits += {.scroll_x}
			self.x_scroll_time = min(1, self.x_scroll_time + core.delta_time * SCROLL_LERP_SPEED)
		} else {
			self.bits -= {.scroll_x}
			self.x_scroll_time = max(0, self.x_scroll_time - core.delta_time * SCROLL_LERP_SPEED)
		}
		if .no_scroll_margin_y not_in self.options && self.layout_size.y <= self.box.h {
			self.layout_size.y -= self.x_scroll_time * SCROLL_BAR_SIZE
		}
		if self.x_scroll_time > 0 && self.x_scroll_time < 1 {
			core.paint_next_frame = true
		}

		// Vertical scrolling
		if self.layout_size.y > self.box.h && .no_scroll_y not_in self.options {
			self.bits += {.scroll_y}
			self.y_scroll_time = min(1, self.y_scroll_time + core.delta_time * SCROLL_LERP_SPEED)
		} else {
			self.bits -= {.scroll_y}
			self.y_scroll_time = max(0, self.y_scroll_time - core.delta_time * SCROLL_LERP_SPEED)
		}
		if .no_scroll_margin_x not_in self.options && self.layout_size.x <= self.box.w {
			self.layout_size.x -= self.y_scroll_time * SCROLL_BAR_SIZE
		}
		if self.y_scroll_time > 0 && self.y_scroll_time < 1 {
			core.paint_next_frame = true
		}
		self.content_box = {self.box.x + self.box.w, self.box.y + self.box.h, 0, 0}

		// Layers currently have their own layouts, but this is subject to change
		layout_box: Box = {
			self.box.x - self.scroll.x,
			self.box.y - self.scroll.y,
			self.layout_size.x,
			self.layout_size.y,
		}
		push_layout(layout_box)
	}
	return
}
// Called for every 'BeginLayer' that is called
@private 
end_layer :: proc(self: ^Layer) {
	if self != nil {
		// Debug stuff
		when ODIN_DEBUG {
			if .show_window in core.debug_bits && self.id != 0 && core.layer_agent.debug_id == self.id {
				paint_box_fill(self.box, {255, 0, 255, 20})
				paint_box_stroke(self.box, 1, {255, 0, 255, 255})
			}
		}

		// Detect clipping
		if (self.box != core.fullscreen_box && !box_in_box(self.box, self.content_box)) || .force_clip in self.options {
			self.bits += {.clipped}
		}

		// End layout
		pop_layout()

		// Handle scrolling
		SCROLL_SPEED :: 16
		SCROLL_STEP :: 55

		// Maximum scroll offset
		max_scroll: [2]f32 = {
			max(self.layout_size.x - self.box.w, 0),
			max(self.layout_size.y - self.box.h, 0),
		}

		// Update scroll offset
		if .hovered in self.state {
			self.scroll_target -= input.mouse_scroll * SCROLL_STEP
		}
		self.scroll_target.x = clamp(self.scroll_target.x, 0, max_scroll.x)
		self.scroll_target.y = clamp(self.scroll_target.y, 0, max_scroll.y)
		if linalg.floor(self.scroll_target - self.scroll) != {} {
			core.paint_next_frame = true
		}
		self.scroll += (self.scroll_target - self.scroll) * SCROLL_SPEED * core.delta_time

		// Manifest scroll bars
		if self.x_scroll_time > 0 {
			box := get_box_bottom(self.inner_box, self.x_scroll_time * SCROLL_BAR_SIZE)
			box.w -= self.y_scroll_time * SCROLL_BAR_SIZE
			box.h -= SCROLL_BAR_PADDING
			box.x += SCROLL_BAR_PADDING
			box.w -= SCROLL_BAR_PADDING * 2
			set_next_box(box)
			if changed, new_value := scrollbar({
				value = self.scroll.x, 
				low = 0, 
				high = max_scroll.x, 
				thumb_size = max(SCROLL_BAR_SIZE * 2, box.w * self.box.w / self.layout_size.x),
			}); changed {
				self.scroll.x = new_value
				self.scroll_target.x = new_value
			}
		}
		if self.y_scroll_time > 0 {
			box := get_box_right(self.inner_box, self.y_scroll_time * SCROLL_BAR_SIZE)
			box.h -= self.x_scroll_time * SCROLL_BAR_SIZE
			box.w -= SCROLL_BAR_PADDING
			box.y += SCROLL_BAR_PADDING
			box.h -= SCROLL_BAR_PADDING * 2
			set_next_box(box)
			if change, new_value := scrollbar({
				value = self.scroll.y, 
				low = 0, 
				high = max_scroll.y, 
				thumb_size = max(SCROLL_BAR_SIZE * 2, box.h * self.box.h / self.layout_size.y), 
				vertical = true,
			}); change {
				self.scroll.y = new_value
				self.scroll_target.y = new_value
			}
		}

		// Handle content clipping
		if .clipped in self.bits {
			// Apply clipping
			assert(self.clip_command != nil)
			self.box.h = max(0, self.box.h)
			self.clip_command.box = self.box
		}
		// Push a new clip command to end clipping
		push_command(self, Command_Clip).box = core.fullscreen_box
		
		if .attached in self.options {
			self.parent.content_box = update_bounding_box(self.parent.content_box, self.inner_box)
		}
		
		// End id context
		if .did_push_id in self.bits {
			pop_id()
		}
	}
	layer_agent_pop(&core.layer_agent)
}
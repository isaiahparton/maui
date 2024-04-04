package maui
import "core:fmt"
import "core:slice"
import "core:runtime"
import "core:math"
import "core:math/linalg"
/*
	Layers are the root of all gui
*/
MAX_LAYERS :: 128
SCROLL_SPEED :: 16
SCROLL_STEP :: 20
SCROLL_BAR_SIZE :: 12
SCROLL_BAR_PADDING :: 0
// Layer interaction state
Layer_Status :: enum {
	Hovered,
	Focused,
}
Layer_State :: bit_set[Layer_Status;u8]
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
Layer_Bits :: bit_set[Layer_Bit;u8]
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
	// Always in the foreground, fixed order
	Tooltip,
	// Special layer for debug drawing
	Debug,
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
Layer_Mesh_Index :: enum {
	Background,
	Foreground,
}
Layer_Info :: struct {
	// Explicit id assignment
	id: Maybe(Id),
	// Placement
	placement: Layer_Placement,
	// Scrollbar padding
	scrollbar_padding: Maybe([2]f32),
	// Growing layout?
	grow: Maybe(Direction),
	// Defined space or the layer size whichever is larger
	scale,
	space: Maybe([2]f32),
	// Alignment of the layout
	layout_align: [2]Alignment,
	// Sorting order
	order: Maybe(Layer_Order),
	// Optional options
	options: Layer_Options,
	// bruh
	owner: Maybe(^Widget),
	// Opacity
	opacity: Maybe(f32),
	// Clipping info
	clip_sides: Maybe(Box_Sides),
}
// A layer's own data
Layer :: struct {
	// Owner widget
	owner: Maybe(^Widget),
	// Relations
	parent: Maybe(^Layer),
	children: [dynamic]^Layer,
	// Base Data
	id: Id,
	// Internal state
	bits: Layer_Bits,
	// User options
	options: Layer_Options,
	// The layer's own state
	state,
	last_state: Layer_State,
	// Painting settings
	opacity: f32,
	// Viewport
	clip_sides: Box_Sides,
	clip_box,
	// Body
	box: Box,
	// Box on which scrollbars are anchored
	inner_box: Box,
	// Bounding box of all painted content
	content_box: Box,
	// Space for scrolling
	last_space,
	space: [2]f32,
	// Scrolling
	scroll, 
	scroll_target: [2]f32,
	scrollbar_time: [2]f32,
	// draw order
	order: Layer_Order,
	// list index
	index: int,
	// controls on this self
	contents: map[Id]^Widget,
	// Draw command
	targets: [Layer_Mesh_Index]int,
}
Layer_Agent :: struct {
	// Fixed memory arena
	arena: Arena(Layer, MAX_LAYERS),
	// Internal layer data
	list: [dynamic]^Layer,
	pool: map[Id]^Layer,
	// Layer context stack
	stack: Stack(^Layer, LAYER_STACK_SIZE),
	// Layer ordering helpers
	should_sort: bool,
	last_top_id, 
	top_id: Id,
	current: ^Layer,
	// Current layer state
	hover_id,
	last_hover_id,
	focus_id,
	last_focus_id: Id,
}
/*
	Add a layer
*/
sort_layer :: proc(list: ^[dynamic]^Layer, layer: ^Layer) {
	append(list, layer)
	if len(layer.children) > 0 {
		slice.sort_by(layer.children[:], proc(a, b: ^Layer) -> bool {
			if a.order == b.order {
				return a.index < b.index
			}
			return int(a.order) < int(b.order)
		})
		for child in layer.children do sort_layer(list, child)
	}
}

destroy_layer_agent :: proc(using self: ^Layer_Agent) {
	for entry in list {
		destroy_layer(entry)
	}
	delete(pool)
	delete(list)
	self^ = {}
}
/*
	Update a layer agent
*/
update_layers :: proc(ui: ^UI) {
	sorted_layer: ^Layer
	ui.layers.last_focus_id = ui.layers.focus_id
	ui.layers.last_hover_id = ui.layers.hover_id
	ui.layers.hover_id = 0
	for layer, i in ui.layers.list {
		if .Stay_Alive in layer.bits {
			layer.bits -= {.Stay_Alive}
			if point_in_box(ui.io.mouse_point, layer.clip_box) {
				ui.layers.hover_id = layer.id
				if mouse_pressed(ui.io, .Left) {
					ui.layers.focus_id = layer.id
					if .No_Sorting not_in layer.options {
						sorted_layer = layer
					}
				}
			}
		} else {
			when ODIN_DEBUG && PRINT_DEBUG_EVENTS {
				fmt.printf("- Layer %x\n", layer.id)
			}
			delete_key(&ui.layers.pool, layer.id)
			if parent, ok := layer.parent.?; ok {
				for child, j in parent.children {
					if child == layer {
						ordered_remove(&parent.children, j)
						break
					}
				}
			}
			destroy_layer(layer)
			(transmute(^Maybe(Layer))layer)^ = nil
			ui.layers.should_sort = true
			ui.painter.next_frame = true
		}
	}
	// If a sorted layer was selected, then find it's root attached parent
	if sorted_layer != nil {
		child := sorted_layer
		for {
			if parent, ok := child.parent.?; ok {
				ui.layers.top_id = child.id
				sorted_layer = child
				child = parent
			} else {
				break
			}
		}
	}
	// Then reorder it with it's siblings
	if ui.layers.top_id != ui.layers.last_top_id {
		if parent, ok := sorted_layer.parent.?; ok {
			for child in parent.children {
				if child.order == sorted_layer.order {
					if child.id == ui.layers.top_id {
						child.index = len(parent.children)
					} else {
						child.index -= 1
					}
				}
			}
		}
		ui.layers.should_sort = true
		ui.layers.last_top_id = ui.layers.top_id
	}
	// Sort the layers
	if ui.layers.should_sort {
		ui.layers.should_sort = false

		clear(&ui.layers.list)
		sort_layer(&ui.layers.list, ui.root_layer)
	}
}

create_layer :: proc(ui: ^UI, id: Id, options: Layer_Options) -> (layer: ^Layer, ok: bool) {
	handle := arena_allocate(&ui.layers.arena) or_return
	layer = &handle.?
	ok = true
	// Initiate the layer
	layer^ = {
		id = id,
		opacity = 0 if .Invisible in options else 1,
	}
	// Append the new layer
	append(&ui.layers.list, layer)
	ui.layers.pool[id] = layer
	if ui.layers.stack.height > 0 {
		parent := ui.layers.current if .Attached in options else ui.root_layer
		append(&parent.children, layer)
		layer.parent = parent
		layer.index = len(parent.children)
	}
	// Will sort layers this frame
	ui.layers.should_sort = true
	ui.painter.next_frame = true
	// Debug info
	when ODIN_DEBUG && PRINT_DEBUG_EVENTS {
		fmt.printf("+ Layer %x\n", id)
	}
	return
}

get_layer :: proc(ui: ^UI, id: Id, options: Layer_Options) -> (layer: ^Layer, ok: bool) {
	layer, ok = ui.layers.pool[id]
	if !ok {
		layer, ok = create_layer(ui, id, options)
	}
	return
}

push_layer :: proc(ui: ^UI, layer: ^Layer) {
	stack_push(&ui.layers.stack, layer)
	ui.layers.current = ui.layers.stack.items[ui.layers.stack.height - 1] if ui.layers.stack.height > 0 else nil
}

pop_layer :: proc(ui: ^UI) {
	stack_pop(&ui.layers.stack)
	ui.layers.current = ui.layers.stack.items[ui.layers.stack.height - 1] if ui.layers.stack.height > 0 else nil
}

destroy_layer :: proc(self: ^Layer) {
	delete(self.contents)
	delete(self.children)
	self^ = {}
}

@(deferred_in_out=_do_layer)
do_layer :: proc(ui: ^UI, info: Layer_Info, loc := #caller_location) -> (self: ^Layer, ok: bool) {
	info := info
	info.id = info.id.? or_else hash(ui, loc)
	return begin_layer(ui, info)
}

@private
_do_layer :: proc(ui: ^UI, _: Layer_Info, _: runtime.Source_Code_Location, self: ^Layer, ok: bool) {
	if ok {
		end_layer(ui, self)
	}
}

current_layer :: proc(ui: ^UI, loc := #caller_location) -> ^Layer {
	assert(ui.layers.current != nil, "", loc)
	return ui.layers.current
}
// Begins a new layer, the layer is created if it doesn't exist
// and is managed internally
begin_layer :: proc(ui: ^UI, info: Layer_Info, loc := #caller_location) -> (self: ^Layer, ok: bool) {
	agent := &ui.layers

	if self, ok = get_layer(ui, info.id.? or_else panic("Must define a layer id", loc), info.options); ok {
		// Push layer stack
		push_layer(ui, self)
		// Set sort order
		self.order = info.order.? or_else self.order
		// Update user options
		self.options = info.options
		self.owner = info.owner
		// Begin id context for layer contents
		if .No_ID not_in self.options {
			push_id(ui, self.id)
			self.bits += {.Did_Push_ID}
		} else {
			self.bits -= {.Did_Push_ID}
		}
		self.clip_sides = info.clip_sides.? or_else Box_Sides{.Bottom, .Top, .Left, .Right}
		// Get box
		switch placement in info.placement {
			case Box: 
			self.box = placement
			self.box.high = linalg.max(self.box.high, self.box.low)
			case Layer_Placement_Info: 
			// Use space if size is not provided
			size: [2]f32 = {
				placement.size.x.? or_else self.space.x,
				placement.size.y.? or_else self.space.y,
			}
			if scale, ok := info.scale.?; ok {
				size *= scale
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
		self.box.low = linalg.floor(self.box.low)
		self.box.high = linalg.floor(self.box.high)
		// Stay alive
		self.bits += {.Stay_Alive}
		//IMPORTANT: Set opacity before painting anything
		self.opacity = info.opacity.? or_else self.opacity
		ui.painter.opacity = self.opacity
		// Append draw target
		self.targets[.Background] = get_draw_target(ui.painter) or_return
		ui.painter.target = get_draw_target(ui.painter) or_return
		self.targets[.Foreground] = ui.painter.target
		// Apply inner padding
		self.inner_box = shrink_box(self.box, info.scrollbar_padding.? or_else 0)
		// Hovering and stuff
		self.last_state = self.state
		self.state = {}
		if agent.hover_id == self.id {
			self.state += {.Hovered}
		}
		if agent.focus_id == self.id {
			self.state += {.Focused}
		}
		// Update clip status
		self.bits -= {.Clipped}
		// Scrolling
		SCROLL_LERP_SPEED :: 7
		// Horizontal scrolling
		if (self.space.x > width(self.box)) && (.No_Scroll_X not_in self.options) {
			self.bits += {.Scroll_X}
			self.scrollbar_time.x = min(1, self.scrollbar_time.x + ui.delta_time * SCROLL_LERP_SPEED)
		} else {
			self.bits -= {.Scroll_X}
			self.scrollbar_time.x = max(0, self.scrollbar_time.x - ui.delta_time * SCROLL_LERP_SPEED)
		}
		if .No_Scroll_Margin_Y not_in self.options && self.space.y <= height(self.box) {
			self.space.y -= self.scrollbar_time.x * SCROLL_BAR_SIZE
		}
		if self.scrollbar_time.x > 0 && self.scrollbar_time.x < 1 {
			ui.painter.next_frame = true
		}
		// Vertical scrolling
		if (self.space.y > height(self.box)) && (.No_Scroll_Y not_in self.options) {
			self.bits += {.Scroll_Y}
			self.scrollbar_time.y = min(1, self.scrollbar_time.y + ui.delta_time * SCROLL_LERP_SPEED)
		} else {
			self.bits -= {.Scroll_Y}
			self.scrollbar_time.y = max(0, self.scrollbar_time.y - ui.delta_time * SCROLL_LERP_SPEED)
		}
		if .No_Scroll_Margin_X not_in self.options && self.space.x <= width(self.box) {
			self.space.x -= self.scrollbar_time.y * SCROLL_BAR_SIZE
		}
		if self.scrollbar_time.y > 0 && self.scrollbar_time.y < 1 {
			ui.painter.next_frame = true
		}
		self.content_box = {self.box.high, self.box.low}
		// Clip box
		self.clip_box = self.box
		// Clip to parent's clip box
		if .Clip_To_Parent in self.options {
			if parent, ok := self.parent.?; ok {
				self.clip_box = {
					linalg.clamp(self.clip_box.low, parent.clip_box.low, parent.clip_box.high),
					linalg.clamp(self.clip_box.high, parent.clip_box.low, parent.clip_box.high),
				}
			}
		}
		// Save last space for layout alignment
		self.last_space = self.space
		// Get layout size
		self.space = info.space.? or_else 0
		// Get space
		self.space = linalg.max(self.space, self.box.high - self.box.low)
		// Copy box
		layout_box := Box{self.box.low, {}}
		// Layout alignment
		switch info.layout_align.x {
			case .Middle:
			layout_box.low.x = center_x(self.box) - self.last_space.x / 2
			case .Far:
			layout_box.low.x = self.box.high.x - self.last_space.x
			case .Near:
			layout_box.low.x = self.box.low.x
		}
		switch info.layout_align.y {
			case .Middle:
			layout_box.low.y = center_y(self.box) - self.last_space.y / 2
			case .Far:
			layout_box.low.y = self.box.high.y - self.last_space.y
			case .Near:
			layout_box.low.y = self.box.low.y
		}
		// Apply scroll offset
		layout_box.low -= self.scroll
		// Set size
		layout_box.high = layout_box.low + self.space
		// Apply scroll padding
		layout_box.high -= self.scrollbar_time * SCROLL_BAR_SIZE
		// Push layout
		layout := push_layout(ui, layout_box)
		// Extending layout
		if direction, ok := info.grow.?; ok {
			#partial switch direction {
				case .Down:
				layout.box.high.y = layout.box.low.y
				case .Up:
				layout.box.low.y = layout.box.high.y
				case .Left:
				layout.box.low.x = layout.box.high.x
				case .Right:
				layout.box.high.x = layout.box.low.x
			}
			layout.grow = direction
		}
	}
	return
}
// Called for every 'begin_layer' that is called
end_layer :: proc(ui: ^UI, self: ^Layer) {
	if self != nil {
		// Pop layout
		layout := current_layout(ui)
		if layout.grow != nil {
			self.space = layout.box.high - layout.original_box.low
		}
		pop_layout(ui)
		// Detect clipping
		new_clip_box := self.box
		if .Clip_To_Parent in self.options {
			if parent, ok := self.parent.?; ok {
				if !box_in_box(self.box, parent.box) {
					self.bits += {.Clipped}
					new_clip_box = {
						linalg.clamp(new_clip_box.low, parent.box.low, parent.box.high),
						linalg.clamp(new_clip_box.high, parent.box.low, parent.box.high),
					}
				}
			}
		}
		if (new_clip_box != Box{{}, ui.size} && !box_in_box(new_clip_box, self.content_box)) || (.Force_Clip in self.options) {
			self.bits += {.Clipped}
		}
		// Is clipping needed?
		if .Clipped in self.bits {
			// Set the layer's clip box here as it is what the cursor is tested against
			self.clip_box = new_clip_box
			if .Top not_in self.clip_sides {
				new_clip_box.low.y = 0
			}
			if .Bottom not_in self.clip_sides {
				new_clip_box.high.y = ui.size.y
			}
			if .Left not_in self.clip_sides {
				new_clip_box.low.x = 0
			}
			if .Right not_in self.clip_sides {
				new_clip_box.high.x = ui.size.x
			}
		}
		// Set the real clipping here
		ui.painter.meshes[ui.painter.target].clip = new_clip_box
		// Maximum scroll offset
		max_scroll: [2]f32 = {
			max(self.space.x - (self.box.high.x - self.box.low.x), 0),
			max(self.space.y - (self.box.high.y - self.box.low.y), 0),
		}
		// Mouse wheel input
		if .Hovered in self.state {
			self.scroll_target -= ui.io.mouse_scroll * SCROLL_STEP * {f32(int(.No_Scroll_X not_in self.options)), f32(int(.No_Scroll_Y not_in self.options))}
		}
		// Repaint if scrolling with wheel
		if linalg.floor(self.scroll_target - self.scroll) != {} {
			ui.painter.next_frame = true
		}
		// Clamp scrolling
		self.scroll_target.x = clamp(self.scroll_target.x, 0, max_scroll.x)
		self.scroll_target.y = clamp(self.scroll_target.y, 0, max_scroll.y)
		// Interpolate scrolling
		self.scroll += (self.scroll_target - self.scroll) * SCROLL_SPEED * ui.delta_time
		// Manifest scroll bars
		if self.scrollbar_time.x > 0 {
			// Horizontal scrolling
			box := get_box_bottom(self.inner_box, self.scrollbar_time.x * SCROLL_BAR_SIZE)
			box.high.x -= self.scrollbar_time.y * SCROLL_BAR_SIZE + SCROLL_BAR_PADDING * 2
			box.high.y -= SCROLL_BAR_PADDING
			box.low.x += SCROLL_BAR_PADDING
			if result := scrollbar(ui, {
				box = box,
				value = self.scroll.x, 
				low = 0, 
				high = max_scroll.x, 
				knob_size = max(SCROLL_BAR_SIZE * 2, width(box) * width(self.box) / self.space.x),
			}); result.changed {
				self.scroll.x = result.value
				self.scroll_target.x = result.value
			}
		}
		if self.scrollbar_time.y > 0 {
			// Vertical scrolling
			box := get_box_right(self.inner_box, self.scrollbar_time.y * SCROLL_BAR_SIZE)
			box.high.y -= self.scrollbar_time.x * SCROLL_BAR_SIZE + SCROLL_BAR_PADDING * 2
			box.high.x -= SCROLL_BAR_PADDING
			box.low.y += SCROLL_BAR_PADDING
			if result := scrollbar(ui, {
				box = box,
				value = self.scroll.y, 
				low = 0, 
				high = max_scroll.y, 
				knob_size = max(SCROLL_BAR_SIZE * 2, height(box) * height(self.box) / self.space.y), 
				vertical = true,
			}); result.changed {
				self.scroll.y = result.value
				self.scroll_target.y = result.value
			}
		}
		// Handle content clipping
		if .Clipped in self.bits {
			// Apply clipping
			self.box.high = linalg.max(self.box.low, self.box.high)
		}
		// Update parent content bounds if
		if .Attached in self.options {
			if parent, ok := self.parent.?; ok {
				parent.state += self.state
				parent.content_box = update_bounding_box(parent.content_box, self.content_box)
			}
		}
		// End id context
		if .Did_Push_ID in self.bits {
			pop_id(ui)
		}
	}
	pop_layer(ui)
	if ui.layers.stack.height > 0 {
		layer := current_layer(ui)

		ui.painter.opacity = layer.opacity
		ui.painter.target = layer.targets[.Foreground]
	}
}

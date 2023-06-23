package maui

import "core:fmt"
import "core:runtime"
import "core:sort"
import "core:slice"
import "core:reflect"
import "core:time"

import "core:strconv"
import "core:unicode"
import "core:unicode/utf8"

import "core:math"
import "core:math/linalg"

import rl "vendor:raylib"

Cursor_Type :: enum {
	none = -1,
	default,
	arrow,
	beam,
	crosshair,
	hand,
	resizeEW,
	resizeNS,
	resizeNWSE,
	resizeNESW,
	resizeAll,
	disabled,
}

RENDER_TIMEOUT 		:: 0.5

FMT_BUFFER_COUNT 	:: 16
FMT_BUFFER_SIZE 	:: 128

TEMP_BUFFER_COUNT 	:: 2
GROUP_STACK_SIZE 	:: 32
LAYER_ARENA_SIZE 	:: 128
MAX_CLIP_RECTS 		:: #config(MAUI_MAX_CLIP_RECTS, 32)
MAX_CONTROLS 		:: #config(MAUI_MAX_CONTROLS, 1024)
LAYER_STACK_SIZE 	:: #config(MAUI_LAYER_STACK_SIZE, 32)
WINDOW_STACK_SIZE 	:: #config(MAUI_WINDOW_STACK_SIZE, 32)
// Maximum layout depth (times you can call push_layout())
MAX_LAYOUTS 		:: #config(MAUI_MAX_LAYOUTS, 32)
// Size of each layer's command buffer
COMMAND_BUFFER_SIZE :: #config(MAUI_COMMAND_BUFFER_SIZE, 256 * 1024)
// Size of id stack (times you can call PushId())
ID_STACK_SIZE 		:: 32
// Repeating key press
KEY_REPEAT_DELAY 	:: 0.5
KEY_REPEAT_RATE 	:: 30
ALL_CORNERS: Box_Corners = {.topLeft, .topRight, .bottomLeft, .bottomRight}

DOUBLE_CLICK_TIME :: time.Millisecond * 200

Color :: [4]u8

Animation :: struct {
	keep_alive: bool,
	value,
	last_value: f32,
}

Text_Buffer :: struct {
	keep_alive: bool,
	buffer: [dynamic]u8,
}

Scribe :: struct {
	index, length, anchor: int,
	last_index, last_length: int,
	offset: [2]f32,
}

Group :: struct {
	state: WidgetState,
}

@private
Debug_Mode :: enum {
	layers,
	windows,
	controls,
}
@private
Debug_Bit :: enum {
	show_window,
}
@private
DebugBits :: bit_set[DebugBit]


Core :: struct {
	// Debugification
	frame_start_time: time.Time,
	frame_duration: time.Duration,

	debug_bits: Debug_Bits,
	debug_mode: Debug_Mode,

	// Widget groups collect information from widgets inside them
	group_depth: 	int,
	groups: 		[GROUP_STACK_SIZE]Group,

	// Core
	current_time,
	delta_time: f32,
	disabled, 
	dragging, 
	is_key_selecting: bool,

	// Should ui be repainted
	painted_last_frame,
	paint_this_frame, 
	paint_next_frame: bool,

	// Uh
	size: [2]f32,
	last_box, fullscreen_box: Box,

	// Values to be used by the next widget
	tooltip_was_attached: bool,
	tooltip_text: string,
	tooltip_side: Box_Side,

	// Text editing/selecting state
	scribe: Scribe,

	// Temporary text buffers
	text_buffers: map[Id]Text_Buffer,

	// Mouse cursor type
	cursor: Cursor_Type,

	// Hash stack
	id_stack: [ID_STACK_SIZE]Id,
	id_count: int,

	// Retained animation values
	animations: map[Id]Animation,

	// Retained control data
	widgets: 			[dynamic]^Widget,
	current_widget:  	^Widget,
	// Internal window data
	windows: 			[dynamic]^Window,
	window_map: 		map[Id]^Window,
	// Window context stack
	window_stack: 		[WINDOW_STACK_SIZE]^Window,
	window_depth: 		int,
	// Current window data
	current_window:		^Window,

	// First layer
	root_layer: 		^Layer,

	// Fixed storage for layers
	layerArena:  		[LAYER_ARENA_SIZE]Layer,
	layerReserved: 		[LAYER_ARENA_SIZE]bool,
	// Internal layer data
	layer_list: 		[dynamic]^Layer,
	layer_map: 			map[Id]^Layer,
	// Layer context stack
	layer_stack: 		[LAYER_STACK_SIZE]^Layer,
	layer_depth: 		int,
	// Layer ordering helpers
	should_sort_layers:			bool,
	last_top_layer, top_layer: Id,
	current_layer: ^Layer,
	// Current layer being drawn (used only by 'NextCommand')
	hot_layer: int,
	// Current layer state
	hovered_layer, 
	last_hovered_layer,
	focused_layer: Id,
	debug_layer: Id,
	// Used for dragging stuff
	dragAnchor: [2]f32,
	// Layout
	layouts: [MAX_LAYOUTS]Layout,
	layout_depth: int,
	// Current clip rect
	clip_box: Box,
	// Next control options
	next_id: Id,
	next_box: Maybe(Box),
	// Widget interactions
	last_hover_id, 
	next_hover_id, 
	hover_id, 
	last_press_id, 
	press_id, 
	next_focus_fd,
	focus_id,
	last_focus_id: Id,
}

_get_clipboard_string: proc() -> string = ---
_set_clipboard_string: proc(string) = ---

get_clipboard_string :: proc() -> string {
	if _get_clipboard_string != nil {
		return _get_clipboard_string()
	}
	return {}
}
set_clipboard_string :: proc(str: string) {
	if _set_clipboard_string != nil {
		_set_clipboard_string(str)
	}
}

@(deferred_none=_enabled)
enabled :: proc(condition: bool) -> bool {
	if !condition {
		core.disabled = true
	}
	return true
}
@private
_enabled :: proc() {
	core.disabled = false
}

current_widget :: proc() -> ^Widget {
	assert(core.current_widget != nil, "There is no widget")
	return core.current_widget
}

begin_group :: proc() {
	using ctx
	groups[groupDepth] = {}
	groupDepth += 1
}
end_group :: proc() -> ^Group {
	using ctx
	groupDepth -= 1
	return &groups[groupDepth]
}

get_text_buffer :: proc(id: Id) -> ^[dynamic]u8 {
	value, ok := &core.textBuffers[id]
	if !ok {
		value = map_insert(&core.textBuffers, id, TextBuffer({}))
		ok = true
	}
	value.keep_alive = true
	return &value.buffer
}

/*
	Animation management
*/
animate_bool :: proc(id: Id, condition: bool, duration: f32) -> f32 {
	animation, ok := &core.animations[id]
	if !ok {
		animation = map_insert(&core.animations, id, Animation({
			value = f32(int(condition)),
		}))
	}
	animation.keep_alive = true
	if condition {
		animation.value = min(1, animation.value + core.deltaTime / duration)
	} else {
		animation.value = max(0, animation.value - core.deltaTime / duration)
	}
	return animation.value
}
get_animation :: proc(id: Id) -> ^f32 {
	if id not_in core.animations {
		core.animations[id] = {}
	}
	animation := &core.animations[id]
	animation.keep_alive = true
	return &animation.value
}

/*
	The global state

	TODO(isaiah): Add manual state swapping
*/
set_next_id :: proc(id: Id) {
	core.nextId = id
}
use_next_id :: proc() -> (id: Id, ok: bool) {
	id = core.nextId
	ok = core.nextId != 0
	return
}

get_screen_point :: proc(h, v: f32) -> [2]f32 {
	return {h * f32(core.size.x), v * f32(core.size.y)}
}
set_screen_size :: proc(w, h: f32) {
	core.size = {w, h}
}

core_init :: proc() -> bool {
	if core == nil {
		core = new(Core)
		// Load graphics
		if !painter_init() {
			return false
		}
		return true
	}
	return false
}
core_uninit :: proc() {
	if core != nil {
		// Free widgets
		for widget in &core.widgets {
			free(widget)
		}
		delete(core.widgets)
		// Free text buffers
		for _, value in core.textBuffers {
			delete(value.buffer)
		}
		delete(core.textBuffers)
		// Free animation pool
		delete(core.animations)
		// Free window data
		for window in core.windows {
			delete_window(window)
		}
		delete(core.windowMap)
		delete(core.windows)
		// Free layer data
		for layer in core.layers {
			DeleteLayer(layer)
		}
		delete(core.layerMap)
		delete(core.layers)
		//
		painter_uninit()
		//
		free(core)
	}
}
core_begin_frame :: proc() {
	using ctx

	// Begin frame
	frameStartTime = time.now()
	// Swap painting bools
	paint_this_frame = false
	if paint_next_frame {
		paint_this_frame = true
		paint_next_frame = false
	}

	// Decide if rendering is needed next frame
	if input.last_mouse_point != input.mouse_point || input.last_key_bits != input.key_bits|| input.last_mouse_bits != input.mouse_bits || input.mouse_scroll != {} {
		paint_this_frame = true
	}
	// Delete unused animations
	for key, value in &animations {
		if value.keep_alive {
			value.keep_alive = false
			if value.last_value != value.value {
				paint_this_frame = true
				value.last_value = value.value
			}
		} else {
			delete_key(&animations, key)
		}
	}

	cursor = .default
	input.runeCount = 0
	// Try tell the user what went wrong if
	// a stack overflow occours
	assert(layoutDepth == 0, "You forgot to pop_layout()")
	assert(layerDepth == 0, "You forgot to PopLayer()")
	assert(idCount == 0, "You forgot to PopId()")
	// Reset fullscreen rect
	fullscreenBox = {0, 0, size.x, size.y}
	// Free and delete unused text buffers
	for key, value in &textBuffers {
		if value.keep_alive {
			value.keep_alive = false
		} else {
			delete(value.buffer)
			delete_key(&textBuffers, key)
		}
	}

	newKeys := input.key_bits - input.last_key_bits
	oldKey := input.lastKey
	for key in Key {
		if key in newKeys && key != input.lastKey {
			input.lastKey = key
			break
		}
	}
	if input.lastKey != oldKey {
		input.keyHoldTimer = 0
	}

	input.keyPulse = false
	if input.lastKey in input.key_bits {
		input.keyHoldTimer += deltaTime
	} else {
		input.keyHoldTimer = 0
	}
	if input.keyHoldTimer >= KEY_REPEAT_DELAY {
		if input.keyPulseTimer > 0 {
			input.keyPulseTimer -= deltaTime
		} else {
			input.keyPulseTimer = 1.0 / KEY_REPEAT_RATE
			input.keyPulse = true
		}
	}
	// Update control interaction ids
	prevHoverId = hoverId
	prevPressId = pressId
	prevFocusId = focusId
	hoverId = nextHoverId
	if dragging && pressId != 0 {
		hoverId = pressId
	}
	if keySelect {
		hoverId = focusId
		if KeyPressed(.enter) {
			pressId = hoverId
		}
	}
	nextHoverId = 0
	if MousePressed(.left) {
		pressId = hoverId
		focusId = pressId
	}

	currentTime += deltaTime
	// Begin root layer
	rootLayer, _ = BeginLayer({
		id = 0,
		rect = core.fullscreenBox, 
		options = {.noPushId},
	})
	// Tab through input fields
	//TODO(isaiah): Add better keyboard navigation with arrow keys
	if KeyPressed(.tab) && core.focusId != 0 {
		array: [dynamic]^Widget
		defer delete(array)

		anchor: int
		for widget in &widgets {
			if .keySelect in widget.options && .disabled not_in widget.bits {
				if widget.id == core.focusId {
					anchor = len(array)
				}
				append(&array, widget)
			}
		}

		if len(array) > 1 {
			slice.sort_by(array[:], proc(a, b: ^Widget) -> bool {
				if a.body.y == b.body.y {
					if a.body.x < b.body.x {
						return true
					}
				} else if a.body.y < b.body.y {
					return true
				}
				return false
			})
			core.focusId = array[(anchor + 1) % len(array)].id
			core.keySelect = true
		}
	}

	dragging = false

	if input.mouse_point - input.last_mouse_point != {} {
		keySelect = false
	}

	clipBox = fullscreenBox

	// Reset input bits
	input.last_key_bits = input.key_bits
	input.last_mouse_bits = input.mouse_bits
	input.last_mouse_point = input.mouse_point
}
core_end_frame :: proc() {
	using ctx
	// Built-in debug window
	when ODIN_DEBUG {
		debug_layer = 0
		if KeyDown(.control) && KeyPressed(.backspace) {
			debug_bits ~= {.show_window}
		}
		if debug_bits >= {.show_window} {
			if Window({
				title = "Debug", 
				rect = {0, 0, 500, 700}, 
				options = {.collapsable, .closable, .title, .resizable},
			}) {
				if current_widget().bits >= {.shouldClose} {
					debug_bits -= {.show_window}
				}

				set_size(30)
				debug_mode = EnumTabs(debug_mode, 0)

				shrink(10); set_size(24)
				if debug_mode == .layers {
					set_side(.bottom); set_size(TEXTURE_HEIGHT)
					if frame({
						layout_size = {TEXTURE_WIDTH, TEXTURE_HEIGHT},
						fill_color = Color{0, 0, 0, 255},
						options = {.no_scroll_margin_x, .no_scroll_margin_y},
					}) {
						paint_texture({0, 0, TEXTURE_WIDTH, TEXTURE_HEIGHT}, current_layout().rect, 255)
						layer := current_layer()
						layer.content_box = update_bounding_box(layer.content_box, current_layout().rect)
					}
					_debug_layer_widget(core.rootLayer)
				} else if debug_mode == .windows {
					for id, window in windowMap {
						push_id(window.id)
							button({
								label = format(window.id), 
								align = .near,
							})
							if current_widget().state >= {.hovered} {
								debug_layer = window.layer.id
							}
						pop_id()
					}
				} else if debug_mode == .controls {
					text({font = .monospace, text = text_format("Layer: %i", hovered_layer), fit = true})
					space(20)
					text({font = .monospace, text = text_format("Hovered: %i", hover_id), fit = true})
					text({font = .monospace, text = text_format("Focused: %i", focus_id), fit = true})
					text({font = .monospace, text = text_format("Pressed: %i", press_id), fit = true})
					space(20)
					text({font = .monospace, text = text_format("Count: %i", len(widgets)), fit = true})
				}
			}
		}
	}
	// End the root layer
	EndLayer(rootLayer)
	// Delete unused controls
	for widget, i in &widgets {
		if .stayAlive in widget.bits {
			widget.bits -= {.stayAlive}
		} else {
			for key, value in widget.layer.contents {
				if key == widget.id {
					delete_key(&widget.layer.contents, key)
				}
			}
			free(widget)
			ordered_remove(&widgets, i)
		}
	}
	// Delete unused windows
	for window, i in &windows {
		if .stayAlive in window.bits {
			window.bits -= {.stayAlive}
		} else {
			ordered_remove(&windows, i)
			delete_key(&windowMap, window.id)
			delete_window(window)
		}
	}
	// Determine hovered layer and reorder if needed
	sorted_layer: ^Layer
	last_hovered_layer = hovered_layer
	hovered_layer = 0
	for layer, i in layers {
		if .stayAlive in layer.bits {
			layer.bits -= {.stayAlive}
			if VecVsBox(input.mouse_point, layer.rect) {
				hovered_layer = layer.id
				if MousePressed(.left) {
					focusedLayer = layer.id
					sorted_layer = layer
				}
			}
		} else {
			delete_key(&layerMap, layer.id)
			if layer.parent != nil {
				for child, j in layer.parent.children {
					if child == layer {
						ordered_remove(&layer.parent.children, j)
						break
					}
				}
			}
			DeleteLayer(layer)
			sortLayers = true
		}
	}
	// If a sorted layer was selected, then find it's root attached parent
	if sorted_layer != nil {
		child := sorted_layer
		for child.parent != nil {
			top_layer = child.id
			sorted_layer = child
			if child.options >= {.attached} {
				child = child.parent
			} else {
				break
			}
		}
	}
	// Then reorder it with it's siblings
	if top_layer != last_top_layer {
		for child in sorted_layer.parent.children {
			if child.order == sorted_layer.order {
				if child.id == top_layer {
					child.index = len(sorted_layer.parent.children)
				} else {
					child.index -= 1
				}
			}
		}
		sortLayers = true
		last_top_layer = top_layer
	}
	// Sort the layers
	if sortLayers {
		sortLayers = false

		clear(&layers)
		SortLayer(&layers, rootLayer)
	}
	// Reset rendered layer
	hotLayer = 0
	paintLastFrame = paint_this_frame
	frameDuration = time.since(frameStartTime)
}
@private
_count_layer_children :: proc(layer: ^Layer) -> int {
	count: int
	for child in layer.children {
		count += 1 + _count_layer_children(child)
	}
	return count
}
@private
_debug_layer_widget :: proc(layer: ^Layer) {
	if layout(.top, 24) {
		PushId(layer.id)
			n := 0
			x := layer
			for x.parent != nil {
				x = x.parent
				n += 1
			}
			Cut(.left, f32(n) * 24); SetSide(.left); SetSize(1, true)
			Button({
				label = Format(layer.id),
				align = .near,
			})
			if CurrentWidget().state >= {.hovered} {
				core.debug_layer = layer.id
			}
		PopId()
	}
	for child in layer.children {
		_DebugLayerWidget(child)
	}
}
sort_layer :: proc(list: ^[dynamic]^Layer, layer: ^Layer) {
	append(list, layer)
	if len(layer.children) > 0 {
		slice.sort_by(layer.children[:], proc(a, b: ^Layer) -> bool {
			if a.order == b.order {
				return a.index < b.index
			}
			return int(a.order) < int(b.order)
		})
		for child in layer.children do SortLayer(list, child)
	}
}
should_render :: proc() -> bool {
	return core.paint_this_frame
}

//@private
core: ^Core
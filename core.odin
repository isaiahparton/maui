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
	resize_EW,
	resize_NS,
	resize_NWSE,
	resize_NESW,
	resize_all,
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
// Size of id stack (times you can call push_id())
ID_STACK_SIZE 		:: 32
// Repeating key press
KEY_REPEAT_DELAY 	:: 0.5
KEY_REPEAT_RATE 	:: 30
ALL_CORNERS: Box_Corners = {.top_left, .top_right, .bottom_left, .bottom_right}

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
	state: Widget_State,
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
Debug_Bits :: bit_set[Debug_Bit]

Tooltip_Info :: struct {
	text: string,
	box_side: Box_Side,
}

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
	next_tooltip: Maybe(Tooltip_Info),

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
	layer_arena:  		[LAYER_ARENA_SIZE]Layer,
	// Internal layer data
	layers: 		[dynamic]^Layer,
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
	drag_anchor: [2]f32,
	// Layout
	layouts: [MAX_LAYOUTS]Layout,
	layout_depth: int,
	// Current clip box
	clip_box: Box,
	// Next control options
	next_id: Maybe(Id),
	next_box: Maybe(Box),
	// Widget ids
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

begin_group :: proc() {
	core.groups[core.group_depth] = {}
	core.group_depth += 1
}
end_group :: proc() -> ^Group {
	core.group_depth -= 1
	return &core.groups[core.group_depth]
}

get_text_buffer :: proc(id: Id) -> ^[dynamic]u8 {
	value, ok := &core.text_buffers[id]
	if !ok {
		value = map_insert(&core.text_buffers, id, Text_Buffer({}))
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
		animation.value = min(1, animation.value + core.delta_time / duration)
	} else {
		animation.value = max(0, animation.value - core.delta_time / duration)
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
	core.next_id = id
}
use_next_id :: proc() -> (id: Id, ok: bool) {
	id, ok = core.next_id.?
	if ok {
		core.next_id = nil
	}
	return
}

get_screen_point :: proc(h, v: f32) -> [2]f32 {
	return {h * f32(core.size.x), v * f32(core.size.y)}
}
set_screen_size :: proc(w, h: f32) {
	core.size = {w, h}
}

init :: proc() -> bool {
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
uninit :: proc() {
	if core != nil {
		// Free widgets
		for widget in &core.widgets {
			free(widget)
		}
		delete(core.widgets)
		// Free text buffers
		for _, value in core.text_buffers {
			delete(value.buffer)
		}
		delete(core.text_buffers)
		// Free animation pool
		delete(core.animations)
		// Free window data
		for window in core.windows {
			delete_window(window)
		}
		delete(core.window_map)
		delete(core.windows)
		// Free layer data
		for layer in core.layers {
			delete_layer(layer)
		}
		delete(core.layer_map)
		delete(core.layers)
		//
		painter_uninit()
		//
		free(core)
	}
}
begin_frame :: proc() {
	using core

	// Begin frame
	frame_start_time = time.now()
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
	input.rune_count = 0
	// Try tell the user what went wrong if
	// a stack overflow occours
	assert(layout_depth == 0, "You forgot to pop_layout()")
	assert(layer_depth == 0, "You forgot to PopLayer()")
	assert(id_count == 0, "You forgot to PopId()")
	// Reset fullscreen box
	fullscreen_box = {0, 0, size.x, size.y}
	// Free and delete unused text buffers
	for key, value in &text_buffers {
		if value.keep_alive {
			value.keep_alive = false
		} else {
			delete(value.buffer)
			delete_key(&text_buffers, key)
		}
	}

	new_keys := input.key_bits - input.last_key_bits
	old_key := input.last_key
	for key in Key {
		if key in new_keys && key != input.last_key {
			input.last_key = key
			break
		}
	}
	if input.last_key != old_key {
		input.key_hold_timer = 0
	}

	input.key_pulse = false
	if input.last_key in input.key_bits {
		input.key_hold_timer += delta_time
	} else {
		input.key_hold_timer = 0
	}
	if input.key_hold_timer >= KEY_REPEAT_DELAY {
		if input.key_pulse_timer > 0 {
			input.key_pulse_timer -= delta_time
		} else {
			input.key_pulse_timer = 1.0 / KEY_REPEAT_RATE
			input.key_pulse = true
		}
	}
	// Update control interaction ids
	last_hover_id = hover_id
	last_press_id = press_id
	last_focus_id = focus_id
	hover_id = next_hover_id
	if dragging && press_id != 0 {
		hover_id = press_id
	}
	if is_key_selecting {
		hover_id = focus_id
		if key_pressed(.enter) {
			press_id = hover_id
		}
	}
	next_hover_id = 0
	if mouse_pressed(.left) {
		press_id = hover_id
		focus_id = press_id
	}

	current_time += delta_time
	// Begin root layer
	root_layer, _ = begin_layer({
		id = 0,
		box = core.fullscreen_box, 
		options = {.no_id},
	})
	// Tab through input fields
	//TODO(isaiah): Add better keyboard navigation with arrow keys
	if key_pressed(.tab) && core.focus_id != 0 {
		array: [dynamic]^Widget
		defer delete(array)

		anchor: int
		for widget in &widgets {
			if .can_key_select in widget.options && .disabled not_in widget.bits {
				if widget.id == core.focus_id {
					anchor = len(array)
				}
				append(&array, widget)
			}
		}

		if len(array) > 1 {
			slice.sort_by(array[:], proc(a, b: ^Widget) -> bool {
				if a.box.y == b.box.y {
					if a.box.x < b.box.x {
						return true
					}
				} else if a.box.y < b.box.y {
					return true
				}
				return false
			})
			core.focus_id = array[(anchor + 1) % len(array)].id
			core.is_key_selecting = true
		}
	}

	dragging = false

	if input.mouse_point - input.last_mouse_point != {} {
		is_key_selecting = false
	}

	clip_box = fullscreen_box

	// Reset input bits
	input.last_key_bits = input.key_bits
	input.last_mouse_bits = input.mouse_bits
	input.last_mouse_point = input.mouse_point
}
end_frame :: proc() {
	using core
	// Built-in debug window
	when ODIN_DEBUG {
		debug_layer = 0
		if key_down(.control) && key_pressed(.backspace) {
			debug_bits ~= {.show_window}
		}
		if debug_bits >= {.show_window} {
			if window({
				title = "Debug", 
				box = {0, 0, 500, 700}, 
				options = {.collapsable, .closable, .title, .resizable},
			}) {
				if current_window.bits >= {.should_close} {
					debug_bits -= {.show_window}
				}

				set_size(30)
				debug_mode = enum_tabs(debug_mode, 0)

				shrink(10); set_size(24)
				if debug_mode == .layers {
					set_side(.bottom); set_size(TEXTURE_HEIGHT)
					if frame({
						layout_size = {TEXTURE_WIDTH, TEXTURE_HEIGHT},
						fill_color = Color{0, 0, 0, 255},
						options = {.no_scroll_margin_x, .no_scroll_margin_y},
					}) {
						paint_texture({0, 0, TEXTURE_WIDTH, TEXTURE_HEIGHT}, current_layout().box, 255)
						current_layer.content_box = update_bounding_box(current_layer.content_box, current_layout().box)
					}
					_debug_layer_widget(core.root_layer)
				} else if debug_mode == .windows {
					for id, window in window_map {
						push_id(window.id)
							button({
								label = format(window.id), 
								align = .near,
							})
							if current_widget.state >= {.hovered} {
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
	end_layer(root_layer)
	// Delete unused controls
	for widget, i in &widgets {
		if .stay_alive in widget.bits {
			widget.bits -= {.stay_alive}
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
		if .stay_alive in window.bits {
			window.bits -= {.stay_alive}
		} else {
			ordered_remove(&windows, i)
			delete_key(&window_map, window.id)
			delete_window(window)
		}
	}
	// Determine hovered layer and reorder if needed
	sorted_layer: ^Layer
	last_hovered_layer = hovered_layer
	hovered_layer = 0
	for layer, i in layers {
		if .stay_alive in layer.bits {
			layer.bits -= {.stay_alive}
			if point_in_box(input.mouse_point, layer.box) {
				hovered_layer = layer.id
				if mouse_pressed(.left) {
					focused_layer = layer.id
					sorted_layer = layer
				}
			}
		} else {
			delete_key(&layer_map, layer.id)
			if layer.parent != nil {
				for child, j in layer.parent.children {
					if child == layer {
						ordered_remove(&layer.parent.children, j)
						break
					}
				}
			}
			delete_layer(layer)
			should_sort_layers = true
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
		should_sort_layers = true
		last_top_layer = top_layer
	}
	// Sort the layers
	if should_sort_layers {
		should_sort_layers = false

		clear(&layers)
		sort_layer(&layers, root_layer)
	}
	// Reset rendered layer
	hot_layer = 0
	painted_last_frame = paint_this_frame
	frame_duration = time.since(frame_start_time)
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
		push_id(layer.id)
			n := 0
			x := layer
			for x.parent != nil {
				x = x.parent
				n += 1
			}
			cut(.left, f32(n) * 24); set_side(.left); set_size(1, true)
			button({
				label = format(layer.id),
				align = .near,
			})
			if current_widget().state >= {.hovered} {
				core.debug_layer = layer.id
			}
		pop_id()
	}
	for child in layer.children {
		_debug_layer_widget(child)
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
		for child in layer.children do sort_layer(list, child)
	}
}
should_render :: proc() -> bool {
	return core.paint_this_frame
}

//@private
core: ^Core
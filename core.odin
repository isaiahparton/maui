/*
	Maui is an immediate mode gui library, but that doesn't mean we can't have retained helper structs

	TODO:
		[x] Nice shiny global variables for placement instead of yucky set functions
		[x] Move animations to widget struct (duh)
		[X] Customizable fonts (default themes provides default fonts)
		[X] Implement new texture atlas system
		[X] Figure out if dynamic fonts are feasable
			[X] Implement dynamic font loading
			[ ] Or Don't
		[ ] Cached text painting
			* Save commands and just copy them when needed
		[X] Remove animation map
		[X] Widget code takes on a more flexible form: assert->layout->update->paint->result
		[ ] Lazy resizing for label fitting widgets
		[ ] Clipped loader painting proc for cool loading animation on buttons
		[ ] Implement measures to reduce the need for constant text formatting
*/

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
import "core:math/ease"
import "core:math/linalg"

Cursor_Type :: enum {
	None = -1,
	Default,
	Arrow,
	Beam,
	Crosshair,
	Hand,
	Resize_EW,
	Resize_NS,
	Resize_NWSE,
	Resize_NESW,
	Resize,
	Disabled,
}

TEMP_BUFFER_COUNT 	:: 2
GROUP_STACK_SIZE 		:: 32
CHIP_STACK_SIZE 		:: 32
MAX_CLIP_RECTS 			:: #config(MAUI_MAX_CLIP_RECTS, 32)
MAX_CONTROLS 				:: #config(MAUI_MAX_CONTROLS, 1024)
LAYER_ARENA_SIZE 		:: 128
LAYER_STACK_SIZE 		:: #config(MAUI_LAYER_STACK_SIZE, 32)
WINDOW_STACK_SIZE 	:: #config(MAUI_WINDOW_STACK_SIZE, 32)
// Size of each layer's command buffer
COMMAND_BUFFER_SIZE :: #config(MAUI_COMMAND_BUFFER_SIZE, 256 * 1024)
// Size of id stack (times you can call push_id())
ID_STACK_SIZE 			:: 32
// Repeating key press
KEY_REPEAT_DELAY 		:: 0.5
KEY_REPEAT_RATE 		:: 30
ALL_CORNERS: Box_Corners = {.Top_Left, .Top_Right, .Bottom_Left, .Bottom_Right}

DOUBLE_CLICK_TIME :: time.Millisecond * 200

Color :: [4]u8

Animation :: struct {
	keep_alive: bool,
	value,
	last_value: f32,
}

Scribe :: struct {
	index, length, anchor: int,
	last_index, last_length: int,
}

Group :: struct {
	state: Widget_State,
}

Tooltip_Info :: struct {
	text: string,
	box_side: Box_Side,
}

Stack :: struct($T: typeid, $N: int) {
	items: [N]T,
	height: int,
}
stack_push :: proc(stack: ^Stack($T, $N), item: T) {
	stack.items[stack.height] = item
	stack.height += 1
}
stack_pop :: proc(stack: ^Stack($T, $N)) {
	stack.height -= 1
}
stack_top :: proc(stack: ^Stack($T, $N)) -> (item: T, ok: bool) #optional_ok {
	assert(stack.height < len(stack.items))
	if stack.height == 0 {
		return {}, false
	}
	return stack.items[stack.height - 1], true
}
stack_top_ref :: proc(stack: ^Stack($T, $N)) -> (ref: ^T, ok: bool) #optional_ok {
	assert(stack.height < len(stack.items))
	if stack.height == 0 {
		return nil, false
	}
	return &stack.items[stack.height - 1], true
}

Deferred_Chip :: struct {
	text: string,
	clicked: bool,
}

Core :: struct {
	// Time
	current_time,
	last_time: f64,
	delta_time: f32,
	frame_start_time: time.Time,
	frame_duration: time.Duration,

	set_cursor: Maybe([2]f32),

	disabled, 
	open_menus,
	is_key_selecting: bool,

	// Should ui be repainted
	painted_last_frame,
	paint_this_frame, 
	paint_next_frame: bool,

	// Uh
	last_size,
	size: [2]f32,
	last_box, fullscreen_box: Box,

	// Mouse cursor type
	cursor: Cursor_Type,

	// Hash stack
	id_stack: Stack(Id, ID_STACK_SIZE),

	// Text chips
	chips: Stack(Deferred_Chip, CHIP_STACK_SIZE),

	// Group stack
	group_stack: Stack(Group, GROUP_STACK_SIZE),

	// Handles text editing
	typing_agent: Typing_Agent,

	// Handles widgets
	widget_agent: Widget_Agent,

	// Handles windows
	window_agent: Window_Agent,

	// Handles layers
	layer_agent: Layer_Agent,

	// Handles layouts
	layout_agent: Layout_Agent,

	// Used for dragging stuff
	drag_anchor: [2]f32,

	// Current clip box
	clip_box: Box,

	// Next stuff
	next_id: Maybe(Id),
	next_box: Maybe(Box),
	next_tooltip: Maybe(Tooltip_Info),
}

_get_clipboard_string: proc() -> string
_set_clipboard_string: proc(string)

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

/*
	Scoped interactability toggling

	if enabled(condition) {
		do_button()
	}
*/
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

/*
	Groups widget states
*/
begin_group :: proc() {
	stack_push(&core.group_stack, Group({}))
}
end_group :: proc() -> (result: ^Group) {
	result = stack_top_ref(&core.group_stack)
	stack_pop(&core.group_stack)
	return
}

/*
	Animation management
*/
animate_bool :: proc(value: ^f32, condition: bool, duration: f32, easing: ease.Ease = .Linear) -> f32 {
	old_value := value^
	if condition {
		value^ = min(1, value^ + core.delta_time * (1 / duration))
	} else {
		value^ = max(0, value^ - core.delta_time * (1 / duration))
	}
	if value^ != old_value {
		core.paint_next_frame = true
	}
	return ease.ease(easing, value^)
}

/*
	The global state
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
		// Free text buffers
		typing_agent_destroy(&core.typing_agent)
		// Free layer data
		layer_agent_destroy(&core.layer_agent)
		// Free window data
		window_agent_destroy(&core.window_agent)
		// Free widgets
		widget_agent_destroy(&core.widget_agent)
		//
		painter_destroy()
		//
		free(core)
	}
}
begin_frame :: proc() {
	using core

	// Try tell the user what went wrong if
	// a stack overflow occours
	assert(layout_agent.stack.height == 0, "You forgot to pop_layout()")
	assert(layer_agent.stack.height == 0, "You forgot to pop_layer()")
	assert(id_stack.height == 0, "You forgot to pop_id()")
	assert(group_stack.height == 0, "You forgot to end_group()")

	// Begin frame
	delta_time = f32(current_time - last_time)	
	frame_start_time = time.now()

	// Reset painter
	painter.draw_index = 0
	painter.opacity = 1

	// Reset placement
	placement = {}

	// Decide if painting is required this frame
	paint_this_frame = false
	if paint_next_frame {
		paint_this_frame = true
		paint_next_frame = false
	}

	// Reset cursor to default state
	cursor = .Default

	// Reset fullscreen box
	fullscreen_box = {high = size}

	// Free and delete unused text buffers
	typing_agent_step(&typing_agent)

	// Update control interaction ids
	widget_agent_update_ids(&widget_agent)

	// Begin root layer
	assert(layer_agent_begin_root(&layer_agent))
	// Begin root layout
	push_layout({{}, size})

	// Tab through input fields
	//TODO(isaiah): Add better keyboard navigation with arrow keys
	//FIXME(isaiah): Text inputs selected with 'tab' do not behave correctly
	if key_pressed(.Tab) && core.widget_agent.focus_id != 0 {
		array: [dynamic]^Widget
		defer delete(array)

		anchor: int
		for widget in widget_agent.list {
			if .Can_Key_Select in widget.options && .Disabled not_in widget.bits {
				append(&array, widget)
			}
		}

		if len(array) > 1 {
			slice.stable_sort_by(array[:], proc(a, b: ^Widget) -> bool {
				if a.box.low.x == b.box.low.x {
					if a.box.low.y < b.box.low.y {
						return true
					}
				} else if a.box.low.x < b.box.low.x {
					return true
				}
				return false
			})
			for entry, i in array {
				if entry.id == core.widget_agent.focus_id {
					anchor = i
				}
			}
			core.widget_agent.focus_id = array[(anchor + 1) % len(array)].id
			core.is_key_selecting = true
		}
	}

	// If the mouse moves, stop key selecting
	if input.mouse_point - input.last_mouse_point != {} {
		is_key_selecting = false
	}

	// Reset clip box
	clip_box = fullscreen_box

	chips.height = 0
}
end_frame :: proc() {
	using core
	// End root layout
	pop_layout()
	// End root layer
	layer_agent_end_root(&layer_agent)
	// Update layers
	layer_agent_step(&layer_agent)
	// Update widgets
	widget_agent_step(&widget_agent)
	// Update windows
	window_agent_step(&window_agent)
	// Decide if rendering is needed next frame
	if input.last_mouse_point != input.mouse_point || input.last_key_set != input.key_set|| input.last_mouse_bits != input.mouse_bits || input.mouse_scroll != {} {
		paint_next_frame = true
	}
	if size != last_size {
		paint_next_frame = true
		last_size = size
	}
	// Reset input bits
	input.rune_count = 0
	input.last_key_set = input.key_set
	input.last_mouse_bits = input.mouse_bits
	input.last_mouse_point = input.mouse_point
	input.mouse_scroll = {}
	// Update timings
	painted_last_frame = paint_this_frame
	frame_duration = time.since(frame_start_time)
	last_time = current_time
}
@private
_count_layer_children :: proc(layer: ^Layer) -> int {
	count: int
	for child in layer.children {
		count += 1 + _count_layer_children(child)
	}
	return count
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
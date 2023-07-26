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
	Resize_all,
	Disabled,
}

RENDER_TIMEOUT 		:: 0.5

FMT_BUFFER_COUNT 	:: 16
FMT_BUFFER_SIZE 	:: 128

TEMP_BUFFER_COUNT 	:: 2
GROUP_STACK_SIZE 	:: 32
CHIP_STACK_SIZE :: 32
MAX_CLIP_RECTS 		:: #config(MAUI_MAX_CLIP_RECTS, 32)
MAX_CONTROLS 		:: #config(MAUI_MAX_CONTROLS, 1024)
LAYER_ARENA_SIZE 	:: 128
LAYER_STACK_SIZE 	:: #config(MAUI_LAYER_STACK_SIZE, 32)
WINDOW_STACK_SIZE 	:: #config(MAUI_WINDOW_STACK_SIZE, 32)
// Size of each layer's command buffer
COMMAND_BUFFER_SIZE :: #config(MAUI_COMMAND_BUFFER_SIZE, 256 * 1024)
// Size of id stack (times you can call push_id())
ID_STACK_SIZE 		:: 32
// Repeating key press
KEY_REPEAT_DELAY 	:: 0.5
KEY_REPEAT_RATE 	:: 30
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

@private
Debug_Mode :: enum {
	Layers,
	Windows,
	Controls,
}
@private
Debug_Bit :: enum {
	Show_Window,
}
@private
Debug_Bits :: bit_set[Debug_Bit]

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
	current_time: f64,
	delta_time: f32,
	frame_start_time: time.Time,
	frame_duration: time.Duration,

	// Debugification
	debug_bits: Debug_Bits,
	debug_mode: Debug_Mode,

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

	// Mouse cursor type
	cursor: Cursor_Type,

	// Hash stack
	id_stack: Stack(Id, ID_STACK_SIZE),

	// Text chips
	chips: Stack(Deferred_Chip, CHIP_STACK_SIZE),

	// Group stack
	group_stack: Stack(Group, GROUP_STACK_SIZE),

	// Retained animation values
	animations: map[Id]Animation,

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
		// Free animation pool
		delete(core.animations)
		// Free text buffers
		typing_agent_destroy(&core.typing_agent)
		// Free layer data
		layer_agent_destroy(&core.layer_agent)
		// Free window data
		window_agent_destroy(&core.window_agent)
		// Free widgets
		widget_agent_destroy(&core.widget_agent)
		//
		painter_uninit()
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
	frame_start_time = time.now()

	// Decide if painting is required this frame
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
	for key, &value in animations {
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

	// Reset cursor to default state
	cursor = .Default

	// Reset fullscreen box
	fullscreen_box = {0, 0, size.x, size.y}

	// Free and delete unused text buffers
	typing_agent_step(&typing_agent)

	// Update input
	input_step(&input)

	// Update control interaction ids
	widget_agent_update_ids(&widget_agent)

	// Begin root layer
	assert(layer_agent_begin_root(&layer_agent))

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
				if a.box.x == b.box.x {
					if a.box.y < b.box.y {
						return true
					}
				} else if a.box.x < b.box.x {
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

	// Reset dragging state
	dragging = false

	// If the mouse moves, stop key selecting
	if input.mouse_point - input.last_mouse_point != {} {
		is_key_selecting = false
	}

	// Reset clip box
	clip_box = fullscreen_box

	// Reset input bits
	input.last_key_bits = input.key_bits
	input.last_mouse_bits = input.mouse_bits
	input.last_mouse_point = input.mouse_point

	chips.height = 0
}
end_frame :: proc() {
	using core
	// Built-in debug window
	//TODO: Make this better
	when ODIN_DEBUG {
		layer_agent.debug_id = 0
		if key_down(.Control) && key_pressed(.Backspace) {
			debug_bits ~= {.Show_Window}
		}
		if debug_bits >= {.Show_Window} {
			if do_window({
				title = "Debug", 
				box = {0, 0, 500, 700}, 
				options = {.Collapsable, .Closable, .Title, .Resizable},
			}) {
				if current_window().bits >= {.Should_Close} {
					debug_bits -= {.Show_Window}
				}

				set_size(30)
				debug_mode = do_enum_tabs(debug_mode, 0)

				shrink(10); set_size(24)
				if debug_mode == .Layers {
					set_side(.Bottom); set_size(TEXTURE_HEIGHT)
					if do_frame({
						layout_size = {TEXTURE_WIDTH, TEXTURE_HEIGHT},
						fill_color = Color{0, 0, 0, 255},
						options = {.No_Scroll_Margin_X, .No_Scroll_Margin_Y},
					}) {
						paint_box_fill(current_layout().box, {0, 0, 0, 255})
						paint_texture({0, 0, TEXTURE_WIDTH, TEXTURE_HEIGHT}, current_layout().box, 255)
						layer_agent.current_layer.content_box = update_bounding_box(layer_agent.current_layer.content_box, current_layout().box)
					}
					_debug_layer_widget(core.layer_agent.root_layer)
				} else if debug_mode == .Windows {
					for id, window in window_agent.pool {
						push_id(window.id)
							do_button({
								label = format(window.id), 
								align = .Near,
							})
							if last_widget().state >= {.Hovered} {
								layer_agent.debug_id = window.layer.id
							}
						pop_id()
					}
				} else if debug_mode == .Controls {
					do_text({
						font = .Monospace, 
						text = text_format("Layer: %i", layer_agent.hover_id), 
						fit = true,
					})
					space(20)
					do_text({
						font = .Monospace, 
						text = text_format("Hovered: %i", widget_agent.hover_id), 
						fit = true,
					})
					do_text({
						font = .Monospace, 
						text = text_format("Focused: %i", widget_agent.focus_id), 
						fit = true,
					})
					do_text({
						font = .Monospace, 
						text = text_format("Pressed: %i", widget_agent.press_id), 
						fit = true,
					})
					space(20)
					do_text({
						font = .Monospace, 
						text = text_format("Count: %i", len(widget_agent.list)), 
						fit = true,
					})
				}
			}
		}
	}
	// End root layer
	layer_agent_end_root(&layer_agent)
	// Update layers
	layer_agent_step(&layer_agent)
	// Update widgets
	widget_agent_step(&widget_agent)
	// Update windows
	window_agent_step(&window_agent)
	// Update timings
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
	if do_layout(.Top, 24) {
		push_id(layer.id)
			n := 0
			x := layer
			for x.parent != nil {
				x = x.parent
				n += 1
			}
			cut(.Left, f32(n) * 24); set_side(.Left); set_size(1, true)
			do_button({
				label = format(layer.id),
				align = .Near,
			})
			if last_widget().state >= {.Hovered} {
				core.layer_agent.debug_id = layer.id
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
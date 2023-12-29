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

PRINT_DEBUG_EVENTS :: false
GROUP_STACK_SIZE 		:: 32
MAX_CLIP_RECTS 			:: #config(MAUI_MAX_CLIP_RECTS, 32)
MAX_CONTROLS 				:: #config(MAUI_MAX_CONTROLS, 1024)
LAYER_STACK_SIZE 		:: #config(MAUI_LAYER_STACK_SIZE, 32)
WINDOW_STACK_SIZE 	:: #config(MAUI_WINDOW_STACK_SIZE, 32)
// Size of id stack (times you can call push_id())
ID_STACK_SIZE 			:: 32
// Repeating key press
ALL_CORNERS: Box_Corners = {.Top_Left, .Top_Right, .Bottom_Left, .Bottom_Right}

DOUBLE_CLICK_TIME :: time.Millisecond * 450

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

Arena :: struct($T: typeid, $N: int) {
	items: [N]Maybe(T),
}
arena_allocate :: proc(arena: ^Arena($T, $N)) -> (handle: ^Maybe(T), ok: bool) {
	for i in 0..<N {
		if arena.items[i] == nil {
			arena.items[i] = T{}
			return &arena.items[i], true
		}
	}
	return nil, false
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

Platform_Layer :: struct {
	screen_size: [2]i32,
	set_cursor: Maybe(Cursor_Type),
	set_mouse_position: Maybe([2]i32),
	get_clipboard_string: proc() -> string,
	set_clipboard_string: proc(string),
}

Renderer_Layer :: struct {
	screen_size: [2]i32,
	load_texture: proc(image: Image) -> (id: u32, ok: bool),
	unload_texture: proc(id: u32),
	update_texture: proc(texture: Texture, data: []u8, x, y, w, h: f32),
}
load_texture :: proc(image: Image) -> (texture: Texture, ok: bool) {
	assert(ui.renderer.load_texture != nil)
	id := ui.renderer.load_texture(image) or_return
	return Texture{
		id = id,
		width = image.width,
		height = image.height,
		channels = image.channels,
	}, true
}
unload_texture :: proc(id: u32) {
	assert(ui.renderer.unload_texture != nil)
	ui.renderer.unload_texture(id)
}
update_texture :: proc(texture: Texture, image: Image, x, y, w, h: f32) {
	assert(ui.renderer.update_texture != nil)
	ui.renderer.update_texture(texture, image.data, x, y, w, h)
}

UI :: struct {
	// Layer
	root_layer: ^Layer,
	
	// Time
	current_time,
	last_time: f64,
	delta_time: f32,
	frame_start_time: time.Time,
	frame_duration: time.Duration,

	disabled, 
	open_menus,
	is_key_selecting: bool,

	platform: Platform_Layer,
	renderer: Renderer_Layer,

	// Uh
	last_size,
	size: [2]f32,
	last_box: Box,

	painter: Painter,
	placement: Placement_Info,
	style: Style,

	// Mouse cursor type
	cursor: Cursor_Type,

	// Hash stack
	id_stack: Stack(Id, ID_STACK_SIZE),

	// Handles text editing
	typing: Typing_Agent,

	// Handles widgets
	widgets: Widget_Agent,

	// Handles panels
	panels: Panel_Agent,

	// Handles layers
	layers: Layer_Agent,

	// Handles layouts
	layouts: Layout_Agent,

	// Used for dragging stuff
	drag_anchor: [2]f32,

	// Current clip box
	clip_box: Box,
}

get_clipboard_string :: proc() -> string {
	assert(ui.platform.get_clipboard_string != nil)
	return ui.platform.get_clipboard_string()
}
set_clipboard_string :: proc(str: string) {
	assert(ui.platform.set_clipboard_string != nil)
	ui.platform.set_clipboard_string(str)
}

/*
	Animation management
*/
animate_bool :: proc(ui: ^UI, value: ^f32, condition: bool, duration: f32, easing: ease.Ease = .Linear) -> f32 {
	old_value := value^
	if condition {
		value^ = min(1, value^ + ui.delta_time * (1 / duration))
	} else {
		value^ = max(0, value^ - ui.delta_time * (1 / duration))
	}
	if value^ != old_value {
		ui.painter.next_frame = true
	}
	return ease.ease(easing, value^)
}

make_ui :: proc(platform: Platform_Layer, renderer: Renderer_Layer) -> (result: UI, ok: bool) {
	// Assign the result
	result = UI{
		platform = platform,
		renderer = renderer,
		painter = make_painter() or_return,
	}
	result.style = {
		color = DARK_STYLE_COLORS,
		layout = {
			title_size = 24,
			size = 24,
			gap_size = 5,
			widget_padding = 7,
		},
		text_size = {
			label = 16,
			title = 16,
			tooltip = 16,
			field = 18,
		},
		rounding = 5,
		panel_rounding = 5,
		tooltip_rounding = 5,
		font = {
			label = load_font(&ctx.painter.atlas, "fonts/Ubuntu-Regular.ttf") or_return,
			title = load_font(&ctx.painter.atlas, "fonts/RobotoSlab-Regular.ttf") or_return,
			monospace = load_font(&ctx.painter.atlas, "fonts/AzeretMono-Regular.ttf") or_return,
			icon = load_font(&ctx.painter.atlas, "fonts/remixicon.ttf") or_return,
		},
	}
	ok = true
	return
}
destroy_ui :: proc(ui: ^UI) {
	// Free text buffers
	destroy_typing_agent(&ctx.typing_agent)
	// Free layer data
	destroy_layer_agent(&ctx.layer_agent)
	// Free panel data
	destroy_panel_agent(&ctx.panel_agent)
	// Free widgets
	destroy_widget_agent(&ctx.widget_agent)
	//
	destroy_painter(&ctx.painter)
}
begin_ui :: proc(ui: ^UI) {
	renderer.screen_size = platform.screen_size
	size = linalg.array_cast(platform.screen_size, f32)

	// Try tell the user what went wrong if
	// a stack overflow occours
	assert(layout_agent.stack.height == 0, "You forgot to pop_layout()")
	assert(layer_agent.stack.height == 0, "You forgot to pop_layer()")
	assert(id_stack.height == 0, "You forgot to pop_id()")

	// Begin frame
	delta_time = f32(current_time - last_time)	
	frame_start_time = time.now()

	// Reset painter
	painter.mesh_index = 0
	painter.opacity = 1
	ui.style.rounded_corners = ALL_CORNERS

	// Reset placement
	placement = {}

	// Decide if painting is required this frame
	painter.this_frame = false
	if ctx.painter.next_frame {
		painter.this_frame = true
		ctx.painter.next_frame = false
	}

	// Reset cursor to default state
	cursor = .Default

	// Free and delete unused text buffers
	typing_agent_step(&typing_agent)

	// Update control interaction ids
	update_widget_agent(&widget_agent)

	// Begin root layer
	root_layer, ok = begin_layer({
		id = 0,
		placement = Box{{}, ui.size}, 
		options = {.No_ID},
	})
	
	// Begin root layout
	push_layout({{}, size})

	// Tab through input fields
	//TODO(isaiah): Add better keyboard navigation with arrow keys
	//FIXME(isaiah): Text inputs selected with 'tab' do not behave correctly
	if key_pressed(.Tab) && ctx.widget_agent.focus_id != 0 {
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
				if entry.id == ctx.widget_agent.focus_id {
					anchor = i
				}
			}
			ctx.widget_agent.focus_id = array[(anchor + 1) % len(array)].id
			ctx.is_key_selecting = true
		}
	}

	// If the mouse moves, stop key selecting
	if input.mouse_point - input.last_mouse_point != {} {
		is_key_selecting = false
	}

	// Reset clip box
	clip_box = {{}, ctx.size}
}
end_ui :: proc(ui: ^UI) {
	// End root layout
	pop_layout(ui)
	// End root layer
	end_layer(&ui.root_layer)
	// Update layers
	update_layer_agent(&ui.layer_agent)
	// Update widgets
	update_widget_agent(&ui.widget_agent)
	// Update panels
	update_panel_agent(&ui.panel_agent)
	// Decide if rendering is needed next frame
	if (input.last_mouse_point != input.mouse_point) || (input.last_key_set != input.key_set) || (input.last_mouse_bits != input.mouse_bits) || (input.mouse_scroll != {}) {
		ctx.painter.next_frame = true
	}
	if size != last_size {
		ctx.painter.next_frame = true
		last_size = size
	}
	// Reset input bits
	input.rune_count = 0
	input.last_key_set = input.key_set
	input.last_mouse_bits = input.mouse_bits
	input.last_mouse_point = input.mouse_point
	input.mouse_scroll = {}
	// Update timings
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
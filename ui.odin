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

UI :: struct {
	// Layer
	root_layer: ^Layer,
	// Time
	current_time,
	last_time: f64,
	delta_time: f32,
	frame_start_time: time.Time,
	frame_duration: time.Duration,
	// If menus are being selected
	open_menus,
	// If key navigation is active
	is_key_selecting: bool,
	// These are shared modules
	io: ^IO,
	painter: ^Painter,
	// Uh
	last_size,
	size: [2]f32,
	last_box: Box,
	// Settings
	placement: Placement_Info,
	style: Style,
	// Mouse cursor type
	cursor: Cursor_Type,
	// Hash stack
	id_stack: Stack(Id, ID_STACK_SIZE),
	// Handles text editing
	scribe: Scribe,
	// Handles widgets
	widgets: Widget_Agent,
	// Handles panels
	panels: Panel_Agent,
	// Handles layers
	layers: Layer_Agent,
	// Handles layouts
	layouts: Layout_Agent,
	// Used for dragging stuff
	drag_anchor: Maybe([2]f32),
	// Current clip box
	clip_box: Box,
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
/*
	Construct a new UI given it's required plugins
*/
make_ui :: proc(io: ^IO, painter: ^Painter) -> (result: UI, ok: bool) {
	// Assign the result
	result, ok = UI{
		io = io,
		painter = painter,
		style = {
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
				label 		= load_font(painter, "fonts/Ubuntu-Regular.ttf") or_return,
				title 		= load_font(painter, "fonts/RobotoSlab-Regular.ttf") or_return,
				monospace = load_font(painter, "fonts/AzeretMono-Regular.ttf") or_return,
				icon 			= load_font(painter, "fonts/remixicon.ttf") or_return,
			},
		},
	}, true
	return
}
destroy_ui :: proc(ui: ^UI) {
	// Free text buffers
	destroy_scribe(&ui.scribe)
	// Free layer data
	destroy_layer_agent(&ui.layers)
	// Free panel data
	destroy_panel_agent(&ui.panels)
	// Free widgets
	destroy_widget_agent(&ui.widgets)
	//
	destroy_painter(ui.painter)
}
begin_ui :: proc(ui: ^UI) {
	// Update screen size
	// ui.painter.size = ui.io.screen_size
	ui.size = linalg.array_cast(ui.io.size, f32)
	// Try tell the user what went wrong if
	// a stack overflow occours
	assert(ui.layouts.stack.height == 0, "You forgot to pop_layout()")
	assert(ui.layers.stack.height == 0, "You forgot to pop_layer()")
	assert(ui.id_stack.height == 0, "You forgot to pop_id()")
	// Begin frame
	ui.delta_time = f32(ui.current_time - ui.last_time)	
	ui.frame_start_time = time.now()
	// Reset painter
	ui.painter.mesh_index = 0
	ui.painter.opacity = 1
	ui.style.rounded_corners = ALL_CORNERS
	// Reset placement
	ui.placement = {}
	// Decide if painting is required this frame
	ui.painter.this_frame = false
	if ui.painter.next_frame {
		ui.painter.this_frame = true
		ui.painter.next_frame = false
	}
	// Free and delete unused text buffers
	update_scribe(&ui.scribe)
	// Update control interaction ids
	update_widgets(ui)
	// Begin root layer
	ui.root_layer = begin_layer(ui, {
		id = 0,
		placement = Box{{}, ui.size}, 
		options = {.No_ID},
	}) or_else panic("bruh")
	// Begin root layout
	push_layout(ui, {{}, ui.size})
	// Tab through input fields
	//TODO(isaiah): Add better keyboard navigation with arrow keys
	//FIXME(isaiah): Text inputs selected with 'tab' do not behave correctly
	if key_pressed(ui.io, .Tab) && ui.widgets.focus_id != 0 {
		array: [dynamic]^Widget
		defer delete(array)
		anchor: int
		for widget in ui.widgets.list {
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
				if entry.id == ui.widgets.focus_id {
					anchor = i
				}
			}
			ui.widgets.focus_id = array[(anchor + 1) % len(array)].id
			ui.is_key_selecting = true
		}
	}
	// If the mouse moves, stop key selecting
	if ui.io.mouse_point - ui.io.last_mouse_point != {} {
		ui.is_key_selecting = false
	}
	// Reset clip box
	ui.clip_box = {{}, ui.size}
}
end_ui :: proc(ui: ^UI) {
	// End root layout
	pop_layout(ui)
	// End root layer
	end_layer(ui, ui.root_layer)
	// Update layers
	update_layers(ui)
	// Update widgets
	update_widgets(ui)
	// Update panels
	update_panels(ui)
	// Decide if rendering is needed next frame
	if (ui.io.last_mouse_point != ui.io.mouse_point) || (ui.io.last_key_set != ui.io.key_set) || (ui.io.last_mouse_bits != ui.io.mouse_bits) || (ui.io.mouse_scroll != {}) {
		ui.painter.next_frame = true
	}
	if ui.size != ui.last_size {
		ui.painter.next_frame = true
		ui.last_size = ui.size
	}
	// Reset input bits
	ui.io.rune_count = 0
	ui.io.last_key_set = ui.io.key_set
	ui.io.last_mouse_bits = ui.io.mouse_bits
	ui.io.last_mouse_point = ui.io.mouse_point
	ui.io.mouse_scroll = {}
	// Update timings
	ui.frame_duration = time.since(ui.frame_start_time)
	ui.last_time = ui.current_time
	// Update texture
	if !ui.painter.ready {
		reset_atlas(ui.painter)
		ui.painter.ready = true
	}
	if ui.painter.should_update {
		ui.painter.should_update = false
		update_texture(ui.painter, ui.painter.texture, ui.painter.image, 0, 0, f32(ui.painter.image.width), f32(ui.painter.image.height))
	}
}
@private
_count_layer_children :: proc(layer: ^Layer) -> int {
	count: int
	for child in layer.children {
		count += 1 + _count_layer_children(child)
	}
	return count
}
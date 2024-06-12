package demo
import maui "../"

import "core:time"
import "core:math"
import "core:strings"
import "core:math/linalg"
import "core:strconv/decimal"
import rl "vendor:raylib"
import "../backend/maui_glfw"
import "../backend/maui_opengl"

import "vendor:glfw"

import "core:fmt"
import "core:mem"

TARGET_FRAME_RATE :: 75
TARGET_FRAME_TIME :: 1.0 / TARGET_FRAME_RATE

Component :: enum {
	Button,
	Text_Editor,
	Slider,
}

Option :: enum {
	Wave,
	Function,
	Collapse,
	Manifold,
}

_main :: proc() -> bool {

	disabled := true
	clicked: bool
	toggle_switch_state: bool
	slider_value: f32
	combo_box_index: int
	chosen_options: [Option]bool
	list := make([dynamic]bool, 9)
	text_input_data: [dynamic]u8
	text_input_data2: [dynamic]u8
	choice: Option
	t: time.Time = time.now()

	// Shared structures
	io: maui.IO
	painter := maui.make_painter() or_return

	// Initialize the platform and renderer
	maui_glfw.init(1200, 1000, "Maui", .OpenGL, &io) or_return
	maui_opengl.init(&painter) or_return

	glfw.SetWindowPos(maui_glfw.get_window_handle(), 0, 0)

	// Only create the ui structure once the `painter` and `io` are initiated
	ui := maui.make_ui(&io, &painter, maui.make_default_style(&painter) or_return)

	// Begin the cycle
	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using maui
		// Beginning of ui calls
		maui_glfw.begin()

		begin_ui(ui)
			
			


			paint_text(ui.painter, {0, ui.size.y}, {
				text = tmp_printf("frame: %fms", time.duration_milliseconds(ui.frame_duration)), 
				font = ui.style.font.title, 
				size = 16,
				baseline = .Bottom,
			}, ui.style.color.content)
			paint_text(ui.painter, {0, ui.size.y - 16}, {
				text = tmp_printf("delta: %f", ui.delta_time), 
				font = ui.style.font.title, 
				size = 16,
				baseline = .Bottom,
			}, ui.style.color.content)
			paint_text(ui.painter, {0, ui.size.y - 32}, {
				text = tmp_printf("time: %f", ui.current_time), 
				font = ui.style.font.title, 
				size = 16,
				baseline = .Bottom,
			}, ui.style.color.content)
		end_ui(ui)

		// Render if needed
		if should_render(&painter) {
			maui_opengl.clear(ui.style.color.background)
			maui_opengl.render(ui)
			maui_glfw.end()
		}
	}

	maui.destroy_ui(ui)

	maui_opengl.destroy()
	maui_glfw.destroy()

	return true
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)

	_main()

	for _, leak in track.allocation_map {
		fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
	}
	for bad_free in track.bad_free_array {
		fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
	}
}
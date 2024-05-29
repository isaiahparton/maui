package demo
import maui "../"

import "core:time"
import "core:math"
import "core:strings"
import "core:math/linalg"
import "core:strconv/decimal"

import "vendor:glfw"
import gl "vendor:OpenGL"
import "vendor:nanovg"
import nanovg_gl "vendor:nanovg/gl"

import "core:fmt"
import "core:mem"

TARGET_FRAME_RATE :: 75
TARGET_FRAME_TIME :: 1.0 / TARGET_FRAME_RATE

Option :: enum {
	Strawberry,
	Dragonfruit,
	Watermelon,
}

_main :: proc() -> bool {
	// Init graphics
	glfw.Init()
	glfw.WindowHint(glfw.SAMPLES, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	window := glfw.CreateWindow(1000, 600, "window of opportunity", nil, nil)
	// Create and assign error callback
	err_callback :: proc(err: i32, desc: cstring) {
		fmt.println(err, desc)
	}
	glfw.SetErrorCallback(glfw.ErrorProc(err_callback))
	glfw.MakeContextCurrent(window)
	gl.load_up_to(3, 3, glfw.gl_set_proc_address)

	disabled := true
	clicked: bool
	toggle_switch_state: bool
	slider_value: f32
	combo_box_index: int
	checkbox_value: bool
	list := make([dynamic]bool, 9)
	text_input_data: [dynamic]u8
	text_input_data2: [dynamic]u8
	choice: Option
	t: time.Time = time.now()

	// Shared structures
	io: maui.IO

	// Initialize the platform and renderer
	ctx := nanovg_gl.Create({})

	// Only create the ui structure once the `painter` and `io` are initiated
	ui := maui.make_ui(&io, ctx, maui.make_default_style(ctx) or_return) or_return

	// Begin the cycle
	for {
		if glfw.WindowShouldClose(window) {
			break
		}

		using maui
		// Beginning of ui calls
		begin_ui(&ui)
			layout := current_layout(&ui)

			cut(&ui, .Left, 200)
			cut(&ui, .Right, 200)
			cut(&ui, .Top, 100)

			ui.placement.size = 30
			button(&ui, {text = "button"})
			
			nanovg.BeginPath(ctx)
			nanovg.FontSize(ctx, 16)
			nanovg.FontFace(ctx, "Default")
			nanovg.TextAlignVertical(ctx, .BOTTOM)
			nanovg.Text(ui.ctx, 0, ui.size.y, tmp_printf("frame: %fms", time.duration_milliseconds(ui.frame_duration)))
			nanovg.Text(ui.ctx, 0, ui.size.y - 16, tmp_printf("delta: %f", ui.delta_time))
			nanovg.Text(ui.ctx, 0, ui.size.y - 32, tmp_printf("time: %f", ui.current_time))
			nanovg.FillColor(ctx, nanovg.ColorHex(0x00ff00ff))
			nanovg.Fill(ctx)
		end_ui(&ui)
	}

	maui.destroy_ui(&ui)

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
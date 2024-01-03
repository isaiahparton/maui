package demo
import maui "../"
import maui_widgets "../widgets"

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

_main :: proc() -> bool {

	counter: int
	value: bool
	// Shared structures
	io: maui.IO
	painter := maui.make_painter() or_return

	// Initialize the platform and renderer
	maui_glfw.init(1200, 1000, "Maui", .OpenGL, &io) or_return
	maui_opengl.init(&painter) or_return

	// Only create the ui structure once the `painter` and `io` are initiated
	ui := maui.make_ui(&io, &painter) or_return

	// Begin the cycle
	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using maui 
		using maui_widgets

		// Beginning of ui calls
		maui_glfw.begin()

		begin_ui(&ui)
			if layout, ok := do_layout(&ui, {{100, 100}, {400, 500}}); ok {
				layout.direction = .Down
				layout.size = 30
				// Execute a button widget and check it's clicked status
				button(&ui, {
					text = "click me!",
					corners = Corners{.Top_Left, .Top_Right},
				})
				space(&ui, 2)
				if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
					layout.direction = .Right
					layout.size = 100
					button(&ui, {
						text = "or me",
						corners = Corners{.Bottom_Left},
					})
					space(&ui, 2)
					layout.size = width(layout.box)
					button(&ui, {
						text = "or maybe me?",
						corners = Corners{.Bottom_Right},
					})
				}
				space(&ui, 2)
				if was_clicked(checkbox(&ui, {value = value, text = "with text"})) {
					value = !value
				}
				space(&ui, 2)
				if was_clicked(checkbox(&ui, {value = value, text = "flipped", text_side = .Right})) {
					value = !value
				}
			}
		end_ui(&ui)

		// Render if needed
		if should_render(&painter) {
			maui_opengl.clear(ui.style.color.base[0])
			maui_opengl.render(&ui)
			maui_glfw.end()
		}
	}

	maui.destroy_ui(&ui)

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
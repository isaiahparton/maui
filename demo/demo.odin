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

ALTERNATE_STYLE_COLORS :: maui.Style_Colors{
	accent = {185, 75, 178, 255},
	base = {211, 204, 48, 255},
	text = {0, 0, 0, 255},
	flash = {0, 0, 0, 255},
	substance = {0, 0, 0, 255},
}

_main :: proc() -> bool {

	disabled := true
	clicked: bool
	checkbox_value: bool

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

		// Beginning of ui calls
		maui_glfw.begin()

		begin_ui(&ui)

			shrink(&ui, 100)

			layout := current_layout(&ui)

			push_layout(&ui, cut_box_left(&layout.box, width(layout.box) / 2))
				shrink(&ui, 100)
				current_layout(&ui).size = 50

				if was_clicked(button(&ui, {
					text = "CLICK TO ENABLE\nTHE OTHER BUTTON" if disabled else "CLICK TO DISABLE\nTHE OTHER BUTTON",
				})) {
					disabled = !disabled
				}
				space(&ui, 10)
				if was_clicked(button(&ui, {
					text = "OR IF YOU PLAY\nLEAGUE OF LEGENDS" if clicked else "CLICK IF YOU LOVE\nGRILLED CHICKEN",
					disabled = disabled,
				})) {
					clicked = true
				}
				space(&ui, 10)
				if was_clicked(checkbox(&ui, {value = checkbox_value, text = "Boolean"})) {
					checkbox_value = !checkbox_value
				}
			pop_layout(&ui)

			push_layout(&ui, cut_box_left(&layout.box, width(layout.box)))
				ui.style.color = ALTERNATE_STYLE_COLORS
				paint_box_fill(ui.painter, current_layout(&ui).box, ui.style.color.base)
				shrink(&ui, 100)
				current_layout(&ui).size = 50

				if was_clicked(button(&ui, {
					text = "CLICK TO ENABLE\nTHE OTHER BUTTON" if disabled else "CLICK TO DISABLE\nTHE OTHER BUTTON",
				})) {
					disabled = !disabled
				}
				space(&ui, 10)
				if was_clicked(button(&ui, {
					text = "OR IF YOU PLAY\nLEAGUE OF LEGENDS" if clicked else "CLICK IF YOU LOVE\nGRILLED CHICKEN",
					disabled = disabled,
				})) {
					clicked = true
				}
				space(&ui, 10)
				if was_clicked(checkbox(&ui, {value = checkbox_value, text = "Boolean"})) {
					checkbox_value = !checkbox_value
				}
			pop_layout(&ui)
			ui.style.color = DARK_STYLE_COLORS

			paint_text(ui.painter, {}, {text = tmp_printf("%fms", time.duration_milliseconds(ui.frame_duration)), font = ui.style.font.title, size = 16}, 255)
		end_ui(&ui)

		// Render if needed
		if should_render(&painter) {
			maui_opengl.clear(ui.style.color.base)
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
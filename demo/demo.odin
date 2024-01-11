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
	base = {120, 120, 140, 255},
	text = {255, 255, 255, 255},
	flash = {0, 255, 0, 255},
	substance = {220, 220, 240, 255},
}

_main :: proc() -> bool {

	disabled := true
	clicked: bool
	checkbox_value: bool
	list := make([dynamic]bool, 9)
	text_input_data: [dynamic]u8

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

			if layout, ok := do_layout(&ui, cut(&ui, .Right, 40)); ok {
				ui.style.color = ALTERNATE_STYLE_COLORS
				paint_box_fill(ui.painter, layout.box, ui.style.color.base)
				layout.size.y = 40
				button(&ui, {
					text = "\uF0D1",
					font = ui.style.font.icon,
					subtle = true,
				})
				button(&ui, {
					text = "\uEC10",
					font = ui.style.font.icon,
					subtle = true,
				})
				button(&ui, {
					text = "\uF255",
					font = ui.style.font.icon,
					subtle = true,
				})
				ui.style.color = DARK_STYLE_COLORS
			}

			layout := current_layout(&ui)
			layout.size = {100, 50}
			shrink(&ui, 100)

			if was_clicked(button(&ui, {
				text = "CLICK TO ENABLE\nTHE OTHER WIDGETS" if disabled else "CLICK TO DISABLE\nTHE OTHER WIDGETS",
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
			layout.size.y = 30
			if was_clicked(checkbox(&ui, {
				value = checkbox_value, 
				text = "Boolean", 
				disabled = disabled,
			})) {
				checkbox_value = !checkbox_value
			}
			space(&ui, 10)
			layout.size.y = 100
			text_input(&ui, {
				data = &text_input_data,
				multiline = true,
			})
			space(&ui, 10)
			if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
				layout.direction = .Right
				if result, open := menu(&ui, {text = "File"}); open {
					button(&ui, {text = "New", subtle = true})
					button(&ui, {text = "Open", subtle = true})
					button(&ui, {text = "Save", subtle = true})
				}
				if result, open := menu(&ui, {text = "Edit"}); open {
					button(&ui, {text = "Undo", subtle = true})
					button(&ui, {text = "Redo", subtle = true})
					button(&ui, {text = "Select All", subtle = true})
				}
			}
			space(&ui, 100)
			layout.size.y = 20
			for &entry, i in list {
				push_id(&ui, i)
					if was_clicked(list_item(&ui, {
						active = entry, 
						text = {"left text", tmp_print(ui.id_stack.items[ui.id_stack.height - 1]), "middle text", "right text"},
					})) {
						entry = !entry
					}
				pop_id(&ui)
			}

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
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

			layout := current_layout(&ui)
			layout.size = {100, 28}
			shrink(&ui, 100)

			if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
				layout.direction = .Right
				layout.size = 30
				button(&ui, {text_size = 16, corners = Corners{.Top_Left, .Bottom_Left}, font = ui.style.font.icon, text = "\uf019"})
				button(&ui, {text_size = 16, font = ui.style.font.icon, text = "\uf02e"})
				button(&ui, {text_size = 16, corners = Corners{.Top_Right, .Bottom_Right}, font = ui.style.font.icon, text = "\uf084"})
				space(&ui, 10)
				layout.size = 100
				button(&ui, {text = "New", corners = ALL_CORNERS})
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
				title = "Text field",
			})
			space(&ui, 10)
			if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
				layout.direction = .Right
				if result, open := menu(&ui, {text = "File"}); open {
					button(&ui, {text = "New", subtle = true, align = .Left})
					button(&ui, {text = "Open", subtle = true, align = .Left})
					button(&ui, {text = "Save", subtle = true, align = .Left})
					button(&ui, {text = "Exit", subtle = true, align = .Left})
				}
				if result, open := menu(&ui, {text = "Edit"}); open {
					button(&ui, {text = "Undo", subtle = true, align = .Left})
					button(&ui, {text = "Redo", subtle = true, align = .Left})
					button(&ui, {text = "Select All", subtle = true, align = .Left})
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
			maui_opengl.clear(ui.style.color.foreground[0])
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
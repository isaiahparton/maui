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

	text: [dynamic]u8
	counter: int
	toggle_button_value: bool
	slider_value: f32
	input_value: f64
	checkbox_values: [4]bool
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
					shape = Button_Shape(Cut_Button_Shape({.Top_Left, .Top_Right})),
				})
				space(&ui, 2)
				if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
					layout.direction = .Right
					layout.size = 100
					button(&ui, {
						text = "or me",
						type = .Normal,
						shape = Button_Shape(Cut_Button_Shape({.Bottom_Left})),
					})
					space(&ui, 2)
					layout.size = width(layout.box)
					button(&ui, {
						text = "or maybe me?",
						shape = Button_Shape(Cut_Button_Shape({.Bottom_Right})),
					})
				}
				space(&ui, 2)
				layout.placement.size = 20
				if result := slider(&ui, {value = slider_value, low = 0, high = 100}); result.changed {
					slider_value = result.value
				}
				space(&ui, 2)
				layout.placement.size = 24
				if n := tree_node(&ui, {text = "Tree"}); n.expanded {
					if n2 := tree_node(&ui, {text = "Node"}); n2.expanded {
						if was_clicked(toggle_button(&ui, {on = toggle_button_value, text = "toggle button"})) {
							toggle_button_value = !toggle_button_value
						}
					}
					if n3 := tree_node(&ui, {text = "Node"}); n3.expanded {
						button(&ui, {text = "leaf"})
					}
				}
				space(&ui, 2)
				layout.placement.size = 34
				if layer, ok := attached_layer(&ui, text_input(&ui, {
					data = &text,
					placeholder = "Type something here",
				}), {
					side = .Bottom,
					grow = .Down,
					stroke_color = ui.style.color.substance[0],
					fill_color = ui.style.color.base[0],
				}); ok {
					button(&ui, {text = "Hello there"})
					button(&ui, {text = "Hello there"})
					button(&ui, {text = "Hello there"})
				}
				space(&ui, 2)
				number_input(&ui, {value = input_value, placeholder = "0.00"})
				layout.placement.size = 80
				if do_row(&ui, 4) {
					current_layout(&ui).placement.align = {.Middle, .Middle}
					if was_clicked(checkbox(&ui, {value = checkbox_values[0], text = "left"})) {
						checkbox_values[0] = !checkbox_values[0]
					}
					if was_clicked(checkbox(&ui, {value = checkbox_values[1], text = "right", text_side = .Right})) {
						checkbox_values[1] = !checkbox_values[1]
					}
					if was_clicked(checkbox(&ui, {value = checkbox_values[2], text = "top", text_side = .Top})) {
						checkbox_values[2] = !checkbox_values[2]
					}
					if was_clicked(checkbox(&ui, {value = checkbox_values[3], text = "bottom", text_side = .Bottom})) {
						checkbox_values[3] = !checkbox_values[3]
					}
				}

			}

			paint_text(ui.painter, {}, {text = tmp_printf("%fms", time.duration_milliseconds(ui.frame_duration)), font = ui.style.font.title, size = 16}, 255)
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
package demo

import maui "../"
import maui_widgets "../widgets"

import "core:time"
import "core:math"
import "core:strings"
import "core:math/linalg"
import rl "vendor:raylib"
import "../backend/maui_glfw"
import "../backend/maui_opengl"


import "core:fmt"
import "core:mem"

TARGET_FRAME_RATE :: 75
TARGET_FRAME_TIME :: 1.0 / TARGET_FRAME_RATE

Choice :: enum {
	One,
	Two,
	Three,
}

_main :: proc() {
	fmt.println("Structure sizes")
	fmt.println("  Painter:", size_of(maui.Painter))
	fmt.println("  Core:", size_of(maui.Core))

	t: time.Time
	tt: time.Time
	show_window: bool
	boolean: bool
	choice: Choice
	gain, pitch: f64
	text: string

	if !maui_glfw.init(1200, 1000, "Maui", .OpenGL) {
		return
	}

	if !maui_opengl.init(&maui_glfw.interface) {
		return
	}

	maui.init()

	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using maui 
		using maui_widgets

		// Beginning of ui calls
		maui_glfw.begin_frame()
		begin_frame()

		// UI calls
		shrink(50)
		if do_horizontal(Exact(200)) {
			placement.size = Exact(200)
			if do_frame({}) {
				placement.side = .Bottom; placement.size = Exact(24)
				for i in 0..<100 {
					push_id(i)
						do_button({align = .Near, label = tmp_printf("button #%i", i + 1)})
					pop_id()
				}
			}
		}

		if do_window({
			placement = child_box(core.fullscreen_box, {300, 480}, {.Near, .Middle}),
			title = "window",
			options = {.Title, .Closable, .Resizable, .Collapsable},
		}) {
			if do_horizontal(Exact(24)) {
				placement.size = Exact(120)
				if do_menu({label = "File"}) {
					placement.size = Exact(24)
					do_option({label = "new"})
					do_option({label = "open"})
					do_option({label = "save"})
					if do_submenu({label = "Import"}) {
						do_option({label = "stuff"})
						do_option({label = "things"})
					}
					if do_submenu({label = "Export"}) {
						do_option({label = "stuff"})
						do_option({label = "things"})
					}
				}
			}
			shrink(20)
			// Set default size for widget placement
			placement.size = Exact(28)
			// Put a text field
			do_text_field({data = &text, placeholder = "type something"})
			space(Exact(10))
			// Just a normal button
			do_button({label = text})
			space(Exact(10))
			// Button that has a state
			if do_toggle_button({state = boolean, label = "toggle button"}) {
				boolean = !boolean
			}
			space(Exact(10))
			// A radio button
			if do_radio_button({on = boolean, text = "radio button"}) {
				boolean = !boolean
			}
			space(Exact(10))
			// A tick box
			do_checkbox({state = &boolean, text = "tick box"})
			space(Exact(10))
			// A horizontal layout
			if do_horizontal(Exact(24)) {
				placement.size = Exact(100); placement.align.x = .Near 
				// A toggle switch
				do_toggle_switch({state = &boolean})
			}
			if boolean {
				space(Exact(30))
				// A knob (cool)
				gain = do_knob(Knob_Info(f64){value = gain, low = -70, high = 10, format = "Gain: %.1f"})
				space(Exact(30))
				// A slider (almost as cool)
				pitch = do_slider(Slider_Info(f64){value = pitch, low = -10, high = 10})
			}
			space(Exact(10))
			if do_horizontal(Exact(24)) {
				do_chip({text = "I'm a chip!"})
			}
		}

		// End of ui calls
		end_frame()
		
		// Update texture if necessary
		if painter.atlas.should_update {
			painter.atlas.should_update = false
			update_texture(painter.atlas.texture, painter.atlas.image, 0, 0, 4096, 4096)
		}

		// Render if needed
		if maui.should_render() {
			maui_opengl.render(&maui_glfw.interface)
			maui_glfw.end_frame()
		}
	}

	maui.uninit()	
	maui_opengl.destroy()
	maui_glfw.destroy()
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
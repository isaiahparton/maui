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
	number: f64
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
		if do_window({
			box = child_box(core.fullscreen_box, {300, 300}, {.Middle, .Middle}),
			title = "Hi! I'm a window :I",
			options = {.Title, .Closable, .Resizable, .Collapsable},
		}) {
			shrink(20)
			placement.size = Exact(28)
			do_button({label = "welcome!"})
			space(Exact(10))
			do_toggle_switch({state = &boolean})
			space(Exact(10))
			do_text_field({data = &text, placeholder = "enter something"})
			space(Exact(10))
			do_checkbox({state = &boolean, text = "Checkbox"})
		}
		if do_window({
			box = child_box(core.fullscreen_box, {300, 400}, {.Near, .Middle}),
			title = "Me too!",
			options = {.Title, .Closable, .Resizable, .Collapsable},
		}) {
			shrink(20)
			placement.size = Exact(28)
			do_button({label = "welcome!"})
			if do_layout(.Top, Exact(24)) {
				placement.side = .Left 
				do_button({label = "Button", fit_to_label = true})
			}
			space(Exact(10))
			if do_toggle_button({state = boolean, label = "Toggle Button"}) {
				boolean = !boolean
			}
			space(Exact(10))
			do_spin_counter(Spin_Counter_Info(f64){digits = 10, value = number})
			space(Exact(10))
			if do_radio_button({on = boolean, text = "Radio Button"}) {
				boolean = !boolean
			}
			space(Exact(10))
			number = do_knob(Knob_Info(f64){value = number, low = -70, high = 10, format = "Gain: %.1f"})
			space(Exact(10))
			number = do_slider(Slider_Info(f64){value = number, low = -70, high = 10})
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
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
	t: time.Time
	tt: time.Time
	show_window: bool
	boolean: bool
	choice: Choice
	slider_value: f32
	gain, pitch: f64
	text: string

	if !maui_glfw.init(1200, 1000, "Maui", .OpenGL) {
		return
	}

	if !maui_opengl.init(maui_glfw.interface) {
		return
	}

	maui.init()

	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using maui 
		using maui_widgets

		// Beginning of ui calls
		maui_glfw.begin_frame()
		begin_frame()

		if do_panel({
			placement = child_box(core.fullscreen_box, {300, 420}, {.Near, .Middle}),
			title = "DIGITAL",
			options = {.Title, .Closable, .Resizable, .Collapsable},
		}) {
			shrink(30)
			placement.size = Exact(32)
			do_button({label = "button"})
			space(Exact(20))
			placement.size = Exact(64)
			if do_toggle_button({label = "toggle button\nwith multiple lines", state = boolean}) {
				boolean = !boolean
			}
			space(Exact(20))
			placement.size = Exact(34)
			do_checkbox({state = &boolean, text = "checkbox"})
			space(Exact(20))
			choice = do_enum_radio_buttons(choice)
			space(Exact(20))
			placement.size = Exact(28)
			do_text_field({data = &text, placeholder = "Write that which thou thinkest"})
		}

		if do_panel({
			placement = child_box(core.fullscreen_box, {240, 320}, {.Middle, .Near}),
			title = "ANALOG",
			options = {.Title, .Closable, .Resizable, .Collapsable},
		}) {
			shrink(30)
			placement.size = Exact(30)
			slider_value = do_slider(Slider_Info(f32){value = slider_value, low = 0, high = 70, format = "%.1f"})
			placement.side = .Left 
			slider_value = do_slider(Slider_Info(f32){value = slider_value, low = 0, high = 70, format = "%.1f", orientation = .Vertical})
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
			maui_opengl.render(maui_glfw.interface)
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
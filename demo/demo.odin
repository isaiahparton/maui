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
	integer: int

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

		shrink(200)
		if do_layout(.Top, Exact(30)) {
			placement.side = .Left; placement.size = Exact(200)
			if do_button({label = "BUTTON"}) {

			}
			space(Exact(10))
			if do_button({label = "BUTTON"}) {

			}
		}
		cut(.Top, Exact(20))
		if do_layout(.Top, Exact(30)) {
			placement.side = .Left; placement.size = Exact(200)
			integer = do_spinner(Spinner_Info(int){value = integer, low = 0, high = 999})
		}

		if do_panel({
			title = "window of opportunity", 
			options = {.Title}, 
			placement = child_box(core.fullscreen_box, {300, 400}, {.Middle, .Middle}),
		}) {
			shrink(10)
			
		}

		paint_text({}, {text = "Layer list", font = style.font.monospace, size = 20}, {}, style.color.base_text[0])
		for layer, i in core.layer_agent.list {
			paint_text({20, 30 + 50 * f32(i)}, {text = tmp_printf("%x: %v", layer.id, layer.box), font = style.font.monospace, size = 20}, {}, style.color.base_text[1])
			paint_text({20, 50 + 50 * f32(i)}, {text = tmp_printf("%v", layer.state), font = style.font.monospace, size = 20}, {}, style.color.base_text[1])
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
package demo

import "core:time"
import "core:strings"
import "core:math/linalg"
import rl "vendor:raylib"
import ui "../"
import "../backend/maui_glfw"
import "../backend/maui_opengl"

import "core:fmt"
import "core:mem"

TARGET_FRAME_RATE :: 60
TARGET_FRAME_TIME :: 1.0 / TARGET_FRAME_RATE

Demo :: struct {
	start: proc(rawptr),
	run: proc(rawptr),
	end: proc(rawptr),
}

_main :: proc() {
	fmt.println("Structure sizes")
	fmt.println("  Painter:", size_of(ui.Painter))
	fmt.println("  Core:", size_of(ui.Core))

	text_demo: Text_Demo = {
		info = {text = "This is a demonstration of text rendering and interaction in maui", size = 20},
	}

	if !maui_glfw.init(1200, 1000, "Maui", .OpenGL) {
		return
	}

	if !maui_opengl.init(&maui_glfw.interface) {
		return
	}

	ui.init()

	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using ui

		// Beginning of ui calls
		maui_glfw.begin_frame()
		begin_frame()

		// UI calls
		shrink(50)
		do_text_demo(&text_demo)

		// End of ui calls
		end_frame()
		
		// Update texture if necessary
		if painter.atlas.should_update {
			painter.atlas.should_update = false
			update_texture(painter.atlas.texture, painter.atlas.image, 0, 0, 4096, 4096)
		}

		// Render if needed
		if ui.should_render() {
			maui_opengl.render(&maui_glfw.interface)
			maui_glfw.end_frame()
		}
	}

	ui.uninit()	
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
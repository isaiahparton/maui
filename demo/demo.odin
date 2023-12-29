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
	// Create the platform
	platform := maui_glfw.make_platform(1200, 1000, "Maui", .OpenGL) or_return
	// Create the renderer
	renderer := maui_opengl.make_renderer(platform.layer) or_return
	// Set up the UI context
	ui := maui.make_ui(platform.layer, renderer.layer) or_return
	// Begin the cycle
	for maui_glfw.cycle(&platform, TARGET_FRAME_TIME) {
		using maui 
		using maui_widgets

		// Beginning of ui calls
		maui_glfw.begin(&platform, &ui)

		begin_ui(&ui)
		if was_clicked(button(&ui, {text = "click me! uwu"})) {
			
		}
		end_ui(&ui)

		// Update texture if necessary
		if ui.painter.atlas.should_update {
			ui.painter.atlas.should_update = false
			update_texture(ui.painter.atlas.texture, ui.painter.atlas.image, 0, 0, f32(ui.painter.atlas.image.width), f32(ui.painter.atlas.image.height))
		}

		// Render if needed
		if maui.should_render(&ui.painter) {
			maui_opengl.clear(ui.style.color.base[0])
			maui_opengl.render(&renderer, &ui)
			maui_glfw.end(&platform)
		}
	}

	maui.destroy_ui(&ui)	
	maui_opengl.destroy_renderer(&renderer)
	maui_glfw.destroy_platform(&platform)

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
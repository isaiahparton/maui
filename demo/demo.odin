package demo

import "core:time"
import "core:strings"
import "core:math/linalg"
import rl "vendor:raylib"
import ui "../"
import ui_backend "../maui_glfw"

import "core:fmt"
import "core:mem"

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

	if !ui_backend.init(1200, 1000, "Maui") {
		return
	}
	ui.init()

	for !ui_backend.should_close() {
		using ui

		// Beginning of ui calls
		begin_frame()
		ui_backend.begin_frame()

		// UI calls
		shrink(50)
		placement.size = Exact(30)
		if do_button({label = "BUTTON", style = .Filled}) {

		}
		space(Exact(20))
		if do_layout(.Top, Exact(24)) {
			placement.side = .Left; placement.size = Exact(200)
			if do_menu({label = "menu", side = .Bottom}) {
				placement.size = Exact(24)
				do_option({label = "wow"})
				do_option({label = "such option"})
				do_option({label = "much choice"})
				if do_submenu({label = "submenu bro", size = {220, 0}}) {
					do_option({label = "another option bro"})
					do_option({label = "yo! another"})
					if do_submenu({label = "submenu bro", size = {220, 0}}) {
						do_option({label = "another option bro"})
						do_option({label = "yo! another"})
					}
				}
			}
		}
		space(Exact(20))
		if do_layout(.Top, Exact(24)) {
			placement.side = .Left; placement.size = Exact(200)
			if do_menu({label = "menu", side = .Bottom}) {
				placement.size = Exact(24)
				do_option({label = "wow"})
				do_option({label = "such option"})
				do_option({label = "much choice"})
				if do_submenu({label = "submenu bro", size = {220, 0}}) {
					do_option({label = "another option bro"})
					do_option({label = "yo! another"})
					if do_submenu({label = "submenu bro", size = {220, 0}}) {
						do_option({label = "another option bro"})
						do_option({label = "yo! another"})
					}
				}
			}
		}
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
			ui_backend.render()
		}
		// Poll events
		ui_backend.poll_events()
	}
	ui.uninit()	
	ui_backend.terminate()
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
package demo

import "core:time"
import "core:strings"
import "core:math/linalg"
import rl "vendor:raylib"
import ui "../"
import ui_backend "../raylib_backend"

import "core:fmt"
import "core:mem"

Demo :: struct {
	start: proc(rawptr),
	run: proc(rawptr),
	end: proc(rawptr),
}

_main :: proc() {
	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(1200, 900, "a window")
	rl.SetExitKey(.KEY_NULL)
	rl.SetTargetFPS(75)

	text_demo: Text_Demo

	ui_backend.init()
	ui.init()

	for true {
		{
			using ui
			begin_frame()
			ui_backend.begin_frame()

			core.current_time = rl.GetTime()

			shrink(100)

			do_text_demo(&text_demo)

			end_frame()

			if painter.atlas.should_update {
				painter.atlas.should_update = false
				update_texture(painter.atlas.texture, painter.atlas.image, 0, 0, 4096, 4096)
			}
		}

		rl.BeginDrawing()
		if ui.should_render() {
			rl.ClearBackground(transmute(rl.Color)ui.get_color(.Base))
			v_count := ui_backend.render()
			
			/*rl.DrawTexture({
				id = 3,
				format = .UNCOMPRESSED_R8G8B8A8,
				width = 4096,
				height = 4096,
				mipmaps = 1,
			}, 0, 0, rl.WHITE)*/
			
			rl.DrawText(rl.TextFormat("Vertices: %i/%i", v_count, ui.DRAW_COMMAND_SIZE), 0, 20, 20, rl.YELLOW)
			rl.DrawText(rl.TextFormat("%.2fms", time.duration_milliseconds(ui.core.frame_duration)), 0, 0, 20, rl.DARKGREEN)
		}
		rl.EndDrawing()
		if rl.WindowShouldClose() {
			break
		}
	}
	ui.uninit()	

	rl.CloseWindow()

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
package demo

import "core:time"
import "core:strings"
import rl "vendor:raylib"
import ui "../"
import ui_backend "../raylib_backend"

import "core:fmt"
import "core:mem"

Choice :: enum {
	First,
	Second,
	Third,
}

Choice_Set :: bit_set[Choice]

_main :: proc() {
	boolean: bool
	text_buffer: [dynamic]u8
	chips: [dynamic]string

	buttons: [ui.Button_Style][ui.Button_Shape]f32

	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(1200, 900, "a window")
	rl.SetExitKey(.KEY_NULL)
	rl.SetTargetFPS(75)

	ui_backend.init()
	ui.init()

	for true {
		{
			using ui
			begin_frame()
			ui_backend.begin_frame()

			core.current_time = rl.GetTime()

			shrink(200)
			if do_layout(.Top, Exact(30)) {
				placement.side = .Left
				placement.size = Exact(30)
				if do_button({
					shape = .Pill,
					label = "BUTTON",
				}) {

				}
				space(Exact(10))
				if do_button({
					shape = .Pill,
					style = .Outlined,
					label = "BUTTON",
				}) {

				}
			}

			end_frame()
		}

		rl.BeginDrawing()
		if ui.should_render() {
			rl.ClearBackground(transmute(rl.Color)ui.get_color(.Base))
			ui_backend.render()
			rl.DrawText(rl.TextFormat("%.2fms", time.duration_milliseconds(ui.core.frame_duration)), 0, 0, 20, rl.BLACK)
		}
		rl.EndDrawing()
		if rl.WindowShouldClose() {
			break
		}
	}

	rl.CloseWindow()

	ui.uninit()
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
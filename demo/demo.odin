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

	size: f32 = 24

	ui_backend.init()
	ui.init()
	for true {
		ui.painter.style.button_font_size += rl.GetMouseWheelMove()
		{
			using ui
			begin_frame()
			ui_backend.begin_frame()

			core.current_time = rl.GetTime()

			shrink(200)

			for i := 0; i < int(core.size.x); i += 10 {
				paint_box_fill({f32(i), 0, 1, core.size.y}, {255, 255, 255, 20})
			}
			paint_aligned_text(core.size / 2, {text = "Such text Much information (wow)", font = painter.style.default_font, size = 20, limit = {50, nil}, wrap = .Word}, .Middle, .Middle, {255, 255, 255, 255})

			if do_layout(.Top, Exact(size)) {
				placement.side = .Left
				do_button({
					label = "BUTTON",
					shape = .Pill,
				})
			}

			end_frame()

			if painter.atlas.should_update {
				painter.atlas.should_update = false
				update_texture(painter.atlas.texture, painter.atlas.image, 0, 0, 4096, 4096)
			}
		}

		rl.BeginDrawing()
		if ui.should_render() {
			rl.ClearBackground({})
			ui_backend.render()
			rl.DrawTexture({
				id = 3,
				format = .UNCOMPRESSED_R8G8B8A8,
				width = 4096,
				height = 4096,
				mipmaps = 1,
			}, 0, 0, rl.WHITE)
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
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
	limit: [2]Maybe(f32) = {50, nil}
	text_wrap: ui.Text_Wrap
	text_align: ui.Text_Align
	text_baseline: ui.Text_Baseline

	ui_backend.init()
	ui.init()

	for true {
		size += rl.GetMouseWheelMove()
		{
			using ui
			begin_frame()
			ui_backend.begin_frame()

			core.current_time = rl.GetTime()

			shrink(200)

			paint_box_fill({0, core.size.y / 2, core.size.x, 1}, {0, 100, 0, 255})
			paint_box_fill({core.size.x / 2, 0, 1, core.size.y}, {0, 100, 0, 255})

			paint_text(core.size / 2, {text = "This is a line\nThis is another line\nHere is another\nAnd yet another still\nThis is the last one don't worry", font = painter.style.default_font, size = size, wrap = text_wrap, limit = limit}, {align = text_align, baseline = text_baseline}, {255, 255, 255, 255})
			
			space(Exact(20))
			placement.size = Exact(30)
			space(Exact(20))
			text_align = do_enum_radio_buttons(text_align)
			space(Exact(20))
			text_baseline = do_enum_radio_buttons(text_baseline)
			space(Exact(20))
			text_wrap = do_enum_radio_buttons(text_wrap)
			space(Exact(20))
			if do_layout(.Top, Exact(30)) {
				placement.side = .Left; placement.size = Exact(200)
				if limit.x != nil {
					if changed, new_value := do_slider(Slider_Info(f32){
						value = limit.x.?, 
						low = 0, 
						high = 500,
						format = "%.0f",
					}); changed {
						limit.x = new_value
					}
				}
			}

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
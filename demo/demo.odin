package demo

import "core:time"
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

main :: proc() {
	choice: Choice
	choice_set: Choice_Set
	switch_state: bool
	slider_value_f32: f32
	slider_value_i32: i32
	calendar_time: time.Time
	temp_calendar_time: time.Time
	spinner_value: int
	text_buffer: [dynamic]u8
	multiline_buffer: [dynamic]u8
	section_state: bool

	button_load_timer: f32


	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(1200, 900, "a window")
	rl.SetTargetFPS(75)
	ui_backend.init()
	ui.init()

	image, _ := ui.load_image("logo.png")
	for true {
		{
			using ui
			begin_frame()
			ui_backend.begin_frame()

			core.current_time = rl.GetTime()

			shrink(100)
			if do_layout(.Left, 0.5, true) {
				shrink(10)
				set_size(30)
				do_text_input({data = &text_buffer})
				space(20)
				do_text_input({data = &text_buffer})
				space(20)
				do_text_input({data = &text_buffer})
			}
			if do_layout(.Left, 1, true) {
				shrink(10)
				set_size(500)
				do_image({
					image = image,
					uniform = true,
				})
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

	ui.unload_image(image)

	rl.CloseWindow()

	ui.uninit()
}
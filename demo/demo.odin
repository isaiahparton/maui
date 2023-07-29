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

	chips: [dynamic]string

	button_load_timer: f32


	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(1200, 900, "a window")
	rl.SetExitKey(.KEY_NULL)
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
				for &entry in chips {
					stack_push(&core.chips, Deferred_Chip{text = entry})
				}
				enter := key_pressed(.Enter)
				change := do_text_input({
					data = &text_buffer,
				})
				if change || enter {
					if len(text_buffer) > 0 {
						if (text_buffer[len(text_buffer) - 1] == ',') {
							append(&chips, strings.clone(string(text_buffer[:len(text_buffer) - 1])))
							clear(&text_buffer)
						} else if enter {
							append(&chips, strings.clone(string(text_buffer[:])))
							clear(&text_buffer)
						}
					}
				} else if len(chips) > 0 && key_pressed(.Backspace) {
					pop(&chips)
				}
				for i in 0..<core.chips.height {
					if core.chips.items[i].clicked {
						ordered_remove(&chips, i)
						break
					}
				}
				core.chips.height = 0

				space(10)
				if do_pill_button({
					label = "Bruh",
					load_time = f32(min(1, core.current_time * 0.1)),
				}) {

				}
				space(10)
				if do_menu({
					label = "Menu",
					size = {0, 90},
				}) {
					set_size(30)
					if do_option({
						label = "Option A",
					}) {

					}
					if do_option({
						label = "Option B",
					}) {

					}
					if do_submenu({
						label = "Submenu A",
						size = {200, 90},
					}) {
						set_size(30)
						if do_option({
							label = "Option C",
						}) {

						}
						if do_option({
							label = "Option D",
						}) {

						}
						if do_submenu({
							label = "Submenu B",
							size = {200, 60},
						}) {
							set_size(30)
							if do_option({
								label = "Option E",
							}) {

							}
							if do_option({
								label = "Option F",
							}) {

							}
						}
					}
				}
			}
			if do_layout(.Left, 1, true) {
				shrink(10)
				set_size(500)
				do_image({
					image = image,
					fit = .Width,
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
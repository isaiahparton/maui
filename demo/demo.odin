package demo

import "core:time"
import rl "vendor:raylib"
import ui "../"
import ui_backend "../raylib_backend"

import "core:fmt"
import "core:mem"

main :: proc() {
	rl.InitWindow(1000, 800, "a window")
	rl.SetTargetFPS(120)
	ui.init()
	ui_backend.init()

	for true {
		ui.begin_frame()
		ui_backend.begin_frame()

		ui.shrink(100)
		if ui.layout(.top, 30) {
			ui.set_side(.left)
			ui.pill_button({label = "Filled"})
			ui.space(10)
			ui.pill_button({label = "Outlined", style = .outlined})
			ui.space(10)
			ui.pill_button({label = "Subtle", style = .subtle})
		}

		ui.end_frame()

		rl.BeginDrawing()
		if ui.should_render() {
			rl.ClearBackground(transmute(rl.Color)ui.get_color(.base))
			ui_backend.render()
			rl.DrawText(rl.TextFormat("%.3fms", time.duration_milliseconds(ui.core.frame_duration)), 0, 0, 20, rl.BLACK)
		}
		rl.EndDrawing()
		if rl.WindowShouldClose() {
			break
		}
	}

	rl.CloseWindow()

	ui.uninit()
}
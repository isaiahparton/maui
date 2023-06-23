package demo

import rl "vendor:raylib"
import ui "../"
import ui_backend "../raylib_backend"

import "core:fmt"
import "core:mem"

main :: proc() {
	rl.InitWindow(1000, 800, "a window")
	ui.core_init()
	ui_backend.init()

	for true {
		ui.begin_frame()
		ui_backend.begin_frame()


		ui.end_frame()

		rl.BeginDrawing()
		if should_render() {
			rl.ClearBackground()
			ui_backend.render()
		}
		rl.EndDrawing()
		if rl.WindowShouldClose() {
			break
		}
	}

	rl.CloseWindow()
}
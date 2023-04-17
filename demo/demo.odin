package demo

import ui "../maui"
import rl "vendor:raylib"
import backend "../mauiRaylib"

import "core:runtime"
import "core:fmt"
import "core:math"
import "core:slice"

Choices :: enum {
	first,
	second,
	third,
}

main :: proc() {

	// Demo values
	choice: Choices = .first
	close := false
	value: f32 = 10.0
	integer := 0
	boolean := false

	wifi := true
	bluetooth := false

	buffer := make([dynamic]u8)

	// set up raylib
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(1000, 800, "Maui Demo")
	rl.MaximizeWindow()
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))

	ui.Init()
	backend.Init()

	ui.SetScreenSize(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))

	for true {
		ui.Refresh()

		backend.NewFrame()

		rect := ui.Cut(.right, 500)
		if layer, ok := ui.Layer(rect, {}); ok {
			ui.PaintRect(layer.body, ui.GetColor(.foreground, 1))
			ui.Shrink(20)

			ui.SetSize(40)
			ui.AlignY(.middle)

			ui.CheckBox(&boolean, "Check Box")
			boolean = ui.ToggleSwitch(boolean)

			ui.Space(10)
			if layout, ok := ui.Layout(ui.Cut(.top, 30)); ok {
				ui.SetSize(30)
				ui.SetSide(.left)
				ui.IconButton(.pencil)
			}

			ui.Space(10)
			if layout, ok := ui.Layout(ui.Cut(.top, 80)); ok {
				layout.side = .left
				layout.alignX = .middle
				layout.alignY = .middle
				layout.size = layout.rect.w / 3
				choice = ui.RadioButtons(choice, .bottom)
			}

			if layout, ok := ui.Layout(ui.Cut(.top, 40)); ok {
				layout.side = .left
				layout.size = layout.rect.w / 3
				layout.margin = 5

				ui.ButtonEx("SOLA FIDE", .subtle)
				ui.ButtonEx("SOLA GRACIA", .normal)
				ui.ButtonEx("SOLA SCRIPTURA", .bright)
			}

			ui.Space(20)
			ui.SetSize(300)
			if ui.Section("Section", {}) {
				ui.SetSize(36)
				ui.Space(10)
				if change, newData := ui.TextInputBytes(buffer[:], "Name", "John Doe", {}); change {
					resize(&buffer, len(newData))
					copy(buffer[:], newData[:])
				}

				ui.Space(10)
				if change, newValue := ui.SliderEx(value, 0, 20, "Slider Value"); change {
					value = newValue
				}

				ui.Space(10)
				value = ui.NumberInputFloat32(value, "Enter a value")

				ui.Space(10)
				ui.SetSize(30)
				choice = ui.EnumMenu(choice, 30)
				
				ui.Space(10)
				if layout, ok := ui.Layout(ui.Cut(.top, 30)); ok {
					layout.side = .left; layout.size = 100
					integer = ui.Spinner(integer, 0, 255)
				}
				ui.Space(10)
				if layout, ok := ui.Layout(ui.Cut(.top, 30)); ok {
					layout.side = .left; layout.size = 100
					integer = ui.DragSpinner(integer, 0, 0)
				}
			}
		}

		/*
			Drawing happens here
		*/
		ui.Prepare()

		rl.BeginDrawing()
		if ui.ShouldRender() {
			rl.ClearBackground(transmute(rl.Color)ui.GetColor(.backing))
			backend.Render()
			rl.DrawText(rl.TextFormat("FPS: %i", rl.GetFPS()), 0, 0, 20, rl.WHITE)
		}
		rl.EndDrawing()

		if rl.WindowShouldClose() || close {
			break
		}
	}
}

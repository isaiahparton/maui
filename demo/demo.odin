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
		if layer, ok := ui.Layer(rect); ok {
			ui.PaintRect(layer.body, ui.GetColor(.foreground, 1))
			ui.PushLayout(rect)
				ui.Shrink(20)

				ui.CheckBox(&boolean, "Check Box")

				ui.Space(10)
				ui.Size(46)
				if clicked, ok := ui.Widget("WiFi", {.bottom}); ok {
					ui.Side(.right)
					ui.Size(60)
					ui.Align(.middle)
					wifi = ui.ToggleSwitch(wifi)
					ui.WidgetDivider()

					if clicked {
						wifi = !wifi
					}
				}
				if clicked, ok := ui.Widget("Bluetooth", {.top}); ok {
					ui.Side(.right)
					ui.Size(60)
					ui.Align(.middle)
					bluetooth = ui.ToggleSwitch(bluetooth)
					ui.WidgetDivider()

					if clicked {
						bluetooth = !bluetooth
					}
				}

				ui.Space(10)
				if ui.Layout(ui.Cut(.top, 30)) {
					ui.Side(.left)
					ui.Size(0.333, true)
					choice = ui.RadioButtons(choice)
				}

				ui.Space(30)
				ui.Size(28)
				if ui.Layout(ui.Cut(.top, 28)) {
					ui.Side(.left)
					ui.Size(0.333, true)
					ui.ButtonEx("SOLA FIDE", .outlined)
					ui.ButtonEx("SOLA GRACIA", .contained)
					ui.ButtonEx("SOLA SCRIPTURA", .bright)
				}

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
				choice = ui.EnumMenu(choice)
				
				ui.Space(10)
				if ui.Layout(ui.Cut(.top, 30)) {
					ui.Side(.left)
					ui.Size(120)
					integer = ui.Spinner(integer, -100, 100)
				}
			ui.PopLayout()
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

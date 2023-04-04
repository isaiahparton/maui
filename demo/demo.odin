package demo

import ui "../maui"
import rl "vendor:raylib"

import "core:runtime"
import "core:fmt"
import "core:math"
import "core:slice"

texture: rl.Texture
commandCount := 0

Render :: proc() {
	using ui
	rl.SetMouseCursor(rl.MouseCursor(int(ui.ctx.cursor)))

	commandCount = 0
	cmd: ^Command
	
	for NextCommand(&cmd) {
		commandCount += 1
		switch v in cmd.variant {
			case ^CommandTexture:
			rl.rlSetTexture(texture.id)
			rl.rlBegin(rl.RL_QUADS)

			rl.rlNormal3f(0, 0, 1)
			rl.rlColor4ub(v.color.r, v.color.g, v.color.b, v.color.a)

			rl.rlTexCoord2f(v.uvMin.x, v.uvMin.y)
			rl.rlVertex2f(v.min.x, v.min.y)

			rl.rlTexCoord2f(v.uvMin.x, v.uvMax.y)
			rl.rlVertex2f(v.min.x, v.max.y)

			rl.rlTexCoord2f(v.uvMax.x, v.uvMax.y)
			rl.rlVertex2f(v.max.x, v.max.y)

			rl.rlTexCoord2f(v.uvMax.x, v.uvMin.y)
			rl.rlVertex2f(v.max.x, v.min.y)

			rl.rlEnd()

			case ^CommandTriangle:
			rl.rlBegin(rl.RL_TRIANGLES)
			rl.rlColor4ub(v.color.r, v.color.g, v.color.b, v.color.a)
			for vertex in v.vertices {
				rl.rlVertex2f(vertex.x, vertex.y)
			}
			rl.rlEnd()

			case ^CommandClip:
			rl.BeginScissorMode(i32(v.rect.x), i32(v.rect.y), i32(v.rect.w), i32(v.rect.h))
		}
	}

	rl.rlDrawRenderBatchActive()
	rl.EndScissorMode()
}

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
	buffer := make([dynamic]u8)

	// set up raylib
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(1000, 800, "Maui Demo")
	rl.MaximizeWindow()
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))

	ui.Init()

	image := transmute(rl.Image)ui.painter.image
	texture = rl.LoadTextureFromImage(image)
	rl.SetTextureFilter(texture, .BILINEAR)
	//ui.DoneWithAtlasImage()

	ui.SetScreenSize(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))

	for true {
		ui.Refresh()

		ui.SetScreenSize(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
		ui.SetMousePosition(f32(rl.GetMouseX()), f32(rl.GetMouseY()))
		ui.SetMouseBit(.left, rl.IsMouseButtonDown(.LEFT))
		ui.SetMouseBit(.right, rl.IsMouseButtonDown(.RIGHT))
		key := rl.GetCharPressed()
		for key != 0 {
			ui.InputAddCharPress(key)
			key = rl.GetCharPressed()
		}

		ui.SetKeyBit(.control, rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL))
		ui.SetKeyBit(.shift, rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT))
		ui.SetKeyBit(.backspace, rl.IsKeyDown(.BACKSPACE))
		ui.SetKeyBit(.left, rl.IsKeyDown(.LEFT))
		ui.SetKeyBit(.right, rl.IsKeyDown(.RIGHT))
		ui.SetKeyBit(.up, rl.IsKeyDown(.UP))
		ui.SetKeyBit(.down, rl.IsKeyDown(.DOWN))
		ui.SetKeyBit(.a, rl.IsKeyDown(.A))

		ui.ctx.deltaTime = rl.GetFrameTime()

		rect := ui.Cut(.right, 400)
		if layer, ok := ui.Layer(rect); ok {
			ui.PaintRect(layer.body, ui.GetColor(.windowBase, 1))
			ui.PushLayout(rect)
				ui.Shrink(20)

				ui.CheckBox(&boolean, "Check Box")

				ui.Space(10)
				boolean = ui.ToggleSwitch(boolean)

				ui.Space(10)
				if ui.Layout(ui.Cut(.top, 30)) {
					ui.CutSide(.left)
					ui.CutSize(0.333, true)
					choice = ui.RadioButtons(choice)
				}

				ui.Space(30)
				ui.Button("sola fide")

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
				if layer, ok := ui.Menu("hi", 120); ok {
					ui.MenuOption("hello")
				}
				
				ui.Space(10)
				if ui.Layout(ui.Cut(.top, 30)) {
					ui.CutSide(.left)
					ui.CutSize(120)
					integer = ui.Spinner(integer, -3, 3)
				}
			ui.PopLayout()
		}

		/*
			Drawing happens here
		*/
		ui.Prepare()

		rl.BeginDrawing()
		if ui.ShouldRender() {
			rl.ClearBackground({0, 0, 0, 255})
			Render()
			rl.DrawText(rl.TextFormat("FPS: %i", rl.GetFPS()), 0, 0, 20, rl.WHITE)
			rl.DrawText(rl.TextFormat("COMMANDS: %i", commandCount), 0, 20, 20, rl.WHITE)
		}
		rl.EndDrawing()

		if rl.IsKeyPressed(.F3) {
			rl.ExportImage(image, "atlas.png")
		}

		if rl.WindowShouldClose() || close {
			break
		}
	}
}

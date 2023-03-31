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

main :: proc() {
	close := false
	boolean := false
	text := "Sämple Téxt"
	buffer := make([dynamic]u8)
	append_elem_string(&buffer, text)
	// set up raylib
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(1000, 800, "Maui Demo")
	rl.MaximizeWindow()
	rl.SetTargetFPS(300)

	ui.Init()

	image := transmute(rl.Image)ui.painter.image
	texture = rl.LoadTextureFromImage(image)
	ui.DoneWithAtlasImage()

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
		ui.SetKeyBit(.backspace, rl.IsKeyDown(.BACKSPACE))
		ui.ctx.deltaTime = rl.GetFrameTime()

		rect := ui.Cut(.right, 400)
		if layer, ok := ui.Layer(rect); ok {
			ui.PaintRect(layer.body, ui.GetColor(.windowBase, 1))
			ui.PushLayout(rect)
				ui.Shrink(20)
				ui.CutSize(30)
				ui.CheckBox(&boolean, "close window")
				ui.Space(10)
				ui.ButtonEx("sola fide")
				ui.Space(10)
				if change, newData := ui.TextInputBytes(buffer[:], "", "", {}); change {
					resize(&buffer, len(newData))
					copy(buffer[:], newData[:])
				}
			ui.PopLayout()
		}

		/*
			Drawing happens here
		*/
		ui.Prepare()
		rl.ClearBackground({0, 0, 0, 255})

		Render()

		rl.DrawText(rl.TextFormat("FPS: %i", rl.GetFPS()), 0, 0, 20, rl.WHITE)
		rl.DrawText(rl.TextFormat("COMMANDS: %i", commandCount), 0, 20, 20, rl.WHITE)
		rl.DrawText("LAYER MAP:", 0, 100, 20, rl.WHITE)
		{
			offset := i32(0)
			for id, value in ui.ctx.layerMap {
				rl.DrawText(rl.TextFormat("%v: %v", id, value.body), 40, 120 + offset, 20, rl.WHITE)
				offset += 20
			}
		}

		if rl.IsKeyDown(.V) {
			for i in 0 ..< ui.MAX_CONTROLS {
				if ui.ctx.controlExists[i] {
					rl.DrawRectangleLinesEx(transmute(rl.Rectangle)ui.ctx.controls[i].body, 1, {255, 255, 0, 255})
				}
			}
		}
		if rl.IsKeyDown(.F) {
			rl.DrawRectangle(0, 0, texture.width, texture.height, rl.BLACK)
			rl.DrawTexture(texture, 0, 0, rl.WHITE)
		}
		rl.EndDrawing()

		if rl.WindowShouldClose() || close {
			break
		}
	}
}

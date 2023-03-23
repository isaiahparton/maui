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

	// set up raylib
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(1000, 800, "Maui Demo")
	rl.MaximizeWindow()
	rl.SetTargetFPS(60)

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
		ui.ctx.deltaTime = rl.GetFrameTime()

		if window, ok := ui.Window(); ok {
			window.options += {.title}
			if window.body == {} {
				window.body = {100, 100, 500, 400}
			}

			ui.Shrink(10)
			ui.CutSize(30)
			ui.ButtonEx("click me!")
		}

		/*
			Drawing happens here
		*/
		ui.Prepare()
		rl.ClearBackground({0, 0, 0, 255})

		Render()

		rl.DrawText(rl.TextFormat("FPS: %i", rl.GetFPS()), 0, 0, 20, rl.WHITE)
		rl.DrawText(rl.TextFormat("COMMANDS: %i", commandCount), 0, 20, 20, rl.WHITE)
		rl.DrawText(rl.TextFormat("LAYER LIST: %v", ui.ctx.layerList), 0, 60, 20, rl.WHITE)

		if rl.IsKeyDown(.F) {
			rl.DrawRectangle(0, 0, texture.width, texture.height, rl.BLACK)
			rl.DrawTexture(texture, 0, 0, rl.WHITE)
			for circle in ui.painter.circles {
				rl.DrawRectangleRec(transmute(rl.Rectangle)circle.source, {0, 255, 0, 100})
			}
		}
		rl.EndDrawing()

		if rl.WindowShouldClose() {
			break
		}
	}
}

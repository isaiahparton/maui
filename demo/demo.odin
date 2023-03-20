package demo

import ui "../maui"
import rl "vendor:raylib"

import "core:runtime"
import "core:fmt"
import "core:math"
import "core:slice"

font, icons: rl.Texture
cmd_count := 0

Render :: proc() {
	using ui
	cmd_count = 0
	cmd: ^Command
	for NextCommand(&cmd) {
		cmd_count += 1
		#partial switch v in cmd.variant {
			case ^CommandTexture:
			rl.DrawTexturePro(
				font if v.texture == 0 else icons, 
				{f32(v.src.x), f32(v.src.y), f32(v.src.w), f32(v.src.h)}, 
				{f32(v.dst.x), f32(v.dst.y), f32(v.dst.w), f32(v.dst.h)}, 
				{}, 
				0, 
				transmute(rl.Color)v.color,
			)

			case ^CommandTriangle:
			rl.rlBegin(rl.RL_TRIANGLES)
			rl.rlColor4ub(v.color.r, v.color.g, v.color.b, v.color.a)
			for i in 0 ..< 3 {
				rl.rlVertex2f(v.points[i].x, v.points[i].y)
			}
			rl.rlEnd()

			case ^CommandClip:
			/*rl.rlDisableScissorTest()
			rl.rlDrawRenderBatchActive()
			rl.rlEnableScissorTest()
			rl.rlScissor(i32(v.rect.x), i32(v.rect.y), i32(v.rect.w), i32(v.rect.h))*/
			rl.BeginScissorMode(i32(v.rect.x), i32(v.rect.y), i32(v.rect.w), i32(v.rect.h))
		}
	}

	rl.rlDrawRenderBatchActive()
	rl.EndScissorMode()
}

main :: proc() {

	title1, title2 := true, false
	resize1, resize2 := false, true

	// set up raylib
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(1000, 800, "Maui Demo")
	rl.MaximizeWindow()
	rl.SetTargetFPS(120)
	rl.rlEnableBackfaceCulling()

	ui.Init()
	ui.SetScreenSize(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))

	image := rl.Image{
		data = ui.ctx.font.imageData,
		width = ui.ctx.font.imageWidth,
		height = ui.ctx.font.imageHeight,
		format = .UNCOMPRESSED_GRAY_ALPHA,
		mipmaps = 1,
	}
	font = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	iconAtlas := rl.LoadImage("icons/atlas.png")
	rl.ImageColorBrightness(&iconAtlas, 255)
	icons = rl.LoadTextureFromImage(iconAtlas)
	rl.UnloadImage(iconAtlas)

	for true {
		ui.Refresh()

		ui.SetScreenSize(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
		ui.SetMousePosition(f32(rl.GetMouseX()), f32(rl.GetMouseY()))
		ui.SetMouseBit(.left, rl.IsMouseButtonDown(.LEFT))
		ui.ctx.deltaTime = rl.GetFrameTime()

		if ui.Panel(ui.Cut(.left, 300), "panel", {.autoFit}) {
			ui.Shrink(30)
			ui.CutSize(30)

			
		}

		/*
			Drawing happens here
		*/
		rl.BeginDrawing()
		// must call Prepare() before rendering
		ui.Prepare()
		if ui.ShouldRender() {
			rl.ClearBackground({150, 150, 150, 255})
			rl.DrawText(rl.TextFormat("FPS: %i", rl.GetFPS()), 0, 0, 20, rl.BLACK)
			rl.DrawText(rl.TextFormat("COMMANDS: %i", cmd_count), 0, 20, 20, rl.BLACK)
			rl.DrawText(rl.TextFormat("COMMANDS SIZE: %i / %i", ui.ctx.commandOffset, ui.COMMAND_STACK_SIZE), 0, 40, 20, rl.BLACK)
			Render()
		}
		rl.EndDrawing()

		if rl.WindowShouldClose() {
			break
		}
	}
}
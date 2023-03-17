package demo

import ui "../maui"
import rl "vendor:raylib"

import "core:runtime"
import "core:fmt"
import "core:slice"

font: rl.Texture

render :: proc() {
	using ui

	rl.rlEnableScissorTest()

	cmd: ^Command
	for next_command(&cmd) {
		#partial switch v in cmd.variant {
			case ^Command_Glyph:
			rl.DrawTexturePro(
				font, 
				{f32(v.src.x), f32(v.src.y), f32(v.src.w), f32(v.src.h)}, 
				{f32(v.origin.x), f32(v.origin.y), f32(v.src.w), f32(v.src.h)}, 
				{}, 
				0, 
				transmute(rl.Color)v.color,
			)

			case ^Command_Rect: 
			rl.DrawRectangle(v.rect.x, v.rect.y, v.rect.w, v.rect.h, transmute(rl.Color)v.color)

			case ^Command_Rect_Lines: 
			rl.DrawRectangleLinesEx({f32(v.rect.x), f32(v.rect.y), f32(v.rect.w), f32(v.rect.h)}, 2, transmute(rl.Color)v.color)

			case ^Command_Quad:
			rl.rlBegin(rl.RL_QUADS)
			rl.rlColor4ub(v.color.r, v.color.g, v.color.b, v.color.a)
			for i in 0..<4 {
				rl.rlVertex2i(v.points[i].x, v.points[i].y)
			}
			rl.rlEnd()

			case ^Command_Triangle:
			rl.rlBegin(rl.RL_TRIANGLES)
			rl.rlColor4ub(v.color.r, v.color.g, v.color.b, v.color.a)
			for i in 0..<3 {
				rl.rlVertex2i(v.points[i].x, v.points[i].y)
			}
			rl.rlEnd()

			case ^Command_Clip:
			rl.rlDrawRenderBatchActive()
			rl.rlScissor(v.rect.x, v.rect.y, v.rect.w, v.rect.h)
		}
	}

	rl.rlDisableScissorTest()
	rl.rlDrawRenderBatchActive()
}

main :: proc() {

	// set up raylib
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(1000, 800, "Maui Demo")
	rl.MaximizeWindow()
	rl.SetTargetFPS(60)

	ui.init()
	ui.set_size(rl.GetScreenWidth(), rl.GetScreenHeight())

	temp_font := rl.LoadFontEx("fonts/Muli.ttf", 26, nil, 566)
	font = temp_font.texture
	ui.state.glyphs = make([]ui.Glyph, temp_font.charsCount)
	for i in 0 ..< temp_font.charsCount {
		r := temp_font.recs[i]
		c := temp_font.chars[i]
		ui.state.glyphs[i] = {
			source = {i32(r.x), i32(r.y), i32(r.width), i32(r.height)},
			offset = {c.offsetX, c.offsetY},
		}
	}

	// define the panel, otherwise it would appear at 0,0 and auto-resize to fit its content
	ui.define_panel("showcase", {origin = {ui.Relative(0.5), ui.Relative(0.5)}, size = {200, 200}})

	for true {
		ui.set_size(rl.GetScreenWidth(), rl.GetScreenHeight())
		ui.set_mouse_position(rl.GetMouseX(), rl.GetMouseY())
		ui.set_mouse_bit(.left, rl.IsMouseButtonDown(.LEFT))
		ui.state.delta_time = rl.GetFrameTime()
		if ui.panel("showcase", false) {
			ui.shrink(10)
			ui.button("Sola fide")
			ui.cut_side(.top)
			ui.space(10)
			ui.button("Sola gracia")
		}

		rl.BeginDrawing()
		rl.ClearBackground(transmute(rl.Color)ui.color(0, 1))

		render()
		ui.refresh()

		rl.DrawFPS(0, 0)
		rl.EndDrawing()

		if rl.WindowShouldClose() {
			break
		}
	}
}
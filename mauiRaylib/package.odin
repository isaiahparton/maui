package mauiRaylib
import rl "vendor:raylib"
import ui "../maui"

@private texture: rl.Texture
Init :: proc() {
	image := transmute(rl.Image)ui.painter.image
	texture = rl.LoadTextureFromImage(image)
	rl.SetTextureFilter(texture, .BILINEAR)
	ui.DoneWithAtlasImage()
}

NewFrame :: proc() {
	ui.SetScreenSize(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
	ui.SetMousePosition(f32(rl.GetMouseX()), f32(rl.GetMouseY()))
	ui.SetMouseBit(.left, rl.IsMouseButtonDown(.LEFT))
	ui.SetMouseBit(.right, rl.IsMouseButtonDown(.RIGHT))
	ui.SetMouseBit(.middle, rl.IsMouseButtonDown(.MIDDLE))
	
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
	ui.SetKeyBit(.enter, rl.IsKeyDown(.ENTER))
	ui.SetKeyBit(.a, rl.IsKeyDown(.A))
	ui.SetKeyBit(.x, rl.IsKeyDown(.X))
	ui.SetKeyBit(.c, rl.IsKeyDown(.C))
	ui.SetKeyBit(.v, rl.IsKeyDown(.V))

	ui.ctx.deltaTime = rl.GetFrameTime()
}

Render :: proc() {
	using ui
	if ctx.cursor == .none {
		rl.HideCursor()
	} else {
		rl.ShowCursor()
		rl.SetMouseCursor(rl.MouseCursor(int(ctx.cursor)))
	}
	if ctx.setMouse {
		rl.SetMousePosition(i32(ctx.setMousePoint.x), i32(ctx.setMousePoint.y))
	}

	cmd: ^Command
	
	for NextCommand(&cmd) {
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
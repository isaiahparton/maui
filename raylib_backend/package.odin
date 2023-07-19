package maui_raylib
import rl "vendor:raylib"
import ui ".."
import "core:fmt"

import "core:strings"

@private texture: rl.Texture

init :: proc() {
	assert(rl.IsWindowReady())

	image := transmute(rl.Image)ui.painter.image
	texture = rl.LoadTextureFromImage(image)
	rl.SetTextureFilter(texture, .POINT)

	ui._set_clipboard_string = proc(str: string) {
		cstr := strings.clone_to_cstring(str)
		defer delete(cstr)
		rl.SetClipboardText(cstr)
	}
	ui._get_clipboard_string = proc() -> string {
		return string(rl.GetClipboardText())
	}
}
update_texture :: proc() {
	rl.UpdateTexture(texture, ui.painter.image.data)
}
uninit :: proc() {
	rl.UnloadTexture(texture)
}

begin_frame :: proc() {
	ui.set_screen_size(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
	ui.set_mouse_point(f32(rl.GetMouseX()), f32(rl.GetMouseY()))
	ui.set_mouse_bit(.Left, rl.IsMouseButtonDown(.LEFT))
	ui.set_mouse_bit(.Right, rl.IsMouseButtonDown(.RIGHT))
	ui.set_mouse_bit(.Middle, rl.IsMouseButtonDown(.MIDDLE))

	ui.set_key_bit(.Control, rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL))
	shift_down := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT); ui.set_key_bit(.Shift, shift_down)
	ui.set_key_bit(.Backspace, rl.IsKeyDown(.BACKSPACE))
	ui.set_key_bit(.Tab, rl.IsKeyDown(.TAB))
	ui.set_key_bit(.Left, rl.IsKeyDown(.LEFT))
	ui.set_key_bit(.Right, rl.IsKeyDown(.RIGHT))
	ui.set_key_bit(.Up, rl.IsKeyDown(.UP))
	ui.set_key_bit(.Down, rl.IsKeyDown(.DOWN))
	ui.set_key_bit(.Alt, rl.IsKeyDown(.LEFT_ALT))
	ui.set_key_bit(.Enter, rl.IsKeyDown(.ENTER))
	ui.set_key_bit(.A, rl.IsKeyDown(.A))
	ui.set_key_bit(.X, rl.IsKeyDown(.X))
	ui.set_key_bit(.C, rl.IsKeyDown(.C))
	ui.set_key_bit(.V, rl.IsKeyDown(.V))

	if shift_down {
		ui.set_mouse_scroll(rl.GetMouseWheelMove(), 0)
	} else {
		ui.set_mouse_scroll(0, rl.GetMouseWheelMove())
	}
	
	key := rl.GetCharPressed()
	for key != 0 {
		ui.input_add_char(key)
		key = rl.GetCharPressed()
	}
	
	ui.core.delta_time = rl.GetFrameTime()
}

render :: proc() {
	using ui

	if core.cursor == .None {
		rl.HideCursor()
	} else {
		rl.ShowCursor()
		rl.SetMouseCursor(rl.MouseCursor(int(core.cursor)))
	}

	cmd: ^Command
	
	for next_command(&cmd) {
		switch v in cmd.variant {
			case ^Command_Texture:
			rl.rlSetTexture(texture.id)
			rl.rlBegin(rl.RL_QUADS)

			rl.rlNormal3f(0, 0, 1)
			rl.rlColor4ub(v.color.r, v.color.g, v.color.b, v.color.a)

			rl.rlTexCoord2f(v.uv_min.x, v.uv_min.y)
			rl.rlVertex2f(v.min.x, v.min.y)

			rl.rlTexCoord2f(v.uv_min.x, v.uv_max.y)
			rl.rlVertex2f(v.min.x, v.max.y)

			rl.rlTexCoord2f(v.uv_max.x, v.uv_max.y)
			rl.rlVertex2f(v.max.x, v.max.y)

			rl.rlTexCoord2f(v.uv_max.x, v.uv_min.y)
			rl.rlVertex2f(v.max.x, v.min.y)

			rl.rlEnd()

			case ^Command_Triangle:
			rl.rlBegin(rl.RL_TRIANGLES)
			rl.rlColor4ub(v.color.r, v.color.g, v.color.b, v.color.a)
			for vertex in v.vertices {
				rl.rlVertex2f(vertex.x, vertex.y)
			}
			rl.rlEnd()

			case ^Command_Clip:
			rl.BeginScissorMode(i32(v.box.x), i32(v.box.y), i32(v.box.w), i32(v.box.h))
		}
	}

	rl.rlDrawRenderBatchActive()
	rl.EndScissorMode()
}
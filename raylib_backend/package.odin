package maui_raylib

import rl "vendor:raylib"
import ui ".."

import "core:fmt"
import "core:runtime"

import "core:strings"

init :: proc() {
	using ui
	assert(rl.IsWindowReady())

	_set_clipboard_string = proc(str: string) {
		cstr := strings.clone_to_cstring(str)
		defer delete(cstr)
		rl.SetClipboardText(cstr)
	}
	_get_clipboard_string = proc() -> string {
		return string(rl.GetClipboardText())
	}
	_update_texture = proc(texture: Texture, data: []u8, x, y, w, h: f32) {
		rl.rlUpdateTexture(texture.id, i32(x), i32(y), i32(w), i32(h), i32(rl.PixelFormat.UNCOMPRESSED_R8G8B8A8), (transmute(runtime.Raw_Slice)data).data)
	}
	_load_texture = proc(image: Image) -> (id: u32, ok: bool) {
		rl_image: rl.Image = {
			data = (transmute(runtime.Raw_Slice)image.data).data,
			width = i32(image.width),
			height = i32(image.height),
			format = .UNCOMPRESSED_R8G8B8A8,
			mipmaps = 1,
		}
		texture := rl.LoadTextureFromImage(rl_image)
		return texture.id, rl.IsTextureReady(texture)
	}
	_unload_texture = proc(id: u32) {
		rl.UnloadTexture({id = id})
	}
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

	rl.rlDisableBackfaceCulling()
	if core.cursor == .None {
		rl.HideCursor()
	} else {
		rl.ShowCursor()
		rl.SetMouseCursor(rl.MouseCursor(int(core.cursor)))
	}

	for layer in core.layer_agent.list {
		if clip, ok := layer.command.clip.?; ok {
			rl.rlScissor(i32(clip.x), i32(clip.y), i32(clip.w), i32(clip.h))
		}
		rl.rlBegin(rl.RL_TRIANGLES)
		rl.rlSetTexture(painter.atlas.texture.id)
		for i in 0..<layer.command.indices_offset {
			v := layer.command.vertices[layer.command.indices[i]]
			rl.rlColor4ub(v.color.r, v.color.g, v.color.b, v.color.a)
			rl.rlTexCoord2f(v.uv.x, v.uv.y)
			rl.rlVertex2f(v.point.x, v.point.y)
		}
		rl.rlEnd()
		if layer.command.clip != nil {
			rl.rlDrawRenderBatchActive()
		}
	}

	rl.rlSetTexture(0)
	rl.EndScissorMode()
	rl.rlEnableBackfaceCulling()
}
package maui_raylib

import rl "vendor:raylib"
import ui ".."

import "core:fmt"
import "core:runtime"

import "core:strings"

init :: proc(w, h: int, title: string) {
	using ui
	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitPanel(i32(w), i32(h), strings.clone_to_cstring(title))

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

terminate :: proc() {
	rl.ClosePanel()
}

should_close :: proc() -> bool {
	return rl.PanelShouldClose()
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
	
	ui.ctx.delta_time = rl.GetFrameTime()
	ui.ctx.current_time = rl.GetTime()
}

render :: proc() -> int {
	using ui

	triangle_count := 0

	rl.rlDrawRenderBatchActive()
	rl.rlDisableBackfaceCulling()
	rl.rlEnableScissorTest()

	if ctx.cursor == .None {
		rl.HideCursor()
	} else {
		rl.ShowCursor()
		rl.SetMouseCursor(rl.MouseCursor(int(ctx.cursor)))
	}

	for &layer in ctx.layer_agent.list {
		for index in layer.draws {
			draw := &painter.draws[index]
			triangle_count += int(draw.vertices_offset / 3)
			/*
				Set up clipping
			*/
			if .Clipped in layer.bits {
				//rl.rlScissor(i32(layer.box.low.x), i32(layer.box.low.y), i32(layer.box.high.x - layer.box.low.x), i32(layer.box.high.y - layer.box.low.y))
			}
			/*
				Draw triangles from indices
			*/
			rl.rlBegin(rl.RL_TRIANGLES)
			rl.rlSetTexture(draw.texture)
			for i in draw.indices[:draw.indices_offset] {
				v := draw.vertices[i]
				/*
				if rl.rlCheckRenderBatchLimit(3) > 0 {
					rl.rlBegin(rl.RL_TRIANGLES)
					rl.rlSetTexture(draw.texture)
				}
				*/
				rl.rlColor4ub(v.color.r, v.color.g, v.color.b, v.color.a)
				rl.rlTexCoord2f(v.uv.x, v.uv.y)
				rl.rlVertex2f(v.point.x, v.point.y)
			}
			rl.rlEnd()
			/*
				Draw current batch
			*/
			rl.rlDrawRenderBatchActive()
		}
	}

	rl.rlSetTexture(0)
	rl.EndScissorMode()
	rl.rlEnableBackfaceCulling()

	return triangle_count
}
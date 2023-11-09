package maui_opengl

import "core:os"
import "core:fmt"
import "core:runtime"

import "vendor:glfw"
import gl "vendor:OpenGL"

load_shader_from_data :: proc(type: u32, data: string) -> (id: u32) {
	id = gl.CreateShader(type)
	cstr := cstring((transmute(runtime.Raw_String)data).data)
	gl.ShaderSource(id, 1, &cstr, nil)
	gl.CompileShader(id)
	return
}
load_shader_from_file :: proc(type: u32, file: string) -> (id: u32, ok: bool) {
	data := os.read_entire_file(file) or_return
	defer delete(data)
	return load_shader_from_data(type, string(data)), true
}
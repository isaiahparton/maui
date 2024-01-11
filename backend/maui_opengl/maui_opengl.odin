package maui_opengl

// Import ctx deps
import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:math"
import "core:math/linalg"
// Import opengl
import gl "vendor:OpenGL"
// Import maui
import maui "../../"
// Import backend
import "../"

/*
	Error checking
*/
gl_check_error :: proc(loc := #caller_location) {
	err := gl.GetError()
	if err != 0 {
		fmt.printf("%v: 0x%i\n", loc, err)
	}
}
check_shader :: proc(id: u32, name: string) -> bool {
	success: i32
	gl.GetShaderiv(id, gl.COMPILE_STATUS, &success)
	if success == 0 {
		info: [512]u8 
		length: i32 
		gl.GetShaderInfoLog(id, 512, &length, transmute([^]u8)(&info))
		fmt.printf("Failed to compile %s\n", name)
		fmt.println(string(info[:length]))
		return false 
	}
	return true
}
check_program :: proc(id: u32, name: string) -> bool {
	success: i32
	gl.GetProgramiv(id, gl.LINK_STATUS, &success)
	if success == 0 {
		info: [512]u8 
		length: i32 
		gl.GetProgramInfoLog(id, 512, &length, transmute([^]u8)(&info))
		fmt.printf("Failed to compile %s\n", name)
		fmt.println(string(info[:length]))
		return false 
	}
	return true
}

Renderer :: struct {
	last_screen_size: [2]i32,
	// Shader program handles
	default_program: u32,
	// Default shader locations
	blur_orientation_loc,
	tex_uniform_loc,
	projmtx_uniform_loc,
	pos_attrib_loc,
	uv_attrib_loc,
	col_attrib_loc: u32,
	// Main fbo
	ibo,
	vbo,
	default_tex,
	default_fbo: u32,
}

@private
renderer: Renderer

/*
	Initialize rendering context
		Load OpenGL
		Load shaders
		Set texture handling procedures
*/
init :: proc(painter: ^maui.Painter) -> (ok: bool) {
  {
		VERTEX_SHADER_330 := #load("./default.vert")
		FRAGMENT_SHADER_330 := #load("./default.frag")

		// Load stuff
		frag_shader := load_shader_from_data(gl.FRAGMENT_SHADER, string(FRAGMENT_SHADER_330))
		check_shader(frag_shader, "default frag shader")
  	vert_shader := load_shader_from_data(gl.VERTEX_SHADER, string(VERTEX_SHADER_330))
		check_shader(vert_shader, "default vert shader")

		renderer.default_program = gl.CreateProgram()
		gl.AttachShader(renderer.default_program, vert_shader)
		gl.AttachShader(renderer.default_program, frag_shader)
		gl.LinkProgram(renderer.default_program)
		check_program(renderer.default_program, "default shader program")

		// Get uniform and attribute locations
		renderer.projmtx_uniform_loc 	= cast(u32)gl.GetUniformLocation(renderer.default_program, "ProjMtx")
		renderer.tex_uniform_loc 			= cast(u32)gl.GetUniformLocation(renderer.default_program, "Texture")
		renderer.pos_attrib_loc 			= cast(u32)gl.GetAttribLocation(renderer.default_program, "Position")
		renderer.uv_attrib_loc 				= cast(u32)gl.GetAttribLocation(renderer.default_program, "UV")
		renderer.col_attrib_loc 			= cast(u32)gl.GetAttribLocation(renderer.default_program, "Color")
  }

	// Generate vertex and index buffers
	gl.GenBuffers(1, &renderer.vbo)
	gl.GenBuffers(1, &renderer.ibo)
	// Bind them
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

	// Texture procedures
	painter.load_texture = proc(image: maui.Image) -> (texture: maui.Texture, ok: bool) {
		gl.BindTexture(gl.TEXTURE_2D, 0)
		gl.GenTextures(1, &texture.id)
		if texture.id == 0 {
			return
		}
		texture.width = image.width
		texture.height = image.height
		texture.channels = image.channels
		// Bind texture
		gl.BindTexture(gl.TEXTURE_2D, texture.id)
		// Set sampling parameters
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_NEAREST)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
		// Upload image data
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(image.width), i32(image.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, (transmute(runtime.Raw_Slice)image.data).data)
		// Generate mipmaps
		gl.GenerateMipmap(gl.TEXTURE_2D)
		// Unbind texture
		gl.BindTexture(gl.TEXTURE_2D, 0)
		ok = true
		return
	}
	painter.unload_texture = proc(texture: maui.Texture) {
		id := texture.id
		gl.DeleteTextures(1, &id)
	}
	painter.update_texture = proc(tex: maui.Texture, data: []u8, x, y, w, h: f32) {
		prev_tex: i32
		gl.GetIntegerv(gl.TEXTURE_BINDING_2D, &prev_tex)
		gl.BindTexture(gl.TEXTURE_2D, tex.id)
		gl.TexSubImage2D(gl.TEXTURE_2D, 0, i32(x), i32(y), i32(w), i32(h), gl.RGBA, gl.UNSIGNED_BYTE, (transmute(runtime.Raw_Slice)data).data)
		gl.BindTexture(gl.TEXTURE_2D, u32(prev_tex))
	}
	ok = true
	return
}

destroy :: proc() {
	// Delete opengl things
	gl.DeleteProgram(renderer.default_program)
	gl.DeleteBuffers(1, &renderer.vbo)
	gl.DeleteBuffers(1, &renderer.ibo)
}

clear :: proc(color: maui.Color) {
	gl.Disable(gl.SCISSOR_TEST)
	gl.ClearColor(f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255)
  gl.Clear(gl.COLOR_BUFFER_BIT)
}

render :: proc(ui: ^maui.UI) -> int {
	renderer.last_screen_size = ui.io.size

	gl.Viewport(0, 0, ui.io.size.x, ui.io.size.y)
	gl.Enable(gl.BLEND)
	gl.Enable(gl.MULTISAMPLE)
	gl.BlendEquation(gl.FUNC_ADD)
	gl.BlendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
	gl.Disable(gl.CULL_FACE)
	gl.Disable(gl.DEPTH_TEST)
	gl.Disable(gl.STENCIL_TEST)
	gl.Enable(gl.SCISSOR_TEST)
	gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)

  // Set projection matrix
  L: f32 = 0
  R: f32 = L + f32(ui.io.size.x)
  T: f32 = 0
  B: f32 = T + f32(ui.io.size.y)
  ortho_projection: linalg.Matrix4x4f32 = {
  	2.0/(R-L), 0.0,	0.0, -1.0,
  	0.0, 2.0/(T-B), 0.0, 1.0,
  	0.0, 0.0, 1.0, 0.0,
  	0.0, 0.0, 0.0, 1.0,
  }

  gl.UseProgram(renderer.default_program)
	gl.Uniform1i(i32(renderer.tex_uniform_loc), 0)
  gl.UniformMatrix4fv(i32(renderer.projmtx_uniform_loc), 1, gl.FALSE, transmute([^]f32)(&ortho_projection))

  vao_handle: u32 
  gl.GenVertexArrays(1, &vao_handle)
	gl.BindVertexArray(vao_handle)

	gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, renderer.ibo)

	gl.EnableVertexAttribArray(renderer.pos_attrib_loc)
	gl.EnableVertexAttribArray(renderer.uv_attrib_loc)
	gl.EnableVertexAttribArray(renderer.col_attrib_loc)
	gl.VertexAttribPointer(renderer.pos_attrib_loc, 2, gl.FLOAT, gl.FALSE, size_of(maui.Vertex), 0)
	gl.VertexAttribPointer(renderer.uv_attrib_loc, 2, gl.FLOAT, gl.FALSE, size_of(maui.Vertex), 8)
	gl.VertexAttribPointer(renderer.col_attrib_loc, 4, gl.UNSIGNED_BYTE, gl.TRUE, size_of(maui.Vertex), 16)

	gl.BindTexture(gl.TEXTURE_2D, ui.painter.texture.id)
	render_meshes(ui)

	// Delete the temporary VAO
	gl.DeleteVertexArrays(1, &vao_handle)

	// Unbind stuff
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindVertexArray(0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

	return 0
}

render_meshes :: proc(ui: ^maui.UI) {
	for &layer in ui.layers.list {
		for target in layer.targets {
			mesh := &ui.painter.meshes[target]
			if clip, ok := mesh.clip.?; ok {
				gl.Enable(gl.SCISSOR_TEST)
				gl.Scissor(i32(clip.low.x), i32(ui.size.y) - i32(clip.high.y), i32(clip.high.x - clip.low.x), i32(clip.high.y - clip.low.y))
			} else {
				gl.Disable(gl.SCISSOR_TEST)
			}
			/*
				Upload vertices and indices
			*/
			vertices := mesh.vertices[:mesh.vertices_offset]
			gl.BufferData(gl.ARRAY_BUFFER, size_of(maui.Vertex) * len(vertices), (transmute(runtime.Raw_Slice)vertices).data, gl.STREAM_DRAW)
			indices := mesh.indices[:mesh.indices_offset]
			gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(u16) * len(indices), (transmute(runtime.Raw_Slice)indices).data, gl.STREAM_DRAW)
			/*
				Draw call
			*/
			gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_SHORT, nil)
		}
	}
}
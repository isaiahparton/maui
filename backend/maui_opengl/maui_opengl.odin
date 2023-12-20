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
	// Context interface
	layer: maui.Renderer_Layer,
	//
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
	// For quick copying between framebuffers
	copy_vao: u32,
	copy_vbo: u32,
	quad_verts: [24]f32,
	// Main fbo
	ibo,
	vbo,
	default_tex,
	default_fbo: u32,
	// These are the size of the default framebuffer
	big_tex,
	big_fbo: u32,
	// These are the size of the default framebuffer
	pingpong_tex,
	pingpong_fbo: [2]u32,
}

load_copy_vao :: proc(using renderer: ^Renderer) {
	quad_verts = {
		-1.0, -1.0,  0.0, 0.0,
		1.0, -1.0,  1.0, 0.0,
		-1.0,  1.0,  0.0, 1.0,
	 	1.0, -1.0,  1.0, 0.0,
	 	1.0,  1.0,  1.0, 1.0,
		-1.0,  1.0,  0.0, 1.0,
	}
	gl.GenVertexArrays(1, &copy_vao)
	gl.GenBuffers(1, &copy_vbo)
	gl.BindVertexArray(copy_vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, copy_vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(quad_verts) * size_of(f32), &quad_verts, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), uintptr(2 * size_of(f32)))
}
delete_copy_vao :: proc(using renderer: ^Renderer) {
	gl.DeleteVertexArrays(1, &copy_vao)
	gl.DeleteBuffers(1, &copy_vbo)
}

load_big_fbo :: proc(using renderer: ^Renderer) {
	gl.GenFramebuffers(1, &big_fbo)
	gl.GenTextures(1, &big_tex)
	gl.BindFramebuffer(gl.FRAMEBUFFER, big_fbo)
	gl.BindTexture(gl.TEXTURE_2D, big_tex)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, layer.screen_size.x, layer.screen_size.y, 0, gl.RGBA, gl.BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, big_tex, 0)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}
delete_big_fbo :: proc(using renderer: ^Renderer) {
	gl.DeleteTextures(1, &big_tex)
	gl.DeleteFramebuffers(1, &big_fbo)
}

load_pingpong_fbos :: proc(using renderer: ^Renderer) {
	gl.GenFramebuffers(2, &pingpong_fbo[0])
	gl.GenTextures(2, &pingpong_tex[0])
	for i in 0..<2 {
		gl.BindFramebuffer(gl.FRAMEBUFFER, pingpong_fbo[i])
		gl.BindTexture(gl.TEXTURE_2D, pingpong_tex[i])
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, layer.screen_size.x, layer.screen_size.y, 0, gl.RGBA, gl.BYTE, nil)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, pingpong_tex[i], 0)
	}
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}
delete_pingpong_fbos :: proc(using renderer: ^Renderer) {
	gl.DeleteTextures(2, &pingpong_tex[0])
	gl.DeleteFramebuffers(2, &pingpong_fbo[0])
}
/*
	Initialize rendering context
		Load OpenGL
		Load shaders
		Set texture handling procedures
*/
make_renderer :: proc() -> (result: Renderer, ok: bool) {
	// Set viewport
  // gl.Viewport(0, 0, screen_size.x, screen_size.y)
  
  {
		VERTEX_SHADER_330 := #load("./default.vert")
		FRAGMENT_SHADER_330 := #load("./default.frag")

		// Load stuff
		frag_shader := load_shader_from_data(gl.FRAGMENT_SHADER, string(FRAGMENT_SHADER_330))
		check_shader(frag_shader, "default frag shader")
  	vert_shader := load_shader_from_data(gl.VERTEX_SHADER, string(VERTEX_SHADER_330))
		check_shader(vert_shader, "default vert shader")

		result.default_program = gl.CreateProgram()
		gl.AttachShader(result.default_program, vert_shader)
		gl.AttachShader(result.default_program, frag_shader)
		gl.LinkProgram(result.default_program)
		check_program(result.default_program, "default shader program")

		// Get uniform and attribute locations
		result.projmtx_uniform_loc 	= cast(u32)gl.GetUniformLocation(result.default_program, "ProjMtx")
		result.tex_uniform_loc 			= cast(u32)gl.GetUniformLocation(result.default_program, "Texture")
		result.pos_attrib_loc 			= cast(u32)gl.GetAttribLocation(result.default_program, "Position")
		result.uv_attrib_loc 				= cast(u32)gl.GetAttribLocation(result.default_program, "UV")
		result.col_attrib_loc 			= cast(u32)gl.GetAttribLocation(result.default_program, "Color")
  }

	load_copy_vao(&result)

	// Generate vertex and index buffers
	gl.GenBuffers(1, &result.vbo)
	gl.GenBuffers(1, &result.ibo)
	// Bind them
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

	// Texture procedures
	maui._load_texture = proc(image: maui.Image) -> (id: u32, ok: bool) {
		gl.BindTexture(gl.TEXTURE_2D, 0)
		gl.GenTextures(1, &id)
		if id == 0 {
			return
		}
		// Bind texture
		gl.BindTexture(gl.TEXTURE_2D, id)
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
	maui._unload_texture = proc(id: u32) {
		id := id
		gl.DeleteTextures(1, &id)
	}
	maui._update_texture = proc(tex: maui.Texture, data: []u8, x, y, w, h: f32) {
		gl.BindTexture(gl.TEXTURE_2D, tex.id)
		gl.TexSubImage2D(gl.TEXTURE_2D, 0, i32(x), i32(y), i32(w), i32(h), gl.RGBA, gl.UNSIGNED_BYTE, (transmute(runtime.Raw_Slice)data).data)
	}

	return
}

destroy_renderer :: proc(using self: ^Renderer) {
	// Delete opengl things
	gl.DeleteProgram(default_program)
	gl.DeleteBuffers(1, &vbo)
	gl.DeleteBuffers(1, &ibo)
	delete_pingpong_fbos(self)
	delete_big_fbo(self)
}

clear :: proc(color: maui.Color) {
	gl.Disable(gl.SCISSOR_TEST)
	gl.ClearColor(f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255)
  gl.Clear(gl.COLOR_BUFFER_BIT)
}

render :: proc(using renderer: ^Renderer, ctx: ^maui.Context) -> int {
	layer = ctx.renderer
	if last_screen_size != layer.screen_size {
		delete_big_fbo(renderer)
		load_big_fbo(renderer)
		delete_pingpong_fbos(renderer)
		load_pingpong_fbos(renderer)
	}
	last_screen_size = layer.screen_size

	gl.Viewport(0, 0, layer.screen_size.x, layer.screen_size.y)
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
  R: f32 = L + f32(layer.screen_size.x)
  T: f32 = 0
  B: f32 = T + f32(layer.screen_size.y)
  ortho_projection: linalg.Matrix4x4f32 = {
  	2.0/(R-L), 0.0,	0.0, -1.0,
  	0.0, 2.0/(T-B), 0.0, 1.0,
  	0.0, 0.0, 1.0, 0.0,
  	0.0, 0.0, 0.0, 1.0,
  }

  gl.UseProgram(default_program)
	gl.Uniform1i(i32(tex_uniform_loc), 0)
  gl.UniformMatrix4fv(i32(projmtx_uniform_loc), 1, gl.FALSE, transmute([^]f32)(&ortho_projection))

  vao_handle: u32 
  gl.GenVertexArrays(1, &vao_handle)
	gl.BindVertexArray(vao_handle)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo)

	gl.EnableVertexAttribArray(pos_attrib_loc)
	gl.EnableVertexAttribArray(uv_attrib_loc)
	gl.EnableVertexAttribArray(col_attrib_loc)
	gl.VertexAttribPointer(pos_attrib_loc, 2, gl.FLOAT, gl.FALSE, size_of(maui.Vertex), 0)
	gl.VertexAttribPointer(uv_attrib_loc, 2, gl.FLOAT, gl.FALSE, size_of(maui.Vertex), 8)
	gl.VertexAttribPointer(col_attrib_loc, 4, gl.UNSIGNED_BYTE, gl.TRUE, size_of(maui.Vertex), 16)

	render_meshes(renderer, ctx)

	// Delete the temporary VAO
	gl.DeleteVertexArrays(1, &vao_handle)

	// Unbind stuff
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindVertexArray(0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

	return 0
}

render_meshes :: proc(using renderer: ^Renderer, ctx: ^maui.Context) {
	for &layer in ctx.layer_agent.list {
		for index in layer.meshes {
			mesh := &ctx.painter.meshes[index]
			if clip, ok := mesh.clip.?; ok {
				gl.Enable(gl.SCISSOR_TEST)
				gl.Scissor(i32(clip.low.x), renderer.layer.screen_size.y - i32(clip.high.y), i32(clip.high.x - clip.low.x), i32(clip.high.y - clip.low.y))
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
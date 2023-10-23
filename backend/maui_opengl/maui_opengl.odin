package maui_opengl

// Import core deps
import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:math"
import "core:math/linalg"
// Import windowing backends
import "vendor:glfw"
// Import opengl
import gl "vendor:OpenGL"
// Import maui
import ui "../../"
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

Context :: struct {
	ibo_handle,
	vbo_handle: u32,

	program_handle,
	vertex_shader_handle,
	fragment_shader_handle: u32,

	tex_uniform_loc,
	projmtx_uniform_loc,
	pos_attrib_loc,
	uv_attrib_loc,
	col_attrib_loc: u32,
}

ctx: Context

/*
	Initialize rendering context
		Load OpenGL
		Load shaders
		Set texture handling procedures
*/
init :: proc(interface: ^backend.Platform_Renderer_Interface) -> bool {
	if interface.platform_api == .GLFW {
		gl.load_up_to(3, 3, glfw.gl_set_proc_address)
	}

	// Set viewport
  gl.Viewport(0, 0, interface.screen_size.x, interface.screen_size.y)

  VERTEX_SHADER_330 := #load("./default.vert")
	FRAGMENT_SHADER_330 := #load("./default.frag")

	// Load stuff
	ctx.vertex_shader_handle = load_shader_from_data(gl.VERTEX_SHADER, transmute([]u8)VERTEX_SHADER_330)
	check_shader(ctx.vertex_shader_handle, "vertex shader")
	ctx.fragment_shader_handle = load_shader_from_data(gl.FRAGMENT_SHADER, transmute([]u8)FRAGMENT_SHADER_330)
	check_shader(ctx.fragment_shader_handle, "fragment shader")

	ctx.program_handle = gl.CreateProgram()
	gl.AttachShader(ctx.program_handle, ctx.vertex_shader_handle)
	gl.AttachShader(ctx.program_handle, ctx.fragment_shader_handle)
	gl.LinkProgram(ctx.program_handle)
	check_program(ctx.program_handle, "shader program")

	// Get uniform and attribute locations
	ctx.projmtx_uniform_loc = cast(u32)gl.GetUniformLocation(ctx.program_handle, "ProjMtx")
	ctx.tex_uniform_loc 		= cast(u32)gl.GetUniformLocation(ctx.program_handle, "Texture")
	ctx.pos_attrib_loc 			= cast(u32)gl.GetAttribLocation(ctx.program_handle, "Position")
	ctx.uv_attrib_loc 			= cast(u32)gl.GetAttribLocation(ctx.program_handle, "UV")
	ctx.col_attrib_loc 			= cast(u32)gl.GetAttribLocation(ctx.program_handle, "Color")

	// Generate vertex and index buffers
	gl.GenBuffers(1, &ctx.vbo_handle)
	gl.GenBuffers(1, &ctx.ibo_handle)
	// Bind them
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

	// Texture procedures
	ui._load_texture = proc(image: ui.Image) -> (id: u32, ok: bool) {
		gl.BindTexture(gl.TEXTURE_2D, 0)
		gl.GenTextures(1, &id)
		if id == 0 {
			return
		}
		// Bind texture
		gl.BindTexture(gl.TEXTURE_2D, id)
		// Upload image data
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(image.width), i32(image.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, (transmute(runtime.Raw_Slice)image.data).data)
		// Set sampling parameters
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_NEAREST)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
		// Generate mipmaps
		gl.GenerateMipmap(gl.TEXTURE_2D)
		// Unbind texture
		gl.BindTexture(gl.TEXTURE_2D, 0)
		ok = true
		return
	}
	ui._unload_texture = proc(id: u32) {
		id := id
		gl.DeleteTextures(1, &id)
	}
	ui._update_texture = proc(tex: ui.Texture, data: []u8, x, y, w, h: f32) {
		gl.BindTexture(gl.TEXTURE_2D, tex.id)
		gl.TexSubImage2D(gl.TEXTURE_2D, 0, i32(x), i32(y), i32(w), i32(h), gl.RGBA, gl.UNSIGNED_BYTE, (transmute(runtime.Raw_Slice)data).data)
	}

	return true
}

destroy :: proc() {
	// Delete opengl things
	gl.DeleteProgram(ctx.program_handle)
	gl.DeleteBuffers(1, &ctx.vbo_handle)
	gl.DeleteBuffers(1, &ctx.ibo_handle)
}

render :: proc(interface: ^backend.Platform_Renderer_Interface) -> int {
	gl.Disable(gl.SCISSOR_TEST)
  gl.ClearColor(0.1, 0.1, 0.1, 1.0)
  gl.Clear(gl.COLOR_BUFFER_BIT)

  gl.Viewport(0, 0, interface.screen_size.x, interface.screen_size.y)
	
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
  R: f32 = L + f32(interface.screen_size.x)
  T: f32 = 0
  B: f32 = T + f32(interface.screen_size.y)
  ortho_projection: linalg.Matrix4x4f32 = {
  	2.0/(R-L), 0.0,	0.0, -1.0,
  	0.0, 2.0/(T-B), 0.0, 1.0,
  	0.0, 0.0, 1.0, 0.0,
  	0.0, 0.0, 0.0, 1.0,
  }

  gl.UseProgram(ctx.program_handle)
	gl.Uniform1i(i32(ctx.tex_uniform_loc), 0)
  gl.UniformMatrix4fv(i32(ctx.projmtx_uniform_loc), 1, gl.FALSE, transmute([^]f32)(&ortho_projection))

  vao_handle: u32 
  gl.GenVertexArrays(1, &vao_handle)
	gl.BindVertexArray(vao_handle)

	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vbo_handle)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.ibo_handle)

	gl.EnableVertexAttribArray(ctx.pos_attrib_loc)
	gl.EnableVertexAttribArray(ctx.uv_attrib_loc)
	gl.EnableVertexAttribArray(ctx.col_attrib_loc)
	gl.VertexAttribPointer(ctx.pos_attrib_loc, 2, gl.FLOAT, gl.FALSE, size_of(ui.Vertex), 0)
	gl.VertexAttribPointer(ctx.uv_attrib_loc, 2, gl.FLOAT, gl.FALSE, size_of(ui.Vertex), 8)
	gl.VertexAttribPointer(ctx.col_attrib_loc, 4, gl.UNSIGNED_BYTE, gl.TRUE, size_of(ui.Vertex), 16)

	for &layer in ui.core.layer_agent.list {
		for index in layer.draws {
			draw := &ui.painter.draws[index]
			if clip, ok := draw.clip.?; ok {
				gl.Scissor(i32(clip.low.x), interface.screen_size.y - i32(clip.high.y), i32(clip.high.x - clip.low.x), i32(clip.high.y - clip.low.y))
			} else {
				gl.Scissor(0, 0, interface.screen_size.x, interface.screen_size.y)
			}

			// Bind the texture for the draw call
			gl.BindTexture(gl.TEXTURE_2D, u32(draw.texture))

			vertices := draw.vertices[:draw.vertices_offset]
			gl.BufferData(gl.ARRAY_BUFFER, size_of(ui.Vertex) * len(vertices), (transmute(runtime.Raw_Slice)vertices).data, gl.STREAM_DRAW)

			indices := draw.indices[:draw.indices_offset]
			gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(u16) * len(indices), (transmute(runtime.Raw_Slice)indices).data, gl.STREAM_DRAW)

			gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_SHORT, nil)
		}
	}

	gl.DeleteVertexArrays(1, &vao_handle)

	// Unbind stuff
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindVertexArray(0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

	return 0
}
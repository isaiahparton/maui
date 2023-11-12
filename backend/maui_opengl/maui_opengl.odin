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
	using interface: backend.Platform_Renderer_Interface,
	last_screen_size: [2]i32,
	// Shader program handles
	default_program,
	extract_program,
	blur_program: u32,
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

ctx: Context

load_copy_vao :: proc() {
	ctx.quad_verts = {
		-1.0, -1.0,  0.0, 0.0,
		1.0, -1.0,  1.0, 0.0,
		-1.0,  1.0,  0.0, 1.0,
	 	1.0, -1.0,  1.0, 0.0,
	 	1.0,  1.0,  1.0, 1.0,
		-1.0,  1.0,  0.0, 1.0,
	}
	gl.GenVertexArrays(1, &ctx.copy_vao)
	gl.GenBuffers(1, &ctx.copy_vbo)
	gl.BindVertexArray(ctx.copy_vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.copy_vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(ctx.quad_verts) * size_of(f32), &ctx.quad_verts, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), uintptr(2 * size_of(f32)))
}
delete_copy_vao :: proc() {
	gl.DeleteVertexArrays(1, &ctx.copy_vao)
	gl.DeleteBuffers(1, &ctx.copy_vbo)
}

load_big_fbo :: proc() {
	gl.GenFramebuffers(1, &ctx.big_fbo)
	gl.GenTextures(1, &ctx.big_tex)
	gl.BindFramebuffer(gl.FRAMEBUFFER, ctx.big_fbo)
	gl.BindTexture(gl.TEXTURE_2D, ctx.big_tex)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, ctx.screen_size.x, ctx.screen_size.y, 0, gl.RGBA, gl.BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, ctx.big_tex, 0)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}
delete_big_fbo :: proc() {
	gl.DeleteTextures(1, &ctx.big_tex)
	gl.DeleteFramebuffers(1, &ctx.big_fbo)
}

load_pingpong_fbos :: proc() {
	gl.GenFramebuffers(2, &ctx.pingpong_fbo[0])
	gl.GenTextures(2, &ctx.pingpong_tex[0])
	for i in 0..<2 {
		gl.BindFramebuffer(gl.FRAMEBUFFER, ctx.pingpong_fbo[i])
		gl.BindTexture(gl.TEXTURE_2D, ctx.pingpong_tex[i])
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, ctx.screen_size.x, ctx.screen_size.y, 0, gl.RGBA, gl.BYTE, nil)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, ctx.pingpong_tex[i], 0)
	}
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}
delete_small_fbos :: proc() {
	gl.DeleteTextures(2, &ctx.small_tex[0])
	gl.DeleteFramebuffers(2, &ctx.small_fbo[0])
}
/*
	Initialize rendering context
		Load OpenGL
		Load shaders
		Set texture handling procedures
*/
init :: proc(interface: backend.Platform_Renderer_Interface) -> bool {
	ctx.interface = interface

	if ctx.platform_api == .GLFW {
		gl.load_up_to(3, 3, glfw.gl_set_proc_address)
	}

	// Set viewport
  gl.Viewport(0, 0, ctx.screen_size.x, ctx.screen_size.y)

  

  {
		VERTEX_SHADER_330 := #load("./default.vert")
		FRAGMENT_SHADER_330 := #load("./default.frag")

		// Load stuff
		frag_shader := load_shader_from_data(gl.FRAGMENT_SHADER, string(FRAGMENT_SHADER_330))
		check_shader(frag_shader, "default frag shader")
  	vert_shader := load_shader_from_data(gl.VERTEX_SHADER, string(VERTEX_SHADER_330))
		check_shader(vert_shader, "default vert shader")

		ctx.default_program = gl.CreateProgram()
		gl.AttachShader(ctx.default_program, vert_shader)
		gl.AttachShader(ctx.default_program, frag_shader)
		gl.LinkProgram(ctx.default_program)
		check_program(ctx.default_program, "default shader program")

		// Get uniform and attribute locations
		ctx.projmtx_uniform_loc = cast(u32)gl.GetUniformLocation(ctx.default_program, "ProjMtx")
		ctx.tex_uniform_loc 		= cast(u32)gl.GetUniformLocation(ctx.default_program, "Texture")
		ctx.pos_attrib_loc 			= cast(u32)gl.GetAttribLocation(ctx.default_program, "Position")
		ctx.uv_attrib_loc 			= cast(u32)gl.GetAttribLocation(ctx.default_program, "UV")
		ctx.col_attrib_loc 			= cast(u32)gl.GetAttribLocation(ctx.default_program, "Color")
  }

  {
		VERTEX_SHADER_330 := #load("./framebuffer.vert")
  	FRAGMENT_SHADER_330 := #load("./extraction.frag")

  	frag_shader := load_shader_from_data(gl.FRAGMENT_SHADER, string(FRAGMENT_SHADER_330))
  	check_shader(frag_shader, "highlight frag shader")
  	vert_shader := load_shader_from_data(gl.VERTEX_SHADER, string(VERTEX_SHADER_330))
		check_shader(vert_shader, "highlight vert shader")

		ctx.extract_program = gl.CreateProgram()
		gl.AttachShader(ctx.extract_program, vert_shader)
		gl.AttachShader(ctx.extract_program, frag_shader)
		gl.LinkProgram(ctx.extract_program)
		check_program(ctx.extract_program, "highlight shader program")
  }

  {
		VERTEX_SHADER_330 := #load("./framebuffer.vert")
  	FRAGMENT_SHADER_330 := #load("./blur.frag")

  	frag_shader := load_shader_from_data(gl.FRAGMENT_SHADER, string(FRAGMENT_SHADER_330))
  	check_shader(frag_shader, "blur frag shader")
  	vert_shader := load_shader_from_data(gl.VERTEX_SHADER, string(VERTEX_SHADER_330))
		check_shader(vert_shader, "blur vert shader")

		ctx.blur_program = gl.CreateProgram()
		gl.AttachShader(ctx.blur_program, vert_shader)
		gl.AttachShader(ctx.blur_program, frag_shader)
		gl.LinkProgram(ctx.blur_program)
		check_program(ctx.blur_program, "blur shader program")
		
  }

	load_copy_vao()

	// Generate vertex and index buffers
	gl.GenBuffers(1, &ctx.vbo)
	gl.GenBuffers(1, &ctx.ibo)
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
	gl.DeleteProgram(ctx.default_program)
	gl.DeleteBuffers(1, &ctx.vbo)
	gl.DeleteBuffers(1, &ctx.ibo)
	delete_small_fbos()
	delete_big_fbo()
}

render :: proc(interface: backend.Platform_Renderer_Interface) -> int {
	ctx.interface = interface
	if ctx.last_screen_size != ctx.screen_size {
		delete_big_fbo()
		load_big_fbo()
		delete_small_fbos()
		load_small_fbos()
	}
	ctx.last_screen_size = ctx.screen_size

	gl.Disable(gl.SCISSOR_TEST)
  gl.ClearColor(0.0, 0.0, 0.0, 1.0)
  gl.Clear(gl.COLOR_BUFFER_BIT)

  gl.Viewport(0, 0, ctx.screen_size.x, ctx.screen_size.y)
	
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
  R: f32 = L + f32(ctx.screen_size.x)
  T: f32 = 0
  B: f32 = T + f32(ctx.screen_size.y)
  ortho_projection: linalg.Matrix4x4f32 = {
  	2.0/(R-L), 0.0,	0.0, -1.0,
  	0.0, 2.0/(T-B), 0.0, 1.0,
  	0.0, 0.0, 1.0, 0.0,
  	0.0, 0.0, 0.0, 1.0,
  }

  gl.UseProgram(ctx.default_program)
	gl.Uniform1i(i32(ctx.tex_uniform_loc), 0)
  gl.UniformMatrix4fv(i32(ctx.projmtx_uniform_loc), 1, gl.FALSE, transmute([^]f32)(&ortho_projection))

  vao_handle: u32 
  gl.GenVertexArrays(1, &vao_handle)
	gl.BindVertexArray(vao_handle)

	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vbo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.ibo)

	gl.EnableVertexAttribArray(ctx.pos_attrib_loc)
	gl.EnableVertexAttribArray(ctx.uv_attrib_loc)
	gl.EnableVertexAttribArray(ctx.col_attrib_loc)
	gl.VertexAttribPointer(ctx.pos_attrib_loc, 2, gl.FLOAT, gl.FALSE, size_of(ui.Vertex), 0)
	gl.VertexAttribPointer(ctx.uv_attrib_loc, 2, gl.FLOAT, gl.FALSE, size_of(ui.Vertex), 8)
	gl.VertexAttribPointer(ctx.col_attrib_loc, 4, gl.UNSIGNED_BYTE, gl.TRUE, size_of(ui.Vertex), 16)

	/*
		First, all ui elements are rendered to the two main FBOs
	*/
	for &layer in ui.core.layer_agent.list {
		for index in layer.meshes {
			mesh := &ui.painter.meshes[index]
			if clip, ok := mesh.clip.?; ok {
				gl.Enable(gl.SCISSOR_TEST)
				gl.Scissor(i32(clip.low.x), ctx.screen_size.y - i32(clip.high.y), i32(clip.high.x - clip.low.x), i32(clip.high.y - clip.low.y))
			} else {
				gl.Scissor(0, 0, ctx.screen_size.x, ctx.screen_size.y)
			}

			// Bind the texture for the mesh call
			switch mat in mesh.material {
				/*
					Normal material
				*/
				case ui.Default_Material:
				gl.BindTexture(gl.TEXTURE_2D, mat.texture)
				/*
					Acrylic material
				*/
				case ui.Acrylic_Material: 
				// Apply blur to main fbo
				draw_acrylic_mat(mat, mesh.clip.? or_else {high = ui.core.size})
				// Bind blurred texture
  			gl.UseProgram(ctx.default_program)
				gl.BindVertexArray(vao_handle)
				gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vbo)
				gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.ibo)
				gl.BindTexture(gl.TEXTURE_2D, ctx.big_tex)
			}
			/*
				Upload vertices and indices
			*/
			vertices := mesh.vertices[:mesh.vertices_offset]
			gl.BufferData(gl.ARRAY_BUFFER, size_of(ui.Vertex) * len(vertices), (transmute(runtime.Raw_Slice)vertices).data, gl.STREAM_DRAW)
			indices := mesh.indices[:mesh.indices_offset]
			gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(u16) * len(indices), (transmute(runtime.Raw_Slice)indices).data, gl.STREAM_DRAW)
			/*
				Draw call
			*/
			gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_SHORT, nil)
		}
	}

	// Delete the temporary VAO
	gl.DeleteVertexArrays(1, &vao_handle)

	// Unbind stuff
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindVertexArray(0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)

	return 0
}

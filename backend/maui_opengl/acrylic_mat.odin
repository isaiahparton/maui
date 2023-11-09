package maui_opengl

import maui "../../"
import gl "vendor:OpenGL"
import "core:fmt"

BLUR_ITERATIONS :: 4
SCALE_FACTOR :: 6

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
/*
	Prepare acrylic effect texture for the given box
*/
draw_acrylic_mat :: proc(mat: maui.Acrylic_Material, box: maui.Box) {
	using maui
	gl.Disable(gl.SCISSOR_TEST)
	/*
		First copy the main framebuffer to another one
	*/
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0)
	gl.ReadBuffer(gl.BACK)
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, ctx.big_fbo)
	gl.DrawBuffer(gl.COLOR_ATTACHMENT0)
	gl.BlitFramebuffer(i32(box.low.x), i32(box.low.y), i32(box.high.x), i32(box.high.y), i32(box.low.x), i32(box.low.y), i32(box.high.x), i32(box.high.y), gl.COLOR_BUFFER_BIT, gl.NEAREST)
	/*
		Then from that one to a lower resolution fbo
	*/
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, ctx.big_fbo)
	gl.ReadBuffer(gl.COLOR_ATTACHMENT0)
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, ctx.small_fbo[0])
	gl.DrawBuffer(gl.COLOR_ATTACHMENT0)
	gl.Viewport(0, 0, ctx.screen_size.x / SCALE_FACTOR, ctx.screen_size.y / SCALE_FACTOR)
	scaled_box: Box = {box.low / SCALE_FACTOR, box.high / SCALE_FACTOR}
	gl.BlitFramebuffer(i32(box.low.x), i32(box.low.y), i32(box.high.x), i32(box.high.y), i32(scaled_box.low.x), i32(scaled_box.low.y), i32(scaled_box.high.x), i32(scaled_box.high.y),
		gl.COLOR_BUFFER_BIT,
		gl.LINEAR)
	/*
		Then apply ping-pong blur effect
	*/
	horizontal := false
	gl.UseProgram(ctx.blur_program)
	gl.Uniform2f(gl.GetUniformLocation(ctx.blur_program, "size"), f32(ctx.screen_size.x), f32(ctx.screen_size.y))
	for i in 0..<mat.amount {
		// Set horizontal uniform
		gl.Uniform1i(gl.GetUniformLocation(ctx.blur_program, "horizontal"), i32(horizontal))
		// Bind draw target
		gl.BindFramebuffer(gl.FRAMEBUFFER, ctx.small_fbo[int(!horizontal)])
		gl.ActiveTexture(gl.TEXTURE0)
		// Bind texture to draw
		gl.BindTexture(gl.TEXTURE_2D, ctx.small_tex[int(horizontal)])
		// Bind vertices to draw
		gl.BindVertexArray(ctx.copy_vao)
		gl.Disable(gl.DEPTH_TEST)
		gl.DrawArrays(gl.TRIANGLES, 0, 6)
		gl.BindVertexArray(0)
		horizontal = !horizontal
	}
	/*
		Copy back to normal resolution fbo
	*/
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, ctx.small_fbo[1])
	gl.ReadBuffer(gl.COLOR_ATTACHMENT0)
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, ctx.big_fbo)
	gl.DrawBuffer(gl.COLOR_ATTACHMENT0)
	gl.Viewport(0, 0, ctx.screen_size.x, ctx.screen_size.y)
	gl.BlitFramebuffer(0, 0, ctx.screen_size.x / SCALE_FACTOR, ctx.screen_size.y / SCALE_FACTOR, 0, 0, ctx.screen_size.x, ctx.screen_size.y, gl.COLOR_BUFFER_BIT, gl.LINEAR)
	// We're done here
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}
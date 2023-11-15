package maui_opengl

import maui "../../"
import gl "vendor:OpenGL"
import "core:fmt"

BLUR_SCALE_FACTOR :: 8
/*
	Prepare acrylic effect texture for the given box
*/
draw_acrylic_mat :: proc(mat: maui.Acrylic_Material, box: maui.Box) {
	using maui
	gl.Disable(gl.SCISSOR_TEST)
	/*
		First copy the main framebuffer to another one
	*/
	{
		gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0)
		gl.ReadBuffer(gl.BACK)
		gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, ctx.big_fbo)
		gl.DrawBuffer(gl.COLOR_ATTACHMENT0)
		gl.BlitFramebuffer(i32(box.low.x), i32(box.low.y), i32(box.high.x), i32(box.high.y), i32(box.low.x), i32(box.low.y), i32(box.high.x), i32(box.high.y), gl.COLOR_BUFFER_BIT, gl.NEAREST)
	}

	scale_factors: [2]f32 = {2, 16}
	/*
		Then from that one to a lower resolution fbo
	*/
	{
		gl.BindFramebuffer(gl.READ_FRAMEBUFFER, ctx.big_fbo)
		gl.ReadBuffer(gl.COLOR_ATTACHMENT0)
		gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, ctx.pingpong_fbo[0])
		gl.DrawBuffer(gl.COLOR_ATTACHMENT0)
		gl.Viewport(0, 0, i32(f32(ctx.screen_size.x) / scale_factors[0]), i32(f32(ctx.screen_size.y) / scale_factors[0]))
		scaled_box: Box = {box.low / scale_factors[0], box.high / scale_factors[0]}
		gl.BlitFramebuffer(i32(box.low.x), i32(box.low.y), i32(box.high.x), i32(box.high.y), i32(scaled_box.low.x), i32(scaled_box.low.y), i32(scaled_box.high.x), i32(scaled_box.high.y),
			gl.COLOR_BUFFER_BIT,
			gl.LINEAR)
	}
	/*
		Then apply ping-pong blur effect
	*/
	gl.UseProgram(ctx.blur_program)
	gl.Viewport(0, 0, ctx.screen_size.x, ctx.screen_size.y)
	last_scale: f32 = 1 / scale_factors[0]
	ITERATIONS :: 8 
	HALF_ITERATIONS :: ITERATIONS / 2
	for i in 0..<ITERATIONS {
		horizontal := i % 2
		scale := 1.0 / scale_factors[i / HALF_ITERATIONS]
		// Set horizontal uniform
		gl.Uniform1f(gl.GetUniformLocation(ctx.blur_program, "srcScale"), last_scale)
		gl.Uniform1f(gl.GetUniformLocation(ctx.blur_program, "dstScale"), scale)
		gl.Uniform1i(gl.GetUniformLocation(ctx.blur_program, "horizontal"), i32(horizontal))
		// Bind draw target
		gl.BindFramebuffer(gl.FRAMEBUFFER, ctx.pingpong_fbo[1 - horizontal])
		gl.ActiveTexture(gl.TEXTURE0)
		gl.Clear(gl.COLOR_BUFFER_BIT)
		// Bind texture to draw
		gl.BindTexture(gl.TEXTURE_2D, ctx.pingpong_tex[horizontal])
		// Bind vertices to draw
		gl.BindVertexArray(ctx.copy_vao)
		gl.Disable(gl.DEPTH_TEST)
		gl.DrawArrays(gl.TRIANGLES, 0, 6)
		gl.BindVertexArray(0)
		last_scale = scale
	}
	/*
		Copy back to normal resolution fbo
	*/
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, ctx.pingpong_fbo[1])
	gl.ReadBuffer(gl.COLOR_ATTACHMENT0)
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, ctx.big_fbo)
	gl.DrawBuffer(gl.COLOR_ATTACHMENT0)
	gl.Viewport(0, 0, ctx.screen_size.x, ctx.screen_size.y)
	gl.BlitFramebuffer(0, 0, i32(f32(ctx.screen_size.x) * last_scale), i32(f32(ctx.screen_size.y) * last_scale), 0, 0, ctx.screen_size.x, ctx.screen_size.y, gl.COLOR_BUFFER_BIT, gl.LINEAR)
	// We're done here
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}

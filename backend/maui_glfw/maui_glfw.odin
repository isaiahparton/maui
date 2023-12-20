package maui_glfw
// Import ctx deps
import "core:fmt"
import "core:time"
import "core:strings"
// Import maui
import "../../"
// Import backend helpers
import "../"
// Import GLFW
import "vendor:glfw"
import gl "vendor:OpenGL"

Platform :: struct {
	// Interface layer
	layer: maui.Platform_Layer,
	//
	window: glfw.WindowHandle,
	cursors: [maui.Cursor_Type]glfw.CursorHandle,
	last_time,
	current_time,
	frame_time: f64,
}

make_platform :: proc(width, height: int, title: string, api: backend.Render_API) -> (result: Platform, ok: bool) {
	glfw.Init()
	if api == .OpenGL {
		glfw.WindowHint(glfw.SAMPLES, 4)
		glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
		glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
		glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	} else {
		return
	}
	glfw.WindowHint(glfw.RESIZABLE, 1)

	// Create temporary cstring
	title_cstr := strings.clone_to_cstring(title)
	defer delete(title_cstr)

	// Create window
	result.window = glfw.CreateWindow(i32(width), i32(height), title_cstr, nil, nil)

	width, height := glfw.GetFramebufferSize(result.window)
	result.layer = {
		screen_size = {width, height},
	}
	// Create and assign error callback
	err_callback :: proc(err: i32, desc: cstring) {
		fmt.println(err, desc)
	}
	glfw.SetErrorCallback(glfw.ErrorProc(err_callback))

	// Load cursors
	result.cursors[.Default] = glfw.CreateStandardCursor(glfw.ARROW_CURSOR)
	result.cursors[.Beam] = glfw.CreateStandardCursor(glfw.IBEAM_CURSOR)
	result.cursors[.Hand] = glfw.CreateStandardCursor(glfw.HAND_CURSOR)
	result.cursors[.Crosshair] = glfw.CreateStandardCursor(glfw.CROSSHAIR_CURSOR)
	result.cursors[.Resize_EW] = glfw.CreateStandardCursor(glfw.HRESIZE_CURSOR)
	result.cursors[.Resize_NS] = glfw.CreateStandardCursor(glfw.VRESIZE_CURSOR)
	result.cursors[.Resize_NESW] = glfw.CreateStandardCursor(glfw.RESIZE_NESW_CURSOR)
	result.cursors[.Resize_NWSE] = glfw.CreateStandardCursor(glfw.RESIZE_NWSE_CURSOR)
	result.cursors[.Resize] = glfw.CreateStandardCursor(glfw.CENTER_CURSOR)

	// resize_callback :: proc(window: glfw.WindowHandle, width, height: i32) {
	// 	interface.screen_size = {width, height}
	// 	maui.ctx.size = {f32(width), f32(height)}
		
	// }
	// glfw.SetFramebufferSizeCallback(result.window, glfw.FramebufferSizeProc(resize_callback))

	scroll_proc :: proc(window: glfw.WindowHandle, x, y: f64) {
		maui.input.mouse_scroll = {f32(x), f32(y)}
	}
	glfw.SetScrollCallback(result.window, glfw.ScrollProc(scroll_proc))

	key_callback :: proc(window: glfw.WindowHandle, key, scancode, action, mods: i32) {
		if key >= 0 {
			switch action {
				case glfw.PRESS: 
				maui.input.key_set[key] = true

				case glfw.REPEAT: 
				maui.input.key_set[key] = true 
				maui.input.last_key_set[key] = false
				
				case glfw.RELEASE: 
				maui.input.key_set[key] = false
			}
		}
	}
	glfw.SetKeyCallback(result.window, glfw.KeyProc(key_callback))

	char_callback :: proc(window: glfw.WindowHandle, char: i32) {
		maui.input.runes[maui.input.rune_count] = rune(char)
		maui.input.rune_count += 1
	}
	glfw.SetCharCallback(result.window, glfw.CharProc(char_callback))

	cursor_proc :: proc(window: glfw.WindowHandle, x, y: i32) {
		x, y := glfw.GetCursorPos(window)
		maui.input.mouse_point = {f32(x), f32(y)}
	}
	glfw.SetCursorPosCallback(result.window, glfw.CursorPosProc(cursor_proc))

	mouse_proc :: proc(window: glfw.WindowHandle, button, action, mods: i32) {
		switch action {
			case glfw.PRESS: maui.input.mouse_bits += {maui.Mouse_Button(button)}
			case glfw.RELEASE: maui.input.mouse_bits -= {maui.Mouse_Button(button)}
		}
	}
	glfw.SetMouseButtonCallback(result.window, glfw.MouseButtonProc(mouse_proc))

	// Set up opengl
	glfw.MakeContextCurrent(result.window)

	

	if api == .OpenGL {
		gl.load_up_to(3, 3, glfw.gl_set_proc_address)
	}
	
	return
}

begin :: proc(using platform: ^Platform, ctx: ^maui.Context) {
	width, height := glfw.GetFramebufferSize(window)
	layer.screen_size = {width, height}

	ctx.size = {f32(width), f32(height)}
	ctx.current_time = glfw.GetTime()
	if ctx.cursor == .None {
		glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
	} else {
		glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL)
		glfw.SetCursor(window, cursors[ctx.cursor])
	}
	glfw.PollEvents()
	/*if point, ok := maui.ctx.set_cursor.?; ok {
		glfw.SetCursorPos(platform.window, f64(point.x), f64(point.y))
		maui.ctx.set_cursor = nil
	}*/
}

end :: proc(using platform: ^Platform) {
	glfw.SwapBuffers(window)
}

cycle :: proc(using platform: ^Platform, target_frame_time: f64) -> bool {
	now := glfw.GetTime()
	frame_time = now - last_time
	if frame_time < target_frame_time {
		time.sleep(time.Second * time.Duration(target_frame_time - frame_time))
	}
	last_time = current_time
	current_time = glfw.GetTime()
	return !should_close(platform)
}

should_close :: proc(using platform: ^Platform) -> bool {
	return bool(glfw.WindowShouldClose(window))
}

destroy_platform :: proc(using self: ^Platform) {
	glfw.DestroyWindow(window)
	self^ = {}
}
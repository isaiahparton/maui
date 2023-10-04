package maui_glfw
// Import core deps
import "core:fmt"
import "core:time"
import "core:strings"
// Import maui
import "../../"
// Import backend helpers
import "../"
// Import GLFW
import "vendor:glfw"

Platform :: struct {
	window: glfw.WindowHandle,
	cursors: [maui.Cursor_Type]glfw.CursorHandle,
	last_time,
	current_time,
	frame_time: f64,
}

platform: Platform
interface: backend.Platform_Renderer_Interface

init :: proc(width, height: int, title: string, api: backend.Render_API) -> bool {
	glfw.Init()
	if api == .OpenGL {
		glfw.WindowHint(glfw.SAMPLES, 4)
		glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
		glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
		glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	} else {
		return false
	}
	glfw.WindowHint(glfw.RESIZABLE, 1)


	// Create temporary cstring
	title_cstr := strings.clone_to_cstring(title)
	defer delete(title_cstr)

	// Create window
	platform.window = glfw.CreateWindow(i32(width), i32(height), title_cstr, nil, nil)

	width, height := glfw.GetFramebufferSize(platform.window)
	interface = {
		render_api = api,
		platform_api = .GLFW,
		screen_size = {width, height},
	}
	// Create and assign error callback
	err_callback :: proc(err: i32, desc: cstring) {
		fmt.println(err, desc)
	}
	glfw.SetErrorCallback(glfw.ErrorProc(err_callback))

	// Load cursors
	/*for member in maui.Cursor_Type {
		shape: i32 
		#partial switch member {
			case maui.Cursor_Type.Arrow: 				shape = glfw.ARROW_CURSOR
			case maui.Cursor_Type.Hand: 				shape = glfw.HAND_CURSOR
			case maui.Cursor_Type.Beam: 				shape = glfw.IBEAM_CURSOR
			case maui.Cursor_Type.Disabled: 		shape = glfw.CURSOR_DISABLED
			case maui.Cursor_Type.Crosshair: 		shape = glfw.CROSSHAIR_CURSOR
			case maui.Cursor_Type.Resize_EW: 		shape = glfw.HRESIZE_CURSOR
			case maui.Cursor_Type.Resize_NS: 		shape = glfw.VRESIZE_CURSOR
			case maui.Cursor_Type.Resize_NESW: 	shape = glfw.RESIZE_NESW_CURSOR
			case maui.Cursor_Type.Resize_NWSE: 	shape = glfw.RESIZE_NWSE_CURSOR
			case maui.Cursor_Type.Default: 			shape = glfw.ARROW_CURSOR
		}
		platform.cursors[member] = glfw.CreateStandardCursor(shape)
	}*/

	key_callback :: proc(window: glfw.WindowHandle, key, scancode, action, mods: i32) {
		switch action {
			case glfw.PRESS: maui.input.key_set[scancode] = true
			case glfw.RELEASE: maui.input.key_set[scancode] = false
		}
	}
	glfw.SetKeyCallback(platform.window, glfw.KeyProc(key_callback))

	cursor_proc :: proc(window: glfw.WindowHandle, _, _: i32) {
		x, y := glfw.GetCursorPos(window)
		maui.input.mouse_point = {f32(x), f32(y)}
	}
	glfw.SetCursorPosCallback(platform.window, glfw.CursorPosProc(cursor_proc))

	mouse_proc :: proc(window: glfw.WindowHandle, button, action, mods: i32) {
		switch action {
			case glfw.PRESS: maui.input.mouse_bits += {maui.Mouse_Button(button)}
			case glfw.RELEASE: maui.input.mouse_bits -= {maui.Mouse_Button(button)}
		}
	}
	glfw.SetMouseButtonCallback(platform.window, glfw.MouseButtonProc(mouse_proc))

	// Set up opengl
	glfw.MakeContextCurrent(platform.window)
	
	return true
}

begin_frame :: proc() {
	width, height := glfw.GetFramebufferSize(platform.window)
	interface.screen_size = {width, height}
	maui.core.size = {f32(width), f32(height)}
	maui.core.current_time = glfw.GetTime()
	glfw.PollEvents()
}

end_frame :: proc() {
	glfw.SwapBuffers(platform.window)
}

cycle :: proc(target_frame_time: f64) -> bool {
	using platform
	now := glfw.GetTime()
	frame_time = now - last_time
	if frame_time < target_frame_time {
		time.sleep(time.Second * time.Duration(target_frame_time - frame_time))
	}
	last_time = current_time
	current_time = glfw.GetTime()
	return !should_close()
}

should_close :: proc() -> bool {
	return bool(glfw.WindowShouldClose(platform.window))
}

destroy :: proc() {
	glfw.DestroyWindow(platform.window)
}
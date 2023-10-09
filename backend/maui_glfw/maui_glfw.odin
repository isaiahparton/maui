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
	platform.cursors[.Default] = glfw.CreateStandardCursor(glfw.ARROW_CURSOR)
	platform.cursors[.Beam] = glfw.CreateStandardCursor(glfw.IBEAM_CURSOR)
	platform.cursors[.Hand] = glfw.CreateStandardCursor(glfw.HAND_CURSOR)
	platform.cursors[.Crosshair] = glfw.CreateStandardCursor(glfw.CROSSHAIR_CURSOR)
	platform.cursors[.Resize_EW] = glfw.CreateStandardCursor(glfw.HRESIZE_CURSOR)
	platform.cursors[.Resize_NS] = glfw.CreateStandardCursor(glfw.VRESIZE_CURSOR)
	platform.cursors[.Resize_NESW] = glfw.CreateStandardCursor(glfw.RESIZE_NESW_CURSOR)
	platform.cursors[.Resize_NWSE] = glfw.CreateStandardCursor(glfw.RESIZE_NWSE_CURSOR)

	key_callback :: proc(window: glfw.WindowHandle, key, scancode, action, mods: i32) {
		switch action {
			case glfw.PRESS, glfw.REPEAT: 
			maui.input.key_set[key] = true
			
			case glfw.RELEASE: 
			maui.input.key_set[key] = false
		}
	}
	glfw.SetKeyCallback(platform.window, glfw.KeyProc(key_callback))

	char_callback :: proc(window: glfw.WindowHandle, char: i32) {
		maui.input.runes[maui.input.rune_count] = rune(char)
		maui.input.rune_count += 1
	}
	glfw.SetCharCallback(platform.window, glfw.CharProc(char_callback))

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

	maui._get_clipboard_string = proc() -> string {
		return string(glfw.GetClipboardString(platform.window))
	}
	maui._set_clipboard_string = proc(str: string) {
		cstr := strings.clone_to_cstring(str)
		glfw.SetClipboardString(platform.window, cstr)
	}
	
	return true
}

begin_frame :: proc() {
	width, height := glfw.GetFramebufferSize(platform.window)
	interface.screen_size = {width, height}
	maui.core.size = {f32(width), f32(height)}
	maui.core.current_time = glfw.GetTime()
	if maui.core.cursor == .None {
		glfw.SetInputMode(platform.window, glfw.CURSOR, glfw.CURSOR_HIDDEN)
	} else {
		glfw.SetInputMode(platform.window, glfw.CURSOR, glfw.CURSOR_NORMAL)
		glfw.SetCursor(platform.window, platform.cursors[maui.core.cursor])
	}
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
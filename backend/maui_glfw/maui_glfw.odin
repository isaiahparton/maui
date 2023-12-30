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
	io: ^maui.IO,
	//
	window: glfw.WindowHandle,
	cursors: [maui.Cursor_Type]glfw.CursorHandle,
	last_time,
	current_time,
	frame_time: f64,
}

@private
platform: Platform

init :: proc(width, height: int, title: string, api: backend.Render_API, io: ^maui.IO) -> (ok: bool) {
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
	platform.window = glfw.CreateWindow(i32(width), i32(height), title_cstr, nil, nil)

	width, height := glfw.GetFramebufferSize(platform.window)
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
	platform.cursors[.Resize] = glfw.CreateStandardCursor(glfw.CENTER_CURSOR)

	// Set IO interfaces
	platform.io = io
	io.get_clipboard_string = proc() -> string {
		return glfw.GetClipboardString(platform.window)
	}
	io.set_clipboard_string = proc(str: string) {
		cstr := strings.clone_to_cstring(str)
		defer delete(cstr)
		glfw.SetClipboardString(platform.window, cstr)
	}
	io.set_cursor_type = proc(type: maui.Cursor_Type) {
		if type == .None {
			glfw.SetInputMode(platform.window, glfw.CURSOR, glfw.CURSOR_DISABLED)
		} else {
			glfw.SetInputMode(platform.window, glfw.CURSOR, glfw.CURSOR_NORMAL)
			glfw.SetCursor(platform.window, platform.cursors[type])
		}
	}
	io.set_cursor_position = proc(x, y: f32) {
		glfw.SetCursorPos(platform.window, f64(x), f64(y))
	}
	// Define callbacks
	resize_proc :: proc(window: glfw.WindowHandle, width, height: i32) {
		platform.io.size = {width, height}
	}
	scroll_proc :: proc(window: glfw.WindowHandle, x, y: f64) {
		platform.io.mouse_scroll = {f32(x), f32(y)}
	}
	key_proc :: proc(window: glfw.WindowHandle, key, scancode, action, mods: i32) {
		if key >= 0 {
			switch action {
				case glfw.PRESS: 
				platform.io.key_set[key] = true

				case glfw.REPEAT: 
				platform.io.key_set[key] = true 
				platform.io.last_key_set[key] = false
				
				case glfw.RELEASE: 
				platform.io.key_set[key] = false
			}
		}
	}
	char_proc :: proc(window: glfw.WindowHandle, char: i32) {
		platform.io.runes[platform.io.rune_count] = rune(char)
		platform.io.rune_count += 1
	}
	cursor_proc :: proc(window: glfw.WindowHandle, x, y: i32) {
		x, y := glfw.GetCursorPos(window)
		platform.io.mouse_point = {f32(x), f32(y)}
	}
	mouse_proc :: proc(window: glfw.WindowHandle, button, action, mods: i32) {
		switch action {
			case glfw.PRESS: platform.io.mouse_bits += {maui.Mouse_Button(button)}
			case glfw.RELEASE: platform.io.mouse_bits -= {maui.Mouse_Button(button)}
		}
	}
	// Set callbacks
	glfw.SetFramebufferSizeCallback(platform.window, glfw.FramebufferSizeProc(resize_proc))
	glfw.SetScrollCallback(platform.window, glfw.ScrollProc(scroll_proc))
	glfw.SetKeyCallback(platform.window, glfw.KeyProc(key_proc))
	glfw.SetCharCallback(platform.window, glfw.CharProc(char_proc))
	glfw.SetCursorPosCallback(platform.window, glfw.CursorPosProc(cursor_proc))
	glfw.SetMouseButtonCallback(platform.window, glfw.MouseButtonProc(mouse_proc))
	// Set up opengl
	glfw.MakeContextCurrent(platform.window)
	// Load gl procs
	if api == .OpenGL {
		gl.load_up_to(3, 3, glfw.gl_set_proc_address)
		ok = true
	}
	return
}

begin :: proc() {
	platform.io.current_time = glfw.GetTime()
	glfw.PollEvents()
}

end :: proc() {
	glfw.SwapBuffers(platform.window)
}

cycle :: proc(target_frame_time: f32) -> bool {
	now := glfw.GetTime()
	platform.io.frame_time = f32(now - platform.io.last_time)
	if platform.io.frame_time < target_frame_time {
		time.sleep(time.Second * time.Duration(target_frame_time - platform.io.frame_time))
	}
	platform.io.last_time = platform.io.current_time
	platform.io.current_time = now
	return !should_close()
}

should_close :: proc() -> bool {
	return bool(glfw.WindowShouldClose(platform.window))
}

destroy :: proc() {
	glfw.DestroyWindow(platform.window)
	platform = {}
}
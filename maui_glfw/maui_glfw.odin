package maui_glfw

import "core:fmt"
import "core:strings"

import "../"

import "vendor:glfw"

Window_Context :: struct {
	window: glfw.WindowHandle,
	cursors: [maui.Cursor_Type]glfw.CursorHandle,
}

init_window_context :: proc(ctx: ^Window_Context, width, height: int, title: string) -> bool {
	glfw.Init()
	glfw.WindowHint(glfw.SAMPLES, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.RESIZABLE, 1)

	// Create temporary cstring
	title_cstr := strings.clone_to_cstring(title)
	defer delete(title_cstr)

	// Create window
	ctx.window = glfw.CreateWindow(i32(width), i32(height), title_cstr, nil, nil)

	// Create and assign error callback
	err_callback :: proc(err: i32, desc: cstring) {
		fmt.println(err, desc)
	}
	glfw.SetErrorCallback(glfw.ErrorProc(err_callback))

	// Load cursors
	for member in maui.Cursor_Type {
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
		ctx.cursors[member] = glfw.CreateStandardCursor(shape)
	}

	// Set up opengl
	glfw.MakeContextCurrent(ctx.window)
	
	return true
}

update_window_context :: proc(ctx: ^Window_Context) {
	
}

destroy_window_context :: proc(ctx: ^Window_Context) {
	glfw.DestroyWindow(ctx.window)
}
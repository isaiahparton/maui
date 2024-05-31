package demo
import maui "../"

import "core:time"
import "core:math"
import "core:strings"
import "core:math/linalg"
import "core:strconv/decimal"

import "vendor:glfw"
import gl "vendor:OpenGL"
import "vendor:nanovg"
import nanovg_gl "vendor:nanovg/gl"

import "core:fmt"
import "core:mem"

TARGET_FRAME_RATE :: 75
TARGET_FRAME_TIME :: 1.0 / TARGET_FRAME_RATE

Option :: enum {
	Wave,
	Function,
	Collapse,
}

window: glfw.WindowHandle
io: maui.IO

_main :: proc() -> bool {
	// Init graphics
	glfw.Init()
	glfw.WindowHint(glfw.SAMPLES, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	window = glfw.CreateWindow(1000, 600, "window of opportunity", nil, nil)

	w, h := glfw.GetFramebufferSize(window)
	io.size = {w, h}

	// Create and assign error callback
	err_callback :: proc(err: i32, desc: cstring) {
		fmt.println(err, desc)
	}
	glfw.SetErrorCallback(glfw.ErrorProc(err_callback))

	// Load cursors
	io.cursors[.Default] = glfw.CreateStandardCursor(glfw.ARROW_CURSOR)
	io.cursors[.Beam] = glfw.CreateStandardCursor(glfw.IBEAM_CURSOR)
	io.cursors[.Hand] = glfw.CreateStandardCursor(glfw.HAND_CURSOR)
	io.cursors[.Crosshair] = glfw.CreateStandardCursor(glfw.CROSSHAIR_CURSOR)
	io.cursors[.Resize_EW] = glfw.CreateStandardCursor(glfw.HRESIZE_CURSOR)
	io.cursors[.Resize_NS] = glfw.CreateStandardCursor(glfw.VRESIZE_CURSOR)
	io.cursors[.Resize_NESW] = glfw.CreateStandardCursor(glfw.RESIZE_NESW_CURSOR)
	io.cursors[.Resize_NWSE] = glfw.CreateStandardCursor(glfw.RESIZE_NWSE_CURSOR)
	io.cursors[.Resize] = glfw.CreateStandardCursor(glfw.CENTER_CURSOR)

	// Set IO interfaces
	io.get_clipboard_string = proc() -> string {
		return glfw.GetClipboardString(window)
	}
	io.set_clipboard_string = proc(str: string) {
		cstr := strings.clone_to_cstring(str)
		defer delete(cstr)
		glfw.SetClipboardString(window, cstr)
	}
	io.set_cursor_type = proc(type: maui.Cursor_Type) {
		if type == .None {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
		} else {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL)
			glfw.SetCursor(window, io.cursors[type])
		}
	}
	io.set_cursor_position = proc(x, y: f32) {
		glfw.SetCursorPos(window, f64(x), f64(y))
	}
	// Define callbacks
	resize_proc :: proc(window: glfw.WindowHandle, width, height: i32) {
		io.size = {width, height}
	}
	scroll_proc :: proc(window: glfw.WindowHandle, x, y: f64) {
		io.mouse_scroll = {f32(x), f32(y)}
	}
	key_proc :: proc(window: glfw.WindowHandle, key, scancode, action, mods: i32) {
		if key >= 0 {
			switch action {
				case glfw.PRESS: 
				io.key_set[key] = true

				case glfw.REPEAT: 
				io.key_set[key] = true 
				io.last_key_set[key] = false
				
				case glfw.RELEASE: 
				io.key_set[key] = false
			}
		}
	}
	char_proc :: proc(window: glfw.WindowHandle, char: i32) {
		io.runes[io.rune_count] = rune(char)
		io.rune_count += 1
	}
	cursor_proc :: proc(window: glfw.WindowHandle, x, y: i32) {
		x, y := glfw.GetCursorPos(window)
		io.mouse_point = {f32(x), f32(y)}
	}
	mouse_proc :: proc(window: glfw.WindowHandle, button, action, mods: i32) {
		switch action {
			case glfw.PRESS: io.mouse_bits += {maui.Mouse_Button(button)}
			case glfw.RELEASE: io.mouse_bits -= {maui.Mouse_Button(button)}
		}
	}
	// Set callbacks
	glfw.SetFramebufferSizeCallback(window, glfw.FramebufferSizeProc(resize_proc))
	glfw.SetScrollCallback(window, glfw.ScrollProc(scroll_proc))
	glfw.SetKeyCallback(window, glfw.KeyProc(key_proc))
	glfw.SetCharCallback(window, glfw.CharProc(char_proc))
	glfw.SetCursorPosCallback(window, glfw.CursorPosProc(cursor_proc))
	glfw.SetMouseButtonCallback(window, glfw.MouseButtonProc(mouse_proc))

	glfw.MakeContextCurrent(window)
	gl.load_up_to(3, 3, glfw.gl_set_proc_address)

	t: time.Time = time.now()
	options: [Option]bool
	combo_box_index: int
	data: [dynamic]u8

	// Initialize the platform and renderer
	ctx := nanovg_gl.Create({.ANTI_ALIAS})

	// Only create the ui structure once the `painter` and `io` are initiated
	ui := maui.make_ui(&io, ctx, maui.make_default_style(ctx) or_return)

	// Begin the cycle
	for {
		if glfw.WindowShouldClose(window) {
			break
		}

		glfw.PollEvents()

		gl.Viewport(0, 0, i32(ui.size.x), i32(ui.size.y))
		gl.ClearColor(ui.style.color.foreground[0].r, ui.style.color.foreground[0].g, ui.style.color.foreground[0].b, ui.style.color.foreground[0].a)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

		using maui
		// Beginning of ui calls
		begin_ui(ui)
			shrink(ui, 100)

			ui.placement.size = 24

			begin_row(ui, 100)
				button(ui, {text = "button"})
			end_row(ui)

			space(ui, 20)

			begin_row(ui)
				ui.placement.side = .Left
				for member, i in Option {
					push_id(ui, i)
					if was_clicked(checkbox(ui, {text = tmp_print(member), value = options[member]})) {
						options[member] = !options[member]
					}
					pop_id(ui)
					space(ui, 10)
				}
			end_row(ui)

			space(ui, 20)

			begin_row(ui, 100)
				if index, ok := combo_box(ui, {index = combo_box_index, items = {"Wave", "Function", "Collapse"}}).index.?; ok {
					combo_box_index = index
				}
			end_row(ui)

			space(ui, 20)
			text_input(ui, {data = &data})

			nanovg.FontSize(ctx, 16)
			nanovg.FontFace(ctx, "Default")
			nanovg.TextAlignHorizontal(ctx, .LEFT)
			nanovg.TextAlignVertical(ctx, .BOTTOM)

			nanovg.FillColor(ctx, nanovg.ColorHex(0xffa0a0a0))
			nanovg.BeginPath(ctx)
			nanovg.Text(ui.ctx, 0, ui.size.y, tmp_printf("frame: %fms", time.duration_milliseconds(ui.frame_duration)))
			nanovg.Text(ui.ctx, 0, ui.size.y - 16, tmp_printf("delta: %f", ui.delta_time))
			nanovg.Text(ui.ctx, 0, ui.size.y - 32, tmp_printf("time: %f", ui.current_time))
			nanovg.Text(ui.ctx, 0, ui.size.y - 48, tmp_printf("size: %v", ui.size))
			nanovg.Fill(ctx)
		end_ui(ui)

		glfw.SwapBuffers(window)
	}

	maui.destroy_ui(ui)

	return true
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)

	_main()

	for _, leak in track.allocation_map {
		fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
	}
	for bad_free in track.bad_free_array {
		fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
	}
}
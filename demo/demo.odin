package demo

import "core:time"
import "core:strings"
import rl "vendor:raylib"
import ui "../"
import ui_backend "../raylib_backend"

import "core:fmt"
import "core:mem"

Choice :: enum {
	First,
	Second,
	Third,
}

Choice_Set :: bit_set[Choice]

_main :: proc() {
	boolean: bool
	text_buffer: [dynamic]u8
	chips: [dynamic]string

	buttons: [ui.Button_Style][ui.Button_Shape]f32

	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(1200, 900, "a window")
	rl.SetExitKey(.KEY_NULL)
	rl.SetTargetFPS(75)

	ui_backend.init()
	ui.init()

	for true {
		{
			using ui
			begin_frame()
			ui_backend.begin_frame()

			core.current_time = rl.GetTime()

			shrink(100)
			if do_layout(.Left, Percent(50)) {
				shrink(10)
				set_size(Pt(30))
				for &entry in chips {
					stack_push(&core.chips, Deferred_Chip{text = entry})
				}
				enter := key_pressed(.Enter)
				change := do_text_input({
					data = &text_buffer,
				})
				if change || enter {
					if len(text_buffer) > 0 {
						if (text_buffer[len(text_buffer) - 1] == ',') {
							append(&chips, strings.clone(string(text_buffer[:len(text_buffer) - 1])))
							clear(&text_buffer)
						} else if enter {
							append(&chips, strings.clone(string(text_buffer[:])))
							clear(&text_buffer)
						}
					}
				} else if len(chips) > 0 && key_pressed(.Backspace) {
					pop(&chips)
				}
				for i in 0..<core.chips.height {
					if core.chips.items[i].clicked {
						ordered_remove(&chips, i)
						break
					}
				}
				core.chips.height = 0

				space(Pt(10))
				do_checkbox({
					state = &boolean,
					text = "Checkbox",
					text_side = .Bottom,
				})
				space(Pt(10))
				boolean = do_toggle_switch({
					state = &boolean,
				})
				space(Pt(10))

				for style in Button_Style {
					if do_layout(.Top, Pt(30)) {
						set_side(.Left)
						for shape in Button_Shape {
							push_id(int(style) + int(shape) * len(Button_Shape))
								if do_button({
									label = format(style),
									style = style,
									shape = shape,
									loading = buttons[style][shape] > 0,
								}) {
									buttons[style][shape] = 3
								}
								buttons[style][shape] = max(0, buttons[style][shape] - core.delta_time)
							pop_id()
							space(Pt(10))
						}
					}
					space(Pt(10))
				}
				
				CHIPS: []string : {"Elithor", "Alminor", "Ucrith", "Malnicus", "Pydrinorium"}
				if do_layout(.Left, Pt(200)) {
					if do_layout(.Top, Pt(20)) {
						set_side(.Left)
						for t, i in CHIPS {
							push_id(i)
								do_toggled_chip({
									state = false,
									text = t,
									row_spacing = Pt(10),
								})
							pop_id()
							space(Pt(10))
						}
					}
					space(Pt(10)); set_size(Pt(30))
					if do_menu({
						label = "Menu",
					}) {
						set_height(Pt(30))
						do_option({label = "Option A"})
						do_option({label = "Option B"})
						if do_submenu({
							label = "Submenu A",
							size = {200, 0},
						}) {
							set_height(Pt(30))
							do_option({label = "Option C"})
							do_option({label = "Option D"})
						}
						if do_submenu({
							label = "Submenu B",
							size = {200, 0},
						}) {
							do_option({label = "Option E"})
							do_option({label = "Option F"})
							if do_submenu({
								label = "Submenu C",
								size = {200, 0},
							}) {
								do_option({label = "Option G"})
								do_option({label = "Option H"})
							}
						}
					}
				}
			}

			end_frame()
		}

		rl.BeginDrawing()
		if ui.should_render() {
			rl.ClearBackground(transmute(rl.Color)ui.get_color(.Base))
			ui_backend.render()
			rl.DrawText(rl.TextFormat("%.2fms", time.duration_milliseconds(ui.core.frame_duration)), 0, 0, 20, rl.BLACK)
		}
		rl.EndDrawing()
		if rl.WindowShouldClose() {
			break
		}
	}

	rl.CloseWindow()

	ui.uninit()
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
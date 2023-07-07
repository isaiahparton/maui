package demo

import "core:time"
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

main :: proc() {
	choice: Choice
	choice_set: Choice_Set
	switch_state: bool
	slider_value_f32: f32
	slider_value_i32: i32
	calendar_time: time.Time
	temp_calendar_time: time.Time
	spinner_value: int
	text_buffer: [dynamic]u8
	multiline_buffer: [dynamic]u8

	button_load_timer: f32

	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(1000, 800, "a window")
	rl.SetTargetFPS(120)
	ui.init()
	ui_backend.init()

	for true {
		ui.begin_frame()
		ui_backend.begin_frame()

		ui.shrink(100)
		if ui.do_layout_box(ui.fake_cut(.bottom, 50)) {
			ui.set_side(.right); ui.set_size(50); ui.set_align(.middle)
			if ui.floating_button({icon = .Github}) {
				rl.OpenURL("https://github.com/isaiahparton/maui")
			}
			if ui.floating_button({icon = .Code}) {
				rl.OpenURL("https://github.com/isaiahparton/maui/blob/new-naming-convention/demo/demo.odin")
			}
		}

		if ui.do_layout(.left, 0.5, true) {

			ui.set_size(30); ui.set_align_y(.middle)
			ui.text({text = "Pill Buttons"})
			if ui.do_layout(.top, 30) {
				ui.set_side(.left)
				if ui.pill_button({label = string("Loading..." if button_load_timer > 0 else "Filled"), loading = button_load_timer > 0}) {
					button_load_timer = 5
				}
				button_load_timer = max(0, button_load_timer - ui.core.delta_time)
				ui.space(10)
				ui.pill_button({label = "Outlined", style = .outlined})
				ui.space(10)
				ui.pill_button({label = "Subtle", style = .subtle})
			}
			ui.space(10)
			ui.text({text = "Normal Buttons"})
			if ui.do_layout(.top, 30) {
				ui.set_side(.left)
				ui.button({label = "Filled", fit_to_label = true})
				ui.space(10)
				ui.button({label = "Outlined", style = .outlined, fit_to_label = true})
				ui.space(10)
				ui.button({label = "Subtle", style = .subtle, fit_to_label = true})
			}
			ui.space(10)
			ui.text({text = "Toggle Buttons"})
			if ui.do_layout(.top, 30) {
				ui.set_side(.left); ui.set_size(80)
				choice = ui.enum_toggle_buttons(choice)
			}
			ui.space(10)
			ui.text({text = "Multiple Choice"})
			for member in Choice {
				ui.push_id(int(member))
					ui.checkbox_bit_set(&choice_set, member, ui.text_capitalize(ui.format(member)))
				ui.pop_id()
			}
			ui.space(10)
			ui.text({text = "Single Choice"})
			choice = ui.enum_radio_buttons(choice)
			ui.space(10)
			if ui.do_layout(.top, 30) {
				ui.set_side(.left); ui.set_size(180)
				if ui.do_menu({
					label = ui.format(choice),
					size = ([2]f32){0, 90},
				}) {
					ui.set_size(30)
					choice = ui.enum_options(choice)
				}
			}
			ui.space(10)
			ui.text({text = "Switches"})
			ui.toggle_switch({state = &switch_state})
		}
		if ui.do_layout(.left, 1, true) {
			ui.set_size(30)
			ui.text({text = "Sliders"})
			if ui.do_layout(.top, 30) {
				ui.set_side(.left); ui.set_size(200)
				if changed, new_value := ui.slider(ui.Slider_Info(f32){value = slider_value_f32, low = 0, high = 10}); changed {
					slider_value_f32 = new_value
				}
			}
			ui.space(10)
			if ui.do_layout(.top, 30) {
				ui.set_side(.left); ui.set_size(100)
				slider_value_i32 = ui.box_slider(ui.Box_Slider_Info(i32){value = slider_value_i32, low = 0, high = 100})
			}
			ui.space(10)
			ui.text({text = "Date & time"})
			if ui.do_layout(.top, 30) {
				ui.set_side(.left); ui.set_size(200)
				ui.date_picker({value = &calendar_time, temp_value = &temp_calendar_time})
			}
			ui.space(10)
			ui.text({text = "Spinners"})
			if ui.do_layout(.top, 70) {
				ui.set_side(.left); ui.set_size(30)
				spinner_value = ui.spinner({value = spinner_value, low = 0, high = 10, orientation = .vertical})
				ui.space(10)
				ui.set_size(70); ui.set_margin_y(20)
				spinner_value = ui.spinner({value = spinner_value, low = 0, high = 10})
			}
			ui.space(10)
			ui.text({text = "Text editing"})
			if ui.do_layout(.top, 30) {
				ui.set_side(.left); ui.set_size(200)
				ui.text_input({data = &text_buffer, title = "Normal"})
			}
			ui.space(10)
			if ui.do_layout(.top, 120) {
				ui.set_side(.left); ui.set_size(200)
				ui.text_input({
					data = &multiline_buffer, 
					title = "Multiline", 
					line_height = 30, 
					edit_bits = {.multiline},
					placeholder = "Placeholder",
				})
			}
		}

		ui.end_frame()

		rl.BeginDrawing()
		if ui.should_render() {
			rl.ClearBackground(transmute(rl.Color)ui.get_color(.base))
			ui_backend.render()
			rl.DrawText(rl.TextFormat("%.3fms", time.duration_milliseconds(ui.core.frame_duration)), 0, 0, 20, rl.BLACK)
		}
		rl.EndDrawing()
		if rl.WindowShouldClose() {
			break
		}
	}

	rl.CloseWindow()

	ui.uninit()
}
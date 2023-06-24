package demo

import "core:time"
import rl "vendor:raylib"
import ui "../"
import ui_backend "../raylib_backend"

import "core:fmt"
import "core:mem"

Choice :: enum {
	first,
	second,
	third,
}
Choice_Set :: bit_set[Choice]

main :: proc() {
	choice: Choice
	choice_set: Choice_Set
	switch_state: bool
	slider_value: f32
	calendar_time: time.Time
	temp_calendar_time: time.Time

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
		if ui.layout(.left, 0.5, true) {

			ui.set_size(30); ui.set_align_y(.middle)
			ui.text({text = "Pill Buttons"})
			if ui.layout(.top, 30) {
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
			if ui.layout(.top, 30) {
				ui.set_side(.left)
				ui.button({label = "Filled", fit_to_label = true})
				ui.space(10)
				ui.button({label = "Outlined", style = .outlined, fit_to_label = true})
				ui.space(10)
				ui.button({label = "Subtle", style = .subtle, fit_to_label = true})
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
			ui.text({text = "Switches"})
			ui.toggle_switch({state = &switch_state})
			ui.space(10)
			ui.text({text = "Sliders"})
			if ui.layout(.top, 30) {
				ui.set_side(.left); ui.set_size(200)
				if changed, new_value := ui.slider(ui.Slider_Info(f32){value = slider_value, low = 0, high = 10}); changed {
					slider_value = new_value
				}
			}
		}
		if ui.layout(.left, 1, true) {
			ui.set_size(30)
			ui.text({text = "Date & time"})
			if ui.layout(.top, 30) {
				ui.set_side(.left); ui.set_size(200)
				ui.date_picker({value = &calendar_time, temp_value = &temp_calendar_time})
			}
		}

		if ui.layout_box(ui.fake_cut(.right, 50)) {
			ui.set_side(.bottom); ui.set_size(50); ui.set_align(.middle)
			if ui.floating_button({icon = .github}) {
				rl.OpenURL("https://github.com/isaiahparton/maui")
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
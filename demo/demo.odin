package demo
import maui "../"

import "core:time"
import "core:math"
import "core:strings"
import "core:math/linalg"
import "core:strconv/decimal"
import rl "vendor:raylib"
import "../backend/maui_glfw"
import "../backend/maui_opengl"

import "vendor:glfw"

import "core:fmt"
import "core:mem"

TARGET_FRAME_RATE :: 75
TARGET_FRAME_TIME :: 1.0 / TARGET_FRAME_RATE

Option :: enum {
	Wave,
	Function,
	Collapse,
	Manifold,
}

_main :: proc() -> bool {

	disabled := true
	clicked: bool
	toggle_switch_state: bool
	slider_value: f32
	combo_box_index: int
	chosen_options: [Option]bool
	list := make([dynamic]bool, 9)
	text_input_data: [dynamic]u8
	text_input_data2: [dynamic]u8
	choice: Option
	t: time.Time = time.now()

	// Shared structures
	io: maui.IO
	painter := maui.make_painter() or_return

	// Initialize the platform and renderer
	maui_glfw.init(1200, 1000, "Maui", .OpenGL, &io) or_return
	maui_opengl.init(&painter) or_return

	// Only create the ui structure once the `painter` and `io` are initiated
	ui := maui.make_ui(&io, &painter, maui.make_default_style(&painter) or_return)

	// Begin the cycle
	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using maui
		// Beginning of ui calls
		maui_glfw.begin()

		begin_ui(ui)
			cut(ui, .Left, 200)
			cut(ui, .Right, 200)
			cut(ui, .Top, 100)

			ui.placement.size = 30
			if tree_node(ui, {text = "Buttons"}).expanded {
				size(ui, 30)
				space(ui, 20)
				push_dividing_layout(ui, cut(ui, .Top, 30))
					ui.placement.side = .Left
					ui.placement.size = 30
					button(ui, {text_size = 16, corners = Corners{.Top_Left, .Bottom_Left}, font = ui.style.font.icon, text = "\uf019"})
					button(ui, {text_size = 16, font = ui.style.font.icon, text = "\uf02e"})
					button(ui, {text_size = 16, corners = Corners{.Top_Right, .Bottom_Right}, font = ui.style.font.icon, text = "\uf084"})
					space(ui, 10)
					button(ui, {text = "New"})
				pop_layout(ui)
				space(ui, 20)
				for member, i in Option {
					push_id(ui, i)
						push_dividing_layout(ui, cut(ui, .Top, 30))
							ui.placement.side = .Left
							ui.placement.size = 100
							if was_clicked(button(ui, {text = tmp_print(member), active = chosen_options[member]})) {
								chosen_options[member] = !chosen_options[member]
							}
						pop_layout(ui)
					pop_id(ui)
				}
			}
			
			if tree_node(ui, {text = "Sliders"}).expanded {
				space(ui, 20)
				ui.placement.size = 28
				push_dividing_layout(ui, cut(ui, .Top, 30))
					ui.placement.side = .Left
					ui.placement.size = 200
					if result := slider(ui, {
						value = slider_value,
						low = 0,
						high = 100,
					}); result.changed {
						slider_value = result.value
					}
					space(ui, 10)
					ui.placement.size = 150
					if was_clicked(toggle_switch(ui, {state = toggle_switch_state})) {
						toggle_switch_state = !toggle_switch_state
					}
				pop_layout(ui)
				space(ui, 20)
			}

			if tree_node(ui, {text = "Text Input"}).expanded {
				ui.placement.size = 28
				space(ui, 20)
				push_dividing_layout(ui, cut(ui, .Top, 300))
					ui.placement.size = 400
					ui.placement.side = .Left
					text_input(ui, {
						data = &text_input_data,
						multiline = true,
						placeholder = "type something here",
					})
				pop_layout(ui)
				space(ui, 10)
				push_dividing_layout(ui, cut(ui, .Top, 28))
					ui.placement.size = 300
					ui.placement.side = .Left
					text_input(ui, {
						data = &text_input_data2,
						placeholder = "single line text input",
					})
					size(ui, 0)
					button(ui, {text = "search"})
				pop_layout(ui)
				space(ui, 20)
			}

			if tree_node(ui, {text = "Lists"}).expanded {
				ui.placement.size = 260
				space(ui, 20)
				if frame(ui, {gradient_size = 40}) {
					ui.placement.size = 24
					for i in 1..=1000 {
						push_id(ui, i)
							list_item(ui, {index = i, text = {tmp_printf("item #%i", i)}})
						pop_id(ui)
					}
				}
				space(ui, 20)
			}

			/*if tree_node(ui, {text = "Date & Time"}).expanded {
				space(ui, 20)
				push_dividing_layout(ui, cut(ui, .Top, 24))
					ui.placement.side = .Left; ui.placement.size = 200
					t = date_picker(ui, {value = t}).new_value.? or_else t
				pop_layout(ui)
				space(ui, 20)
			}*/

			if tree_node(ui, {text = "Multiple Choice"}).expanded {
				ui.placement.size = 30
				space(ui, 20)
				for member, i in Option {
					push_id(ui, i)
						if was_clicked(checkbox(ui, {
							value = chosen_options[member], 
							text = tmp_print(member), 
						})) {
							chosen_options[member] = !chosen_options[member]
						}
					pop_id(ui)
				}
			}

			if tree_node(ui, {text = "Single Choice"}).expanded {
				space(ui, 20)
				ui.placement.size = 30
				push_dividing_layout(ui, cut(ui, .Top, 24))
					ui.placement.side = .Left; ui.placement.size = 200
					combo_box_index = combo_box(ui, {index = combo_box_index, items = {"Wave", "Function", "Collapse", "Manifold"}}).index.? or_else combo_box_index
				pop_layout(ui)
				space(ui, 20)
				for member, i in Option {
					push_id(ui, i)
						if was_clicked(radio_button(ui, {state = choice == member, text = tmp_print(member)})) {
							choice = member
						}
					pop_id(ui)
				}
			}

			cut(ui, .Top, 100)

			paint_text(ui.painter, {0, ui.size.y}, {
				text = tmp_printf("frame: %fms", time.duration_milliseconds(ui.frame_duration)), 
				font = ui.style.font.title, 
				size = 16,
				baseline = .Bottom,
			}, ui.style.color.content)
			paint_text(ui.painter, {0, ui.size.y - 16}, {
				text = tmp_printf("delta: %f", ui.delta_time), 
				font = ui.style.font.title, 
				size = 16,
				baseline = .Bottom,
			}, ui.style.color.content)
			paint_text(ui.painter, {0, ui.size.y - 32}, {
				text = tmp_printf("time: %f", ui.current_time), 
				font = ui.style.font.title, 
				size = 16,
				baseline = .Bottom,
			}, ui.style.color.content)
		end_ui(ui)

		// Render if needed
		if should_render(&painter) {
			maui_opengl.clear(ui.style.color.background)
			maui_opengl.render(ui)
			maui_glfw.end()
		}
	}

	maui.destroy_ui(ui)

	maui_opengl.destroy()
	maui_glfw.destroy()

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
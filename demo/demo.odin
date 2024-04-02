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
	Strawberry,
	Dragonfruit,
	Watermelon,
}

_main :: proc() -> bool {

	disabled := true
	clicked: bool
	toggle_switch_state: bool
	slider_value: f32
	combo_box_index: int
	checkbox_value: bool
	list := make([dynamic]bool, 9)
	text_input_data: [dynamic]u8
	text_input_data2: [dynamic]u8
	choice: Option
	t, tt: time.Time = time.now(), {}

	// Shared structures
	io: maui.IO
	painter := maui.make_painter() or_return

	// Initialize the platform and renderer
	maui_glfw.init(1200, 1000, "Maui", .OpenGL, &io) or_return
	maui_opengl.init(&painter) or_return

	// Only create the ui structure once the `painter` and `io` are initiated
	ui := maui.make_ui(&io, &painter, maui.make_default_style(&painter) or_return) or_return

	// Begin the cycle
	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using maui
		// Beginning of ui calls
		maui_glfw.begin()

		begin_ui(&ui)
			layout := current_layout(&ui)
			layout.size = {100, 28}

			if panel(&ui, {
				placement = Panel_Placement_Info{
					origin = ui.size / 2,
					align = {.Middle, .Middle},
					size = {320, 480},
				},
				options = {.Title, .Collapsable, .Closable},
				title = "window of opportunity",
			}) {
				if layout, ok := do_layout(&ui, cut(&ui, .Down, 24)); ok {
					layout.size = {100, 24}
					layout.direction = .Right
					if result, open := menu(&ui, {text = "File", width = 160}); open {
						option(&ui, {text = "New"})
						option(&ui, {text = "Open"})
						option(&ui, {text = "Save"})
						option(&ui, {text = "Exit"})
					}
					if result, open := menu(&ui, {text = "Edit", width = 160}); open {
						option(&ui, {text = "Undo"})
						option(&ui, {text = "Redo"})
						option(&ui, {text = "Select All"})
						option(&ui, {text = "Deselect"})
					}
					if result, open := menu(&ui, {text = "Tools", width = 160}); open {
						if result, open := submenu(&ui, {text = "Diagnostics"}); open {
							option(&ui, {text = "Memory dump"})
							option(&ui, {text = "Scan"})
						}
						option(&ui, {text = "Recovery"})
						option(&ui, {text = "Generation"})
						if result, open := submenu(&ui, {text = "Preferences"}); open {
							option(&ui, {text = "Local"})
							option(&ui, {text = "Global"})
						}
					}
					paint_box_fill(ui.painter, layout.box, ui.style.color.foreground[1])
				}
				shrink(&ui, 30)
				if result := combo_box(&ui, {
					items = {"Wolf", "Tiger", "Orca"},
					index = combo_box_index,
				}); result.changed {
					combo_box_index = result.index
				}
				paint_box_loader(&ui, current_layout(&ui).box)
			}

			if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
				layout.direction = .Right
				layout.size = 200
				tab(&ui, {text = "Dashboard"})
				tab(&ui, {text = "Printing"})
				tab(&ui, {text = "Records"})
			}
			shrink(&ui, 100)

			if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
				layout.direction = .Right
				layout.size = 30
				button(&ui, {text_size = 16, corners = Corners{.Top_Left, .Bottom_Left}, font = ui.style.font.icon, text = "\uf019"})
				button(&ui, {text_size = 16, font = ui.style.font.icon, text = "\uf02e"})
				button(&ui, {text_size = 16, corners = Corners{.Top_Right, .Bottom_Right}, font = ui.style.font.icon, text = "\uf084"})
				space(&ui, 10)
				button(&ui, {fit_text = true, type = .Filled, text = "New", corners = Corners{.Bottom_Right}, corner_style = .Cut})
			}
			
			space(&ui, 10)
			if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
				layout.direction = .Right
				layout.size = 30
				button(&ui, {text_size = 16, corners = Corners{.Top_Left, .Bottom_Left}, font = ui.style.font.icon, text = "\uf019", type = .Outlined})
				button(&ui, {text_size = 16, font = ui.style.font.icon, text = "\uf02e", type = .Outlined})
				button(&ui, {text_size = 16, corners = Corners{.Top_Right, .Bottom_Right}, font = ui.style.font.icon, text = "\uf084", type = .Outlined})
				space(&ui, 10)
				button(&ui, {fit_text = true, text = "New", corners = Corners{.Bottom_Right}, corner_style = .Rounded, type = .Outlined})
			}
			
			space(&ui, 10)
			if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
				layout.direction = .Right
				layout.size = 30
				button(&ui, {text_size = 16, corners = Corners{.Top_Left, .Bottom_Left}, font = ui.style.font.icon, text = "\uf019", type = .Subtle})
				button(&ui, {text_size = 16, font = ui.style.font.icon, text = "\uf02e", type = .Subtle})
				button(&ui, {text_size = 16, corners = Corners{.Top_Right, .Bottom_Right}, font = ui.style.font.icon, text = "\uf084", type = .Subtle})
				space(&ui, 10)
				button(&ui, {fit_text = true, text = "New", corners = Corners{.Bottom_Right}, corner_style = .Cut, type = .Subtle})
			}
			
			space(&ui, 10)
			if layout, ok := do_layout(&ui, cut(&ui, .Down, 30)); ok {
				layout.direction = .Right
				layout.size = 200
				if result := slider(&ui, {
					value = slider_value,
					low = 0,
					high = 100,
				}); result.changed {
					slider_value = result.value
				}
				space(&ui, 10)
				layout.size.x = 150
				if was_clicked(toggle_switch(&ui, {state = toggle_switch_state})) {
					toggle_switch_state = !toggle_switch_state
				}
			}
			space(&ui, 10)
			if layout, ok := do_layout(&ui, cut(&ui, .Down, 100)); ok {
				layout.size.x = 300
				layout.direction = .Right
				text_input(&ui, {
					data = &text_input_data,
					multiline = true,
					placeholder = "type something here",
				})
			}
			space(&ui, 10)
			text_input(&ui, {
				data = &text_input_data2,
				placeholder = "single line text input",
			})
			space(&ui, 10)
			layout.placement.size.y = 180
			if frame(&ui, {}) {
				current_layout(&ui).placement.size.y = 24
				for i in 1..=69 {
					push_id(&ui, i)
						list_item(&ui, {text = {tmp_printf("Button #%i", i)}})
					pop_id(&ui)
				}
			}
			layout.placement.size.y = 24
			space(&ui, 10)
			if _, ok := do_layout(&ui, cut(&ui, .Down, 24)); ok {
				ui.layouts.current.direction = .Right; ui.layouts.current.size.x = 200
				date_picker(&ui, {value = &t, temp_value = &tt})
			}
			space(&ui, 10)
			if tree_node(&ui, {text = "Tree node"}).expanded {
				layout.size.y = 28
				space(&ui, 10)
				button(&ui, {text = "hidden button"})
				space(&ui, 10)
				button(&ui, {text = "another hidden button"})
				space(&ui, 10)
				if was_clicked(checkbox(&ui, {
					value = checkbox_value, 
					text = "Checkbox", 
				})) {
					checkbox_value = !checkbox_value
				}
				space(&ui, 10)
				for member, i in Option {
					push_id(&ui, i)
						if was_clicked(radio_button(&ui, {state = choice == member, text = tmp_print(member)})) {
							choice = member
						}
					pop_id(&ui)
				}
				space(&ui, 10)
			}

			paint_text(ui.painter, {0, ui.size.y}, {
				text = tmp_printf("frame: %fms", time.duration_milliseconds(ui.frame_duration)), 
				font = ui.style.font.title, 
				size = 16,
				baseline = .Bottom,
			}, ui.style.color.text[0])
			paint_text(ui.painter, {0, ui.size.y - 16}, {
				text = tmp_printf("delta: %f", ui.delta_time), 
				font = ui.style.font.title, 
				size = 16,
				baseline = .Bottom,
			}, ui.style.color.text[0])
			paint_text(ui.painter, {0, ui.size.y - 32}, {
				text = tmp_printf("time: %f", ui.current_time), 
				font = ui.style.font.title, 
				size = 16,
				baseline = .Bottom,
			}, ui.style.color.text[0])
		end_ui(&ui)

		// Render if needed
		if should_render(&painter) {
			maui_opengl.clear(ui.style.color.foreground[0])
			maui_opengl.render(&ui)
			maui_glfw.end()
		}
	}

	maui.destroy_ui(&ui)

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
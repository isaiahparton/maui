package demo

import maui "../"
import maui_widgets "../widgets"

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

Choice :: enum {
	One,
	Two,
	Three,
}

Currency :: enum {
	USD,
	MXN,
	CAD,
	EUR,
	RUB,
}

_main :: proc() {
	t: time.Time
	tt: time.Time
	show_window: bool
	boolean: bool
	n: int

	hsva: [4]f32

	choice: Choice
	choices: bit_set[Choice]

	slider_value: f32

	price: f64
	currency: Currency

	textation,
	scribblage: string

	integer,combo_box_index: int
	spin_counter_state: maui_widgets.Spin_Counter_State

	counter: u32

	if !maui_glfw.init(1200, 1000, "Maui", .OpenGL) {
		return
	}

	if !maui_opengl.init(maui_glfw.interface) {
		return
	}

	maui.init()

	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using maui 
		using maui_widgets

		// Beginning of ui calls
		maui_glfw.begin_frame()
		begin_frame()

		paint_text({4, 4}, {text = tmp_printf("Frame time: %fms", time.duration_milliseconds(core.frame_duration)), font = style.font.content, size = style.text_size.label}, {}, style.color.base_text[1])

		cut(.Left, Exact(300))
		cut(.Right, Exact(300))
		cut(.Top, Exact(50))
		placement.size = Exact(30)

		do_text({text = "maui", font = style.font.title, size = 40, align = .Middle})
		cut(.Top, Exact(20))
		placement.size = Exact(100)
		do_interactable_text({text = "is a mixed mode UI framework designed for easy development of desktop applications and tools. It is renderer and platform independant, currently supporting GLFW and OpenGL.", font = style.font.content, size = 18})
		cut(.Top, Exact(20))

		placement.size = Exact(30)
		
		placement.size = Exact(30); placement.align.y = .Middle
		if do_tree_node({text = "Single choice"}) {
			if do_tree_node({text = "Multi switches"}) {
				n = do_multi_switch({
					options = {'\uEA27', '\uEA25', '\uEA28'},
					index = n,
				}) or_else n
			}
			if do_tree_node({text = "Radio buttons"}) {
				choice = do_enum_radio_buttons(choice)
			}
		}
		if do_tree_node({text = "Multiple choice"}) {
			for member, i in Choice {
				push_id(i)
					do_checkbox_bit_set(&choices, member, tmp_print(member))
				pop_id()
			}
		}
		if do_tree_node({text = "Buttons"}) {
			placement.size = Exact(50)
			if do_horizontal(3) {
				paint_rounded_box_fill(current_layout().box, style.rounding, style.color.base[1])
				shrink(10)

				placement.margin[.Left] = Exact(10)
				placement.margin[.Right] = Exact(10)
				for style, i in Button_Style {
					push_id(i)
						do_button({label = tmp_print(style), style = style})
					pop_id()
				}
			}
			space(Exact(10))
			placement.size = Exact(70)
			do_button({label = "A larger button\nwith several\nlines of text"})
		}
		if do_tree_node({text = "Menus"}) {
			if do_horizontal(2, 10) {
				if do_menu({label = "Menu"}) {
					placement.size = Exact(24); placement.side = .Top
					do_option({label = "option"})
					do_option({label = "opción"})
					do_option({label = "выбор"})
					do_option({label = "επιλογή"})
				}
				space(Exact(10))
				if new_index, changed := do_strings_menu({
					items = {"happ :)", "sab :(", "angy >:(", "chair"},
					index = n,
				}); changed {
					n = new_index
				}
			}
		}

		placement.size = Exact(140)

		if new_hsva, changed := do_color_wheel({hsva = hsva}); changed {
			hsva = new_hsva
		}
		space(Exact(20))
		cut(.Right, Exact(200))
		placement.size = Exact(30)

		hsva.x = do_slider(Slider_Info(f32){value = hsva.x, low = 0, high = 360})
		hsva.y = do_slider(Slider_Info(f32){value = hsva.y, low = 0, high = 1})
		hsva.z = do_slider(Slider_Info(f32){value = hsva.z, low = 0, high = 1})
		hsva.w = do_slider(Slider_Info(f32){value = hsva.w, low = 0, high = 1})

		paint_box_fill({core.size - 200, core.size}, hsva_to_rgba(hsva))

		// End of ui calls
		end_frame()
		
		// Update texture if necessary
		if painter.atlas.should_update {
			painter.atlas.should_update = false
			update_texture(painter.atlas.texture, painter.atlas.image, 0, 0, f32(painter.atlas.image.width), f32(painter.atlas.image.height))
		}

		// Render if needed
		if maui.should_render() {
			maui_opengl.clear(style.color.base[0])
			maui_opengl.render(maui_glfw.interface)
			maui_glfw.end_frame()
		}
	}

	maui.uninit()	
	maui_opengl.destroy()
	maui_glfw.destroy()
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
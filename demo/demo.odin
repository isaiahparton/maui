package demo

import maui "../"
import maui_widgets "../widgets"

import "core:time"
import "core:math"
import "core:strings"
import "core:math/linalg"
import rl "vendor:raylib"
import "../backend/maui_glfw"
import "../backend/maui_opengl"


import "core:fmt"
import "core:mem"

TARGET_FRAME_RATE :: 75
TARGET_FRAME_TIME :: 1.0 / TARGET_FRAME_RATE

Choice :: enum {
	One,
	Two,
	Three,
}

_main :: proc() {
	t: time.Time
	tt: time.Time
	show_window: bool
	boolean: bool
	choice: Choice
	choices: bit_set[Choice]
	slider_value: f32
	gain, pitch: f64
	textation,
	scribblage: string
	integer,combo_box_index: int

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

		shrink(200)
		if do_layout(.Top, Exact(100)) {
			if do_layout(.Right, Exact(300)) {
				placement.side = .Right; placement.size = Exact(30)
				slider_value = do_slider(Slider_Info(f32){orientation = .Vertical, value = slider_value, low = 0, high = 777})
				space(Exact(20))
				placement.size = Exact(50)
				integer = do_spinner(Spinner_Info(int){orientation = .Vertical, value = integer})
			}
			if do_layout(.Top, Exact(30)) {
				placement.side = .Left; placement.size = Exact(200)
				attach_tooltip("I have a tooltip!", .Top)
				if do_button({label = "a button"}) {

				}
				space(Exact(20))
				placement.size = Exact(170)
				if do_menu({label = "menu"}) {
					placement.size = Exact(20)
					prev_rounded_corners := style.rounded_corners
					for member, i in Choice {
						style.rounded_corners = {}
						if i == 0 {
							style.rounded_corners += {.Top_Left, .Top_Right}
						}
						if i == len(Choice) - 1 {
							style.rounded_corners += {.Bottom_Left, .Bottom_Right}
						}
						push_id(i)
							do_option({label = tmp_print(member)})
						pop_id()
					}
					style.rounded_corners = prev_rounded_corners
				}
				space(Exact(20))
				placement.size = Exact(170)
				if index, ok := do_combo_box({
					items = {
						"first",
						"second",
						"third",
						"fourth",
					},
					index = combo_box_index,
				}); ok {
					combo_box_index = index
				}
			}
			cut(.Top, Exact(20))
			if do_horizontal(Exact(60)) {
				placement.side = .Left; placement.size = Exact(250)
				if do_button({label = "a button\nwith multiple lines"}) {

				}
			}
		}
		
		cut(.Top, Exact(20))
		if do_layout(.Top, Exact(30)) {
			placement.side = .Left; placement.size = Exact(100)
			integer = do_spinner(Spinner_Info(int){value = integer, low = 0, high = 999})
			space(Exact(20))
			slider_value = do_numeric_field(Numeric_Field_Info(f32){value = slider_value, precision = 2, suffix = "kg"}).value
			space(Exact(20))
			integer = do_numeric_field(Numeric_Field_Info(int){value = integer}).value
		}
		cut(.Top, Exact(20))
		if do_horizontal(Exact(30)) {
			placement.size = Exact(300)
			do_text_field({data = &textation, title = "scriptum", placeholder = "scribes quod cogitas"})
		}
		cut(.Top, Exact(20))
		if do_horizontal(Exact(180)) {
			placement.size = Exact(320)
			style.rounded_corners = {.Bottom_Left, .Bottom_Right}
			do_text_field({data = &scribblage, placeholder = "multae lineae textus", multiline = true})
		}
		cut(.Top, Exact(20))
		if do_horizontal(Exact(30)) {
			placement.size = Exact(200)
			slider_value = do_slider(Slider_Info(f32){value = slider_value, low = 0, high = 777, format = "%.0f"})
		}
		cut(.Top, Exact(30))
		if do_horizontal(Exact(30)) {
			placement.size = Exact(80)
			prev_rounded_corners := style.rounded_corners
			for member, i in Choice {
				style.rounded_corners = {}
				if i == 0 {
					style.rounded_corners += {.Top_Left, .Bottom_Left}
				}
				if i == len(Choice) - 1 {
					style.rounded_corners += {.Top_Right, .Bottom_Right}
				}
				push_id(i)
					do_toggle_button_bit(&choices, member, tmp_print(member))
				pop_id()
			}
			style.rounded_corners = prev_rounded_corners
		}
		space(Exact(20))
		do_interactable_text({text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras sit amet ex ut enim efficitur vestibulum. Vestibulum egestas ornare nisl, at congue odio tempor vel. Nullam hendrerit accumsan ipsum, tempus cursus tortor. Pellentesque congue leo ligula, eu semper sapien condimentum sed. Etiam eget euismod augue, ac dictum urna. Aenean scelerisque, turpis quis sollicitudin efficitur, tortor magna efficitur libero, at placerat dolor lacus vel sapien. Aliquam in velit elit. Fusce et orci a neque commodo elementum molestie id nunc. Sed blandit ex quis elit malesuada tincidunt. Sed rhoncus ex non lorem finibus, vitae pharetra ligula malesuada."})

		/*
		if do_panel({
			title = "window of opportunity", 
			options = {.Title, .Closable, .Collapsable}, 
			placement = Panel_Placement_Info{
				origin = core.size / 2,
				size = {320, 440},
				align = {.Middle, .Middle},
			},
		}) {
			shrink(10)

		}
		*/

		/*
		DEBUG_TEXT_SIZE :: 12
		paint_text({}, {text = "Layer list", font = style.font.monospace, size = DEBUG_TEXT_SIZE}, {}, style.color.base_text[0])
		for layer, i in core.layer_agent.list {
			paint_text({12, 18 + 32 * f32(i)}, {text = tmp_printf("%x: %v", layer.id, layer.box), font = style.font.monospace, size = DEBUG_TEXT_SIZE}, {}, style.color.base_text[1])
			paint_text({12, 32 + 32 * f32(i)}, {text = tmp_printf("%v", layer.state), font = style.font.monospace, size = DEBUG_TEXT_SIZE}, {}, style.color.base_text[1])
		}
		*/

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
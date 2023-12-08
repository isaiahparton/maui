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

	// Load fonts
	icon_font, _ := maui.load_font(&maui.painter.atlas, "fonts/remixicon.ttf")

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
		do_interactable_text({text = "is an immediate mode UI framework designed for easy development of desktop applications and tools. It is renderer and platform independant, currently supporting GLFW and OpenGL.", font = style.font.content, size = 18})
		cut(.Top, Exact(20))

		placement.size = Exact(30)
		if do_tree_node({text = "Buttons", size = Exact(100)}) {
			if do_layout(.Top, Exact(30)) {
				placement.side = .Left; placement.size = Exact(200)
				do_button({label = "Button"})
			}
		}
		if do_tree_node({text = "Toggle switches", size = Exact(100)}) {

		}
		if do_tree_node({text = "Text input", size = Exact(100)}) {
			
		}
		if do_tree_node({text = "Multiple choice", size = Exact(100)}) {
			placement.size = Exact(30)
			for member, i in Choice {
				push_id(i)
					do_checkbox_bit_set(&choices, member, tmp_print(member))
				pop_id()
			}
		}
		if do_tree_node({text = "Single choice", size = Exact(100)}) {
			
		}

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
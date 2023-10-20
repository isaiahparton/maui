package demo

import "core:time"
import "core:math"
import "core:strings"
import "core:math/linalg"
import rl "vendor:raylib"
import ui "../"
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
	fmt.println("Structure sizes")
	fmt.println("  Painter:", size_of(ui.Painter))
	fmt.println("  Core:", size_of(ui.Core))

	t: time.Time
	tt: time.Time
	show_window: bool
	boolean: bool
	choice: Choice
	number: f64
	slider_int: i64
	text: string
	text_demo: Text_Demo = {
		info = {text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque pharetra, mauris at laoreet volutpat, libero diam pulvinar sem, vitae ultricies metus enim ac dolor. Aenean id diam libero. Nam elit dolor, condimentum eget mauris eu, venenatis scelerisque enim. Pellentesque porttitor massa quis erat congue, id condimentum eros volutpat.", size = 20},
	}

	if !maui_glfw.init(1200, 1000, "Maui", .OpenGL) {
		return
	}

	if !maui_opengl.init(&maui_glfw.interface) {
		return
	}

	ui.init()

	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using ui

		// Beginning of ui calls
		maui_glfw.begin_frame()
		begin_frame()

		// UI calls
		shrink(50)
		if do_layout(.Top, Exact(24)) {
			placement.side = .Left; placement.size = Exact(150)
			painter.style.stroke_thickness = math.round(do_slider(Slider_Info(f32){value = painter.style.stroke_thickness, low = 0, high = 4}))
		}
		space(Exact(10))
		for shape in Button_Shape {
			push_id(int(shape))
			if do_layout(.Top, Exact(24)) {
				placement.side = .Left 
				do_button({shape = shape, style = .Filled, label = "Button", color = get_color(.Accent), fit_to_label = true})
				space(Exact(10))
				do_button({shape = shape, style = .Outlined, label = "Button", fit_to_label = true})
				space(Exact(10))
				do_button({shape = shape, style = .Subtle, label = "Button", fit_to_label = true})
				space(Exact(10))
			}
			pop_id()
			space(Exact(10))
		}
		space(Exact(10))
		if do_layout(.Top, Exact(24)) {
			placement.side = .Left; placement.size = Exact(200)
			if do_menu({label = "open me!"}) {
				placement.size = Exact(24)
				if do_option({label = "click me!! :)"}) {

				}
				if .Hovered in last_widget().state {
					if do_option({label = "can't touch this! >:}"}) {

					}
				}
				if do_submenu({label = "check this out!"}) {
					do_option({label = "you found me!! :D"})
				}
			}
		}
		space(Exact(10))
		if do_layout(.Top, Exact(24)) {
			placement.side = .Left; placement.size = Exact(70)
			choice = do_enum_toggle_buttons(choice)
		}
		space(Exact(10))
		placement.size = Exact(30); placement.align.y = .Middle
		choice = do_enum_radio_buttons(choice, .Left)
		space(Exact(10))
		do_checkbox({state = &show_window, text = "show window"})
		space(Exact(10))
		if do_horizontal(Exact(28)) {
			placement.size = Exact(200)
			do_text_field({data = &text, title = "Text!"})
		}
		space(Exact(10))
		if do_horizontal(Exact(28)) {
			placement.size = Exact(200)
			if res := do_numeric_field(Numeric_Field_Info(f64){value = number, title = "Number!", precision = 2}); res.changed {
				number = res.value
			}
		}
		space(Exact(10))
		if do_horizontal(Exact(28)) {
			placement.size = Exact(200)
			do_date_picker({value = &t, temp_value = &tt})
		}
		space(Exact(10))
		if do_horizontal(Exact(28)) {
			placement.size = Exact(100)
			slider_int = do_box_slider(Box_Slider_Info(i64){value = slider_int, low = 0, high = 100})
			space(Exact(10))
			slider_int = do_spinner(Spinner_Info(i64){value = slider_int, low = 0, high = 100})
		}
		space(Exact(10))
		boolean = do_toggle_switch({state = Toggle_Switch_State(boolean)})

		if show_window {
			if do_window({
				box = child_box(core.fullscreen_box, {300, 300}, {.Middle, .Middle}),
				title = "Hi! I'm a window :I",
				options = {.Title, .Closable, .Resizable, .Collapsable},
			}) {
				shrink(20)
				placement.size = Exact(24)
				do_button({label = "welcome!"})
			}
		}

		// End of ui calls
		end_frame()
		
		// Update texture if necessary
		if painter.atlas.should_update {
			painter.atlas.should_update = false
			update_texture(painter.atlas.texture, painter.atlas.image, 0, 0, 4096, 4096)
		}

		// Render if needed
		if ui.should_render() {
			maui_opengl.render(&maui_glfw.interface)
			maui_glfw.end_frame()
		}
	}

	ui.uninit()	
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
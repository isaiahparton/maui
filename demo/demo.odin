package demo

import "core:time"
import "core:strings"
import "core:math/linalg"
import rl "vendor:raylib"
import ui "../"
import "../backend/maui_glfw"
import "../backend/maui_opengl"

import "core:fmt"
import "core:mem"

TARGET_FRAME_RATE :: 60
TARGET_FRAME_TIME :: 1.0 / TARGET_FRAME_RATE

Demo :: struct {
	start: proc(rawptr),
	run: proc(rawptr),
	end: proc(rawptr),
}

_main :: proc() {
	fmt.println("Structure sizes")
	fmt.println("  Painter:", size_of(ui.Painter))
	fmt.println("  Core:", size_of(ui.Core))

	text_demo: Text_Demo = {
		info = {text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque pharetra, mauris at laoreet volutpat, libero diam pulvinar sem, vitae ultricies metus enim ac dolor. Aenean id diam libero. Nam elit dolor, condimentum eget mauris eu, venenatis scelerisque enim. Pellentesque porttitor massa quis erat congue, id condimentum eros volutpat. Maecenas non augue sollicitudin, ultricies ligula quis, tristique ante. Donec feugiat quam sit amet molestie ultrices. Sed bibendum aliquam odio, et volutpat lorem vestibulum at. Duis bibendum tellus sit amet viverra maximus. Ut tincidunt efficitur risus sed efficitur. Phasellus faucibus pretium rhoncus. Suspendisse consectetur nisi sed urna sollicitudin, ac porta ante viverra. Fusce condimentum eros vitae nisi porttitor, et ultricies est ultricies. Nullam ac dictum risus. Nulla rutrum non nibh eu maximus. Aenean tempor sapien ex, at condimentum dui tempor commodo. Aliquam tempor maximus mollis. Proin id gravida eros. Vestibulum quis sem fringilla, semper lorem non, aliquam nulla. Proin libero ante, rhoncus congue posuere sed, porttitor ut odio. Nullam non eros congue, gravida leo quis, sodales augue. Cras viverra, justo non finibus gravida, augue ligula porta nunc, id placerat felis magna sed ante. Cras vel velit tincidunt, ultrices massa vel, malesuada mi. Nunc malesuada odio quis ipsum tempus, in convallis lacus ultricies. Maecenas euismod urna nisl, dictum ullamcorper dui pharetra sed. Praesent id imperdiet enim. Donec eu tincidunt ipsum. Mauris ut quam cursus lacus auctor finibus. Curabitur mattis rutrum ipsum. Nam mi nibh, dictum eget suscipit in, rhoncus a dolor. In et arcu quis magna sagittis sagittis. Suspendisse potenti. Donec imperdiet rhoncus nibh, ac porttitor dui mollis at. Cras vitae diam purus. Duis scelerisque congue leo, ac bibendum neque ultricies nec. Nam facilisis, arcu eget luctus auctor, arcu ipsum aliquam eros, quis lacinia tellus mauris eget purus. Aliquam fringilla mollis lorem vel posuere. Aliquam felis ipsum, porta id blandit at, maximus eget purus. Sed blandit velit ut mollis tempus. Vestibulum tristique lorem quis enim commodo blandit. Duis tortor ligula, vehicula quis sollicitudin placerat, consequat non purus. Nullam sodales dolor enim. Vestibulum vulputate nulla nec ante faucibus, sed ultrices lectus tincidunt. Morbi consequat tincidunt risus, vel cursus mauris placerat aliquam. Nam convallis feugiat lacus eget lobortis. Nam eget ex velit. Aliquam mattis facilisis nulla eu varius. Donec elementum dui sed elit rhoncus elementum. Ut vitae odio ac velit aliquam elementum. Sed vulputate orci mi, et aliquam enim vestibulum in. Sed ac massa nulla. Phasellus tempus quis ligula at laoreet. Nam varius est vel turpis venenatis suscipit. Nam eu tellus nec purus congue commodo id at enim. Maecenas scelerisque risus non tincidunt accumsan. In sed fermentum ipsum, sed pellentesque ex. Donec finibus augue et consequat pharetra. Quisque rutrum mattis leo eu facilisis. Aenean congue aliquet magna, faucibus egestas diam euismod sit amet. Aliquam erat volutpat. Nam id enim porta, convallis odio vitae, ornare tortor. Duis pharetra pharetra lectus, vulputate aliquet metus congue sit amet. Cras viverra vestibulum neque eget semper. Sed dictum felis a viverra pretium. Aliquam in ipsum ultrices, ultricies metus cursus, lacinia purus. Morbi sit amet mattis lacus, sed consectetur ex.", size = 20},
	}

	if !maui_glfw.init(1200, 1000, "Maui", .OpenGL) {
		return
	}

	if !maui_opengl.init(&maui_glfw.interface) {
		return
	}

		value: [2]f64
	ui.init()

	for maui_glfw.cycle(TARGET_FRAME_TIME) {
		using ui

		// Beginning of ui calls
		maui_glfw.begin_frame()
		begin_frame()

		// UI calls
		shrink(50)
		placement.size = Exact(30)
		if do_layout(.Top, Exact(26)) {
			placement.size = Exact(100); placement.side = .Left
			if res := do_numeric_field(Numeric_Field_Info(f64){
				value = value[0],
				precision = 2,
			}); res.changed {
				value[0] = res.value
			}
			space(Exact(20))
			if res := do_numeric_field(Numeric_Field_Info(f64){
				value = value[1],
				precision = 2,
			}); res.changed {
				value[1] = res.value
			}
		}
		do_text_demo(&text_demo)

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
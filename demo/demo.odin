package demo

import ui "isaiah:maui"
import rl "vendor:raylib"
import backend "isaiah:maui/raylibBackend"

import "core:runtime"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:mem"
import "core:time"

// Set up your own layout values
DEFAULT_SPACING :: 10
HEADER_LEADING_SPACE :: 24
HEADER_TRAILING_SPACE :: 12
DEFAULT_BUTTON_SIZE :: 36
DEFAULT_TEXT_INPUT_SIZE :: 36

Tabs :: enum {
	text,
	input,
	table,
}
Choices :: enum {
	first,
	second,
	third,
}
DemoWindow :: enum {
	widgetGallery,
	dataTable,
}

_main :: proc() {
	windowOpen: [DemoWindow]bool

	// Demo values
	choices: bit_set[Choices]
	choice: Choices = .first
	close := false
	value := 10.0
	integer := 0
	items := 100
	boolean := false
	font: ui.FontIndex
	tab: Tabs

	a, b, c: bool

	wordwrap: bool

	buffer := make([dynamic]u8)
	defer delete(buffer)

	// set up raylib
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(1000, 800, "Maui Demo")
	rl.SetExitKey(.NULL)
	rl.MaximizeWindow()
	TARGET_FPS :: 60
	rl.SetTargetFPS(TARGET_FPS)

	ui.Init()
	backend.Init()

	ui.SetScreenSize(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))

	for true {
		ui.NewFrame()
		backend.NewFrame()

		{
			using ui
			rect := Cut(.right, 500)
			Shrink(100)
			if Layout(.left, 200) {
				SetSize(30)
				AttachTooltip("I'm a tooltip", .top)
				windowOpen[.widgetGallery] = ToggleButton({
					value = windowOpen[.widgetGallery], 
					label = "Widget Gallery",
				})
				if Window({
					title = "Widget Gallery", 
					rect = {700, 200, 400, 500}, 
					options = {.title, .collapsable, .closable},
				}) {
					Shrink(10); SetSize(30)
					tab = EnumTabs(tab, 0)
					Shrink(30); SetSize(30)
					if tab == .input {
						if Layout(.top, 30) {
							SetSide(.left); SetSize(120)
							integer = Spinner({
								value = integer, 
								low = -100, 
								high = 100,
							})
							SetSide(.right); SetSize(120)
							integer = RectSlider(RectSliderInfo(int){
								value = integer, 
								low = -100, 
								high = 100,
							})
						}
						Space(20)
						if change, newValue := Slider(SliderInfo(f64){
							value = value, 
							low = 0, 
							high = 10, 
							format = "%.2f",
						}); change {
							value = newValue
						}
						Space(20)
						if Menu({
							label = "Open me!", 
							size = {0, 120},
						}) {
							SetSize(30)
							MenuOption("Option A", false)
							MenuOption("Option B", false)
							MenuOption("Option C", false)
							if SubMenu("Radio Buttons", {200, 90}) {
								SetSize(30); AlignY(.middle); Cut(.left, 4)
								choice = EnumRadioButtons(choice, .left)
							}
						}
					} else if tab == .text {
						SetSize(36)
						TextInput({
							buffer = &buffer, 
							title = "Type some text", 
							placeholder = "Placeholder",
						})
						Space(100)
						SetSize(1, true)
					} else if tab == .table {
						SetSize(1, true)
						if layer, ok := Frame({
							layoutSize = {0, 2400},
						}); ok {
							SetSize(24)
							for i in 0..<100 {
								Text({text = TextFormat("Text %i", i + 1)})
							}
						}
					}
				}
				Space(10)
				windowOpen[.dataTable] = ToggleButton({
					value = windowOpen[.dataTable], 
					label = "Data Table",
				})
				if Window({
					title = "Style", 
					rect = {200, 200, 600, 500},
					layoutSize = Vec2{0, f32(len(ColorIndex)) * 30 + 60},
					options = {.title, .collapsable, .resizable, .closable},
				}) {
					window := CurrentWindow()
					Shrink(30)
					for member in ColorIndex {
						PushId(int(member))
							if Layout(.top, 30) {
								SetSide(.right); SetSize(100)
								painter.style.colors[member].a = RectSlider(RectSliderInfo(u8){painter.style.colors[member].a, 0, 255})
								painter.style.colors[member].b = RectSlider(RectSliderInfo(u8){painter.style.colors[member].b, 0, 255})
								painter.style.colors[member].g = RectSlider(RectSliderInfo(u8){painter.style.colors[member].g, 0, 255})
								painter.style.colors[member].r = RectSlider(RectSliderInfo(u8){painter.style.colors[member].r, 0, 255})
								SetSize(1, true)
								TextBox({
									font = .default, 
									text = Format(member),
								})
							}
						PopId()
					}
				}
			}
		}

		/*
			Drawing happens here
		*/
		ui.EndFrame()
		duration := time.duration_milliseconds(ui.ctx.frameDuration)
		
		rl.BeginDrawing()
		if ui.ShouldRender() {
			rl.ClearBackground(transmute(rl.Color)ui.GetColor(.base))
			backend.Render()
			rl.DrawText(rl.TextFormat("fps: %i", rl.GetFPS()), 0, 0, 20, rl.BLACK)
			rl.DrawText(rl.TextFormat("time: %f", rl.GetTime()), 0, 20, 20, rl.BLACK)
			rl.DrawText(rl.TextFormat("%fms", duration), 0, 40, 20, rl.BLACK)
		}
		rl.EndDrawing()


		if rl.WindowShouldClose() || close {
			break
		}
	}

	ui.Uninit()
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	_main()

	for _, leak in track.allocation_map {
		fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
	}
	for bad_free in track.bad_free_array {
		fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
	}
}
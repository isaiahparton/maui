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
DEFAULT_BUTTON_SIZE :: 26
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
	enableSubMenu := false
	tm: time.Time = time.now()
	temp_tm: time.Time

	a, b, c: bool

	wordwrap: bool

	buffer := make([dynamic]u8)
	defer delete(buffer)

	// set up raylib
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(1000, 800, "Maui Demo")
	rl.SetExitKey(.NULL)
	rl.MaximizeWindow()
	TARGET_FPS :: 120
	rl.SetTargetFPS(TARGET_FPS)

	ui.Init()
	backend.Init()

	ui.SetScreenSize(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))

	for true {
		ui.NewFrame()
		backend.NewFrame()

		{
			using ui
			if Window({
				title = "Widget Gallery", 
				rect = {800, 200, 500, 500}, 
				options = {.title, .collapsable, .closable},
			}) {
				Shrink(10); SetSize(30)
				tab = EnumTabs(tab, 0)
				Shrink(20); SetSize(30)

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
					Space(30)
					if TreeNode({text = "Slider", size = 100}) {
						SetSize(1, true)
						SetMargin(20)
						if change, newValue := Slider(SliderInfo(f64){
							value = value, 
							low = 0, 
							high = 10, 
							format = "%.2f",
							guides = ([]f64)({
								0,
								5,
								10,
							}),
						}); change {
							value = newValue
						}
					}
					if TreeNode({text = "Boolean controls", size = 100}) {
						Cut(.left, 20)
						ToggleSwitch({
							state = &boolean,
							onIcon = .check,
							offIcon = .close,
						})
					}
					Space(20)

					SetSize(DEFAULT_BUTTON_SIZE)
					if Menu({
						label = "Open me!", 
						size = {0, DEFAULT_BUTTON_SIZE * 4},
						align = .middle,
					}) {
						SetSize(DEFAULT_BUTTON_SIZE)
						Option({label = "Option A"})
						Option({label = "Option B"})
						if Option({
							label = "Enable Submenu", 
							active = enableSubMenu,
							noDismiss = true,
						}) {
							enableSubMenu = !enableSubMenu
						}
						if Enabled(enableSubMenu) {
							if SubMenu({
								label = "Sub Menu", 
								size = {200, DEFAULT_BUTTON_SIZE * 3},
							}) {
								SetSize(DEFAULT_BUTTON_SIZE)
								Option({label = "Option C"})
								Option({label = "Option D"})
								if SubMenu({
									label = "Radio Buttons", 
									side = .right,
									size = {200, DEFAULT_BUTTON_SIZE * 3},
								}) {
									SetSize(26); AlignY(.middle); Cut(.left, 2)
									choice = EnumRadioButtons(choice, .left)
								}
							}
						}
					}
				} else if tab == .text {
					SetSize(30)
					DatePicker({
						value = &tm,
						tempValue = &temp_tm,
					})
					Space(20)
					SetSize(20)
					if Layout(.top, 20) {
						SetSide(.left)
						newChoice := choice
						for member in Choices {
							PushId(int(member))
								if ToggleChip({state = choice == member, rowSpacing = 10, text = Format(member)}) {
									newChoice = member
								}
								Space(10)
							PopId()
						}
						choice = newChoice
					}
					Space(20)
					if Layout(.top, 30) {
						SetSide(.left)
						Button({
							label = "Filled",
							fitToLabel = true,
						})
						Space(10)
						Button({
							label = "Outlined",
							fitToLabel = true,
							style = .outlined,
						})
						Space(10)
						Button({
							label = "Subtle",
							fitToLabel = true,
							style = .subtle,
						})
					}
					Space(10)
					if Layout(.top, 30) {
						SetSide(.left)
						PillButton({
							label = "Filled",
							fitToLabel = true,
						})
						Space(10)
						PillButton({
							label = "Outlined",
							fitToLabel = true,
							style = .outlined,
						})
						Space(10)
						PillButton({
							label = "Subtle",
							fitToLabel = true,
							style = .subtle,
						})
					}
					SetSize(30)
					Space(20)
					CheckBox({state = &c, text = "Checkbox"})
					Space(20)
					choice = EnumRadioButtons(choice)

					if layout, ok := LayoutEx(GetRectBottom(CurrentLayout().rect, 40)); ok {
						SetSize(40); SetSide(.right)
						FloatingButton({icon = .calendar})
					}
				} else if tab == .table {
					SetSize(1, true)
					if Frame({
						layoutSize = {0, 2400},
					}) {
						SetSize(24)
						for i in 0..<100 {
							Text({text = TextFormat("Text %i", i + 1)})
						}
					}
				}
			}
			if Window({
				title = "Style", 
				rect = {200, 200, 600, 500},
				layoutSize = Vec2{700, f32(len(ColorIndex)) * 30 + 60},
				options = {.title, .collapsable, .resizable, .closable},
				layerOptions = {.noScrollMarginY},
			}) {
				window := CurrentWindow()
				Shrink(30)
				for member in ColorIndex {
					PushId(int(member))
						if Layout(.top, 24) {
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
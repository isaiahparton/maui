package demo

import ui "isaiah:maui"
import rl "vendor:raylib"
import backend "isaiah:maui/raylibBackend"

import "core:runtime"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:mem"

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
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))

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
				windowOpen[.widgetGallery] = ToggleButton(windowOpen[.widgetGallery], "Widget Gallery")
				if Window("Widget Gallery", {200, 200, 400, 500}, {.title, .collapsable, .closable}) {
					Shrink(30); SetSize(30)
					if Layout(.top, 30) {
						SetSide(.left); SetSize(120)
						integer = Spinner(integer, -100, 100)
						SetSide(.right)
						integer = DragSpinner(integer, -100, 100)
					}
					Space(20)
					if Menu("Open me!", 120) {
						SetSize(30)
						MenuOption("Option A", false)
						MenuOption("Option B", false)
						MenuOption("Option C", false)
						if SubMenu("More Options", {200, 90}) {
							SetSize(30)
							MenuOption("Option D", false)
							MenuOption("Option E", false)
							MenuOption("Option F", false)
						}
					}
				}
				Space(10)
				windowOpen[.dataTable] = ToggleButton(windowOpen[.dataTable], "Data Table")
				if Window("Window Options", {200, 200, 400, 500}, {.title, .collapsable, .closable}) {
					PaintRoundedRectEx(GetCurrentLayout().rect, WINDOW_ROUNDNESS, {.bottomLeft, .bottomRight}, GetColor(.widgetBase))
					Shrink(10); SetSize(30)
					tab = EnumTabs(tab, 0)
					PaintRect(GetCurrentLayout().rect, GetColor(.foreground))
					Shrink(30)
					window := CurrentWindow()
					CheckBoxBitSetHeader(&window.options, "Options")
					for member in WindowOption {
						PushId(HashId(int(member)))
							CheckBoxBitSet(&window.options, member, CapitalizeString(Format(member)))
						PopId()
					}
				}
			}
		}

		/*
			Drawing happens here
		*/
		ui.EndFrame()

		rl.BeginDrawing()
		if ui.ShouldRender() {
			rl.ClearBackground(transmute(rl.Color)ui.GetColor(.foreground))
			backend.Render()
			rl.DrawText(rl.TextFormat("FPS: %i", rl.GetFPS()), 0, 0, 20, rl.BLACK)
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
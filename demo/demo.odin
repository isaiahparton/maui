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

_main :: proc() {

	// Demo values
	choices: bit_set[Choices]
	choice: Choices = .first
	close := false
	value: f32 = 10.0
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
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(1000, 800, "Maui Demo")
	rl.MaximizeWindow()
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))

	ui.Init()
	backend.Init()

	ui.SetScreenSize(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))

	for true {
		ui.Refresh()

		backend.NewFrame()

		rect := ui.Cut(.right, 500)
		if layer, ok := ui.Layer(rect, {0, 2000}); ok {
			ui.PaintRect(layer.body, ui.GetColor(.foreground, 1))

			// Tabs
			ui.SetSize(40)
			tab = ui.EnumTabs(tab)

			// Apply content padding
			ui.Shrink(20)

			if tab == .text {
				ui.SetSize(30)
				wordwrap = ui.CheckBox(wordwrap, "Enable word wrap")
				if ui.Layout(.top, 30) {
					ui.SetSide(.left); ui.SetSize(120)
					font = ui.EnumMenu(font, 30)
				}
				ui.SetSize(1, true)
				ui.Space(DEFAULT_SPACING)
				ui.TextBox(font, "Lorem ipsum dolor sit amet. Et unde alias eum repellendus earum est autem error cum esse enim? Est veritatis asperiores vel fugiat unde non dolorem voluptatibus rem maiores autem? Vel facilis eveniet ea molestiae fugiat ut cupiditate corrupti. Qui consequatur earum sed explicabo iste qui dolorum iste qui dolor sapiente ex odit obcaecati aut quibusdam vitae. Eum rerum harum et laboriosam praesentium cum numquam dolores. Sed pariatur autem a atque quia et dolor numquam et animi harum et molestias ratione et amet delectus aut nemo nemo. Eum autem inventore ea ipsam harum cum architecto rerum cum incidunt quia? Eos velit deleniti cum magnam quod aut eaque eligendi vel assumenda vitae sit dolor placeat? Aut omnis perferendis eos repellendus deleniti et exercitationem molestiae ut dolorem fugit.", {.wordwrap} if wordwrap else {})
			} else if tab == .input {
				ui.SetSize(40)
				ui.AlignY(.middle)

				// Boolean controls
				ui.Text(.header, "Boolean Controls", true)
				ui.Space(HEADER_TRAILING_SPACE)
				boolean = ui.CheckBox(boolean, "Check Box")
				ui.Space(DEFAULT_SPACING)
				boolean = ui.ToggleSwitch(boolean)

				// Round buttons
				ui.Space(HEADER_LEADING_SPACE)
				ui.Text(.header, "Round Buttons", true)
				ui.Space(HEADER_TRAILING_SPACE)
				if ui.Layout(.top, 30) {
					ui.SetSide(.left);
					ui.PillButtonEx("SOLA FIDE", .subtle)
					ui.Space(DEFAULT_SPACING)
					ui.PillButtonEx("SOLA GRACIA", .normal)
					ui.Space(DEFAULT_SPACING)
					ui.PillButtonEx("SOLA SCRIPTURA", .bright)
				}

				// Regular Buttons
				ui.Space(HEADER_LEADING_SPACE)
				ui.Text(.header, "Default Buttons", true)
				ui.Space(HEADER_TRAILING_SPACE)
				if ui.Layout(.top, 30) {
					ui.SetSize(30); ui.SetSide(.left);
					a = ui.ToggleButtonEx(a, ui.Icon.formatBold, {.topLeft, .bottomLeft})
					b = ui.ToggleButtonEx(b, ui.Icon.formatItalic, {})
					c = ui.ToggleButtonEx(c, ui.Icon.formatUnderline, {.topRight, .bottomRight})
					ui.Space(DEFAULT_SPACING)
					ui.ButtonEx("\ue87d Favorites", {.topLeft, .bottomLeft})
					ui.Space(2)
					ui.ButtonEx(ui.Icon.add, {.topRight, .bottomRight})
				}

				// Text input
				ui.Space(HEADER_LEADING_SPACE)
				ui.Text(.header, "Text Input", true)
				ui.Space(HEADER_TRAILING_SPACE)
				ui.SetSize(DEFAULT_TEXT_INPUT_SIZE)
				if change, newData := ui.TextInputBytes(buffer[:], "Name", "John Doe", {}); change {
					resize(&buffer, len(newData))
					copy(buffer[:], newData[:])
				}
				ui.Space(DEFAULT_SPACING)
				value = ui.NumberInputFloat32(value, "Enter a value")

				// Single choice
				ui.Space(HEADER_LEADING_SPACE)
				ui.Text(.header, "Single choice", true)
				ui.Space(HEADER_TRAILING_SPACE)
				ui.SetSize(30)
				choice = ui.RadioButtons(choice, .left)
				ui.Space(DEFAULT_SPACING)
				if ui.Layout(.top, 30) {
					ui.SetSize(120); ui.SetSide(.left)
					choice = ui.EnumMenu(choice, 30)
				}

				// Single choice
				ui.Space(HEADER_LEADING_SPACE)
				ui.Text(.header, "Multiple choice", true)
				ui.Space(HEADER_TRAILING_SPACE)
				ui.SetSize(30)
				ui.CheckBoxBitSetHeader(&choices, "Choices")
				for element in Choices {
					ui.PushId(ui.HashId(int(element)))
						ui.CheckBoxBitSet(&choices, element, ui.Format(element))
					ui.PopId()
				}
				ui.Space(DEFAULT_SPACING)
				if ui.Layout(.top, 30) {
					ui.SetSize(240); ui.SetSide(.left)
					choices = ui.BitSetMenu(choices, 30)
				}
			} else if tab == .table {
				if ui.Layout(.top, 30) {
					ui.SetSide(.left); ui.SetSize(120)
					items = ui.Spinner(items, 0, 1000)
				}
				ui.Space(DEFAULT_SPACING)
				ui.SetSize(300)
				if layer, ok := ui.Frame({0, f32(items) * 30}); ok {
					ui.AlignY(.middle)
					ui.SetSize(30)
					for i in 0 ..< items {
						ui.Text(.default, ui.StringFormat(" Item %i", i + 1), false)
					}
				}
			}
		}

		/*
			Drawing happens here
		*/
		ui.Prepare()

		rl.BeginDrawing()
		if ui.ShouldRender() {
			rl.ClearBackground(transmute(rl.Color)ui.GetColor(.backing))
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
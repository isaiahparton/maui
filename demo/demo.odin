package demo

import ui "../maui"
import rl "vendor:raylib"
import backend "../mauiRaylib"

import "core:runtime"
import "core:fmt"
import "core:math"
import "core:slice"

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

main :: proc() {

	// Demo values
	choice: Choices = .first
	close := false
	value: f32 = 10.0
	integer := 0
	boolean := false
	tab: Tabs

	a, b, c: bool

	wordwrap: bool

	buffer := make([dynamic]u8)

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
		if layer, ok := ui.Layer(rect, {}); ok {
			ui.PaintRect(layer.body, ui.GetColor(.foreground, 1))
			ui.Enable()

			// Tabs
			ui.SetSize(40)
			tab = ui.EnumTabs(tab)

			// Apply content padding
			ui.Shrink(20)

			if tab == .text {
				ui.SetSize(30)
				wordwrap = ui.CheckBox(wordwrap, "Enable word wrap")
				ui.SetSize(300)
				ui.TextBox(.default, "Lorem ipsum dolor sit amet. Et unde alias eum repellendus earum est autem error cum esse enim? Est veritatis asperiores vel fugiat unde non dolorem voluptatibus rem maiores autem? Vel facilis eveniet ea molestiae fugiat ut cupiditate corrupti. Qui consequatur earum sed explicabo iste qui dolorum iste qui dolor sapiente ex odit obcaecati aut quibusdam vitae. Eum rerum harum et laboriosam praesentium cum numquam dolores. Sed pariatur autem a atque quia et dolor numquam et animi harum et molestias ratione et amet delectus aut nemo nemo. Eum autem inventore ea ipsam harum cum architecto rerum cum incidunt quia? Eos velit deleniti cum magnam quod aut eaque eligendi vel assumenda vitae sit dolor placeat? Aut omnis perferendis eos repellendus deleniti et exercitationem molestiae ut dolorem fugit.", {.wordwrap} if wordwrap else {})
				ui.Space(100)
				ui.Text(.label, "\ue5ca\ue3c9\ue145\ue15b\ue5cd\ue88a\ue746\ue87d", true)
				ui.Text(.default, "\ue5ca\ue3c9\ue145\ue15b\ue5cd\ue88a\ue746\ue87d", true)
				ui.Text(.header, "\ue5ca\ue3c9\ue145\ue15b\ue5cd\ue88a\ue746\ue87d", true)
			} else if tab == .input {
				ui.SetSize(40)
				ui.AlignY(.middle)

				// Boolean controls
				ui.Text(.header, "Boolean Controls", true)
				ui.Space(HEADER_TRAILING_SPACE)
				boolean = ui.CheckBox(boolean, "Check Box")
				ui.Space(DEFAULT_SPACING)
				boolean = ui.ToggleSwitch(boolean)

				// Icon buttons
				ui.Space(HEADER_LEADING_SPACE)
				ui.Text(.header, "Toolbox", true)
				ui.Space(HEADER_TRAILING_SPACE)
				if layout, ok := ui.Layout(ui.Cut(.top, 30)); ok {
					ui.SetSize(30); ui.SetSide(.left);
					a = ui.ToggleButtonEx(a, ui.Icon.heart, {.topLeft, .bottomLeft})
					b = ui.ToggleButtonEx(b, ui.Icon.heart, {})
					c = ui.ToggleButtonEx(c, ui.Icon.heart, {.topRight, .bottomRight})
					ui.Space(DEFAULT_SPACING)
				}

				// Radio buttons
				ui.Space(HEADER_LEADING_SPACE)
				ui.Text(.header, "Radio Buttons", true)
				ui.Space(HEADER_TRAILING_SPACE)
				if layout, ok := ui.Layout(ui.Cut(.top, 40)); ok {
					layout.side = .left
					layout.alignX = .middle
					layout.alignY = .middle
					layout.size = layout.rect.w / 3
					choice = ui.RadioButtons(choice, .bottom)
				}

				// Radio buttons
				ui.Space(HEADER_LEADING_SPACE)
				ui.Text(.header, "Buttons", true)
				ui.Space(HEADER_TRAILING_SPACE)
				if layout, ok := ui.Layout(ui.Cut(.top, 40)); ok {
					layout.side = .left; layout.size = layout.rect.w / 3; layout.margin = 5
					ui.RoundButtonEx("SOLA FIDE", .subtle)
					ui.RoundButtonEx("SOLA GRACIA", .normal)
					ui.RoundButtonEx("SOLA SCRIPTURA", .bright)
				}

				// Radio buttons
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
			} else if tab == .table {
				ui.Text(.default, "Comming soon...", true)
				ui.SetSize(500)
				if layer, ok := ui.Frame(1000); ok {
					ui.SetSize(30)
					for i in 0 ..< 20 {
						ui.Text(.default, ui.StringFormat("Text %i", i), false)
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
}

package maui

import "core:fmt"
import "core:math/linalg"

import "vendor:nanovg"

Check_Box_Info :: struct {
	using generic: Generic_Widget_Info,
	value: bool,
	text: string,
	text_side: Maybe(Box_Side),
}
Check_Box_Widget_Variant :: struct {
	hover_time,
	disable_time: f32,
}
//#Info fields
// - `state` Either a `bool`, a `^bool` or one of `{.on, .off, .unknown}`
// - `text` If defined, the check box will display text on `text_side` of itself
// - `text_side` The side on which text will appear (defaults to left)
checkbox :: proc(ui: ^UI, info: Check_Box_Info, loc := #caller_location) -> Generic_Widget_Result {
	SIZE :: 22
	HALF_SIZE :: SIZE / 2
	// Check if there is text
	has_text := len(info.text) > 0
	// Default orientation
	text_side := info.text_side.? or_else .Left
	// Determine total size
	size, text_size: [2]f32
	if has_text {

		text_box: Box
		nanovg.FontFace(ui.ctx, "Default")
		nanovg.FontSize(ui.ctx, ui.style.text_size.label)
		nanovg.TextBounds(ui.ctx, 0, 0, info.text, transmute(^[4]f32)&text_box)
		text_size = text_box.high - text_box.low

		if text_side == .Bottom || text_side == .Top {
			size.x = max(SIZE, text_size.x)
			size.y = SIZE + text_size.y
		} else {
			size.x = SIZE + text_size.x + ui.style.layout.widget_padding * 2
			size.y = SIZE
		}
	} else {
		size = SIZE
	}
	layout := current_layout(ui)
	// Create
	self, result := get_widget(ui, info.generic, loc)
	// Colocate
	self.box = info.box.? or_else align_inner(next_box_of_size(ui, size), size, ui.placement.align)
	// Update
	update_widget(ui, self)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Check_Box_Widget_Variant{}
	}
	data := &self.variant.(Check_Box_Widget_Variant)
	// Animate
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.disable_time = animate(ui, data.disable_time, DEFAULT_WIDGET_DISABLE_TIME, .Disabled in self.bits)
	// Painting
	if .Should_Paint in self.bits || true {
		icon_box: Box
		if has_text {
			switch text_side {
				case .Left:
				icon_box = {self.box.low, SIZE}
				case .Right:
				icon_box = {{self.box.high.x - SIZE, self.box.low.y}, SIZE}
				case .Top:
				icon_box = {{center_x(self.box) - HALF_SIZE, self.box.high.y - SIZE}, SIZE}
				case .Bottom:
				icon_box = {{center_x(self.box) - HALF_SIZE, self.box.low.y}, SIZE}
			}
			icon_box.low = linalg.floor(icon_box.low)
			icon_box.high += icon_box.low
		} else {
			icon_box = self.box
		}
		// Paint box
		opacity := 1 - 0.5 * data.disable_time
		fill_color := ui.style.color.background[0]

		nanovg.FillPaint(ui.ctx, nanovg.LinearGradient(icon_box.low.x, icon_box.low.y, icon_box.low.x, icon_box.high.y, ui.style.color.background[1], ui.style.color.background[0]))
		nanovg.BeginPath(ui.ctx)
		nanovg.RoundedRect(ui.ctx, icon_box.low.x, icon_box.low.y, icon_box.high.x - icon_box.low.x, icon_box.high.y - icon_box.low.y, ui.style.rounding)
		nanovg.Fill(ui.ctx)

		center := box_center(icon_box)
		// Paint icon
		if info.value {
			scale: f32 = HALF_SIZE * 0.5
			a, b, c: [2]f32 = {-1, -0.047} * scale, {-0.333, 0.619} * scale, {1, -0.713} * scale

			nanovg.StrokeWidth(ui.ctx, 3)
			nanovg.LineCap(ui.ctx, .ROUND)
			nanovg.LineJoin(ui.ctx, .ROUND)
			nanovg.StrokeColor(ui.ctx, ui.style.color.substance)
			nanovg.BeginPath(ui.ctx)
			nanovg.MoveTo(ui.ctx, center.x + a.x, center.y + a.y)
			nanovg.LineTo(ui.ctx, center.x + b.x, center.y + b.y)
			nanovg.LineTo(ui.ctx, center.x + c.x, center.y + c.y)
			nanovg.Stroke(ui.ctx)
		}
		// Paint text
		if has_text {
			nanovg.FillColor(ui.ctx, fade(ui.style.color.text[0], opacity))
			nanovg.BeginPath(ui.ctx)
			switch text_side {
				case .Left: 	
				nanovg.TextAlignHorizontal(ui.ctx, .LEFT)
				nanovg.TextAlignVertical(ui.ctx, .MIDDLE)
				nanovg.Text(ui.ctx, icon_box.high.x + ui.style.layout.widget_padding, center.y, info.text)
				case .Right: 	
				nanovg.TextAlignHorizontal(ui.ctx, .RIGHT)
				nanovg.TextAlignVertical(ui.ctx, .MIDDLE)
				nanovg.Text(ui.ctx, icon_box.low.x - ui.style.layout.widget_padding, center.y, info.text)
				case .Top: 		
				nanovg.TextAlignHorizontal(ui.ctx, .CENTER)
				nanovg.TextAlignVertical(ui.ctx, .TOP)
				nanovg.Text(ui.ctx, self.box.low.x, self.box.low.y, info.text)
				case .Bottom: 	
				nanovg.TextAlignHorizontal(ui.ctx, .CENTER)
				nanovg.TextAlignVertical(ui.ctx, .BOTTOM)
				nanovg.Text(ui.ctx, self.box.low.x, self.box.high.y, info.text)
			}
			nanovg.Fill(ui.ctx)
		}
	}
	if data.hover_time > 0 {
		nanovg.FillColor(ui.ctx, fade(nanovg.RGBA(0, 0, 0, 25), data.hover_time))
		nanovg.BeginPath(ui.ctx)
		nanovg.RoundedRect(ui.ctx, self.box.low.x, self.box.low.y, self.box.high.x - self.box.low.x, self.box.high.y - self.box.low.y, ui.style.rounding)
		nanovg.Fill(ui.ctx)
	}
	//
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// We're done here
	return Generic_Widget_Result{self = self},
}
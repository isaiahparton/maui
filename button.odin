package maui

import "core:fmt"
import "core:math"

import "vendor:nanovg"

Button_Widget_Variant :: struct {
	hover_time,
	disable_time: f32,
}
Button_Type :: enum {
	Filled,
	Outlined,
	Subtle,
}
Button_Info :: struct {
	using generic: Generic_Widget_Info,
	text: string,
	font: Maybe(Font_Handle),
	text_align: Maybe(Text_Align),
	text_size: Maybe(f32),
	fit_text: bool,
	type: Button_Type,
	// Highlights the button with a tint and a solid bar
	highlight: Maybe(Color),
}
Button_Result :: struct {
	using generic: Generic_Widget_Result,
	min_width: f32,
}
button :: proc(ui: ^UI, info: Button_Info, loc := #caller_location) -> Button_Result {
	// Get widget
	self, generic_result := get_widget(ui, info.generic, loc)
	result: Button_Result = {
		generic = generic_result,
	}
	layout := current_layout(ui)
	// Get minimum width
	if info.fit_text {
		text_box: Box
		nanovg.TextBounds(ui.ctx, 0, 0, info.text, transmute(^[4]f32)&text_box)
		text_size := text_box.high - text_box.low

		ui.placement.size = text_size.x + height(layout.box)
	}
	// Colocate the button
	self.box = info.box.? or_else next_box(ui)
	update_widget(ui, self)
	// Assert variant existence
	if self.variant == nil {
		self.variant = Button_Widget_Variant{}
	}
	data := &self.variant.(Button_Widget_Variant)
	// Update retained data
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.disable_time = animate(ui, data.disable_time, DEFAULT_WIDGET_DISABLE_TIME, .Disabled in self.bits)
	if .Hovered in self.state {
		ui.cursor = .Hand
	}
	// Paint
	if .Should_Paint in self.bits {
		opacity: f32 = 1.0 - data.disable_time * 0.5
		text_color: Color

		// Types
		switch info.type {
			case .Filled:
			fill := blend_colors(data.hover_time, ui.style.color.button, ui.style.color.button_hovered)
			nanovg.FillPaint(ui.ctx, nanovg.LinearGradient(self.box.low.x, self.box.low.y, self.box.low.x, self.box.high.y, alpha_blend_colors(fill, nanovg.RGBA(255, 255, 255, 50)), fill))
			case .Outlined:
			nanovg.FillColor(ui.ctx, fade(ui.style.color.button_hovered, data.hover_time))
			if data.hover_time < 1 {
				nanovg.StrokeWidth(ui.ctx, 2)
				nanovg.StrokeColor(ui.ctx, ui.style.color.button)
			}
			case .Subtle:
			nanovg.FillColor(ui.ctx, fade(ui.style.color.button_hovered, data.hover_time))
		}

		nanovg.BeginPath(ui.ctx)
		nanovg.RoundedRect(ui.ctx, self.box.low.x, self.box.low.y, self.box.high.x - self.box.low.x, self.box.high.y - self.box.low.y, ui.style.rounding)
		nanovg.Fill(ui.ctx)

		switch info.type {
			case .Filled:
			nanovg.FillColor(ui.ctx, blend_colors(data.hover_time, ui.style.color.label, ui.style.color.label_hovered))
			case .Outlined:
			nanovg.FillColor(ui.ctx, blend_colors(data.hover_time, ui.style.color.label, ui.style.color.label_hovered))
			case .Subtle:
			nanovg.FillColor(ui.ctx, blend_colors(data.hover_time, ui.style.color.label, ui.style.color.label_hovered))
		}
		// Highlight
		if color, ok := info.highlight.?; ok {
			// paint_rounded_box_corners_fill(ui.painter, self.box, ui.style.rounding, info.corners, fade(color, 0.3))
			if (info.corners & Corners{.Bottom_Left, .Bottom_Right}) == {} {
				// paint_box_fill(ui.painter, get_box_bottom(self.box, 4), color)
			}
		}
		// Text title
		nanovg.BeginPath(ui.ctx)
		nanovg.TextAlignHorizontal(ui.ctx, .CENTER)
		nanovg.TextAlignVertical(ui.ctx, .MIDDLE)
		nanovg.FontSize(ui.ctx, ui.style.text_size.label)
		text_origin: [2]f32
		text_align := info.text_align.? or_else .Middle
		switch text_align {
			case .Left:
			text_origin = {self.box.low.x + ui.style.layout.widget_padding, (self.box.low.y + self.box.high.y) / 2}
			case .Middle:
			text_origin = center(self.box)
			case .Right:
			text_origin = {self.box.high.x - ui.style.layout.widget_padding, (self.box.low.y + self.box.high.y) / 2}
		}
		result.min_width = nanovg.Text(ui.ctx, text_origin.x, text_origin.y, info.text) + height(layout.box)
		nanovg.Fill(ui.ctx)
	}
	// Get next hover state
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	update_layer_content_bounds(ui.layers.current, self.box)
	// we're done here
	return result
}
package maui
import "../"
// Core dependencies
import "core:fmt"
import "core:runtime"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:unicode/utf8"
import "core:math"
import "core:math/linalg"

// Edit a dynamic array of bytes or a string
// NOTE: Editing a string that was not allocated will segfault!
Text_Input_Data :: union {
	^[dynamic]u8,
	^string,
}
Text_Input_State :: struct {
	offset: [2]f32,
}
Text_Input_Info :: struct {
	using generic: Generic_Widget_Info,
	data: Text_Input_Data,
	title: Maybe(string),
	placeholder: Maybe(string),
	multiline,
	hidden: bool,
}
Text_Input_Result :: struct {
	using generic: Generic_Widget_Result,
	changed,
	submitted: bool,
}
Text_Input_Widget_Variant :: struct {
	hover_time,
	focus_time: f32,
	offset: [2]f32,
}
text_input :: proc(ui: ^UI, info: Text_Input_Info, loc := #caller_location) -> Text_Input_Result {
	self, generic_result := get_widget(ui, info, loc)
	result: Text_Input_Result = {
		generic = generic_result,
	}
	// Colocate
	self.options += {.Draggable, .Can_Key_Select}
	self.box = info.box.? or_else layout_next(current_layout(ui))
	// Assert variant existence
	if self.variant == nil {
		self.variant = Text_Input_Widget_Variant{}
	}
	data := &self.variant.(Text_Input_Widget_Variant)
	// Update
	update_widget(ui, self)
	// Animate
	data.focus_time = animate(ui, data.focus_time, 0.15, .Focused in self.state)
	// Text cursor
	if .Hovered in self.state {
		ui.cursor = .Beam
	}
	// Get a temporary buffer if necessary
	buffer := info.data.(^[dynamic]u8) or_else get_scribe_buffer(&ui.scribe, self.id)
	// Text edit
	if .Focused in (self.state - self.last_state) {
		if text, ok := info.data.(^string); ok {
			resize(buffer, len(text))
			copy(buffer[:], text[:])
		}
	}
	if .Focused in self.state {
		if key_pressed(ui.io, .Enter) || key_pressed(ui.io, .Keypad_Enter) {
			result.submitted = true
		}
		result.changed = escribe_text(&ui.scribe, ui.io, {
			array = buffer,
			multiline = info.multiline,
		})
	}
	// Get data source
	text: string
	switch type in info.data {
		case ^string:
		text = type^
		case ^[dynamic]u8:
		text = string(type[:])
	}
	text_info: Text_Info = {
		text = text, 
		font = ui.style.font.label,
		size = ui.style.text_size.field,
		clip = self.box,
		hidden = info.hidden,
	}
	// Do text interaction
	inner_box: Box = shrink_box(self.box, ui.style.layout.widget_padding)
	text_origin: [2]f32 = inner_box.low
	if !info.multiline {
		text_origin.y += height(inner_box) / 2
		text_info.baseline = .Middle
	}
	corners: Corners = info.corners.? or_else ALL_CORNERS
	// Paint!
	if (.Should_Paint in self.bits) {
		if info.placeholder != nil {
			if len(text) == 0 {
				paint_text(
					ui.painter,
					text_origin, 
					{font = text_info.font, size = text_info.size, text = info.placeholder.?, baseline = text_info.baseline}, 
					ui.style.color.text[1],
				)
			}
		}
		opacity: f32 = 1.0
		stroke_color := blend_colors(data.focus_time, fade(ui.style.color.substance, 0.5), ui.style.color.accent)
		layer := current_layer(ui)
		ui.painter.target = layer.targets[.Background]
		if data.focus_time < 1 {
			paint_box_inner_gradient(ui.painter, self.box, 0, 56, {}, fade(stroke_color, 0.5 * (1 - data.focus_time)))
		}
		paint_box_stroke(ui.painter, self.box, 1, stroke_color)
		if title, ok := info.title.?; ok {
			paint_text(ui.painter, {text_origin.x, self.box.low.y - 2}, {
				text = title,
				baseline = .Bottom,
				font = ui.style.font.title,
				size = ui.style.text_size.title,
			}, ui.style.color.text[0])
		}
		ui.painter.target = layer.targets[.Foreground]
	}
	// Do text scrolling or whatever
	// Focused state
	if .Focused in (self.state - self.last_state) {
		ui.scribe.selection.offset = len(text)
		ui.scribe.selection.length = 0
	}
	text_result := paint_tactile_text(ui, self, text_origin - data.offset, {base = text_info}, ui.style.color.text[0])

	// Get the text location and cursor offsets
	if .Focused in self.state {
		if text_result.selection.line > ui.scribe.line {
			if text_result.selection_bounds.high.y > inner_box.high.y {
				data.offset.y += (text_result.selection_bounds.high.y - inner_box.high.y)
			}
		} else if text_result.selection.line < ui.scribe.line {
			if text_result.selection_bounds.low.y < inner_box.low.y {
				data.offset.y -= (inner_box.low.y - text_result.selection_bounds.low.y)
			}
		}
		if text_result.selection.column < ui.scribe.column {
			if text_result.selection_bounds.low.x < inner_box.low.x {
				data.offset.x -= (inner_box.low.x - text_result.selection_bounds.low.x)
			}
		}
		if text_result.selection_bounds.high.x > inner_box.high.x {
			data.offset.x += (text_result.selection_bounds.high.x - inner_box.high.x)
		}
		
		offset_x_limit := max(width(text_result.bounds) - width(inner_box), 0)
		if .Pressed in self.state {
			left_over := self.box.low.x - ui.io.mouse_point.x 
			if left_over > 0 {
				data.offset.x -= left_over * 0.2
				ui.painter.next_frame = true
			}
			right_over := ui.io.mouse_point.x - self.box.high.x
			if right_over > 0 {
				data.offset.x += right_over * 0.2
				ui.painter.next_frame = true
			}
			data.offset.x = clamp(data.offset.x, 0, offset_x_limit)
		} else {
			if ui.scribe.offset < ui.scribe.last_selection.offset {
				if text_result.selection_bounds.low.x < inner_box.low.x {
					data.offset.x = max(0, text_result.selection_bounds.low.x - text_result.bounds.low.x)
				}
			} else if ui.scribe.offset > ui.scribe.last_selection.offset || ui.scribe.length > ui.scribe.last_selection.length {
				if text_result.selection_bounds.high.x > inner_box.high.x {
					data.offset.x = min(offset_x_limit, (text_result.selection_bounds.high.x - text_result.bounds.low.x) - width(inner_box))
				}
			}
		}
		// What to do if change occoured
		if result.changed {
			self.state += {.Changed}
			ui.painter.next_frame = true
			if value, ok := info.data.(^string); ok {
				delete(value^)
				value^ = strings.clone_from_bytes(buffer[:])
			}
		}
	}
	// Whatever
	if .Focused in (self.last_state - self.state) {
		result.submitted = true
	}
	ui.scribe.selection = text_result.selection
	// Update hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// Only for content clipping of title (not very elegant)
	if info.title != nil {
		self.box.low.y -= 10
	}
	return result
}
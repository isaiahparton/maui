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
	multiline: bool,
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
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
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
	}
	// Do text interaction
	inner_box: Box = {{self.box.low.x + ui.style.layout.widget_padding, self.box.low.y}, {self.box.high.x - ui.style.layout.widget_padding, self.box.high.y}}
	text_origin: [2]f32 = inner_box.low
	if !info.multiline {
		text_origin.y += height(inner_box) / 2
		text_info.baseline = .Middle
	} else {
		text_origin.y += ui.style.layout.widget_padding
	}
	// Paint!
	if (.Should_Paint in self.bits) {
		if info.placeholder != nil {
			if len(text) == 0 {
				paint_text(
					ui.painter,
					text_origin, 
					{font = ui.style.font.label, size = ui.style.text_size.field, text = info.placeholder.?, baseline = .Middle}, 
					ui.style.color.text[0],
				)
			}
		}
		fill_color := fade(ui.style.color.substance, 0.2 * data.hover_time * (1 - data.focus_time))
		stroke_color := blend_colors(data.focus_time, ui.style.color.substance, ui.style.color.accent)
		points, point_count := get_path_of_box_with_cut_corners(self.box, height(self.box) * 0.2, {.Top_Right})
		layer := current_layer(ui)
		ui.painter.target = layer.targets[.Background]
		paint_path_fill(ui.painter, points[:point_count], fill_color)
		ui.painter.target = layer.targets[.Foreground]
		paint_titled_input_stroke(ui, self.box, info.title, height(self.box) * 0.2, ui.style.stroke_width, stroke_color)
	}
	// Do text scrolling or whatever
	// Focused state
	if .Focused in (self.state - self.last_state) {
		ui.scribe.selection.offset = len(text)
		ui.scribe.selection.length = 0
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
	text_result := paint_tactile_text(ui, self, text_origin - data.offset, {base = text_info}, ui.style.color.text[0])
		ui.scribe.selection = text_result.selection
	// Get the text location and cursor offsets
	if .Focused in self.state {
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
	// Update hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// Only for content clipping of title (not very elegant)
	if info.title != nil {
		self.box.low.y -= 10
	}
	return result
}
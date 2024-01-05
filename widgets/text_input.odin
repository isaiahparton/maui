package maui_widgets
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
	using generic: maui.Generic_Widget_Info,
	data: Text_Input_Data,
	title: Maybe(string),
	placeholder: Maybe(string),
	multiline: bool,
}
Text_Input_Result :: struct {
	using generic: maui.Generic_Widget_Result,
	changed,
	submitted: bool,
}
text_input :: proc(ui: ^maui.UI, info: Text_Input_Info, loc := #caller_location) -> Text_Input_Result {
	using maui
	self, generic_result := get_widget(ui, hash(ui, loc))
	result: Text_Input_Result = {
		generic = generic_result,
	}
	// Colocate
	self.options += {.Draggable, .Can_Key_Select}
	self.box = info.box.? or_else layout_next(current_layout(ui))
	// Update
	update_widget(ui, self)
	// Animate
	hover_time := animate_bool(ui, &self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
	focus_time := animate_bool(ui, &self.timers[1], .Focused in self.state, 0.15)
	// Text cursor
	if .Hovered in self.state {
		ui.cursor = .Beam
	}
	// Get a temporary buffer if necessary
	buffer := info.data.(^[dynamic]u8) or_else get_scribe_buffer(&ui.scribe, self.id)
	state := (^Text_Input_State)(require_data(self, Text_Input_State))
	// Text edit
	if .Focused in (self.state - self.last_state) {
		if text, ok := info.data.(^string); ok {
			resize(buffer, len(text))
			copy(buffer[:], text[:])
		}
	}
	// Paint!
	if (.Should_Paint in self.bits) {
		fill_color := fade(ui.style.color.substance[1], 0.2 * hover_time)
		stroke_color := ui.style.color.substance[0]
		points, point_count := get_path_of_box_with_cut_corners(self.box, height(self.box) * 0.2, {.Top_Right})
		paint_path_fill(ui.painter, points[:point_count], fill_color)
		scale := width(self.box) * 0.5 * focus_time
		center := center_x(self.box)
		paint_box_fill(ui.painter, {{center - scale, self.box.high.y - 2}, {center + scale, self.box.high.y}}, stroke_color)
		paint_path_stroke(ui.painter, points[:point_count], true, 1, 0, stroke_color)
	}
	// Get data source
	text: string
	switch type in info.data {
		case ^string:
		text = type^
		case ^[dynamic]u8:
		text = string(type[:])
	}
	// Do text scrolling or whatever
	// Focused state
	if .Focused in (self.state - self.last_state) {
		ui.scribe.index = len(text)
		ui.scribe.length = 0
	}
	if .Focused in self.state {
		if key_pressed(ui.io, .Enter) || key_pressed(ui.io, .Keypad_Enter) {
			result.submitted = true
		}
		result.changed = escribe_text(&ui.scribe, ui.io, {
			array = buffer,
			bits = Text_Edit_Bits{.Multiline} if info.multiline else {},
		})
	}
	// Do text interaction
	inner_box: Box = {{self.box.low.x + ui.style.layout.widget_padding, self.box.low.y}, {self.box.high.x - ui.style.layout.widget_padding, self.box.high.y}}
	text_origin: [2]f32 = inner_box.low
	text_info: Text_Info = {
		text = text, 
		font = ui.style.font.label,
		size = ui.style.text_size.field,
		clip = self.box,
	}
	if !info.multiline {
		text_origin.y += height(inner_box) / 2
		text_info.baseline = .Middle
	} else {
		text_origin.y += ui.style.layout.widget_padding
	}
	text_result := paint_interact_text(ui, self, text_origin - state.offset, text_info, {}, ui.style.color.base_text[0])
	if .Focused in self.state {
		offset_x_limit := max(width(text_result.bounds) - width(inner_box), 0)
		if .Pressed in self.state {
			left_over := self.box.low.x - ui.io.mouse_point.x 
			if left_over > 0 {
				state.offset.x -= left_over * 0.2
				ui.painter.next_frame = true
			}
			right_over := ui.io.mouse_point.x - self.box.high.x
			if right_over > 0 {
				state.offset.x += right_over * 0.2
				ui.painter.next_frame = true
			}
			state.offset.x = clamp(state.offset.x, 0, offset_x_limit)
		} else {
			if ui.scribe.index < ui.scribe.last_index {
				if text_result.selection_bounds.low.x < inner_box.low.x {
					state.offset.x = max(0, text_result.selection_bounds.low.x - text_result.bounds.low.x)
				}
			} else if ui.scribe.index > ui.scribe.last_index || ui.scribe.length > ui.scribe.last_length {
				if text_result.selection_bounds.high.x > inner_box.high.x {
					state.offset.x = min(offset_x_limit, (text_result.selection_bounds.high.x - text_result.bounds.low.x) - width(inner_box))
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
	// Widget decoration
	if .Should_Paint in self.bits {
		// Draw placeholder
		if info.placeholder != nil {
			if len(text) == 0 {
				paint_text(
					ui.painter,
					text_origin, 
					{font = ui.style.font.label, size = ui.style.text_size.field, text = info.placeholder.?}, 
					ui.style.color.base_text[0],
				)
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
package maui
import "core:fmt"
import "core:strings"
import "core:io"
import "core:strconv"

Number_Input_Info :: struct {
	using generic: Generic_Widget_Info,
	value: f64,
	format,
	label: Maybe(string),
}
Number_Input_Result :: struct {
	using generic: Generic_Widget_Result,
	new_value: Maybe(f64),
}
number_input :: proc(ui: ^UI, info: Number_Input_Info, loc := #caller_location) -> Number_Input_Result {
	self, generic_result := get_widget(ui, info, loc)
	result: Number_Input_Result = {
		generic = generic_result,
	}
	// Colocate
	self.options += {.Draggable, .Can_Key_Select}
	self.box = info.box.? or_else next_box(ui)
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
	buffer := get_scribe_buffer(&ui.scribe, self.id)
	// printf the current value to the buffer if it's empty
	if len(buffer) == 0 {
		clear(buffer)
		w := strings.to_writer(transmute(^strings.Builder)buffer)
		fmt.wprintf(w, info.format.? or_else "%f", info.value)
	}
	text_info: Text_Info = {
		text = string(buffer[:]), 
		font = ui.style.font.label,
		size = ui.style.text_size.field,
		clip = self.box,
		baseline = .Middle,
	}
	// Do text interaction
	inner_box: Box = shrink_box(self.box, ui.style.layout.widget_padding)
	text_origin: [2]f32 = inner_box.low
	text_origin.y += height(inner_box) / 2
	// Paint!
	if (.Should_Paint in self.bits) {
		layer := current_layer(ui)
		ui.painter.target = layer.targets[.Background]
		paint_box_fill(ui.painter, self.box, ui.style.color.backing)
		if label, ok := info.label.?; ok {
			paint_text(ui.painter, {text_origin.x, self.box.low.y - 2}, {
				text = label,
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
		ui.scribe.selection.offset = len(text_info.text)
		ui.scribe.selection.length = 0
	}
	if .Focused in self.state {
		if key_pressed(ui.io, .Enter) || key_pressed(ui.io, .Keypad_Enter) {
			// result.submitted = true
		}
		if escribe_text(&ui.scribe, ui.io, {
			array = buffer,
		}) {
			self.state += {.Changed}
			ui.painter.next_frame = true
			if new_value, ok := strconv.parse_f64(string(buffer[:])); ok {
				result.new_value = new_value
			}
		}
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
	}
	// Whatever
	if .Focused in (self.last_state - self.state) {
		// result.submitted = true
	}
	ui.scribe.selection = text_result.selection
	// Update hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// Only for content clipping of title (not very elegant)
	if info.label != nil {
		self.box.low.y -= 10
	}
	return result
}
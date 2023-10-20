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
Text_Field_Data :: union {
	^[dynamic]u8,
	^string,
}

Text_Field_Info :: struct {
	data: Text_Field_Data,
	title: Maybe(string),
	placeholder: Maybe(string),
	multiline: bool,
}
Text_Field_Result :: struct {
	changed,
	submitted: bool,
}
do_text_field :: proc(info: Text_Field_Info, loc := #caller_location) -> (res: Text_Field_Result) {
	using maui
	if self, ok := do_widget(hash(loc), {.Draggable, .Can_Key_Select}); ok {
		// Colocate
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
		// Text cursor
		if .Hovered in self.state {
			core.cursor = .Beam
		}
		// Get a temporary buffer if necessary
		buffer := info.data.(^[dynamic]u8) or_else typing_agent_get_buffer(&core.typing_agent, self.id)
		// Text edit
		if .Got_Focus in self.state {
			if text, ok := info.data.(^string); ok {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
		}
		// Paint!
		paint_rounded_box_fill(self.box, painter.style.widget_rounding, get_color(.Widget_Back))
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
		if .Focused in self.state {
			if key_pressed(.Enter) || key_pressed(.Keypad_Enter) {
				res.submitted = true
			}
			res.changed = typing_agent_edit(&core.typing_agent, {
				array = buffer,
				bits = {},
			})
		}
		// Do text interaction
		inner_box: Box = {{self.box.low.x + WIDGET_PADDING, self.box.low.y}, {self.box.high.x - WIDGET_PADDING, self.box.high.y}}
		text_res := paint_interact_text(
			{inner_box.low.x, (inner_box.low.y + inner_box.high.y) / 2} - self.offset, 
			self,
			&core.typing_agent, 
			{text = text, font = painter.style.default_font, size = painter.style.default_font_size},
			{baseline = .Middle, clip = self.box},
			{},
			get_color(.Text),
		)
		if .Focused in self.state {
			offset_x_limit := max(width(text_res.bounds) - width(inner_box), 0)
			if .Pressed in self.state {
				left_over := self.box.low.x - input.mouse_point.x 
				if left_over > 0 {
					self.offset.x -= left_over * 0.2
					core.paint_next_frame = true
				}
				right_over := input.mouse_point.x - self.box.high.x
				if right_over > 0 {
					self.offset.x += right_over * 0.2
					core.paint_next_frame = true
				}
				self.offset.x = clamp(self.offset.x, 0, offset_x_limit)
			} else {
				if core.typing_agent.index < core.typing_agent.last_index {
					if text_res.selection_bounds.low.x < inner_box.low.x {
						self.offset.x = max(0, text_res.selection_bounds.low.x - text_res.bounds.low.x)
					}
				} else if core.typing_agent.index > core.typing_agent.last_index || core.typing_agent.length > core.typing_agent.last_length {
					if text_res.selection_bounds.high.x > inner_box.high.x {
						self.offset.x = min(offset_x_limit, (text_res.selection_bounds.high.x - text_res.bounds.low.x) - width(inner_box))
					}
				}
			}
			// What to do if change occoured
			if res.changed {
				self.state += {.Changed}
				core.paint_next_frame = true
				if value, ok := info.data.(^string); ok {
					delete(value^)
					value^ = strings.clone_from_bytes(buffer[:])
				}
			}
		}
		// Widget decoration
		if .Should_Paint in self.bits {
			paint_labeled_widget_frame(
				box = self.box, 
				text = info.title, 
				offset = WIDGET_PADDING,
				thickness = 1, 
				color = style_widget_stroke(self, hover_time),
			)
			// Draw placeholder
			if info.placeholder != nil {
				if len(buffer) == 0 {
					paint_text(
						{self.box.low.x + WIDGET_PADDING, center_y(self.box)}, 
						{font = painter.style.title_font, size = painter.style.title_font_size, text = info.placeholder.?}, 
						{baseline = .Middle}, 
						get_color(.Text, 0.5),
					)
				}
			}
		}
		// Whatever
		if .Lost_Focus in self.state {
			res.submitted = true
		}
		// Update hover
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
		// Only for content clipping of title (not very elegant)
		if info.title != nil {
			self.box.low.y -= 10
		}
	}
	return
}
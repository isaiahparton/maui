package maui
// Core dependencies
import "core:fmt"
import "core:runtime"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:unicode/utf8"
import "core:math"
import "core:math/linalg"
import "core:intrinsics"

Text_Edit_Result :: struct {
	using self: ^Widget,
	changed: bool,
}

// Edit a dynamic array of bytes or a string
// NOTE: Editing a string that was not allocated will segfault!
Text_Input_Data :: union {
	^[dynamic]u8,
	^string,
}

Text_Input_Info :: struct {
	data: Text_Input_Data,
	title: Maybe(string),
	placeholder: Maybe(string),
	multiline: bool,
}
Text_Input_Result :: struct {
	changed: bool,
}
do_text_input :: proc(info: Text_Input_Info, loc := #caller_location) -> (change: bool) {
	if self, ok := do_widget(hash(loc), {.Draggable, .Can_Key_Select}); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)
		// Animation values
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
		paint_rounded_box_fill(self.box, painter.style.widget_rounding, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), hover_time * 0.1))
		// Get data source
		text: string
		switch type in info.data {
			case ^string:
			text = type^
			case ^[dynamic]u8:
			text = string(type[:])
		}
		// Do text interaction
		interact_res := paint_interact_text(
			{self.box.low.x + WIDGET_TEXT_OFFSET, (self.box.low.y + self.box.high.y) / 2}, 
			self,
			&core.typing_agent, 
			{text = text, font = painter.style.default_font, size = painter.style.default_font_size},
			{baseline = .Middle, clip = self.box},
			{},
			get_color(.Text),
		)
		// Focused state
		if .Focused in self.state {
			change = typing_agent_edit(&core.typing_agent, {
				array = buffer,
				bits = {},
			})
			// What to do if change occoured
			if change {
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
			// Widget decor
			stroke_color := get_color(.Widget_Stroke, 1.0 if .Focused in self.state else (0.5 + 0.5 * hover_time))
			paint_labeled_widget_frame(
				box = self.box, 
				text = info.title, 
				offset = WIDGET_TEXT_OFFSET,
				thickness = 2, 
				color = stroke_color,
				)
			// Draw placeholder
			if info.placeholder != nil {
				if len(buffer) == 0 {
					paint_text(
						{self.box.low.x + WIDGET_TEXT_OFFSET, center_y(self.box)}, 
						{font = painter.style.title_font, size = painter.style.title_font_size, text = info.placeholder.?}, 
						{baseline = .Middle}, 
						get_color(.Text, 0.5),
						)
				}
			}
		}
		// Update hover before
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
		// Only for content clipping of title (not very elegant)
		if info.title != nil {
			self.box.low.y -= 10
		}
	}
	return
}

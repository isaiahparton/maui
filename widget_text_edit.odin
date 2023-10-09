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

// Edit a dynamic array of bytes
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
	chip_clicked: Maybe(int),
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
		paint_box_fill(self.box, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), hover_time * 0.1))
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
			{baseline = .Middle},
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
// Edit number values
Number_Input_Info :: struct($T: typeid) where intrinsics.type_is_numeric(T) {
	value: T,
	title,
	suffix,
	format: Maybe(string),
	text_align: Maybe([2]Alignment),
	trim_decimal,
	no_outline: bool,
}
do_number_input :: proc(info: Number_Input_Info($T), loc := #caller_location) -> (new_value: T) {
	new_value = info.value
	if self, ok := do_widget(hash(loc), {.Draggable, .Can_Key_Select}); ok {
		using self
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)
		// Animation values
		hover_time := animate_bool(&timers[0], .Hovered in state, 0.1)
		// Cursor style
		if state & {.Hovered, .Pressed} != {} {
			core.cursor = .Beam
		}
		// Has decimal?
		has_decimal := false 
		switch typeid_of(T) {
			case f16, f32, f64: has_decimal = true
		}
		// Formatting
		text := transmute([]u8)tmp_printf(info.format.? or_else "%v", info.value)
		if info.trim_decimal && has_decimal {
			text = transmute([]u8)trim_zeroes(string(text))
		}
		// Painting
		text_align := info.text_align.? or_else {
			.Near,
			.Middle,
		}
		paint_box_fill(box, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), hover_time * 0.05))
		if !info.no_outline {
			stroke_color := get_color(.Widget_Stroke) if .Focused in self.state else get_color(.Widget_Stroke, 0.5 + 0.5 * hover_time)
			paint_labeled_widget_frame(
				box = box, 
				text = info.title, 
				offset = WIDGET_TEXT_OFFSET, 
				thickness = 1, 
				color = stroke_color,
			)
		}
		select_result: Selectable_Text_Result

		// Update text input
		if state >= {.Focused} {
			buffer := typing_agent_get_buffer(&core.typing_agent, id)
			if state >= {.Got_Focus} {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			text_edit_bits: Text_Edit_Bits = {.Numeric, .Integer}
			switch typeid_of(T) {
				case f16, f32, f64: text_edit_bits -= {.Integer}
			}
			select_result = selectable_text(self, {
				font_data = font_data, 
				data = buffer[:], 
				box = box, 
				padding = {box.h * 0.25, box.h / 2 - font_data.size / 2},
				align = text_align,
			})
			if typing_agent_edit(&core.typing_agent, {
				array = buffer, 
				bits = text_edit_bits, 
				capacity = 18,
				select_result = select_result,
			}) {
				core.paint_next_frame = true
				str := string(buffer[:])
				switch typeid_of(T) {
					case f64, f32, f16:  		
					new_value = T(strconv.parse_f64(str) or_else 0)
					case int, i128, i64, i32, i16, i8: 
					new_value = T(strconv.parse_i128(str) or_else 0)
					case u128, u64, u32, u16, u8:
					new_value = T(strconv.parse_u128(str) or_else 0)
				}
				state += {.Changed}
			}
		} else {
			select_result = selectable_text(self, {
				font_data = font_data, 
				data = text, 
				box = box, 
				padding = {box.h * 0.25, box.h / 2 - font_data.size / 2},
				align = text_align,
			})
		}

		if suffix, ok := info.suffix.?; ok {
			paint_string(font_data, suffix, {box.x + box.h * 0.25, box.y + box.h / 2} + select_result.view_offset + {select_result.text_size.x, 0}, get_color(.Text, 0.5), {
				align = {.Near, .Middle},
				clip_box = box,
			})
		}
	}
	return
}

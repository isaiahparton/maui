package maui
import "core:time"
import "core:math/linalg"
import "core:strings"
import "core:strconv"

Date_Picker_Info :: struct {
	using generic: Generic_Widget_Info,
	value,
	temp_value: ^time.Time,
	title: Maybe(string),
}
Date_Picker_Result :: struct {
	using generic: Generic_Widget_Result,
	changed: bool,
}
date_picker :: proc(ui: ^UI, info: Date_Picker_Info, loc := #caller_location) -> Date_Picker_Result {
	self, generic_result := get_widget(ui, info, loc)
	result: Date_Picker_Result = {
		generic = generic_result,
	}
	// Colocate
	box := info.box.? or_else next_box(ui)
	// Animate
	if self.variant == nil {
		self.variant = Menu_Widget_Variant{}
	}
	data := &self.variant.(Menu_Widget_Variant)
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.open_time = animate(ui, data.open_time, 0.1, data.is_open)
	// Date 
	year, month, day := time.date(info.value^)
	buffer := get_scribe_buffer(&ui.scribe, self.id)
	text_input_result := text_input(ui, {
		data = buffer, 
		placeholder = "DD/MM/YYYY",
		box = box,
	})
	if text_input_result.changed {
		if len(buffer) > 0 {
			values, _ := strings.split(string(buffer[:]), "/")
			defer delete(values)
			if len(values) == 3 {
				new_day := int(strconv.parse_uint(values[0]) or_else 1)
				new_month := int(clamp(strconv.parse_uint(values[1]) or_else 1, 1, 12))
				new_year := int(max(strconv.parse_uint(values[2]) or_else 0, 1970))
				info.value^ = time.datetime_to_time(new_year, new_month, new_day, 0, 0, 0) or_else info.value^
				info.temp_value^ = info.value^
			}
		}
	}
	if was_clicked(button(ui, {
		box = get_box_right(box, height(box)),
		corners = {.Top_Right, .Bottom_Right},
		font = ui.style.font.icon,
		text = "\uf783",
	})) {
		data.is_open = true
	}	
	// Activate!
	if data.is_open {
		size: [2]f32 = {370, 280}
		side: Box_Side = .Bottom
		OFFSET :: 10
		// Find optimal side of attachment
		box := get_attached_box(self.box, side, size, OFFSET * data.open_time)
		box.low = linalg.clamp(box.low, 0, ui.size - size)
		box.high = box.low + size
		// Layer
		if layer, ok := do_layer(ui, {
			placement = box,
			order = .Background,
			options = {.Attached},
		}); ok {
			// Fill
			paint_rounded_box_fill(ui.painter, layer.box, ui.style.rounding, ui.style.color.foreground[1])
			paint_rounded_box_corners_fill(ui.painter, get_box_bottom(layer.box, 6), ui.style.rounding, {.Bottom_Left, .Bottom_Right}, ui.style.color.accent)
			cut(ui, .Bottom, 6)
			// Stuff
			shrink(ui, 10)
			// Action buttons
			push_dividing_layout(ui, cut(ui, .Bottom, 30))
				ui.placement.side = .Right; ui.placement.size = 70
				if was_clicked(button(ui, {text = "Cancel", corners = ALL_CORNERS})) {
					info.temp_value^ = info.value^
					data.is_open = false
				}
				space(ui, 10)
				if was_clicked(button(ui, {text = "Save", corners = ALL_CORNERS})) {
					info.value^ = info.temp_value^
					data.is_open = false
					result.changed = true
				}
				ui.placement.side = .Left;
				if was_clicked(button(ui, {text = "Today", corners = ALL_CORNERS})) {
					info.temp_value^ = time.now()
				}
			pop_layout(ui)
			// Display a calendar
			new_value := calendar(ui, info.temp_value^)
			if info.temp_value^ != new_value {
				info.temp_value^ = new_value
				_year, _month, _day := time.date(new_value)
				text := tmp_printf("%2i/%2i/%4i", _day, _month, _year)
				clear(buffer)
				append_string(buffer, text)
			}
		}
	}
	// Hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// Click
	if was_clicked(result) {
		data.is_open = !data.is_open
		if data.is_open {
			info.temp_value^ = info.value^
		}
	}
	return result
}
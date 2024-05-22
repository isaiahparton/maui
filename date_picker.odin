package maui
import "core:time"
import "core:math/linalg"
import "core:math/ease"
import "core:strings"
import "core:strconv"

Date_Picker_Info :: struct {
	using generic: Generic_Widget_Info,
	value: time.Time,
	title: Maybe(string),
}
Date_Picker_Result :: struct {
	using generic: Generic_Widget_Result,
	new_value: Maybe(time.Time),
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
	data.open_time = animate(ui, data.open_time, 0.2, data.is_open)
	// Date 
	year, month, day := time.date(info.value)
	buffer := get_scribe_buffer(&ui.scribe, self.id)
	if len(buffer) == 0 {
		_year, _month, _day := time.date(info.value)
		text := tmp_printf("%2i/%2i/%4i", _day, _month, _year)
		clear(buffer)
		append_string(buffer, text)
	}
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
				result.new_value = time.datetime_to_time(new_year, new_month, new_day + 1, 0, 0, 0) or_else info.value
			}
		}
	}
	button_result := button(ui, {
		box = get_box_right(box, height(box)),
		corners = {.Top_Right, .Bottom_Right},
		font = ui.style.font.icon,
		text = "\uf783",
	})
	if was_clicked(button_result) {
		data.is_open = true
	}	
	// Activate!
	if data.is_open {
		size: [2]f32 = {370, 245}
		side: Box_Side = .Top
		// Find optimal side of attachment
		n := 5 * ease.quadratic_out(data.open_time)
		box := get_attached_box(box, side, size, n)
		box.low = linalg.clamp(box.low, 0, ui.size - size)
		box.high = box.low + size
		// Layer
		if layer, ok := do_layer(ui, {
			placement = box,
			order = .Background,
			options = {.Attached},
		}); ok {
			cut(ui, .Bottom, 7)
			// Fill
			paint_rounded_box_fill(ui.painter, ui.layouts.current.box, ui.style.rounding, ui.style.color.foreground[1])
			paint_rounded_box_stroke(ui.painter, ui.layouts.current.box, ui.style.rounding, 1, ui.style.color.substance)
			p: [2]f32 = {center_x(ui.layouts.current.box), ui.layouts.current.box.high.y}
			paint_triangle_fill(ui.painter, {p.x - 10, p.y}, {p.x, p.y + n}, {p.x + 10, p.y}, ui.style.color.foreground[1])
			paint_triangle_stroke(ui.painter, {p.x - 10, p.y}, {p.x, p.y + n}, {p.x + 10, p.y}, 1, ui.style.color.substance)
			paint_box_fill(ui.painter, {{p.x - 10, p.y - 1}, {p.x + 10, p.y}}, ui.style.color.foreground[1])
			// Stuff
			shrink(ui, 10)
			// Display a calendar
			if new_value := calendar(ui, info.value); new_value != info.value {
				result.new_value = new_value
				_year, _month, _day := time.date(new_value)
				text := tmp_printf("%2i/%2i/%4i", _day, _month, _year)
				clear(buffer)
				append_string(buffer, text)
			}

			if ui.widgets.focus_id != text_input_result.self.?.id && ui.widgets.focus_id != button_result.self.?.id && .Focused not_in (layer.last_state + layer.state) {
				data.is_open = false
			}
		}
	}
	// Hover
	update_widget_hover(ui, self, point_in_box(ui.io.mouse_point, self.box))
	// Click
	if was_clicked(result) {
		data.is_open = !data.is_open
		if data.is_open {
			result.new_value = info.value
		}
	}
	return result
}
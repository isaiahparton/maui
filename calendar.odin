package maui

import "../"

import "core:time"
import "core:math/linalg"

CALENDAR_WIDTH :: 440
CALENDAR_HEIGHT :: 250

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
	self.box = info.box.? or_else layout_next(current_layout(ui))
	// Update
	update_widget(ui, self)
	// Animate
	if self.variant == nil {
		self.variant = Menu_Widget_Variant{}
	}
	data := &self.variant.(Menu_Widget_Variant)
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	data.open_time = animate(ui, data.open_time, 0.1, data.is_open)
	// Date 
	year, month, day := time.date(info.value^)
	// Paint (kinda rhymes)
	if .Should_Paint in self.bits {
		paint_box_fill(ui.painter, self.box, ui.style.color.substance)
	}
	// Activate!
	if data.is_open {
		size: [2]f32 = {440, 260}
		side: Box_Side = .Bottom
		OFFSET :: 10
		// Find optimal side of attachment
		if self.box.low.x < size.x + OFFSET {
			side = .Right 
		} else if self.box.high.x + size.x + OFFSET >= ui.size.x {
			side = .Left
		} else if self.box.high.y + size.y + OFFSET >= ui.size.y {
			side = .Top
		}
		box := get_attached_box(self.box, side, size, OFFSET * data.open_time)
		box.low = linalg.clamp(box.low, 0, ui.size - size)
		box.high = box.low + size
		// Layer
		if layer, ok := do_layer(ui, {
			placement = box,
			order = .Background,
			options = {.Attached},
		}); ok {
			// Temporary state
			year, month, day := time.date(info.temp_value^)
			// Fill
			paint_box_fill(ui.painter, layer.box, ui.style.color.background[0])
			// Stuff
			shrink(ui, 10)
			ui.layouts.current.direction = .Down
			// Main options
			if _, ok := do_layout(ui, cut(ui, .Up, 30)); ok {
				ui.layouts.current.direction = .Left; ui.layouts.current.size = 70
				if was_clicked(button(ui, {text = "Cancel"})) {
					info.temp_value^ = info.value^
					data.is_open = false
				}
				space(ui, 10)
				if was_clicked(button(ui, {text = "Save"})) {
					info.value^ = info.temp_value^
					data.is_open = false
					result.changed = true
				}
				ui.layouts.current.direction = .Right;
				if was_clicked(button(ui, {text = "Today"})) {
					info.temp_value^ = time.now()
				}
			}
			// Combo boxes
			if _, ok := do_layout(ui, cut(ui, .Down, 20)); ok {
				ui.layouts.current.direction = .Right; ui.layouts.current.size = 135; ui.layouts.current.align = {.Middle, .Middle}
				month_days := int(time.days_before[int(month)])
				if int(month) > 0 {
					month_days -= int(time.days_before[int(month) - 1])
				}
				if _, ok := menu(ui, {text = tmp_print(day)}); ok {
					ui.layouts.current.size = 20
					for i in 1..=month_days {
						push_id(ui, i)
							if was_clicked(option(ui, {text = tmp_print(i)})) {
								day = i
								info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
							}
						pop_id(ui)
					}
				}
				space(ui, 10)
				if _, ok := menu(ui, {text = tmp_print(month)}); ok {
					ui.layouts.current.size = 20
					for member in time.Month {
						push_id(ui, int(member))
							if was_clicked(option(ui, {text = tmp_print(member)})) {
								month = member
								info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
							}
						pop_id(ui)
					}
				}
				space(ui, 10)
				if _, ok := menu(ui, {text = tmp_print(year)}); ok {
					ui.layouts.current.size = 20
					low := max(year - 4, 1970)
					for i in low..=(low + 8) {
						push_id(ui, i)
							if was_clicked(option(ui, {text = tmp_print(i)})) {
								year = i
								info.temp_value^, _ = time.datetime_to_time(i, int(month), day, 0, 0, 0, 0)
							}
						pop_id(ui)
					}
				}
			}
			space(ui, 10)
			// Skip buttons
			if _, ok := do_layout(ui, cut(ui, .Down, 20)); ok {
				ui.layouts.current.direction = .Right; ui.layouts.current.size = 70
				// Subtract one year
				if was_clicked(button(ui, {text = "<<<"})) {
					year -= 1
					info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
				}
				// Subtract one month
				if was_clicked(button(ui, {text = "<<"})) {
					month = time.Month(int(month) - 1)
					if int(month) <= 0 {
						month = time.Month(12)
						year -= 1
					}
					info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
				}
				// Subtract one day
				if was_clicked(button(ui, {text = "<"})) {
					info.temp_value^._nsec -= i64(time.Hour * 24)
					year, month, day = time.date(info.temp_value^)
				}
				// Add one day
				if was_clicked(button(ui, {text = ">"})) {
					info.temp_value^._nsec += i64(time.Hour * 24)
					year, month, day = time.date(info.temp_value^)
				}
				// Add one month
				if was_clicked(button(ui, {text = ">>"})) {
					month = time.Month(int(month) + 1)
					if int(month) >= 13 {
						month = time.Month(1)
						year += 1
					}
					info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
				}
				// Add one year
				if was_clicked(button(ui, {text = ">>>"})) {
					year += 1
					info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
				}
			}
			space(ui, 10)
			// Weekdays
			if _, ok := do_layout(ui, cut(ui, .Down, 20)); ok {
				ui.layouts.current.direction = .Right; ui.layouts.current.size = 60; ui.layouts.current.align = {.Middle, .Middle}
				for day in ([]string)({"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}) {
					text_box(ui, {
						text_info = Text_Info{
							text = day, 
							align = .Middle, 
							baseline = .Middle,
						},
					})
				}
			}
			WEEK_DURATION :: i64(time.Hour * 24 * 7)
			OFFSET :: i64(time.Hour * 72)
			t, _ := time.datetime_to_time(year, int(month), 0, 0, 0, 0, 0)
			day_time := (t._nsec / WEEK_DURATION) * WEEK_DURATION - OFFSET
			if _, ok := do_layout(ui, cut(ui, .Down, 20)); ok {
				ui.layouts.current.direction = .Right; ui.layouts.current.size = 60
				for i in 0..<42 {
					if (i > 0) && (i % 7 == 0) {
						pop_layout(ui)
						push_layout(ui, cut(ui, .Down, 20))
						ui.layouts.current.direction = .Right
						ui.layouts.current.size = 60
					}
					_, _month, _day := time.date(transmute(time.Time)day_time)
					push_id(ui, i)
						if was_clicked(button(ui, {text = tmp_print(_day), color = ui.style.color.substance if (_month == month && _day == day) else (ui.style.color.accent if time.month(transmute(time.Time)day_time) != month else nil)})) {
							info.temp_value^ = transmute(time.Time)day_time
						}
					pop_id(ui)
					day_time += i64(time.Hour * 24)
				}
			}
			// Stroke
			paint_rounded_box_stroke(ui.painter, layer.box, ui.style.rounding, 1, ui.style.color.stroke[0])
			// Clamp value
			info.temp_value._nsec = max(info.temp_value._nsec, 0)
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
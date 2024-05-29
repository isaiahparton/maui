package maui

/*import "../"

import "core:time"
import "core:math/linalg"

CALENDAR_WIDTH :: 440
CALENDAR_HEIGHT :: 250

calendar :: proc(ui: ^UI, value: time.Time, loc := #caller_location) -> (new_value: time.Time) {
	push_id(ui, hash(ui, loc))
	defer pop_id(ui)
	new_value = value
	// Temporary state
	year, month, day := time.date(value)
	ui.placement.side = .Top
	// Combo boxes
	push_dividing_layout(ui, cut(ui, .Top, 20))
		ui.placement.side = .Left; ui.placement.align = {.Middle, .Middle}
		month_days := int(time.days_before[int(month)])
		if int(month) > 0 {
			month_days -= int(time.days_before[int(month) - 1])
		}
		ui.placement.size = 95
		{	
			result: Generic_Widget_Result
			ok: bool
			if result, ok = menu(ui, {
				text = tmp_print(day),
				height = 160,
			}); ok {
				ui.placement.size = 20
				for i in 1..=month_days {
					push_id(ui, i)
						if was_clicked(option(ui, {text = tmp_print(i)})) {
							day = i
							new_value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
						}
					pop_id(ui)
				}
			}
			if was_clicked(button(ui, {
				text = "<", 
				type = .Filled,
				box = get_box_left(result.self.?.box, height(result.self.?.box)),
			})) {
				new_value._nsec -= i64(time.Hour * 24)
				year, month, day = time.date(new_value)
			}
			paint_box_fill(ui.painter, get_box_bottom(ui.last_box, 1), ui.style.color.substance)
			if was_clicked(button(ui, {
				text = ">", 
				type = .Filled,
				box = get_box_right(result.self.?.box, height(result.self.?.box)),
			})) {
				new_value._nsec += i64(time.Hour * 24)
				year, month, day = time.date(new_value)
			}
			paint_box_fill(ui.painter, get_box_bottom(ui.last_box, 1), ui.style.color.substance)
		}
		ui.placement.size = 140
		space(ui, 10)
		{
			result: Generic_Widget_Result
			ok: bool
			if result, ok = menu(ui, {
				text = tmp_print(month),
				height = 160,
			}); ok {
				ui.placement.size = 20
				for member in time.Month {
					push_id(ui, int(member))
						if was_clicked(option(ui, {text = tmp_print(member)})) {
							month = member
							new_value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
						}
					pop_id(ui)
				}
			}
			if was_clicked(button(ui, {
				text = "<", 
				type = .Filled,
				box = get_box_left(result.self.?.box, height(result.self.?.box)),
			})) {
				month = time.Month(int(month) - 1)
				if int(month) <= 0 {
					month = time.Month(12)
					year -= 1
				}
				new_value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
			}
			paint_box_fill(ui.painter, get_box_bottom(ui.last_box, 1), ui.style.color.substance)
			if was_clicked(button(ui, {
				text = ">", 
				type = .Filled,
				box = get_box_right(result.self.?.box, height(result.self.?.box)),
			})) {
				month = time.Month(int(month) + 1)
				if int(month) >= 13 {
					month = time.Month(1)
					year += 1
				}
				new_value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
			}
			paint_box_fill(ui.painter, get_box_bottom(ui.last_box, 1), ui.style.color.substance)
		}
		ui.placement.size = 95
		space(ui, 10)
		{
			result: Generic_Widget_Result
			ok: bool
			if result, ok = menu(ui, {
				text = tmp_print(year),
				height = 160,
			}); ok {
				ui.placement.size = 20
				low := max(year - 4, 1970)
				for i in low..=(low + 8) {
					push_id(ui, i)
						if was_clicked(option(ui, {text = tmp_print(i)})) {
							year = i
							new_value, _ = time.datetime_to_time(i, int(month), day, 0, 0, 0, 0)
						}
					pop_id(ui)
				}
			}
			if was_clicked(button(ui, {
				text = "<", 
				type = .Filled,
				box = get_box_left(result.self.?.box, height(result.self.?.box)),
			})) {
				year -= 1
				new_value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
			}
			paint_box_fill(ui.painter, get_box_bottom(ui.last_box, 1), ui.style.color.substance)
			if was_clicked(button(ui, {
				text = ">", 
				type = .Filled,
				box = get_box_right(result.self.?.box, height(result.self.?.box)),
			})) {
				year += 1
				new_value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
			}
			paint_box_fill(ui.painter, get_box_bottom(ui.last_box, 1), ui.style.color.substance)
		}
	pop_layout(ui)
	space(ui, 10)
	DAY_WIDTH :: 50
	DAY_HEIGHT :: 26
	// Weekdays
	push_dividing_layout(ui, cut(ui, .Top, 20))
		ui.placement.side = .Left; ui.placement.size = DAY_WIDTH; ui.placement.align = {.Middle, .Middle}
		for day in ([]string)({"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}) {
			text_box(ui, {
				text_info = Text_Info{
					text = day, 
					align = .Middle, 
					baseline = .Middle,
					font = ui.style.font.label,
					size = ui.style.text_size.label,
				},
			})
		}
	pop_layout(ui)
	space(ui, 10)
	WEEK_DURATION :: i64(time.Hour * 24 * 7)
	OFFSET: i64 : i64(time.Hour) * -96
	t, _ := time.datetime_to_time(year, int(month), 0, 0, 0, 0, 0)
	day_time := ((t._nsec + i64(time.Hour * 48)) / WEEK_DURATION) * WEEK_DURATION + OFFSET
	push_dividing_layout(ui, cut(ui, .Top, DAY_HEIGHT))
		ui.placement.side = .Left; ui.placement.size = DAY_WIDTH
		for i in 0..<42 {
			if (i > 0) && (i % 7 == 0) {
				pop_layout(ui)
				push_dividing_layout(ui, cut(ui, .Top, DAY_HEIGHT))
				ui.placement.side = .Left
				ui.placement.size = DAY_WIDTH
			}
			_, _month, _day := time.date(transmute(time.Time)day_time)
			push_id(ui, i)
				if was_clicked(button(ui, {
					text = tmp_print(_day), 
					type = .Subtle if time.month(transmute(time.Time)day_time) != month else .Filled,
					highlight = ui.style.color.accent if (_month == month && _day == day) else nil,
				})) {
					new_value = transmute(time.Time)day_time
				}
			pop_id(ui)
			day_time += i64(time.Hour * 24)
		}
	pop_layout(ui)
	// Clamp value
	new_value._nsec = max(new_value._nsec, 0)
	return
}*/
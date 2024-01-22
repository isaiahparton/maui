package maui
/*import "core:time"
import "core:math/linalg"

CALENDAR_WIDTH :: 440
CALENDAR_HEIGHT :: 250

Date_Picker_Info :: struct {
	using generic: Generic_Widget_Info,
	value: time.Time,
	title: Maybe(string),
}
Date_Picker_Result :: struct {
	using generic: Generic_Widget_Result,
	value: time.Time,
	changed: bool,
}
Date_Picker_Widget_Variant :: struct {
	using button: Button_Widget_Variant,
	value: time.Time,
	is_open: bool,
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
	// Variant
	if self.variant == nil {
		self.variant = Date_Picker_Widget_Variant{}
	}
	data := &self.variant.(Date_Picker_Widget_Variant)
	// Animate
	data.hover_time = animate(ui, data.hover_time, DEFAULT_WIDGET_HOVER_TIME, .Hovered in self.state)
	// Date 
	year, month, day := time.date(info.value)
	// Paint (kinda rhymes)
	if .Should_Paint in self.bits {
		paint_text(ui.painter, center(self.box), {
			text = tmp_printf("%2i/%2i/%4i", day, int(month), year), 
			size = ui.style.text_size.label,
			font = ui.style.font.label,
		}, ui.style.color.text[0])
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
		box := get_attached_box(self.box, side, size, OFFSET)
		box.low = linalg.clamp(box.low, 0, ui.size - size)
		box.high = box.low + size
		// Layer
		if layer, ok := do_layer(ui, {
			placement = box,
			order = .Background,
			options = {.Attached},
		}); ok {
			// Temporary state
			year, month, day := time.date(data.value)
			// Fill
			paint_box_fill(ui.painter, layer.box, ui.style.color.foreground[0])
			// Stuff
			shrink(ui, 10)
			ui.layouts.current.direction = .Down
			// Main options
			if _, ok := do_layout(ui, cut(ui, .Down, 30)); ok {
				ui.layouts.current.direction = .Left; ui.layouts.current.size = 70
				if was_clicked(button(ui, {text = "Cancel"})) {
					data.value = info.value
					data.is_open = false
				}
				space(ui, 10)
				if was_clicked(button(ui, {text = "Save"})) {
					result.value = data.value
					result.changed = true
					data.is_open = false
				}
				ui.layouts.current.direction = .Right;
				if was_clicked(button(ui, {text = "Today"})) {
					data.value = time.now()
				}
			}
			// Combo boxes
			if _, ok := do_layout(ui, cut(ui, .Down, 30)); ok {
				ui.layouts.current.direction = .Right; ui.layouts.current.size = 135; ui.layouts.current.align = {.Middle, .Middle}
				month_days := int(time.days_before[int(month)])
				if int(month) > 0 {
					month_days -= int(time.days_before[int(month) - 1])
				}
				if menu({text = tmp_print(day), size = {0, 120}}) {
					ui.layouts.current.size = 20
					for i in 1..=month_days {
						push_id(i)
							if do_option({text = tmp_print(i)}) {
								day = i
								data.value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
							}
						pop_id()
					}
				}
				space(10)
				if do_menu({text = tmp_print(month), size = {0, 120}}) {
					ui.layouts.current.size = 20
					for member in time.Month {
						push_id(int(member))
							if do_option({text = tmp_print(member)}) {
								month = member
								data.value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
							}
						pop_id()
					}
				}
				space(10)
				if do_menu({text = tmp_print(year), size = {0, 120}}) {
					ui.layouts.current.size = 20
					low := max(year - 4, 1970)
					for i in low..=(low + 8) {
						push_id(i)
							if do_option({text = tmp_print(i)}) {
								year = i
								data.value, _ = time.datetime_to_time(i, int(month), day, 0, 0, 0, 0)
							}
						pop_id()
					}
				}
			}
			space(10)
			// Skip buttons
			if do_layout(.Top, 20) {
				ui.layouts.current.side = .Left; ui.layouts.current.size = 70
				// Subtract one year
				if button({text = "<<<", style = .Filled}) {
					year -= 1
					data.value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
				}
				// Subtract one month
				if button({text = "<<", style = .Filled}) {
					month = time.Month(int(month) - 1)
					if int(month) <= 0 {
						month = time.Month(12)
						year -= 1
					}
					data.value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
				}
				// Subtract one day
				if button({text = "<", style = .Filled}) {
					data.value._nsec -= i64(time.Hour * 24)
					year, month, day = time.date(data.value)
				}
				// Add one day
				if button({text = ">", style = .Filled}) {
					data.value._nsec += i64(time.Hour * 24)
					year, month, day = time.date(data.value)
				}
				// Add one month
				if button({text = ">>", style = .Filled}) {
					month = time.Month(int(month) + 1)
					if int(month) >= 13 {
						month = time.Month(1)
						year += 1
					}
					data.value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
				}
				// Add one year
				if button({text = ">>>", style = .Filled}) {
					year += 1
					data.value, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
				}
			}
			space(10)
			// Weekdays
			if do_layout(.Top, 20) {
				ui.layouts.current.side = .Left; ui.layouts.current.size = 60; ui.layouts.current.align = {.Middle, .Middle}
				for day in ([]string)({"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}) {
					do_text({text = day, align = .Middle, baseline = .Middle})
				}
			}
			WEEK_DURATION :: i64(time.Hour * 24 * 7)
			OFFSET :: i64(time.Hour * 72)
			t, _ := time.datetime_to_time(year, int(month), 0, 0, 0, 0, 0)
			day_time := (t._nsec / WEEK_DURATION) * WEEK_DURATION - OFFSET
			if do_layout(.Top, 20) {
				ui.layouts.current.side = .Left; ui.layouts.current.size = 60
				for i in 0..<42 {
					if (i > 0) && (i % 7 == 0) {
						pop_layout()
						push_layout(cut(.Top, 20))
						ui.layouts.current.side = .Left
						ui.layouts.current.size = 60
					}
					_, _month, _day := time.date(transmute(time.Time)day_time)
					push_id(i)
						if button({text = tmp_print(_day), style = .Filled, color = get_color(.Accent) if (_month == month && _day == day) else (get_color(.Button_Base, 0.5) if time.month(transmute(time.Time)day_time) != month else nil)}) {
							data.value = transmute(time.Time)day_time
						}
					pop_id()
					day_time += i64(time.Hour * 24)
				}
			}
			// Stroke
			paint_rounded_box_stroke(layer.box, WINDOW_ROUNDNESS, 1, get_color(.Widget_Stroke_Focused))
			// Clamp value
			info.temp_value._nsec = max(info.temp_value._nsec, 0)
		}
	}
	// Hover
	update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	// Click
	if widget_clicked(self, .Left) {
		self.bits ~= {.Active}
		if self.bits >= {.Active} {
			data.value = info.value
		}
	}
	return
}*/
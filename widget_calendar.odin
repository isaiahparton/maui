package maui

import "core:time"

CALENDAR_WIDTH :: 440
CALENDAR_HEIGHT :: 250

Date_Picker_Info :: struct {
	value,
	temp_value: ^time.Time,
}
do_date_picker :: proc(info: Date_Picker_Info, loc := #caller_location) -> (changed: bool) {
	if self, ok := do_widget(hash(loc)); ok {
		self.box = layout_next(current_layout())
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
		update_widget(self)

		year, month, day := time.date(info.value^)
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1))
			paint_box_stroke(self.box, 1, get_color(.Widget_Stroke, 0.5 + 0.5 * hover_time))
			paint_label_box(tmp_print("%2i-%2i-%4i", day, int(month), year), shrink_box(self.box, [2]f32{height(self.box) * 0.25, 0}), get_color(.Button_Base), .Left, .Middle)
			paint_aligned_icon(painter.style.default_font, painter.style.default_font_size, .Calendar, center(self.box), get_color(.Button_Base), {.Middle, .Middle})
		}

		if .Active in self.bits {
			box: Box = {low = {width(self.box) * 0.5 - CALENDAR_WIDTH * 0.5, self.box.high.y}}
			if layer, ok := do_layer({
				box = box,
				order = .Background,
				options = {.Attached},
				shadow = Layer_Shadow_Info({
					roundness = WINDOW_ROUNDNESS,
					offset = SHADOW_OFFSET,
				}),
			}); ok {

				// Temporary state
				year, month, day := time.date(info.temp_value^)

				// Fill
				paint_rounded_box_fill(layer.box, WINDOW_ROUNDNESS, get_color(.Widget_Back))
				shrink(10)
				if do_layout(.Top, Exact(20)) {
					placement.side = .Left; placement.size = Exact(135); placement.align = {.Middle, .Middle}
					month_days := int(time.days_before[int(month)])
					if int(month) > 0 {
						month_days -= int(time.days_before[int(month) - 1])
					}
					placement.size = Exact(20)
					if do_menu({label = tmp_print(day), size = {0, 120}, layout_size = ([2]f32){0, f32(month_days) * 20}}) {
						for i in 1..=month_days {
							push_id(i)
								if do_option({label = tmp_print(i)}) {
									day = i
									info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
								}
							pop_id()
						}
					}
					space(Exact(10))
					if do_menu({label = tmp_print(month), size = {0, 120}, layout_size = ([2]f32){0, 240}}) {
						for member in time.Month {
							push_id(int(member))
								if do_option({label = tmp_print(member)}) {
									month = member
									info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
								}
							pop_id()
						}
					}
					space(Exact(10))
					if do_menu({label = tmp_print(year), size = {0, 120}, layout_size = ([2]f32){0, 180}}) {
						low := max(year - 4, 1970)
						for i in low..=(low + 8) {
							push_id(i)
								if do_option({label = tmp_print(i)}) {
									year = i
									info.temp_value^, _ = time.datetime_to_time(i, int(month), day, 0, 0, 0, 0)
								}
							pop_id()
						}
					}
				}
				space(Exact(10))
				if do_layout(.Top, Exact(20)) {
					placement.side = .Left; placement.size = Exact(70)
					// Subtract one year
					if do_button({label = "<<<", style = .Filled}) {
						year -= 1
						info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
					}
					// Subtract one month
					if do_button({label = "<<", style = .Filled}) {
						month = time.Month(int(month) - 1)
						if int(month) <= 0 {
							month = time.Month(12)
							year -= 1
						}
						info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
					}
					// Subtract one day
					if do_button({label = "<", style = .Filled}) {
						info.temp_value^._nsec -= i64(time.Hour * 24)
						year, month, day = time.date(info.temp_value^)
					}
					// Add one day
					if do_button({label = ">", style = .Filled}) {
						info.temp_value^._nsec += i64(time.Hour * 24)
						year, month, day = time.date(info.temp_value^)
					}
					// Add one month
					if do_button({label = ">>", style = .Filled}) {
						month = time.Month(int(month) + 1)
						if int(month) >= 13 {
							month = time.Month(1)
							year += 1
						}
						info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
					}
					// Add one year
					if do_button({label = ">>>", style = .Filled}) {
						year += 1
						info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
					}
				}
				if do_layout(.Top, Exact(20)) {
					placement.side = .Left; placement.size = Exact(60); placement.align = {.Middle, .Middle}
					for day in ([]string)({"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}) {
						//do_text({text = day})
					}
				}
				WEEK_DURATION :: i64(time.Hour * 24 * 7)
				OFFSET :: i64(time.Hour * 72)
				t, _ := time.datetime_to_time(year, int(month), 0, 0, 0, 0, 0)
				day_time := (t._nsec / WEEK_DURATION) * WEEK_DURATION - OFFSET
				if do_layout(.Top, Exact(20)) {
					placement.side = .Left; placement.size = Exact(60)
					for i in 0..<42 {
						if (i > 0) && (i % 7 == 0) {
							pop_layout()
							push_layout(cut(.Top, Exact(20)))
							placement.side = .Left
						}
						_, _month, _day := time.date(transmute(time.Time)day_time)
						push_id(i)
							if do_button({label = tmp_print(_day), style = .Filled if (_month == month && _day == day) else .Outlined, color = get_color(.Button_Base, 0.5) if time.month(transmute(time.Time)day_time) != month else nil}) {
								info.temp_value^ = transmute(time.Time)day_time
							}
						pop_id()
						day_time += i64(time.Hour * 24)
					}
				}
				if do_layout(.Bottom, Exact(30)) {
					placement.side = .Right; placement.size = Exact(60)
					if do_button({label = "Cancel", style = .Outlined}) {
						info.temp_value^ = info.value^
						self.bits -= {.Active}
					}
					space(Exact(10))
					if do_button({label = "Save"}) {
						info.value^ = info.temp_value^
						self.bits -= {.Active}
						changed = true
					}
					placement.side = .Left;
					if do_button({label = "Today", style = .Outlined}) {
						info.temp_value^ = time.now()
					}
				}
				// Stroke
				paint_rounded_box_stroke(layer.box, WINDOW_ROUNDNESS, 1, get_color(.Base_Stroke))

				info.temp_value._nsec = max(info.temp_value._nsec, 0)
			}
		}

		if widget_clicked(self, .Left) {
			self.bits ~= {.Active}
			if self.bits >= {.Active} {
				info.temp_value^ = info.value^
			}
		}
	}
	return
}
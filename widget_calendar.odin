package maui

import "core:time"

CALENDAR_WIDTH :: 440
CALENDAR_HEIGHT :: 250

Date_Picker_Info :: struct {
	value,
	temp_value: ^time.Time,
}
do_date_picker :: proc(info: Date_Picker_Info, loc := #caller_location) -> (changed: bool) {
	if self, ok := do_widget(hash(loc), layout_next(current_layout()), {}); ok {

		hover_time := animate_bool(self.id, .hovered in self.state, 0.1)

		year, month, day := time.date(info.value^)
		if .should_paint in self.bits {
			paint_box_fill(self.box, alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), 0.2 if .pressed in self.state else hover_time * 0.1))
			paint_box_stroke(self.box, 1, get_color(.widget_stroke, 0.5 + 0.5 * hover_time))
			paint_label_box(text_format("%2i-%2i-%4i", day, int(month), year), shrink_box_separate(self.box, {self.box.h * 0.25, 0}), get_color(.button_base), {.near, .middle})
			paint_aligned_icon(get_font_data(.default), .Calendar, {self.box.x + self.box.w - self.box.h / 2, self.box.y + self.box.h / 2}, 1, get_color(.button_base), {.middle, .middle})
		}

		if .active in self.bits {
			box: Box = {0, 0, CALENDAR_WIDTH, CALENDAR_HEIGHT}
			box.x = self.box.x + self.box.w / 2 - box.w / 2
			box.y = self.box.y + self.box.h
			if layer, ok := do_layer({
				box = box,
				order = .background,
				options = {.attached},
				shadow = Layer_Shadow_Info({
					roundness = WINDOW_ROUNDNESS,
					offset = SHADOW_OFFSET,
				}),
			}); ok {

				// Temporary state
				year, month, day := time.date(info.temp_value^)

				// Fill
				paint_rounded_box_fill(layer.box, WINDOW_ROUNDNESS, get_color(.widget_bg))
				shrink(10)
				if do_layout(.top, 20) {
					set_side(.left); set_size(135); set_align(.middle)
					month_days := int(time.days_before[int(month)])
					if int(month) > 0 {
						month_days -= int(time.days_before[int(month) - 1])
					}
					if do_menu({label = format(day), size = {0, 120}, layout_size = ([2]f32){0, f32(month_days) * 20}}) {
						set_size(20)
						for i in 1..=month_days {
							push_id(i)
								if do_option({label = format(i)}) {
									day = i
									info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
								}
							pop_id()
						}
					}
					space(10)
					if do_menu({label = format(month), size = {0, 120}, layout_size = ([2]f32){0, 240}}) {
						set_size(20)
						for member in time.Month {
							push_id(int(member))
								if do_option({label = format(member)}) {
									month = member
									info.temp_value^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
								}
							pop_id()
						}
					}
					space(10)
					if do_menu({label = format(year), size = {0, 120}, layout_size = ([2]f32){0, 180}}) {
						set_size(20)
						low := max(year - 4, 1970)
						for i in low..=(low + 8) {
							push_id(i)
								if do_option({label = format(i)}) {
									year = i
									info.temp_value^, _ = time.datetime_to_time(i, int(month), day, 0, 0, 0, 0)
								}
							pop_id()
						}
					}
				}
				space(10)
				if do_layout(.top, 20) {
					set_side(.left); set_size(70)
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
				if do_layout(.top, 20) {
					set_side(.left); set_size(60); set_align(.middle)
					for day in ([]string)({"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}) {
						do_text({text = day})
					}
				}
				WEEK_DURATION :: i64(time.Hour * 24 * 7)
				OFFSET :: i64(time.Hour * 72)
				t, _ := time.datetime_to_time(year, int(month), 0, 0, 0, 0, 0)
				day_time := (t._nsec / WEEK_DURATION) * WEEK_DURATION - OFFSET
				if do_layout(.top, 20) {
					set_side(.left); set_size(60)
					for i in 0..<42 {
						if (i > 0) && (i % 7 == 0) {
							pop_layout()
							push_layout(cut(.top, 20))
							set_side(.left); set_size(60)
						}
						_, _month, _day := time.date(transmute(time.Time)day_time)
						push_id(i)
							if do_button({label = format(_day), style = .Filled if (_month == month && _day == day) else .Outlined, color = get_color(.button_base, 0.5) if time.month(transmute(time.Time)day_time) != month else nil}) {
								info.temp_value^ = transmute(time.Time)day_time
							}
						pop_id()
						day_time += i64(time.Hour * 24)
					}
				}
				if do_layout(.bottom, 30) {
					set_side(.right); set_size(60)
					if do_button({label = "Cancel", style = .Outlined}) {
						info.temp_value^ = info.value^
						self.bits -= {.active}
					}
					space(10)
					if do_button({label = "Save"}) {
						info.value^ = info.temp_value^
						self.bits -= {.active}
						changed = true
					}
					set_side(.left); set_size(60)
					if do_button({label = "Today", style = .Outlined}) {
						info.temp_value^ = time.now()
					}
				}
				// Stroke
				paint_rounded_box_stroke(layer.box, WINDOW_ROUNDNESS, true, get_color(.base_stroke))

				info.temp_value._nsec = max(info.temp_value._nsec, 0)
			}
		}

		if widget_clicked(self, .left) {
			self.bits ~= {.active}
			if self.bits >= {.active} {
				info.temp_value^ = info.value^
			}
		}
	}
	return
}
package maui

import "core:time"

CALENDAR_WIDTH :: 440
CALENDAR_HEIGHT :: 240

DatePickerState :: struct {
	month: time.Month,
	day,
	year: int,
	value: time.Time,
}
DatePickerInfo :: struct {
	value: ^time.Time,
	state: ^DatePickerState,
}
DatePicker :: proc(info: DatePickerInfo, loc := #caller_location) {
	if self, ok := Widget(HashId(loc), LayoutNext(CurrentLayout()), {}); ok {

		hoverTime := AnimateBool(self.id, .hovered in self.state, 0.1)

		year, month, day := time.date(info.value^)
		if .shouldPaint in self.bits {
			PaintRect(self.body, GetColor(.buttonBase, 0.2 if .pressed in self.state else hoverTime * 0.1))
			PaintRectLines(self.body, 1, GetColor(.buttonBase))
			PaintLabelRect(TextFormat("%2i-%2i-%4i", int(month), day, year), self.body, GetColor(.buttonBase), .near, .middle)
			PaintIconAligned(GetFontData(.default), .calendar, {self.body.x + self.body.w - self.body.h / 2, self.body.y + self.body.h / 2}, GetColor(.buttonBase), .middle, .middle)
		}

		if .active in self.bits {
			rect: Rect = {0, 0, CALENDAR_WIDTH, CALENDAR_HEIGHT}
			rect.x = self.body.x + self.body.w / 2 - rect.w / 2
			rect.y = self.body.y + self.body.h
			if layer, ok := Layer({
				rect = rect,
				order = .background,
				options = {.shadow, .attached},
			}); ok {
				// Fill
				PaintRoundedRect(layer.rect, WINDOW_ROUNDNESS, GetColor(.base))
				Shrink(10)
				if Layout(.top, 20) {
					SetSide(.left); SetSize(140); Align(.middle)
					Text({text = Format(info.state.year)})
					Text({text = Format(info.state.month)})
					Text({text = Format(info.state.day)})
				}
				if Layout(.top, 20) {
					SetSide(.left); SetSize(70)
					// Subtract one year
					if Button({label = "<<<", style = .filled}) {
						info.state.year -= 1
						info.state.value, _ = time.datetime_to_time(info.state.year, int(info.state.month), info.state.day, 0, 0, 0, 0)
					}
					// Subtract one month
					if Button({label = "<<", style = .filled}) {
						info.state.month = time.Month(int(info.state.month) - 1)
						if int(info.state.month) <= 0 {
							info.state.month = time.Month(12)
							info.state.year -= 1
						}
						info.state.value, _ = time.datetime_to_time(info.state.year, int(info.state.month), info.state.day, 0, 0, 0, 0)
					}
					// Subtract one day
					if Button({label = "<", style = .filled}) {
						info.state.value._nsec -= i64(time.Hour * 24)
						info.state.year, info.state.month, info.state.day = time.date(info.state.value)
					}
					// Add one day
					if Button({label = ">", style = .filled}) {
						info.state.value._nsec += i64(time.Hour * 24)
						info.state.year, info.state.month, info.state.day = time.date(info.state.value)
					}
					// Add one month
					if Button({label = ">>", style = .filled}) {
						info.state.month = time.Month(int(info.state.month) + 1)
						if int(info.state.month) >= 13 {
							info.state.month = time.Month(1)
							info.state.year += 1
						}
						info.state.value, _ = time.datetime_to_time(info.state.year, int(info.state.month), info.state.day, 0, 0, 0, 0)
					}
					// Add one year
					if Button({label = ">>>", style = .filled}) {
						info.state.year += 1
						info.state.value, _ = time.datetime_to_time(info.state.year, int(info.state.month), info.state.day, 0, 0, 0, 0)
					}
				}
				if Layout(.top, 20) {
					SetSide(.left); SetSize(60); Align(.middle)
					Text({text = "Mon"})
					Text({text = "Tue"})
					Text({text = "Wed"})
					Text({text = "Thu"})
					Text({text = "Fri"})
					Text({text = "Sat"})
					Text({text = "Sun"})
				}
				WEEK_DURATION :: i64(time.Hour * 24 * 7)
				t, _ := time.datetime_to_time(info.state.year, int(info.state.month), 0, 0, 0, 0, 0)
				day_time := (t._nsec / WEEK_DURATION) * WEEK_DURATION + i64(time.Hour * 24 * 4)
				state_time, _ := time.datetime_to_time(info.state.year, int(info.state.month), info.state.day, 0, 0, 0, 0)
				if Layout(.top, 20) {
					SetSide(.left); SetSize(60)
					for i in 0..<42 {
						if (i > 0) && (i % 7 == 0) {
							PopLayout()
							PushLayout(Cut(.top, 20))
							SetSide(.left); SetSize(60)
						}
						day := time.day(transmute(time.Time)day_time)
						PushId(i)
							//FIXME(isaiah): Sometimes, incorrect button is highlighted
							if Button({label = Format(day), style = .filled if day_time == state_time._nsec else .outlined, color = GetColor(.buttonBase, 0.5) if time.month(transmute(time.Time)day_time) != info.state.month else nil}) {
								info.state.value = transmute(time.Time)day_time
								info.state.year, info.state.month, info.state.day = time.date(info.state.value)
							}
						PopId()
						day_time += i64(time.Hour * 24)
					}
				}
				if Layout(.bottom, 30) {
					SetSide(.right); SetSize(60)
					if Button({label = "Save"}) {
						info.value^ = info.state.value
					}
					Space(10)
					if Button({label = "Cancel"}) {
						year, month, day := time.date(info.value^)
						info.state^ = {
							value = info.value^,
							month = month,
							year = year,
							day = day,
						}
					}
				}
				// Stroke
				PaintRoundedRectOutline(layer.rect, WINDOW_ROUNDNESS, true, GetColor(.baseStroke))
			}
		}

		if WidgetClicked(self, .left) {
			self.bits ~= {.active}
			year, month, day := time.date(info.value^)
			info.state^ = {
				value = info.value^,
				month = month,
				year = year,
				day = day,
			}
		}
	}
}
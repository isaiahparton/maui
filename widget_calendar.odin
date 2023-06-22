package maui

import "core:time"

CALENDAR_WIDTH :: 440
CALENDAR_HEIGHT :: 240

DatePickerInfo :: struct {
	value: ^time.Time,
	tempValue: ^time.Time,
}
DatePicker :: proc(info: DatePickerInfo, loc := #caller_location) {
	if self, ok := Widget(HashId(loc), LayoutNext(CurrentLayout()), {}); ok {

		hoverTime := AnimateBool(self.id, .hovered in self.state, 0.1)

		year, month, day := time.date(info.value^)
		if .shouldPaint in self.bits {
			PaintRect(self.body, AlphaBlend(GetColor(.widgetBackground), GetColor(.widgetShade), 0.2 if .pressed in self.state else hoverTime * 0.1))
			PaintRectLines(self.body, 1, GetColor(.buttonBase))
			PaintLabelRect(TextFormat("%2i-%2i-%4i", day, int(month), year), self.body, GetColor(.buttonBase), .near, .middle)
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

				// Temporary state
				year, month, day := time.date(info.tempValue^)

				// Fill
				PaintRoundedRect(layer.rect, WINDOW_ROUNDNESS, GetColor(.widgetBackground))
				Shrink(10)
				if Layout(.top, 20) {
					SetSide(.left); SetSize(1, true); Align(.middle)
					//DAY_SUFFIXES : []string = {"th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th"}
					Text({text = TextFormat("%i %v %i", day, month, year)})
				}
				if Layout(.top, 20) {
					SetSide(.left); SetSize(70)
					// Subtract one year
					if Button({label = "<<<", style = .filled}) {
						year -= 1
						info.tempValue^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
					}
					// Subtract one month
					if Button({label = "<<", style = .filled}) {
						month = time.Month(int(month) - 1)
						if int(month) <= 0 {
							month = time.Month(12)
							year -= 1
						}
						info.tempValue^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
					}
					// Subtract one day
					if Button({label = "<", style = .filled}) {
						info.tempValue^._nsec -= i64(time.Hour * 24)
						year, month, day = time.date(info.tempValue^)
					}
					// Add one day
					if Button({label = ">", style = .filled}) {
						info.tempValue^._nsec += i64(time.Hour * 24)
						year, month, day = time.date(info.tempValue^)
					}
					// Add one month
					if Button({label = ">>", style = .filled}) {
						month = time.Month(int(month) + 1)
						if int(month) >= 13 {
							month = time.Month(1)
							year += 1
						}
						info.tempValue^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
					}
					// Add one year
					if Button({label = ">>>", style = .filled}) {
						year += 1
						info.tempValue^, _ = time.datetime_to_time(year, int(month), day, 0, 0, 0, 0)
					}
				}
				if Layout(.top, 20) {
					SetSide(.left); SetSize(60); Align(.middle)
					for day in ([]string)({"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}) {
						Text({text = day})
					}
				}
				WEEK_DURATION :: i64(time.Hour * 24 * 7)
				OFFSET :: i64(time.Hour * 72)
				t, _ := time.datetime_to_time(year, int(month), 0, 0, 0, 0, 0)
				day_time := (t._nsec / WEEK_DURATION) * WEEK_DURATION - OFFSET
				if Layout(.top, 20) {
					SetSide(.left); SetSize(60)
					for i in 0..<42 {
						if (i > 0) && (i % 7 == 0) {
							PopLayout()
							PushLayout(Cut(.top, 20))
							SetSide(.left); SetSize(60)
						}
						_, _month, _day := time.date(transmute(time.Time)day_time)
						PushId(i)
							if Button({label = Format(_day), style = .filled if (_month == month && _day == day) else .outlined, color = GetColor(.buttonBase, 0.5) if time.month(transmute(time.Time)day_time) != month else nil}) {
								info.tempValue^ = transmute(time.Time)day_time
							}
						PopId()
						day_time += i64(time.Hour * 24)
					}
				}
				if Layout(.bottom, 30) {
					SetSide(.right); SetSize(60)
					if Button({label = "Cancel", style = .outlined}) {
						info.tempValue^ = info.value^
						self.bits -= {.active}
					}
					Space(10)
					if Button({label = "Save"}) {
						info.value^ = info.tempValue^
						self.bits -= {.active}
					}
					SetSide(.left); SetSize(60)
					if Button({label = "Today", style = .outlined}) {
						info.tempValue^ = time.now()
					}
				}
				// Stroke
				PaintRoundedRectOutline(layer.rect, WINDOW_ROUNDNESS, true, GetColor(.baseStroke))

				if .focused not_in self.state && .focused not_in layer.state {
					self.bits -= {.active}
				}
			}
		}

		if WidgetClicked(self, .left) {
			self.bits ~= {.active}
			if self.bits >= {.active} {
				info.tempValue^ = info.value^
			}
		}
	}
}
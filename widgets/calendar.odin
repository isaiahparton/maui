package maui_widgets

import "../"

import "core:time"
import "core:math/linalg"

CALENDAR_WIDTH :: 440
CALENDAR_HEIGHT :: 250

Date_Picker_Info :: struct {
	value,
	temp_value: ^time.Time,
	title: Maybe(string),
}
do_date_picker :: proc(info: Date_Picker_Info, loc := #caller_location) -> (changed: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		// Colocate
		self.box = use_next_box() or_else layout_next(current_layout())
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, DEFAULT_WIDGET_HOVER_TIME)
		open_time := animate_bool(&self.timers[1], .Active in self.bits, 0.2, .Quadratic_Out)
		// Date 
		year, month, day := time.date(info.value^)
		// Paint (kinda rhymes)
		if .Should_Paint in self.bits {
			paint_box_fill(self.box, alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1))
			paint_labeled_widget_frame(self.box, info.title, WIDGET_PADDING, 1, style_widget_stroke(self))
			paint_label_box(tmp_printf("%2i/%2i/%4i", day, int(month), year), shrink_box(self.box, [2]f32{height(self.box) * 0.25, 0}), get_color(.Button_Base), .Left, .Middle)
		}
		// Activate!
		if .Active in self.bits {
			size: [2]f32 = {CALENDAR_WIDTH, 260}
			box: Box = {low = {width(self.box) * 0.5 - (size.x / 2), self.box.high.y}}
			box.low = linalg.clamp(box.low, 0, core.size - size)
			box.low.y += 10 * open_time
			box.high = box.low + size
			// Layer
			if layer, ok := do_layer({
				placement = box,
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
				paint_rounded_box_fill(layer.box, WINDOW_ROUNDNESS, get_color(.Base))
				// Stuff
				shrink(10)
				placement.side = .Top
				// Main options
				if do_layout(.Bottom, Exact(30)) {
					placement.side = .Right; placement.size = Exact(70)
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
				// Combo boxes
				if do_layout(.Top, Exact(20)) {
					placement.side = .Left; placement.size = Exact(135); placement.align = {.Middle, .Middle}
					month_days := int(time.days_before[int(month)])
					if int(month) > 0 {
						month_days -= int(time.days_before[int(month) - 1])
					}
					if do_menu({label = tmp_print(day), size = {0, 120}}) {
						placement.size = Exact(20)
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
					if do_menu({label = tmp_print(month), size = {0, 120}}) {
						placement.size = Exact(20)
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
					if do_menu({label = tmp_print(year), size = {0, 120}}) {
						placement.size = Exact(20)
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
				// Skip buttons
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
				space(Exact(10))
				// Weekdays
				if do_layout(.Top, Exact(20)) {
					placement.side = .Left; placement.size = Exact(60); placement.align = {.Middle, .Middle}
					for day in ([]string)({"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}) {
						do_text({text = day, align = .Middle, baseline = .Middle})
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
							placement.size = Exact(60)
						}
						_, _month, _day := time.date(transmute(time.Time)day_time)
						push_id(i)
							if do_button({label = tmp_print(_day), style = .Filled, color = get_color(.Accent) if (_month == month && _day == day) else (get_color(.Button_Base, 0.5) if time.month(transmute(time.Time)day_time) != month else nil)}) {
								info.temp_value^ = transmute(time.Time)day_time
							}
						pop_id()
						day_time += i64(time.Hour * 24)
					}
				}
				// Stroke
				paint_rounded_box_stroke(layer.box, WINDOW_ROUNDNESS, 1, get_color(.Base_Stroke))
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
				info.temp_value^ = info.value^
			}
		}
	}
	return
}
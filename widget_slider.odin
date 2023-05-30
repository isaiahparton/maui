package maui

import "core:strconv"

// Integer spinner (compound widget)
Spinner :: proc(value, low, high: int, loc := #caller_location) -> (newValue: int) {
	loc := loc
	newValue = value
	// Sub-widget rectangles
	rect := LayoutNext(CurrentLayout())
	leftButtonRect := CutRectLeft(&rect, 30)
	rightButtonRect := CutRectRight(&rect, 30)
	// Number input
	SetNextRect(rect)
	PaintRect(rect, GetColor(.widgetBackground))
	newValue = clamp(NumberInput(
		value = value, 
		format = "%i",
		textOptions = {.alignCenter},
		).(int), low, high)
	// Step buttons
	loc.column += 1
	SetNextRect(leftButtonRect)
	if Button(
		label = Icon.remove, 
		align = .middle,
		loc = loc,
	) {
		newValue = max(low, value - 1)
	}
	loc.column += 1
	SetNextRect(rightButtonRect)
	if Button(
		label = Icon.add, 
		align = .middle,
		loc = loc,
	) {
		newValue = min(high, value + 1)
	}
	return
}

// Fancy slider
SliderInfo :: struct($T: typeid) {
	value,
	low,
	high: T,
	markers: Maybe([]T),
	format: Maybe(string),
}
Slider :: proc(
	value,
	low,
	high: $T,
	markers: $S/[]T = {},
	format: string = "%v", 
	loc := #caller_location,
) -> (changed: bool, newValue: T) {
	SIZE :: 16
	HEIGHT :: SIZE / 2
	HALF_HEIGHT :: HEIGHT / 2
	rect := LayoutNext(CurrentLayout())
	rect = ChildRect(rect, {rect.w, SIZE}, .near, .middle)
	if self, ok := Widget(HashId(loc), rect, {.draggable}); ok {
		PushId(self.id) 
			hoverTime := AnimateBool(HashIdFromInt(0), self.state & {.hovered, .pressed} != {}, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .pressed in self.state, 0.1)
		PopId()

		range := self.body.w - HEIGHT
		if .shouldPaint in self.bits {
			barRect: Rect = {self.body.x, self.body.y + HALF_HEIGHT, self.body.w, self.body.h - HEIGHT}
			if value < high {
				PaintRoundedRect(barRect, HALF_HEIGHT, GetColor(.widgetBackground))
			}
			offset := range * clamp((value - low) / high, 0, 1)
			PaintRoundedRect({barRect.x, barRect.y, offset, barRect.h}, HALF_HEIGHT, BlendColors(GetColor(.widget), GetColor(.accent), hoverTime))
			thumbCenter: Vec2 = {self.body.x + HALF_HEIGHT + offset, self.body.y + self.body.h / 2}
			// TODO: Constants for these
			thumbRadius := self.body.h
			if hoverTime > 0 {
				radius := thumbRadius + 10 * (pressTime + hoverTime)
				PaintCircle(thumbCenter, radius, GetColor(.baseShade, BASE_SHADE_ALPHA * hoverTime))
				Tooltip(self.id, TextFormat(format, value), thumbCenter + {0, -radius / 2 - 2}, .middle, .far)
			}
			PaintCircle(thumbCenter, thumbRadius, BlendColors(GetColor(.widget), GetColor(.accent), hoverTime))
		}

		if .pressed in self.state {
			result = {
				change = true,
				newValue = clamp(low + ((input.mousePoint.x - self.body.x - HALF_HEIGHT) / range) * (high - low), low, high),
			}
		}
	}
	return
}

// Rectangle slider with text edit
RectSlider :: proc(value, low, high: int, loc := #caller_location) -> (newValue: int) {
	newValue = value
	if self, ok := Widget(HashId(loc), LayoutNext(CurrentLayout())); ok {
		self.options += {.draggable}

		PushId(self.id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in self.state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .pressed in self.state, 0.1)
		PopId()

		if self.bits >= {.shouldPaint} {
			PaintRect(self.body, GetColor(.widgetBackground))
			if .active not_in self.bits {
				if low < high {
					PaintRect({self.body.x, self.body.y, self.body.w * (f32(value - low) / f32(high - low)), self.body.h}, BlendColors(GetColor(.widget), GetColor(.accent), pressTime))
				} else {
					PaintRect(self.body, GetColor(.widget))
				}
			}
			PaintRectLines(self.body, 2 if .active in self.bits else 1, GetColor(.accent) if .active in self.bits else GetColor(.widgetStroke, hoverTime))
		}
		fontData := GetFontData(.monospace)
		text := FormatSlice(value)
		if WidgetClicked(self, .left, 2) {
			self.bits = self.bits ~ {.active}
			self.state += {.gotFocus}
		}
		if .active in self.bits {
			if self.state & {.pressed, .hovered} != {} {
				ctx.cursor = .beam
			}
			buffer := GetTextBuffer(self.id)
			TextPro(fontData, buffer[:], self.body, {.alignCenter, .selectAll}, self.state)
			if .gotFocus in self.state {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			if .lostFocus in self.state {
				if TextEdit(buffer, {.numeric, .integer}) {
					if parsedValue, ok := strconv.parse_int(string(buffer[:])); ok {
						newValue = parsedValue
					}
					ctx.renderTime = RENDER_TIMEOUT
				}
			}
		} else {
			center: Vec2 = {self.body.x + self.body.w / 2, self.body.y + self.body.h / 2}
			PaintStringAligned(fontData, string(text), center, GetColor(.text), .middle, .middle)
			if .pressed in self.state {
				if low < high {
					newValue = low + int(((input.mousePoint.x - self.body.x) / self.body.w) * f32(high - low))
				} else {
					newValue = value + int(input.mousePoint.x - input.prevMousePoint.x) + int(input.mousePoint.y - input.prevMousePoint.y)
				}
			}
			if .hovered in self.state {
				ctx.cursor = .resizeEW
			}
		}

		if .focused not_in self.state {
			self.bits -= {.active}
		}
	}
	if low < high {
		newValue = clamp(newValue, low, high)
	}
	return
}
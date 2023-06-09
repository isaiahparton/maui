package maui

import "core:strconv"
import "core:fmt"
import "core:intrinsics"

// Integer spinner (compound widget)
SpinnerInfo :: struct {
	value,
	low,
	high: int,
}
Spinner :: proc(info: SpinnerInfo, loc := #caller_location) -> (newValue: int) {
	loc := loc
	newValue = info.value
	// Sub-widget rectangles
	rect := LayoutNext(CurrentLayout())
	leftButtonRect := CutRectLeft(&rect, 30)
	rightButtonRect := CutRectRight(&rect, 30)
	// Number input
	SetNextRect(rect)
	PaintRect(rect, GetColor(.widgetBackground))
	newValue = clamp(NumberInput(NumberInputInfo(int){
		value = info.value,
		textOptions = {.alignCenter},
		noOutline = true,
	}), info.low, info.high)
	// Step buttons
	loc.column += 1
	SetNextRect(leftButtonRect)
	if Button({
		label = Icon.remove, 
		align = .middle,
	}, loc) {
		newValue = max(info.low, info.value - 1)
	}
	loc.column += 1
	SetNextRect(rightButtonRect)
	if Button({
		label = Icon.add, 
		align = .middle,
	}, loc) {
		newValue = min(info.high, info.value + 1)
	}
	return
}

// Fancy slider
SliderInfo :: struct($T: typeid) {
	value,
	low,
	high: T,
	guides: Maybe([]T),
	format: Maybe(string),
}
Slider :: proc(info: SliderInfo($T), loc := #caller_location) -> (changed: bool, newValue: T) {
	SIZE :: 16
	HEIGHT :: SIZE / 2
	HALF_HEIGHT :: HEIGHT / 2
	format := info.format.? or_else "%v"
	rect := LayoutNext(CurrentLayout())
	rect = ChildRect(rect, {rect.w, SIZE}, .near, .middle)
	if self, ok := Widget(HashId(loc), rect, {.draggable}); ok {
		PushId(self.id) 
			hoverTime := AnimateBool(HashIdFromInt(0), self.state & {.hovered, .pressed} != {}, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .pressed in self.state, 0.1)
		PopId()

		range := self.body.w - HEIGHT
		offset := range * clamp(f32((info.value - info.low) / info.high), 0, 1)
		barRect: Rect = {self.body.x, self.body.y + HALF_HEIGHT, self.body.w, self.body.h - HEIGHT}
		thumbCenter: Vec2 = {self.body.x + HALF_HEIGHT + offset, self.body.y + self.body.h / 2}
		thumbRadius: f32 = 9
		shadeRadius := thumbRadius + 5 * (pressTime + hoverTime)
		if .shouldPaint in self.bits {
			if info.guides != nil {
				r := f32(info.high - info.low)
				fontData := GetFontData(.label)
				for entry in info.guides.? {
					x := barRect.x + HALF_HEIGHT + range * (f32(entry - info.low) / r)
					PaintLine({x, barRect.y}, {x, barRect.y - 10}, 1, GetColor(.widget))
					PaintStringAligned(fontData, TextFormat(format, entry), {x, barRect.y - 12}, GetColor(.widget), .middle, .far)
				}
			}
			if info.value < info.high {
				PaintRoundedRect(barRect, HALF_HEIGHT, GetColor(.widgetBackground))
			}
			PaintRoundedRect({barRect.x, barRect.y, offset, barRect.h}, HALF_HEIGHT, BlendColors(GetColor(.widget), GetColor(.accent), hoverTime))
			PaintCircle(thumbCenter, shadeRadius, 12, GetColor(.baseShade, BASE_SHADE_ALPHA * hoverTime))
			PaintCircle(thumbCenter, thumbRadius, 12, BlendColors(GetColor(.widget), GetColor(.accent), hoverTime))
		}
		if hoverTime > 0 {
			Tooltip(self.id, TextFormat(format, info.value), thumbCenter + {0, -shadeRadius - 2}, .middle, .far)
		}

		if .pressed in self.state {
			changed = true
			point := input.mousePoint.x
			newValue = clamp(info.low + T((point - self.body.x - HALF_HEIGHT) / range) * (info.high - info.low), info.low, info.high)
			if info.guides != nil {
				r := info.high - info.low
				for entry in info.guides.? {
					x := self.body.x + HALF_HEIGHT + f32(entry / r) * range
					if abs(x - point) < 10 {
						newValue = entry
					}
				}
			}
		}
	}
	return
}

// Rectangle slider with text edit
RectSliderInfo :: struct($T: typeid) {
	value,
	low,
	high: T,
}
RectSlider :: proc(info: RectSliderInfo($T), loc := #caller_location) -> (newValue: T) where intrinsics.type_is_integer(T) {
	newValue = info.value
	if self, ok := Widget(HashId(loc), LayoutNext(CurrentLayout()), {.draggable}); ok {
		PushId(self.id) 
			hoverTime := AnimateBool(HashIdFromInt(0), .hovered in self.state, 0.1)
			pressTime := AnimateBool(HashIdFromInt(1), .pressed in self.state, 0.1)
		PopId()

		if self.bits >= {.shouldPaint} {
			PaintRect(self.body, GetColor(.widgetBackground))
			if .active not_in self.bits {
				if info.low < info.high {
					PaintRect({self.body.x, self.body.y, self.body.w * (f32(info.value - info.low) / f32(info.high - info.low)), self.body.h}, AlphaBlend(GetColor(.widget), GetColor(.widgetShade), 0.2 if .pressed in self.state else hoverTime * 0.1))
				} else {
					PaintRect(self.body, GetColor(.widget))
				}
			} else {
				PaintRectLines(self.body, 2, GetColor(.accent))
			}
		}
		fontData := GetFontData(.monospace)
		text := FormatToSlice(info.value)
		if WidgetClicked(self, .left, 2) {
			self.bits += {.active}
			self.state += {.gotFocus}
		}
		if .active in self.bits {
			if self.state & {.pressed, .hovered} != {} {
				ctx.cursor = .beam
			}
			buffer := GetTextBuffer(self.id)
			TextPro(fontData, buffer[:], self.body, {.alignCenter, .selectAll}, self)
			if .gotFocus in self.state {
				resize(buffer, len(text))
				copy(buffer[:], text[:])
			}
			if .focused in self.state {
				if TextEdit(buffer, {.numeric, .integer}) {
					if parsedValue, ok := strconv.parse_int(string(buffer[:])); ok {
						newValue = T(parsedValue)
					}
					ctx.paintThisFrame = true
				}
			}
		} else {
			center: Vec2 = {self.body.x + self.body.w / 2, self.body.y + self.body.h / 2}
			PaintStringAligned(fontData, string(text), center, GetColor(.text), .middle, .middle)
			if .pressed in self.state {
				if info.low < info.high {
					newValue = T(f32(info.low) + clamp((input.mousePoint.x - self.body.x) / self.body.w, 0, 1) * f32(info.high - info.low))
				} else {
					newValue = info.value + T(input.mousePoint.x - input.prevMousePoint.x) + T(input.mousePoint.y - input.prevMousePoint.y)
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
	if info.low < info.high {
		newValue = clamp(newValue, info.low, info.high)
	}
	return
}
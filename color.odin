package maui

import "core:math"
import "core:math/linalg"

import "vendor:nanovg"

Color :: nanovg.Color

blend_colors :: proc(time: f32, colors: ..Color) -> Color {
	if len(colors) > 0 {
		if len(colors) == 1 {
			return colors[0]
		}
		if time <= 0 {
			return colors[0]
		} else if time >= f32(len(colors) - 1) {
			return colors[len(colors) - 1]
		} else {
			i := int(math.floor(time))
			t := time - f32(i)
			return colors[i] + {
				(colors[i + 1].r - colors[i].r) * t,
				(colors[i + 1].g - colors[i].g) * t,
				(colors[i + 1].b - colors[i].b) * t,
				(colors[i + 1].a - colors[i].a) * t,
			}
		}
	}
	return {}
}
// Color processing
set_color_brightness :: proc(color: Color, value: f32) -> Color {
	return {
		clamp(color.r + value, 0, 1),
		clamp(color.g + value, 0, 1),
		clamp(color.b + value, 0, 1),
		color.a,
	}
}
color_to_hsv :: proc(color: Color) -> [4]f32 {
	hsva := linalg.vector4_rgb_to_hsl(linalg.Vector4f32{f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0})
	return hsva.xyzw
}
color_from_hsv :: proc(hue, saturation, value: f32) -> Color {
	rgba := linalg.vector4_hsl_to_rgb(hue, saturation, value, 1.0)
	return {rgba.r * 255.0, rgba.g * 255.0, rgba.b * 255.0, rgba.a * 255.0}
}
fade :: proc(color: Color, alpha: f32) -> Color {
	return {color.r, color.g, color.b, color.a * alpha}
}
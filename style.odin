package maui

//TODO(isaiah): Migrate these to values in Style
WINDOW_ROUNDNESS :: 6
WINDOW_TITLE_SIZE :: 34
WIDGET_TEXT_OFFSET :: 9

SCROLL_BAR_SIZE :: 14
SCROLL_BAR_PADDING :: 0

GHOST_TEXT_ALPHA :: 0.6
DIVIDER_ALPHA :: 0.45
BASE_SHADE_ALPHA :: 0.1
SHADOW_OFFSET :: 7
DISABLED_SHADE_ALPHA :: 0.5

// Default color schemes
DEFAULT_COLORS_LIGHT :: [Color_Index]Color {
	.accent 			= {45, 105, 238, 255},
	.base 				= {230, 230, 235, 255},
	.base_shade 		= {0, 0, 0, 255},
	.base_stroke		= {112, 113, 116, 255},
	.widget_bg 			= {255, 255, 255, 255},
	.widget	 			= {165, 165, 175, 255},
	.widget_shade 		= {0, 0, 15, 255},
	.widget_stroke 		= {105, 105, 105, 255},
	.intense 			= {62, 62, 67, 255},
	.intense_shade 		= {230, 239, 255, 255},
	.shadow 			= {0, 0, 0, 35},
	.text_inverted 		= {218, 218, 218, 255},
	.text 				= {45, 45, 45, 255},
	.tooltip_fill 		= {45, 45, 77, 255},
	.tooltip_stroke  	= {},
	.tooltip_text 		= {255, 255, 255, 255},
	.scrollbar  		= {255, 255, 255, 255},
	.scroll_thumb 		= {165, 185, 185, 255},
	.scroll_thumb_shade = {255, 255, 255, 255},

	.button_base 		= {82, 82, 92, 255},
	.button_shade		= {0, 0, 0, 255},
	.button_text 		= {255, 255, 255, 255},
}
/*DEFAULT_COLORS_DARK :: [Color_Index]Color {
	.accent 			= {45, 135, 248, 255},
	.base 				= {28, 28, 28, 255},
	.base_shade 			= {255, 255, 255, 255},
	.base_stroke			= {112, 113, 116, 255},
	.widget_bg 	= {54, 54, 54, 255},
	.widget	 			= {74, 74, 74, 255},
	.widget_shade 		= {255, 255, 255, 255},
	.widget_stroke 		= {105, 105, 105, 255},
	.intense 			= {178, 178, 178, 255},
	.intense_shade 		= {0, 0, 0, 255},
	.shadow 			= {0, 0, 0, 55},
	.text_inverted 		= {25, 25, 25, 255},
	.text 				= {215, 215, 215, 255},
	.tooltip_fill 		= {45, 55, 68, 255},
	.tooltip_stroke  	= {50, 170, 170, 255},
	.tooltip_text 		= {170, 170, 170, 255},
	.scrollbar  		= {62, 62, 62, 255},
	.scroll_thumb 		= {92, 92, 92, 255},
	.scroll_thumbShade   = {255, 255, 255, 255},
}*/

Color_Index :: enum {
	// Base color
	base,
	// Hover or click shading for base color
	base_shade,
	// Outlining for base color
	base_stroke,
	// Color of focused or selected widgets
	accent,
	// Background of a slider
	widget_bg,
	// Base color for widgets
	widget,
	// How widgets are shaded when hovered or pressed
	widget_shade,
	// Widget outline
	widget_stroke,
	// Outline
	intense,
	// Outline shading
	intense_shade,
	// Shadows
	shadow,
	// Color of text
	text,
	// Text color when highlighted
	text_inverted,
	// Tooltips
	tooltip_fill,
	tooltip_stroke,
	tooltip_text,
	// Scrollbars
	scrollbar,
	scroll_thumb,
	scroll_thumb_shade,

	button_base,
	button_shade,
	button_text,
}
Rule_Index :: enum {
	window_roundness,
	tab_roundness,
	widget_text_offset,
	window_title_size,
}

MAX_COLOR_CHANGES :: 64
MAX_RULE_CHANGES :: 64

Color_Change :: struct {
	index: Color_Index,
	value: Color,
}
Rule_Change :: struct {
	index: Rule_Index,
	value: f32,
}

// Style
Style :: struct {
	fontSizes: 			[Font_Index]int,
	colors: 			[Color_Index]Color,
	rules:				[Rule_Index]f32,

	rule_change_stack:	[MAX_RULE_CHANGES]Rule_Change,
	rule_change_count: 	int,
	color_change_stack: [MAX_COLOR_CHANGES]Color_Change,
	color_change_count: int,
}

push_color :: proc(index: Color_Index, value: Color) {
	using painter
	style.color_change_stack[style.rule_change_count] = {
		index = index,
		value = style.colors[index],
	}
	style.rule_change_count += 1
	style.colors[index] = value
}
pop_color :: proc() {
	using painter
	assert(style.rule_change_count > 0)
	style.rule_change_count -= 1
	style.colors[style.color_change_stack[style.rule_change_count].index] = style.color_change_stack[style.rule_change_count].value
}
push_rule :: proc(index: Rule_Index, value: f32) {
	using painter
	style.rule_change_stack[style.rule_change_count] = {
		index = index,
		value = style.rules[index],
	}
	style.rule_change_count += 1
	style.rules[index] = value
}
pop_rule :: proc() {
	using painter
	assert(style.rule_change_count > 0)
	style.rule_change_count -= 1
	style.rules[style.rule_change_stack[style.rule_change_count].index] = style.rule_change_stack[style.rule_change_count].value
}

get_rule :: proc(index: Rule_Index) -> f32 {
	return painter.style.rules[index]
}
get_color :: proc(index: Color_Index, alpha: f32 = 1) -> Color {
	color := painter.style.colors[index]
	if alpha == 1 {
		return color
	} else if alpha == 0 {
		return {}
	}
	return {color.r, color.g, color.b, u8(f32(color.a) * clamp(alpha, 0, 1))}
}

style_shade :: proc(base: Color, amount: f32) -> Color {
	return alpha_blend_colors(base, painter.style.colors[.widget_shade], amount * 0.1)
}
style_intense_shaded :: proc(amount: f32) -> Color {
	return alpha_blend_colors(painter.style.colors[.intense], painter.style.colors[.intense_shade], amount * 0.15)
}
style_widget_shaded :: proc(amount: f32) -> Color {
	return alpha_blend_colors(painter.style.colors[.widget], painter.style.colors[.widget_shade], amount * 0.1)
}
style_base_shaded :: proc(amount: f32) -> Color {
	return alpha_blend_colors(painter.style.colors[.base], painter.style.colors[.base_shade], amount * 0.1)
}
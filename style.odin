package maui

//TODO(isaiah): Migrate these to values in Style
WINDOW_ROUNDNESS :: 6
WINDOW_TITLE_SIZE :: 30

SCROLL_BAR_SIZE :: 10
SCROLL_BAR_PADDING :: 0

GHOST_TEXT_ALPHA :: 0.6
DIVIDER_ALPHA :: 0.45
BASE_SHADE_ALPHA :: 0.1
SHADOW_OFFSET :: 7
DISABLED_SHADE_ALPHA :: 0.5

ICON_STROKE_THICKNESS :: 1

WIDGET_PADDING :: 6
WIDGET_TEXT_MARGIN :: 2

// Default color schemes
DEFAULT_COLORS_LIGHT :: [Color_Index]Color {
	.Accent 							= {45, 105, 238, 255},
	.Base 								= {30, 30, 32, 255},
	.Base_Shade 					= {255, 255, 255, 35},
	.Base_Stroke					= {112, 113, 116, 255},
	.Widget_Back					= {12, 12, 16, 255},
	.Widget	 							= {65, 65, 75, 255},
	.Widget_Shade 				= {255, 255, 255, 255},
	.Widget_Stroke 				= {85, 85, 85, 255},
	.Widget_Stroke_Focused 	= {0, 255, 108, 255},
	.Intense 							= {62, 62, 67, 255},
	.Intense_Shade 				= {230, 239, 255, 255},
	.Shadow 							= {0, 0, 0, 50},
	.Text_Inverted 				= {218, 218, 218, 255},
	.Text 								= {255, 255, 255, 255},
	.Text_Highlight  			= {0, 100, 220, 255},
	.Tooltip_Fill 				= {240, 240, 250, 255},
	.Tooltip_Stroke  			= {},
	.Tooltip_Text 				= {50, 50, 50, 255},
	.Scrollbar  					= {15, 15, 18, 255},
	.Scroll_Thumb 				= {45, 45, 49, 255},
	.Scroll_Thumb_Shade 	= {255, 255, 255, 255},

	.Button_Base 					= {45, 85, 80, 255},
	.Button_Shade					= {255, 255, 255, 65},
	.Button_Text 					= {30, 30, 32, 255},
}
/*DEFAULT_COLORS_DARK :: [Color_Index]Color {
	.accent 			= {45, 135, 248, 255},
	.Base 				= {28, 28, 28, 255},
	.Base_Shade 			= {255, 255, 255, 255},
	.Base_stroke			= {112, 113, 116, 255},
	.Widget_bg 	= {54, 54, 54, 255},
	.Widget	 			= {74, 74, 74, 255},
	.Widget_Shade 		= {255, 255, 255, 255},
	.Widget_stroke 		= {105, 105, 105, 255},
	.Intense 			= {178, 178, 178, 255},
	.Intense_Shade 		= {0, 0, 0, 255},
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
	Base,
	// Hover or click shading for base color
	Base_Shade,
	// Outlining for base color
	Base_Stroke,
	// Color of focused or selected widgets
	Accent,
	// Background of a slider
	Widget_Back,
	// Base color for widgets
	Widget,
	// How widgets are shaded when hovered or pressed
	Widget_Shade,
	// Widget outline
	Widget_Stroke,
	Widget_Stroke_Focused,
	// Outline
	Intense,
	// Outline shading
	Intense_Shade,
	// Shadows
	Shadow,
	// Color of text
	Text,
	// Text color when highlighted
	Text_Inverted,
	Text_Highlight,
	// Tooltips
	Tooltip_Fill,
	Tooltip_Stroke,
	Tooltip_Text,
	// Scrollbars
	Scrollbar,
	Scroll_Thumb,
	Scroll_Thumb_Shade,

	Button_Base,
	Button_Shade,
	Button_Text,
}
Rule_Index :: enum {
	Window_Roundness,
	Tab_Roundness,
	Window_Title_Size,
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
	default_font,
	button_font,
	title_font,
	monospace_font: Font_Handle,
	default_font_size,
	button_font_size,
	title_font_size,
	monospace_font_size: f32,
	widget_rounding: f32,
	text_box_padding: f32,
	stroke_thickness: f32,

	colors: 						[Color_Index]Color,
	rules:							[Rule_Index]f32,

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

style_widget_stroke :: proc(w: ^Widget, opacity: f32) -> Color {
	return get_color(.Widget_Stroke_Focused) if .Focused in w.state else get_color(.Widget_Stroke, opacity)
}
style_shade :: proc(base: Color, amount: f32) -> Color {
	return alpha_blend_colors(base, painter.style.colors[.Widget_Shade], fade(255, amount * 0.1))
}
style_intense_shaded :: proc(amount: f32) -> Color {
	return alpha_blend_colors(painter.style.colors[.Intense], painter.style.colors[.Intense_Shade], amount * 0.15)
}
style_widget_shaded :: proc(amount: f32) -> Color {
	return alpha_blend_colors(painter.style.colors[.Widget], painter.style.colors[.Widget_Shade], amount * 0.1)
}
style_base_shaded :: proc(amount: f32) -> Color {
	return alpha_blend_colors(painter.style.colors[.Base], painter.style.colors[.Base_Shade], amount * 0.1)
}
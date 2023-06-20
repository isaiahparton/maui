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
DEFAULT_COLORS_LIGHT :: [ColorIndex]Color {
	.accent 			= {45, 105, 238, 255},
	.base 				= {230, 230, 235, 255},
	.baseShade 			= {0, 0, 0, 255},
	.baseStroke			= {112, 113, 116, 255},
	.widgetBackground 	= {255, 255, 255, 255},
	.widget	 			= {165, 165, 175, 255},
	.widgetShade 		= {0, 0, 15, 255},
	.widgetStroke 		= {105, 105, 105, 255},
	.intense 			= {62, 62, 67, 255},
	.intenseShade 		= {230, 239, 255, 255},
	.shadow 			= {0, 0, 0, 35},
	.textInverted 		= {218, 218, 218, 255},
	.text 				= {45, 45, 45, 255},
	.tooltipFill 		= {45, 45, 77, 255},
	.tooltipStroke  	= {},
	.tooltipText 		= {255, 255, 255, 255},
	.scrollbar  		= {255, 255, 255, 255},
	.scrollThumb 		= {165, 185, 185, 255},
	.scrollThumbShade   = {255, 255, 255, 255},

	.buttonBase 		= {82, 82, 92, 255},
	.buttonShade		= {0, 0, 0, 255},
	.buttonText 		= {255, 255, 255, 255},
}
/*DEFAULT_COLORS_DARK :: [ColorIndex]Color {
	.accent 			= {45, 135, 248, 255},
	.base 				= {28, 28, 28, 255},
	.baseShade 			= {255, 255, 255, 255},
	.baseStroke			= {112, 113, 116, 255},
	.widgetBackground 	= {54, 54, 54, 255},
	.widget	 			= {74, 74, 74, 255},
	.widgetShade 		= {255, 255, 255, 255},
	.widgetStroke 		= {105, 105, 105, 255},
	.intense 			= {178, 178, 178, 255},
	.intenseShade 		= {0, 0, 0, 255},
	.shadow 			= {0, 0, 0, 55},
	.textInverted 		= {25, 25, 25, 255},
	.text 				= {215, 215, 215, 255},
	.tooltipFill 		= {45, 55, 68, 255},
	.tooltipStroke  	= {50, 170, 170, 255},
	.tooltipText 		= {170, 170, 170, 255},
	.scrollbar  		= {62, 62, 62, 255},
	.scrollThumb 		= {92, 92, 92, 255},
	.scrollThumbShade   = {255, 255, 255, 255},
}*/

ColorIndex :: enum {
	// Base color
	base,
	// Hover or click shading for base color
	baseShade,
	// Outlining for base color
	baseStroke,
	// Color of focused or selected widgets
	accent,
	// Background of a slider
	widgetBackground,
	// Base color for widgets
	widget,
	// How widgets are shaded when hovered or pressed
	widgetShade,
	// Widget outline
	widgetStroke,
	// Outline
	intense,
	// Outline shading
	intenseShade,
	// Shadows
	shadow,
	// Color of text
	text,
	// Text color when highlighted
	textInverted,
	// Tooltips
	tooltipFill,
	tooltipStroke,
	tooltipText,
	// Scrollbars
	scrollbar,
	scrollThumb,
	scrollThumbShade,

	buttonBase,
	buttonShade,
	buttonText,
}
RuleIndex :: enum {
	windowRoundness,
	widgetTextOffset,
	windowTitleSize,
}

MAX_COLOR_CHANGES :: 64
MAX_RULE_CHANGES :: 64

ColorChange :: struct {
	index: ColorIndex,
	value: Color,
}
RuleChange :: struct {
	index: RuleIndex,
	value: f32,
}

// Style
Style :: struct {
	fontSizes: 			[FontIndex]int,
	colors: 			[ColorIndex]Color,
	rules:				[RuleIndex]f32,
	windowRoundness,
	tabRoundness: 		int,

	ruleChangeStack:	[MAX_RULE_CHANGES]RuleChange,
	ruleChangeCount: 	int,
	colorChangeStack: 	[MAX_COLOR_CHANGES]ColorChange,
	colorChangeCount: 	int,
}

PushColor :: proc(index: ColorIndex, value: Color) {
	using painter
	style.colorChangeStack[style.ruleChangeCount] = {
		index = index,
		value = style.colors[index],
	}
	style.ruleChangeCount += 1
	style.colors[index] = value
}
PopColor :: proc() {
	using painter
	assert(style.ruleChangeCount > 0)
	style.ruleChangeCount -= 1
	style.colors[style.colorChangeStack[style.ruleChangeCount].index] = style.colorChangeStack[style.ruleChangeCount].value
}
PushRule :: proc(index: RuleIndex, value: f32) {
	using painter
	style.ruleChangeStack[style.ruleChangeCount] = {
		index = index,
		value = style.rules[index],
	}
	style.ruleChangeCount += 1
	style.rules[index] = value
}
PopRule :: proc() {
	using painter
	assert(style.ruleChangeCount > 0)
	style.ruleChangeCount -= 1
	style.rules[style.ruleChangeStack[style.ruleChangeCount].index] = style.ruleChangeStack[style.ruleChangeCount].value
}

GetRule :: proc(index: RuleIndex) -> f32 {
	return painter.style.rules[index]
}
GetColor :: proc(index: ColorIndex, alpha: f32 = 1) -> Color {
	color := painter.style.colors[index]
	if alpha == 1 {
		return color
	} else if alpha == 0 {
		return {}
	}
	return {color.r, color.g, color.b, u8(f32(color.a) * clamp(alpha, 0, 1))}
}

StyleShade :: proc(base: Color, shadeAmount: f32) -> Color {
	return AlphaBlend(base, painter.style.colors[.widgetShade], shadeAmount * 0.1)
}
StyleIntenseShaded :: proc(shadeAmount: f32) -> Color {
	return AlphaBlend(painter.style.colors[.intense], painter.style.colors[.intenseShade], shadeAmount * 0.15)
}
StyleWidgetShaded :: proc(shadeAmount: f32) -> Color {
	return AlphaBlend(painter.style.colors[.widget], painter.style.colors[.widgetShade], shadeAmount * 0.1)
}
StyleBaseShaded :: proc(shadeAmount: f32) -> Color {
	return AlphaBlend(painter.style.colors[.base], painter.style.colors[.baseShade], shadeAmount * 0.1)
}
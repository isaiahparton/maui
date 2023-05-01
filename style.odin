package maui

/*
	Geometric appearance
*/
WINDOW_ROUNDNESS :: 8
WINDOW_TITLE_SIZE :: 40

WIDGET_ROUNDNESS :: 5
WIDGET_TEXT_OFFSET :: 9

CHECKBOX_SIZE :: 22
HALF_CHECKBOX_SIZE :: CHECKBOX_SIZE / 2

SCROLL_BAR_SIZE :: 14
SCROLL_BAR_PADDING :: 4

/*
	Color schemes
*/
COLOR_SCHEME_LIGHT: #sparse [ColorIndex]Color = {
	.accent = {55, 125, 248, 255},
	.accentHover = {35, 105, 250, 255},
	.accentPress = {16, 65, 245, 255},

	.foreground = {218, 218, 218, 255},
	.foregroundHover = {200, 200, 200, 255},
	.foregroundPress = {170, 170, 170, 255},

	.backing = {255, 255, 255, 255},
	.backingHighlight = {240, 240, 240, 255},
	.iconBase = {135, 135, 135, 255},

	.widgetBase = {157, 157, 162, 255},
	.widgetHover = {143, 144, 155, 255},
	.widgetPress = {112, 113, 129, 255},

	.outlineBase = {112, 113, 116, 255},

	.textBright = {15, 15, 15, 255},
	.text = {75, 75, 75, 255},
	.shade = {0, 0, 0, 255},
}
COLOR_SCHEME_DARK: #sparse [ColorIndex]Color = {
	.accent = {53, 120, 243, 255},
	.accentHover = {53, 120, 243, 255},
	.accentPress = {53, 120, 243, 255},

	.foreground = {28, 28, 28, 255},
	.foregroundHover = {28, 28, 28, 255},
	.foregroundPress = {28, 28, 28, 255},
	.backing = {18, 18, 18, 255},
	.backingHighlight = {18, 18, 18, 255},
	.iconBase = {192, 192, 192, 255},

	.widgetBase = {50, 50, 50, 255},
	.widgetHover = {61, 60, 63, 255},
	.widgetPress = {77, 76, 79, 255},

	.outlineBase = {80, 80, 80, 255},

	.textBright = {255, 255, 255, 255},
	.text = {200, 200, 200, 255},
	.shade = 255,
}

ColorIndex :: enum {
	foreground,
	foregroundHover,
	foregroundPress,

	// Background of text inputs and toggle switches
	backing,
	backingHighlight,

	// Clickable things
	widgetBase,
	widgetHover,
	widgetPress,

	// Outline
	outlineBase,

	// Some bright accent color that stands out
	accent,
	accentHover,
	accentPress,

	shade,
	iconBase,
	text,
	textBright,
}

// Style
Style :: struct {
	colors: [ColorIndex]Color,
}

GetColor :: proc(index: ColorIndex, alpha: f32 = 1) -> Color {
	color := ctx.style.colors[index]
	return {color.r, color.g, color.b, u8(f32(color.a) * clamp(alpha, 0, 1))}
}
StyleApplyShade :: proc(base: Color, amount: f32) -> Color {
	return BlendColors(base, ctx.style.colors[.shade], amount * 0.1)
}
StyleGetWidgetColor :: proc(base: Color, amount: f32) -> Color {
	return BlendColors(base, 255, amount * 0.1)
}
StyleGetShadeColor :: proc(alpha: f32 = 1) -> Color {
	color := ctx.style.colors[.shade]
	return {color.r, color.g, color.b, u8(f32(color.a) * alpha * 0.075)}
}
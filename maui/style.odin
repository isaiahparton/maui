package maui

/*
	Geometric appearance
*/
WINDOW_ROUNDNESS :: 10
WINDOW_TITLE_SIZE :: 40

WIDGET_HEIGHT :: 36
WIDGET_ROUNDNESS :: 5
WIDGET_TEXT_OFFSET :: 7

WIDGET_SIZE :: 46
BUTTON_SIZE :: 32

CHECKBOX_SIZE :: 22
HALF_CHECKBOX_SIZE :: CHECKBOX_SIZE / 2

MENU_SIZE :: 32
MENU_OPTION_SIZE :: 28

/*
	Color schemes
*/
COLOR_SCHEME_LIGHT: #sparse [ColorIndex]Color = {
	.accent = {50, 120, 243, 255},
	.foreground = {255, 255, 255, 255},
	.backing = {212, 211, 218, 255},
	.iconBase = {135, 135, 135, 255},

	.widgetBase = {170, 170, 174, 255},
	.widgetHover = {162, 163, 169, 255},
	.widgetPress = {150, 151, 157, 255},
	.widgetShade = {0, 0, 0, 255},

	.outlineBase = {112, 113, 116, 255},

	.textBright = {15, 15, 15, 255},
	.text = {58, 58, 58, 255},
	.shade = {0, 0, 0, 255},
}
COLOR_SCHEME_DARK: #sparse [ColorIndex]Color = {
	.accent = {53, 120, 243, 255},
	.foreground = {28, 28, 28, 255},
	.backing = {18, 18, 18, 255},
	.iconBase = {192, 192, 192, 255},

	.widgetBase = {50, 50, 50, 255},
	.widgetHover = {61, 60, 63, 255},
	.widgetPress = {77, 76, 79, 255},
	.widgetShade = {255, 255, 255, 255},

	.outlineBase = {80, 80, 80, 255},

	.textBright = {255, 255, 255, 255},
	.text = {200, 200, 200, 255},
	.shade = 255,
}

ColorIndex :: enum {
	foreground,

	// Background of text inputs and toggle switches
	backing,

	// Clickable things
	widgetBase,
	widgetShade,
	widgetHover,
	widgetPress,

	// Outline
	outlineBase,

	// Some bright accent color that stands out
	accent,

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
	return {color.r, color.g, color.b, u8(f32(color.a) * alpha)}
}
StyleApplyShade :: proc(base: Color, amount: f32) -> Color {
	return BlendColors(base, ctx.style.colors[.shade], amount * 0.1)
}
StyleGetWidgetColor :: proc(hover, press: f32) -> Color {
	return BlendThreeColors(ctx.style.colors[.widgetBase], ctx.style.colors[.widgetHover], ctx.style.colors[.widgetPress], hover + press)
}
StyleGetShadeColor :: proc(alpha: f32 = 1) -> Color {
	color := ctx.style.colors[.shade]
	return {color.r, color.g, color.b, u8(f32(color.a) * alpha * 0.1)}
}
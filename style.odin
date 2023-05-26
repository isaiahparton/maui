package maui

/*
	Geometric appearance
*/
WINDOW_ROUNDNESS :: 6
WINDOW_TITLE_SIZE :: 34

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

	.foreground = {255, 255, 255, 255},
	.foregroundHover = {245, 245, 245, 255},
	.foregroundPress = {230, 230, 230, 255},

	.backing = {218, 218, 218, 255},
	.backingHighlight = {200, 200, 200, 255},

	.widgetBase = {182, 185, 182, 255},
	.widgetHover = {167, 168, 170, 255},
	.widgetPress = {145, 145, 155, 255},

	.outlineBase = {112, 113, 116, 255},
	.outlineHot = {140, 141, 144, 255},
	.outlineActive = {112, 113, 116, 255},

	.highlightedText = {218, 218, 218, 255},
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

	.widgetBase = {50, 50, 50, 255},
	.widgetHover = {61, 60, 63, 255},
	.widgetPress = {77, 76, 79, 255},

	.outlineBase = {80, 80, 80, 255},
	.outlineHot = {80, 80, 80, 255},
	.outlineActive = {80, 80, 80, 255},

	.highlightedText = {18, 18, 18, 255},
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
	outlineHot,
	outlineActive,

	// Some bright accent color that stands out
	accent,
	accentHover,
	accentPress,

	//Shading for items on the foreground
	//foregroundShade,
	//Shading for items in the background
	//backgroundShade,

	shade,
	text,
	highlightedText,
}

MAX_COLOR_CHANGES :: 32

ColorChange :: struct {
	index: ColorIndex,
	value: Color,
}

// Style
Style :: struct {
	colors: [ColorIndex]Color,
	changeStack: [MAX_COLOR_CHANGES]ColorChange,
	changeCount: int,
}

PushColor :: proc(index: ColorIndex, value: Color) {
	using ctx
	style.changeStack[style.changeCount] = {
		index = index,
		value = style.colors[index],
	}
	style.changeCount += 1
	style.colors[index] = value
}
PopColor :: proc() {
	using ctx
	assert(style.changeCount > 0)
	style.changeCount -= 1
	style.colors[style.changeStack[style.changeCount].index] = style.changeStack[style.changeCount].value
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
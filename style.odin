package maui

/*
	Default style values
*/
DARK_STYLE_COLORS :: Style_Colors{
	accent = {32, 232, 122, 255},
	accent_text = {0, 0, 0, 255},
	background = {
		{45, 45, 45, 255},
		{70, 70, 70, 255},
	},
	background_stroke = {80, 80, 80, 255},
	foreground = {
		{30, 30, 30, 255},
		{24, 24, 24, 255},
	},
	text = {
		{255, 255, 255, 255},
		{195, 195, 195, 255},
	},
	button = {68, 68, 68, 255},
	button_hovered = {99, 99, 99, 255},
	button_pressed = {99, 184, 54, 255},
	button_text = {255, 255, 255, 255},
	stroke = {124, 152, 165, 255},
	flash = {0, 255, 0, 255},
	substance = {245, 245, 245, 255},
}
/*
	Fonts used in different parts of the ui
*/
Style_Fonts :: struct {
	content,
	label,
	tooltip,
	monospace,
	icon,
	title: Font_Handle,
}
/*
	Text sizes for different things
*/
Style_Text_Size :: struct {
	label,
	title,
	field,
	tooltip: f32,
}
/*
	Some layout guidelines
*/
Style_Layout :: struct {
	widget_padding: f32,
	tooltip_padding: f32,
	size: f32,
	title_size: f32,
	gap_size: f32,
}
/*
	Colors
*/
Style_Colors :: struct {
	text,
	background,
	foreground: [2]Color,
	background_stroke,
	button,
	button_hovered,
	button_pressed,
	button_text,
	substance,
	accent,
	accent_text,
	stroke,
	base,
	flash: Color,
}
/*
	Unified style structure
*/
Style :: struct {
	font: Style_Fonts,
	text_size: Style_Text_Size,
	layout: Style_Layout,
	color: Style_Colors,
	tooltip_rounding,
	tooltip_padding,
	panel_rounding,
	rounding: f32,
	stroke_width: f32,
	title_margin: f32,
	title_padding: f32,
	rounded_corners: Corners,
}
package maui

/*
	Default style values
*/
DARK_STYLE_COLORS :: Style_Colors{
	accent = {215, 75, 178, 255},
	base = {0, 0, 0, 255},
	text = {255, 255, 255, 255},
	flash = {0, 255, 0, 255},
	substance = {255, 255, 255, 255},
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
	substance,
	accent,
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
	panel_rounding,
	rounding: f32,
	stroke_width: f32,
	rounded_corners: Corners,
}
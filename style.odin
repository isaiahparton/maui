package maui

/*
	Default style values
*/
LIGHT_STYLE_COLORS :: Style_Colors{
	accent_hover = {0, 0, 0, 255},
	accent = {
		{32, 100, 221, 255},
		{47, 126, 247, 255},
	},
	base_hover = {205, 180, 255, 25},
	base_click = {0, 180, 255, 25},
	base = {
		{235, 245, 245, 255},
		{205, 215, 216, 255},
	},
	base_text = {
		{112, 112, 112, 255},
		{225, 225, 225, 255},
	},
	substance_hover = {0, 0, 0, 25},
	substance_click = {0, 180, 255, 25},
	substance = {
		{145, 155, 159, 255},
		{95, 95, 97, 255},
	},
	substance_text = {
		{35, 156, 126, 255},
		{4, 52, 22, 255},
	},
}
DARK_STYLE_COLORS :: Style_Colors{
	accent_hover = {0, 0, 0, 255},
	accent = {
		{32, 100, 221, 255},
		{47, 126, 247, 255},
	},
	base_hover = {205, 180, 255, 25},
	base_click = {0, 180, 255, 25},
	base = {
		{33, 32, 37, 255},
		{51, 42, 47, 255},
	},
	base_text = {
		{112, 112, 112, 255},
		{225, 225, 225, 255},
	},
	substance_hover = {205, 180, 255, 25},
	substance_click = {0, 180, 255, 25},
	substance = {
		{57, 55, 59, 255},
		{72, 70, 75, 255},
	},
	substance_text = {
		{35, 36, 36, 255},
		{4, 5, 5, 255},
	},
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
	base,
	base_text,
	substance,
	substance_text,
	accent: [2]Color,
	accent_hover,
	base_click,
	base_hover,
	substance_click,
	substance_hover: Color,
	glass: Color,
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
	rounded_corners: Corners,
}
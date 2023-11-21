package maui

/*
	Default style values
*/
DARK_STYLE_COLORS :: Style_Colors{
	accent = {
		{32, 100, 221, 255},
		{47, 126, 247, 255},
	},
	base = {
		{5, 6, 7, 255},
		{24, 25, 26, 255},
	},
	base_text = {
		{195, 195, 195, 255},
		{195, 195, 195, 255},
	},
	substance = {
		{66, 67, 70, 255},
		{200, 201, 201, 255},
	},
	substance_text = {
		{75, 76, 76, 255},
		{4, 5, 5, 255},
	},
	glass = {210, 225, 230, 255},
}
/*
	Fonts used in different parts of the ui
*/
Style_Fonts :: struct {
	content,
	label,
	tooltip,
	monospace,
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
	button_rounding: f32,
	corner_rounding: Box_Corners,
}

style: Style
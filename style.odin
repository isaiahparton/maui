package maui

/*
	Default style values
*/
DARK_STYLE_COLORS :: Style_Colors{
	accent = {
		{196, 167, 85, 255},
		{255, 201, 28, 255},
	},
	base = {
		{33, 34, 39, 255},
		{33, 34, 39, 255},
	},
	base_text = {
		{195, 195, 195, 255},
		{195, 195, 195, 255},
	},
	substance = {
		{146, 147, 155, 255},
		{200, 201, 201, 255},
	},
	substance_text = {
		{25, 26, 26, 255},
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
}

style: Style
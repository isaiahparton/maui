package maui

/*
	Default style values
*/
DARK_STYLE_COLORS :: Style_Colors{
	status = {248, 226, 34, 255},

	base = {37, 40, 42, 255},
	base_light = {48, 56, 58, 255},
	base_dark = {20, 20, 24, 255},
	base_stroke = {0, 0, 0, 255},

	extrusion = {45, 46, 47, 255},
	extrusion_light = {60, 61, 62, 255},
	extrusion_dark = {30, 31, 32, 255},

	indent = {22, 27, 29, 255},
	indent_dark = {7, 6, 8, 255},
	indent_light = {53, 54, 62, 255},

	text = {195, 195, 195, 255},
	text_highlight = {20, 150, 255, 255},

	scroll_bar = {10, 11, 12, 255},
	scroll_thumb = {43, 44, 45, 255},

	tooltip_stroke = {0, 0, 0, 255},
	tooltip_fill = {210, 215, 215, 255},
	tooltip_text = {25, 25, 26, 255},
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
	// Colorful things
	accent,
	// Things that display status
	status,
	// Base (background)
	base,
	base_light,
	base_dark,
	base_stroke,
	// Things to be pressed
	extrusion,
	extrusion_light,
	extrusion_dark,
	// Indents
	indent,
	indent_dark,
	indent_light,
	// Things to be read
	text,
	text_highlight: Color,
	// Scrollbar
	scroll_bar,
	scroll_thumb: Color,
	// Tooltips
	tooltip_fill,
	tooltip_text,
	tooltip_stroke: Color,
	shadow: Color,
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
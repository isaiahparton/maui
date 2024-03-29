package maui

make_default_style :: proc(painter: ^Painter) -> (style: Style, ok: bool) {
	default_font := load_font(painter, "fonts/Rajdhani-Medium.ttf") or_return
	style, ok = {
		color = get_dark_style_colors(),
		title_margin = 10,
		title_padding = 2,
		layout = {
			title_size = 24,
			size = 24,
			gap_size = 5,
			widget_padding = 7,
		},
		text_size = {
			label = 18,
			title = 18,
			tooltip = 14,
			field = 18,
		},
		rounding = 6,
		stroke_width = 1,
		panel_rounding = 5,
		tooltip_rounding = 5,
		tooltip_padding = 2,
		panel_background_opacity = 0.85,
		font = {
			label 		= default_font,
			title 		= default_font,
			tooltip 	= default_font,
			monospace = load_font(painter, "fonts/UbuntuMono-Regular.ttf") or_return,
			icon 			= load_font(painter, "fonts/Font Awesome 6 Free-Solid-900.otf") or_return,
		},
	}, true
	return
}
/*
	Default style values
*/
get_light_style_colors :: proc() -> Style_Colors {
	return Style_Colors{
		accent = {0, 85, 225, 255},
		accent_text = {0, 0, 0, 255},
		background = {
			{195, 201, 198, 255},
			{165, 170, 166, 255},
		},
		foreground = {
			{255, 255, 255, 255},
			{235, 235, 235, 255},
		},
		text = {
			{0, 0, 0, 255},
			{92, 92, 92, 255},
		},
		panel = {45, 45, 45, 255},
		stroke = {124, 152, 165, 255},
		flash = {0, 255, 0, 255},
		substance = {60, 60, 60, 255},
	}
}
get_dark_style_colors :: proc() -> Style_Colors {
	return Style_Colors{
		accent = {255, 0, 55, 255},
		accent_text = {0, 0, 0, 255},
		background = {
			{25, 32, 29, 255},
			{55, 55, 55, 255},
		},
		foreground = {
			{12, 12, 12, 255},
			{24, 24, 24, 255},
		},
		text = {
			{255, 255, 255, 255},
			{125, 125, 125, 255},
		},
		panel = blend_colors(0.25, {172, 245, 255, 255}, {0, 0, 0, 255}),
		stroke = {124, 152, 165, 255},
		flash = {0, 255, 0, 255},
		substance = {172, 245, 255, 255},
	}
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
	substance,
	accent,
	accent_text,
	stroke,
	base,
	panel,
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
	panel_background_opacity: f32,
	rounded_corners: Corners,
}
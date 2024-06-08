package maui

make_default_style :: proc(painter: ^Painter) -> (style: Style, ok: bool) {
	default_font := load_font(painter, "fonts/Gabarito-Regular.ttf") or_return
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
		accent = {50, 166, 60, 255},
		accent_text = {0, 0, 0, 255},
		background = {
			{210, 218, 212, 255},
			{185, 190, 186, 255},
		},
		foreground = {
			{240, 240, 240, 255},
			{220, 220, 225, 255},
		},
		text = {
			{0, 0, 0, 255},
			{105, 105, 115, 255},
		},
		panel = {45, 45, 45, 255},
		stroke = {124, 152, 165, 255},
		flash = {0, 255, 0, 255},
		substance = {60, 60, 60, 255},
		button = {
			default = {171, 160, 167, 255},
			hovered = {44, 40, 53, 255},
		},
		button_label = {
			default = {0, 0, 0, 255},
			hovered = {255, 255, 255, 255},
		},
	}
}
get_dark_style_colors :: proc() -> Style_Colors {
	return Style_Colors{
		button = {
			default = {85, 85, 89, 255},
			hovered = {200, 200, 200, 255},
		},
		button_shadow = {62, 62, 64, 255},
		floating_button_shade = {255, 255, 255, 70},
		button_label = {
			default = {255, 255, 255, 255},
			hovered = {45, 45, 45, 255},
		},
		icon = {
			default = {255, 255, 255, 255},
			hovered = {230, 212, 32, 255},
		},
		accent = {230, 212, 32, 255},
		accent_text = {0, 0, 0, 255},
		background = {
			{64, 67, 69, 255},
			{72, 73, 75, 255},
		},
		foreground = {
			{45, 46, 50, 255},
			{55, 58, 61, 255},
		},
		hover_shade = {255, 255, 255, 30},
		text = {
			{255, 255, 255, 255},
			{125, 125, 125, 255},
		},
		panel = blend_colors(0.25, {172, 245, 255, 255}, {0, 0, 0, 255}),
		stroke = {124, 152, 165, 255},
		flash = {0, 255, 0, 255},
		substance = {200, 200, 200, 255},
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
Style_Dynamic_Color :: struct {
	default,
	hovered: Color,
}
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
	button_shadow,
	hover_shade,
	floating_button_shade,
	flash: Color,
	// Dynamic colors
	icon,
	button,
	button_label,
	active_button: Style_Dynamic_Color,
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
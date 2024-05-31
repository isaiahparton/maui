package maui

import "vendor:nanovg"

make_default_style :: proc(ctx: ^nanovg.Context) -> (style: Style, ok: bool) {
	default_font := nanovg.CreateFont(ctx, "Default", "fonts/Roboto-Regular.ttf")
	style, ok = {
		color = get_light_style_colors(),
		title_margin = 10,
		title_padding = 2,
		layout = {
			title_size = 24,
			size = 24,
			gap_size = 5,
			widget_padding = 7,
		},
		text_size = {
			label = 16,
			title = 12,
			tooltip = 14,
			field = 16,
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
			monospace = nanovg.CreateFont(ctx, "Monospace", "fonts/UbuntuMono-Regular.ttf"),
			icon 			= nanovg.CreateFont(ctx, "Icon", "fonts/Font Awesome 6 Free-Solid-900.otf"),
		},
	}, true
	return
}
/*
	Default style values
*/
get_light_style_colors :: proc() -> Style_Colors {
	return Style_Colors{
		accent = nanovg.RGBA(25, 128, 224, 255),
		background = {
			nanovg.RGBA(210, 218, 212, 255),
			nanovg.RGBA(185, 190, 186, 255),
		},
		foreground = {
			nanovg.RGBA(240, 240, 240, 255),
			nanovg.RGBA(235, 235, 235, 255),
		},
		text = {
			nanovg.RGBA(0, 0, 0, 255),
			nanovg.RGBA(40, 40, 40, 255),
		},
		substance = nanovg.RGBA(0, 0, 0, 255),
		button = nanovg.RGBA(171, 160, 167, 255),
		button_hovered = nanovg.RGBA(44, 40, 53, 255),
		backing = nanovg.RGBA(215, 215, 215, 255),
		label = nanovg.RGBA(44, 40, 53, 255),
		label_hovered = nanovg.RGBA(255, 255, 255, 255),
	}
}
get_dark_style_colors :: proc() -> Style_Colors {
	return Style_Colors{
		background = {
			nanovg.ColorHex(0xa0a0a0ff),
			nanovg.ColorHex(0xb0b0b0ff),
		},
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
	backing,
	button,
	label,
	button_hovered,
	label_hovered,
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
package maui

import "core:math/linalg"
import rl "vendor:raylib"

Button_Style :: enum {
	filled,
	outlined,
	subtle,
}
// Standalone button for major actions
Pill_Button_Info :: struct {
	label: Label,
	loading: bool,
	fit_to_label: Maybe(bool),
	style: Maybe(Button_Style),
	fill_color: Maybe(Color),
	text_color: Maybe(Color),
}
pill_button :: proc(info: Pill_Button_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	if (info.fit_to_label.? or_else true) && (layout.side == .left || layout.side == .right) {
		layout.size = measure_label(info.label).x + (layout.box.h - layout.margin.y * 2) + layout.margin.x * 2
		if info.loading {
			layout.size += layout.box.h * 0.75
		}
	}
	if self, ok := do_widget(hash(loc), layout_next(layout)); ok {
		using self
		hover_time := animate_bool(self.id, .hovered in state, 0.1)
		if .hovered in self.state {
			core.cursor = .hand
		}
		// Graphics
		if .should_paint in bits {
			roundness := box.h / 2
			switch info.style.? or_else .filled {
				case .filled:
				paint_pill_fill_h(self.box, alpha_blend_colors(get_color(.button_base), get_color(.button_shade), 0.3 if .pressed in self.state else hover_time * 0.15))
				if info.loading {
					paint_loader({self.box.x + self.box.h * 0.75, self.box.y + self.box.h / 2}, self.box.h * 0.25, core.current_time, get_color(.button_text, 0.5))
					paint_label_box(info.label, squish_box_right(self.box, self.box.h * 0.5), get_color(.button_text, 0.5), {.far, .middle})
				} else {
					paint_label_box(info.label, self.box, get_color(.button_text), {.middle, .middle})
				}
				
				case .outlined:
				paint_pill_fill_h(self.box, get_color(.button_base, 0.2 if .pressed in self.state else hover_time * 0.1))
				paint_pill_stroke_h(self.box, true, get_color(.button_base))
				if info.loading {
					paint_loader({self.box.x + self.box.h * 0.75, self.box.y + self.box.h / 2}, self.box.h * 0.25, core.current_time, get_color(.button_base, 0.5))
					paint_label_box(info.label, squish_box_right(self.box, self.box.h * 0.5), get_color(.button_base, 0.5), {.far, .middle})
				} else {
					paint_label_box(info.label, self.box, get_color(.button_base), {.middle, .middle})
				}
			
				case .subtle:
				paint_pill_fill_h(self.box, get_color(.button_base, 0.2 if .pressed in self.state else hover_time * 0.1))
				if info.loading {
					paint_loader({self.box.x + self.box.h * 0.75, self.box.y + self.box.h / 2}, self.box.h * 0.25, core.current_time, get_color(.button_base, 0.5))
					paint_label_box(info.label, squish_box_right(self.box, self.box.h * 0.5), get_color(.button_base, 0.5), {.far, .middle})
				} else {
					paint_label_box(info.label, self.box, get_color(.button_base), {.middle, .middle})
				}
			}

			if info.loading {
				core.paint_next_frame = true
			}
		}
		// Click result
		clicked = .clicked in state && click_button == .left
	}
	return
}

// Square buttons
Button_Info :: struct {
	label: Label,
	align: Maybe(Alignment),
	join: Box_Sides,
	fit_to_label: bool,
	color: Maybe(Color),
	style: Button_Style,
}
button :: proc(info: Button_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	if info.fit_to_label {
		layout_fit_label(layout, info.label)
	}
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(layout)); ok {
		// Animations
		hover_time := animate_bool(self.id, .hovered in self.state, 0.1)
		// Cursor
		if .hovered in self.state {
			core.cursor = .hand
		}
		// Graphics
		if .should_paint in self.bits {
			color := info.color.? or_else get_color(.button_base)
			switch info.style {
				case .filled:
				paint_box_fill(self.box, alpha_blend_colors(color, get_color(.button_shade), 0.3 if .pressed in self.state else hover_time * 0.15))
				paint_label_box(info.label, box_padding(self.box, {self.box.h * 0.25, 0}), get_color(.button_text), {info.align.? or_else .middle, .middle})

				case .outlined:
				paint_box_fill(self.box, fade(color, 0.2 if .pressed in self.state else hover_time * 0.1))
				if .left not_in info.join {
					paint_box_fill({self.box.x, self.box.y, 1, self.box.h}, color)
				}
				if .right not_in info.join {
					paint_box_fill({self.box.x + self.box.w - 1, self.box.y, 1, self.box.h}, color)
				}
				paint_box_fill({self.box.x, self.box.y, self.box.w, 1}, color)
				paint_box_fill({self.box.x, self.box.y + self.box.h - 1, self.box.w, 1}, color)
				
				paint_label_box(info.label, box_padding(self.box, {self.box.h * 0.25, 0}), color, {info.align.? or_else .middle, .middle})

				case .subtle:
				paint_box_fill(self.box, get_color(.button_base, 0.2 if .pressed in self.state else hover_time * 0.1))
				paint_label_box(info.label, box_padding(self.box, {self.box.h * 0.25, 0}), color, {info.align.? or_else .middle, .middle})
			}
		}
		// Result
		clicked = .clicked in self.state && self.click_button == .left
	}
	return
}

// Square buttons that toggle something
Toggle_Button_Info :: struct {
	label: Label,
	state: bool,
	align: Maybe(Alignment),
	fit_to_label: bool,
	join: Box_Sides,
}
toggle_button :: proc(info: Toggle_Button_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	if info.fit_to_label {
		layout_fit_label(layout, info.label)
	}
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(layout)); ok {
		// Animations
		hover_time := animate_bool(self.id, .hovered in self.state, 0.1)
		// Paintions
		if .should_paint in self.bits {
			color := get_color(.accent if info.state else .widget_stroke)
			if info.state {
				paint_box_fill(self.box, get_color(.accent, 0.2 if .pressed in self.state else 0.1))
			} else {
				paint_box_fill(self.box, get_color(.base_shade, 0.2 if .pressed in self.state else 0.1 * hover_time))
			}

			if info.state {
				paint_box_stroke(self.box, 2, get_color(.accent))
			} else {
				color := get_color(.widget_stroke)
				if .left not_in info.join {
					paint_box_fill({self.box.x, self.box.y, 1, self.box.h}, color)
				}
				if .right not_in info.join {
					paint_box_fill({self.box.x + self.box.w - 1, self.box.y, 1, self.box.h}, color)
				}
				paint_box_fill({self.box.x, self.box.y, self.box.w, 1}, color)
				paint_box_fill({self.box.x, self.box.y + self.box.h - 1, self.box.w, 1}, color)
			}

			paint_label_box(info.label, box_padding(self.box, {self.box.h * 0.25, 0}), color, {info.align.? or_else .middle, .middle})
		}
		// Result
		if .clicked in self.state && self.click_button == .left {
			clicked = true
		}
	}
	return
}
toggle_button_bit :: proc(set: ^$S/bit_set[$B], bit: B, label: Label, loc := #caller_location) -> (click: bool) {
	click = toggle_button(
		value = bit in set, 
		label = label, 
		loc = loc,
		)
	if click {
		set^ ~= {bit}
	}
	return
}
enum_toggle_buttons :: proc(value: $T, loc := #caller_location) -> (new_value: T) {
	new_value = value
	for member, i in T {
		push_id(int(member))
			sides: Box_Sides
			if i > 0 {
				sides += {.left}
			}
			if i < len(T) - 1 {
				sides += {.right}
			}
			if toggle_button({label = format(member), state = value == member, join = sides}) {
				new_value = member
			}
		pop_id()
	}
	return
}
// Smol subtle buttons
Floating_Button_Info :: struct {
	icon: Icon,
}
floating_button :: proc(info: Floating_Button_Info, loc := #caller_location) -> (clicked: bool) {
	if self, ok := do_widget(hash(loc), child_box(use_next_box() or_else layout_next(current_layout()), {40, 40}, {.middle, .middle})); ok {
		hover_time := animate_bool(self.id, self.state >= {.hovered}, 0.1)
		// Painting
		if self.bits >= {.should_paint} {
			center := linalg.round(box_center(self.box))
			paint_circle_fill_texture(center + {0, 5}, 40, get_color(.base_shade, 0.2))
			paint_circle_fill_texture(center, 40, alpha_blend_colors(get_color(.button_base), get_color(.button_shade), (2 if self.state >= {.pressed} else hover_time) * 0.1))
			paint_aligned_icon(get_font_data(.header), info.icon, center, 1, get_color(.button_text), {.middle, .middle})
		}
		// Result
		clicked = .clicked in self.state && self.click_button == .left
	}
	return
}
package maui

import "core:math/linalg"
import rl "vendor:raylib"

Button_Style :: enum {
	Filled,
	Outlined,
	Subtle,
}
Button_Shape :: enum {
	Square,
	Pill,
	Left_Arrow,
	Right_Arrow,
}
// Standalone button for major actions
Pill_Button_Info :: struct {
	label: Label,
	loading: bool,
	load_time: Maybe(f32),
	fit_to_label: Maybe(bool),
	style: Maybe(Button_Style),
	fill_color: Maybe(Color),
	text_color: Maybe(Color),
}
do_pill_button :: proc(info: Pill_Button_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	if (info.fit_to_label.? or_else true) && (layout.side == .Left || layout.side == .Right) {
		layout.size = measure_label(info.label).x + (layout.box.h - (layout.margin[.Top] + layout.margin[.Bottom])) + layout.margin[.Left] + layout.margin[.Right]
		if info.loading {
			layout.size += layout.box.h * 0.75
		}
	}
	if self, ok := do_widget(hash(loc), layout_next(layout)); ok {
		using self
		hover_time := animate_bool(self.id, .Hovered in state, 0.1)
		if .Hovered in self.state {
			core.cursor = .Hand
		}
		// Graphics
		if .Should_Paint in bits {
			roundness := box.h / 2
			switch info.style.? or_else .Filled {
				case .Filled:
				paint_pill_fill_h(self.box, alpha_blend_colors(get_color(.Button_Base), get_color(.Button_Shade), 0.3 if .Pressed in self.state else hover_time * 0.15))
				if load_time, ok := info.load_time.?; ok {
					paint_pill_fill_clipped_h(self.box, {self.box.x, self.box.y, self.box.w * load_time, self.box.h}, get_color(.Button_Shade, 0.25))
					if load_time > 0 && load_time < 1 {
						core.paint_next_frame = true
					}
				}
				if info.loading {
					paint_loader({self.box.x + self.box.h * 0.75, self.box.y + self.box.h / 2}, self.box.h * 0.25, f32(core.current_time), get_color(.Button_Text, 0.5))
					paint_label_box(info.label, squish_box_right(self.box, self.box.h * 0.5), get_color(.Button_Text, 0.5), {.Far, .Middle})
				} else {
					paint_label_box(info.label, self.box, get_color(.Button_Text), {.Middle, .Middle})
				}
				
				case .Outlined:
				paint_pill_fill_h(self.box, get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1))
				paint_pill_stroke_h(self.box, true, get_color(.Button_Base))
				if info.loading {
					paint_loader({self.box.x + self.box.h * 0.75, self.box.y + self.box.h / 2}, self.box.h * 0.25, f32(core.current_time), get_color(.Button_Base, 0.5))
					paint_label_box(info.label, squish_box_right(self.box, self.box.h * 0.5), get_color(.Button_Base, 0.5), {.Far, .Middle})
				} else {
					paint_label_box(info.label, self.box, get_color(.Button_Base), {.Middle, .Middle})
				}
			
				case .Subtle:
				paint_pill_fill_h(self.box, get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1))
				if info.loading {
					paint_loader({self.box.x + self.box.h * 0.75, self.box.y + self.box.h / 2}, self.box.h * 0.25, f32(core.current_time), get_color(.Button_Base, 0.5))
					paint_label_box(info.label, squish_box_right(self.box, self.box.h * 0.5), get_color(.Button_Base, 0.5), {.Far, .Middle})
				} else {
					paint_label_box(info.label, self.box, get_color(.Button_Base), {.Middle, .Middle})
				}
			}

			if info.loading {
				core.paint_next_frame = true
			}
		}
		// Click result
		clicked = widget_clicked(self, .Left)
	}
	return
}

// Square buttons
Button_Info :: struct {
	label: Label,
	align: Maybe(Alignment),
	join: Box_Sides,
	color: Maybe(Color),
	fit_to_label: bool,
	style: Button_Style,
}
do_button :: proc(info: Button_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	if info.fit_to_label {
		layout_fit_label(layout, info.label)
	}
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(layout)); ok {
		// Animations
		hover_time := animate_bool(self.id, .Hovered in self.state, 0.1)
		// Cursor
		if .Hovered in self.state {
			core.cursor = .Hand
		}
		// Graphics
		if .Should_Paint in self.bits {
			color := info.color.? or_else get_color(.Button_Base)
			switch info.style {
				case .Filled:
				paint_box_fill(self.box, alpha_blend_colors(color, get_color(.Button_Shade), 0.3 if .Pressed in self.state else hover_time * 0.15))
				paint_label_box(info.label, box_padding(self.box, {self.box.h * 0.25, 0}), get_color(.Button_Text), {info.align.? or_else .Middle, .Middle})

				case .Outlined:
				paint_box_fill(self.box, fade(color, 0.2 if .Pressed in self.state else hover_time * 0.1))
				if .Left not_in info.join {
					paint_box_fill({self.box.x, self.box.y, 1, self.box.h}, color)
				}
				if .Right not_in info.join {
					paint_box_fill({self.box.x + self.box.w - 1, self.box.y, 1, self.box.h}, color)
				}
				paint_box_fill({self.box.x, self.box.y, self.box.w, 1}, color)
				paint_box_fill({self.box.x, self.box.y + self.box.h - 1, self.box.w, 1}, color)
				
				paint_label_box(info.label, box_padding(self.box, {self.box.h * 0.25, 0}), color, {info.align.? or_else .Middle, .Middle})

				case .Subtle:
				paint_box_fill(self.box, get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1))
				paint_label_box(info.label, box_padding(self.box, {self.box.h * 0.25, 0}), color, {info.align.? or_else .Middle, .Middle})
			}
		}
		// Result
		clicked = widget_clicked(self, .Left)
	}
	return
}

// Square buttons that toggle something
Toggle_Button_Info :: struct {
	label: Label,
	state: bool,
	align: Maybe(Alignment),
	color: Maybe(Color),
	fit_to_label: bool,
	join: Box_Sides,
}
do_toggle_button :: proc(info: Toggle_Button_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	if info.fit_to_label {
		layout_fit_label(layout, info.label)
	}
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(layout)); ok {
		// Animations
		hover_time := animate_bool(self.id, .Hovered in self.state, 0.1)
		// Paintions
		if .Should_Paint in self.bits {
			color := get_color(.Accent if info.state else .Widget_Stroke)
			if info.state {
				paint_box_fill(self.box, get_color(.Accent, 0.2 if .Pressed in self.state else 0.1))
			} else {
				paint_box_fill(self.box, get_color(.Base_Shade, 0.2 if .Pressed in self.state else 0.1 * hover_time))
			}

			if info.state {
				paint_box_stroke(self.box, 2, get_color(.Accent))
			} else {
				color := get_color(.Widget_Stroke)
				if .Left not_in info.join {
					paint_box_fill({self.box.x, self.box.y, 1, self.box.h}, color)
				}
				if .Right not_in info.join {
					paint_box_fill({self.box.x + self.box.w - 1, self.box.y, 1, self.box.h}, color)
				}
				if .Top not_in info.join {
					paint_box_fill({self.box.x, self.box.y, self.box.w, 1}, color)
				}
				if .Bottom not_in info.join {
					paint_box_fill({self.box.x, self.box.y + self.box.h - 1, self.box.w, 1}, color)
				}
			}

			paint_label_box(info.label, box_padding(self.box, {self.box.h * 0.25, 0}), color, {info.align.? or_else .Middle, .Middle})
		}
		// Result
		clicked = widget_clicked(self, .Left)
	}
	return
}
do_toggle_button_bit :: proc(set: ^$S/bit_set[$B], bit: B, label: Label, loc := #caller_location) -> (click: bool) {
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
do_enum_toggle_buttons :: proc(value: $T, loc := #caller_location) -> (new_value: T) {
	new_value = value
	layout := current_layout()
	horizontal := layout.side == .Left || layout.side == .Right
	for member, i in T {
		push_id(int(member))
			sides: Box_Sides
			if i > 0 {
				sides += {.Left} if horizontal else {.Top}
			}
			if i < len(T) - 1 {
				sides += {.Right} if horizontal else {.Bottom}
			}
			if do_toggle_button({label = format(member), state = value == member, join = sides}) {
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
do_floating_button :: proc(info: Floating_Button_Info, loc := #caller_location) -> (clicked: bool) {
	if self, ok := do_widget(hash(loc), child_box(use_next_box() or_else layout_next(current_layout()), {40, 40}, {.Middle, .Middle})); ok {
		hover_time := animate_bool(self.id, self.state >= {.Hovered}, 0.1)
		// Painting
		if self.bits >= {.Should_Paint} {
			center := linalg.round(box_center(self.box))
			paint_circle_fill_texture(center + {0, 5}, 40, get_color(.Base_Shade, 0.2))
			paint_circle_fill_texture(center, 40, alpha_blend_colors(get_color(.Button_Base), get_color(.Button_Shade), (2 if self.state >= {.Pressed} else hover_time) * 0.1))
			paint_aligned_icon(get_font_data(.Header), info.icon, center, 1, get_color(.Button_Text), {.Middle, .Middle})
		}
		// Result
		clicked = widget_clicked(self, .Left)
	}
	return
}
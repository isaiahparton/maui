package maui

import "core:math/linalg"
import rl "vendor:raylib"

Button_Style :: enum {
	Filled,
	Outlined,
	Subtle,
}
Button_Shape :: enum {
	Rectangle,
	Pill,
	Left_Arrow,
	Right_Arrow,
}

get_size_for_label :: proc(layout: ^Layout, label: Label) -> Exact {
	return measure_label(label).x + (layout.box.h - get_exact_margin(layout, .Top) - get_exact_margin(layout, .Bottom)) + get_exact_margin(layout, .Left) + get_exact_margin(layout, .Right)
}

// Square buttons
Button_Info :: struct {
	label: Label,
	align: Maybe(Alignment),
	color: Maybe(Color),
	fit_to_label: Maybe(bool),
	loading: bool,
	load_time: Maybe(f32),
	join: Box_Sides,
	style: Button_Style,
	shape: Button_Shape,
}
do_button :: proc(info: Button_Info, loc := #caller_location) -> (clicked: bool) {
	if self, ok := do_widget(hash(loc)); ok {
		layout := current_layout()
		if next_box, ok := use_next_box(); ok {
			self.box = next_box
		} else if int(placement.side) > 1 && (info.fit_to_label.? or_else true) {
			size := get_size_for_label(layout, info.label)
			if info.shape == .Left_Arrow || info.shape == .Right_Arrow {
				size += get_layout_height(layout) / 2
			}
			self.box = layout_next_of_size(layout, size)
		} else {
			self.box = layout_next(layout)
		}
		// Animations
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
		// Update
		update_widget(self)
		// Cursor
		if .Hovered in self.state {
			core.cursor = .Hand
		}
		// Graphics
		if .Should_Paint in self.bits {
			base_color := info.color.? or_else get_color(.Button_Base)
			#partial switch info.shape {
				case .Rectangle:
				switch info.style {
					case .Filled:
					paint_box_fill(self.box, alpha_blend_colors(base_color, get_color(.Button_Shade), fade(255, 0.3 if .Pressed in self.state else hover_time * 0.15)))

					case .Outlined:
					paint_box_fill(self.box, fade(base_color, 0.2 if .Pressed in self.state else hover_time * 0.1))
					if .Left not_in info.join {
						paint_box_fill({self.box.x, self.box.y, 1, self.box.h}, base_color)
					}
					if .Right not_in info.join {
						paint_box_fill({self.box.x + self.box.w - 1, self.box.y, 1, self.box.h}, base_color)
					}
					paint_box_fill({self.box.x, self.box.y, self.box.w, 1}, base_color)
					paint_box_fill({self.box.x, self.box.y + self.box.h - 1, self.box.w, 1}, base_color)

					case .Subtle:
					paint_box_fill(self.box, get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1))
				}

				case .Pill: 
				switch info.style {
					case .Filled:
					paint_pill_fill_h(self.box, alpha_blend_colors(get_color(.Button_Base), get_color(.Button_Shade), 0.3 if .Pressed in self.state else hover_time * 0.15))
					
					case .Outlined:
					paint_pill_fill_h(self.box, get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1))
					paint_pill_stroke_h(self.box, 1, get_color(.Button_Base))
				
					case .Subtle:
					paint_pill_fill_h(self.box, get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1))
				}

				case .Left_Arrow:
				#partial switch info.style {
					case .Filled:
					n := self.box.h * 0.5
					fill_color := alpha_blend_colors(get_color(.Button_Base), get_color(.Button_Shade), 0.3 if .Pressed in self.state else hover_time * 0.15)
					paint_left_ribbon_fill(self.box, fill_color)

					case .Outlined:
					n := self.box.h * 0.5
					fill_color := get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1)
					paint_left_ribbon_fill(self.box, fill_color)
					stroke_color := get_color(.Button_Base)
					paint_left_ribbon_stroke(self.box, stroke_color)
				
					case .Subtle:
					paint_left_ribbon_fill(self.box, get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1))
				}

				case .Right_Arrow:
				#partial switch info.style {
					case .Filled:
					n := self.box.h * 0.5
					fill_color := alpha_blend_colors(get_color(.Button_Base), get_color(.Button_Shade), 0.3 if .Pressed in self.state else hover_time * 0.15)
					paint_right_ribbon_fill(self.box, fill_color)

					case .Outlined:
					n := self.box.h * 0.5
					fill_color := get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1)
					paint_right_ribbon_fill(self.box, fill_color)
					stroke_color := get_color(.Button_Base)
					paint_right_ribbon_stroke(self.box, stroke_color)
				
					case .Subtle:
					paint_right_ribbon_fill(self.box, get_color(.Button_Base, 0.2 if .Pressed in self.state else hover_time * 0.1))
				}
			}
			label_color := get_color(.Button_Text if info.style == .Filled else .Button_Base)
			if info.loading {
				loader_time := animate_bool(&self.timers[1], info.loading, 0.25)
				paint_loader(box_center(self.box), self.box.h * 0.3, f32(core.current_time), fade(label_color, loader_time))
			} else {
				paint_label_box(info.label, self.box, label_color, .Middle, .Middle)
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
	if self, ok := do_widget(hash(loc)); ok {
		layout := current_layout()
		if next_box, ok := use_next_box(); ok {
			self.box = next_box
		} else if int(placement.side) > 1 {
			self.box = layout_next_of_size(layout, get_size_for_label(layout, info.label))
		} else {
			self.box = layout_next(layout)
		}
		update_widget(self)
		// Animations
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
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

			paint_label_box(info.label, box_padding(self.box, {self.box.h * 0.25, 0}), color, .Middle, .Middle)
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
	if self, ok := do_widget(hash(loc)); ok {
		self.box = child_box(use_next_box() or_else layout_next(current_layout()), {40, 40}, {.Middle, .Middle})
		hover_time := animate_bool(&self.timers[0], self.state >= {.Hovered}, 0.1)
		update_widget(self)
		// Painting
		if self.bits >= {.Should_Paint} {
			center := linalg.round(box_center(self.box))
			paint_circle_fill_texture(center + {0, 5}, 40, get_color(.Base_Shade, 0.2))
			paint_circle_fill_texture(center, 40, alpha_blend_colors(get_color(.Button_Base), get_color(.Button_Shade), (2 if self.state >= {.Pressed} else hover_time) * 0.1))
			paint_aligned_icon(painter.style.button_font, info.icon, center, 1, get_color(.Button_Text), {.Middle, .Middle})
		}
		// Result
		clicked = widget_clicked(self, .Left)
	}
	return
}
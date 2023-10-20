package maui_widgets
import "../"

import "core:fmt"
import "core:math/linalg"

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

// Square buttons
Button_Info :: struct {
	label: maui.Label,
	align: Maybe(maui.Alignment),
	color: Maybe(maui.Color),
	fit_to_label: Maybe(bool),
	loading: bool,
	load_time: Maybe(f32),
	join: maui.Box_Sides,
	style: Button_Style,
	shape: Button_Shape,
}
do_button :: proc(info: Button_Info, loc := #caller_location) -> (clicked: bool) {
	using maui
	if self, ok := do_widget(hash(loc)); ok {
		// Colocate
		layout := current_layout()
		if next_box, ok := use_next_box(); ok {
			self.box = next_box
		} else if int(placement.side) > 1 && (info.fit_to_label.? or_else false) {
			size := get_size_for_label(layout, info.label)
			if info.shape == .Left_Arrow || info.shape == .Right_Arrow {
				size += get_layout_height(layout) / 2
			}
			self.box = layout_next_of_size(layout, size)
		} else {
			self.box = layout_next(layout)
		}
		// Update
		update_widget(self)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
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
					paint_box_fill(self.box, alpha_blend_colors(base_color, get_color(.Button_Shade), 1 if .Pressed in self.state else hover_time * 0.5))

					case .Outlined:
					paint_box_fill(self.box, fade(base_color, 0.3 if .Pressed in self.state else hover_time * 0.15))
					paint_box_stroke(self.box, painter.style.stroke_thickness, base_color)

					case .Subtle:
					paint_box_fill(self.box, fade(base_color, 0.3 if .Pressed in self.state else hover_time * 0.15))
				}

				case .Pill: 
				switch info.style {
					case .Filled:
					paint_pill_fill_h(self.box, alpha_blend_colors(base_color, get_color(.Button_Shade), 1 if .Pressed in self.state else hover_time * 0.5))
					
					case .Outlined:
					paint_pill_fill_h(self.box, fade(base_color, 0.3 if .Pressed in self.state else hover_time * 0.15))
					paint_pill_stroke_h(self.box, painter.style.stroke_thickness, get_color(.Button_Base))
				
					case .Subtle:
					paint_pill_fill_h(self.box, fade(base_color, 0.3 if .Pressed in self.state else hover_time * 0.15))
				}

				case .Left_Arrow:
				#partial switch info.style {
					case .Filled:
					fill_color := alpha_blend_colors(get_color(.Button_Base), get_color(.Button_Shade), 1 if .Pressed in self.state else hover_time * 0.5)
					paint_left_ribbon_fill(self.box, fill_color)

					case .Outlined:
					fill_color := fade(base_color, 0.3 if .Pressed in self.state else hover_time * 0.15)
					paint_left_ribbon_fill(self.box, fill_color)
					stroke_color := get_color(.Button_Base)
					paint_left_ribbon_stroke(self.box, painter.style.stroke_thickness, stroke_color)
				
					case .Subtle:
					paint_left_ribbon_fill(self.box, fade(base_color, 0.3 if .Pressed in self.state else hover_time * 0.15))
				}

				case .Right_Arrow:
				#partial switch info.style {
					case .Filled:
					fill_color := alpha_blend_colors(get_color(.Button_Base), get_color(.Button_Shade), 1 if .Pressed in self.state else hover_time * 0.5)
					paint_right_ribbon_fill(self.box, fill_color)

					case .Outlined:
					fill_color := fade(base_color, 0.3 if .Pressed in self.state else hover_time * 0.15)
					paint_right_ribbon_fill(self.box, fill_color)
					stroke_color := get_color(.Button_Base)
					paint_right_ribbon_stroke(self.box, painter.style.stroke_thickness, stroke_color)
				
					case .Subtle:
					paint_right_ribbon_fill(self.box, fade(base_color, 0.3 if .Pressed in self.state else hover_time * 0.15))
				}
			}
			label_color := get_color(.Button_Text if info.style == .Filled else .Button_Base)
			if info.loading {
				loader_time := animate_bool(&self.timers[1], info.loading, 0.25)
				paint_loader(box_center(self.box), height(self.box) * 0.3, f32(core.current_time), fade(label_color, loader_time))
			} else {
				paint_label_box(info.label, self.box, label_color, .Middle, .Middle)
			}
		}
		// Result
		clicked = widget_clicked(self, .Left)
		// Update hover
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}
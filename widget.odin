package maui

import "core:fmt"
import "core:math"
import "core:mem"
import "core:runtime"
import "core:unicode/utf8"
import "core:math/ease"
import "core:math/linalg"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:time"

MAX_WIDGET_TIMERS :: 3
DEFAULT_WIDGET_HOVER_TIME :: 0.1
DEFAULT_WIDGET_PRESS_TIME :: 0.075

// General purpose booleans
Widget_Bit :: enum {
	// Widget thrown away if no
	Stay_Alive,
	// For independently toggled widgets
	Active,
	// If the widget is diabled (duh)
	Disabled,
	// For attached menus
	Menu_Open,
	// Should be painted this frame
	Should_Paint,
	Negative,
}

Widget_Bits :: bit_set[Widget_Bit]

// Behavior options
Widget_Option :: enum {
	// The widget does not receive input
	Static,
	// The widget will maintain focus, hover and press state if
	// the mouse is held after clicking even when not hovered
	Draggable,
	// If the widget can be selected with the keyboard
	Can_Key_Select,
}

Widget_Options :: bit_set[Widget_Option]

// Interaction state
Widget_Status :: enum {
	// Just got status
	Got_Hover,
	Got_Focus,
	Got_Press,
	// Has status
	Hovered,
	Focused,
	Pressed,
	// Just lost status
	Lost_Hover,
	Lost_Focus,
	Lost_Press,
	// Data modified
	Changed,
	// Pressed and released
	Clicked,
}

Widget_State :: bit_set[Widget_Status]

// Universal control data (stoopid get rid of it)
Widget :: struct {
	id: 						Id,
	box: 						Box,
	bits: 					Widget_Bits,
	options: 				Widget_Options,
	state: 					Widget_State,
	click_button:  	Mouse_Button,
	click_time: 		time.Time,
	click_count: 		int,
	// Parent layer
	layer: 					^Layer,
	// Retained data (impossible!!)
	offset,
	label_size: [2]f32,
	timers: [MAX_WIDGET_TIMERS]f32,
}

WIDGET_STACK_SIZE :: 32

Widget_Agent :: struct {
	list: [dynamic]^Widget,
	stack: [WIDGET_STACK_SIZE]^Widget,
	stack_height: int,
	last_widget,
	current_widget: ^Widget,
	// State
	last_hover_id, 
	next_hover_id, 
	hover_id, 
	last_press_id, 
	press_id, 
	next_focus_fd,
	focus_id,
	last_focus_id: Id,
	dragging,
	auto_focus,
	will_auto_focus: bool,
}

widget_agent_assert :: proc(using self: ^Widget_Agent, id: Id) -> (widget: ^Widget, ok: bool) {
	layer := current_layer()
	widget, ok = layer.contents[id]
	if !ok {
		widget, ok = widget_agent_create(self, id, layer)
	}
	assert(ok)
	assert(widget != nil)
	return
}

widget_agent_create :: proc(using self: ^Widget_Agent, id: Id, layer: ^Layer) -> (widget: ^Widget, ok: bool) {
	widget = new(Widget)
	widget^ = {
		id = id,
		layer = layer,
	}
	append(&list, widget)
	layer.contents[id] = widget
	painter.next_frame = true
	ok = true

	when ODIN_DEBUG && PRINT_DEBUG_EVENTS {
		fmt.printf("+ Widget %x\n", id)
	}

	return
}

widget_agent_push :: proc(using self: ^Widget_Agent, widget: ^Widget) {
	stack[stack_height] = widget
	stack_height += 1
	current_widget = widget
	last_widget = widget
}

widget_agent_pop :: proc(using self: ^Widget_Agent, loc := #caller_location) {
	assert(stack_height > 0, "", loc)
	stack_height -= 1
	if stack_height > 0 {
		current_widget = stack[stack_height - 1]
	} else {
		current_widget = nil
	}
}

widget_agent_destroy :: proc(using self: ^Widget_Agent) {
	for entry in list {
		free(entry)
	}
	delete(list)
}

widget_agent_step :: proc(using self: ^Widget_Agent) {
	dragging = false
	auto_focus = will_auto_focus
	will_auto_focus = false
	for widget, i in &list {
		if .Stay_Alive in widget.bits {
			widget.bits -= {.Stay_Alive}
		} else {
			when ODIN_DEBUG && PRINT_DEBUG_EVENTS {
				fmt.printf("- Widget %x\n", widget.id)
			}
			
			for key, value in widget.layer.contents {
				if key == widget.id {
					delete_key(&widget.layer.contents, key)
				}
			}
			free(widget)
			ordered_remove(&list, i)
			// Make sure we paint the next frame
			painter.next_frame = true
		}
	}
}

widget_agent_update_ids :: proc(using self: ^Widget_Agent) {
	last_hover_id = hover_id
	last_press_id = press_id
	last_focus_id = focus_id
	hover_id = next_hover_id
	if dragging && press_id != 0 {
		hover_id = press_id
	}
	if core.is_key_selecting {
		hover_id = focus_id
		if key_pressed(.Enter) {
			press_id = hover_id
		}
	}
	next_hover_id = 0
	if mouse_pressed(.Left) {
		press_id = hover_id
		focus_id = press_id
	}
	dragging = false
}

update_widget_hover :: proc(w: ^Widget, condition: bool) {
	if !(core.widget_agent.dragging && w.id != core.widget_agent.hover_id) && core.layer_agent.hover_id == w.layer.id && condition {
		core.widget_agent.next_hover_id = w.id
	}
}
widget_agent_update_state :: proc(using self: ^Widget_Agent, w: ^Widget) {
	assert(w != nil)
	// If hovered
	if hover_id == w.id {
		w.state += {.Hovered}
		if last_hover_id != w.id {
			w.state += {.Got_Hover}
		}
		pressed_buttons := input.mouse_bits - input.last_mouse_bits
		if pressed_buttons != {} {
			if w.click_count == 0 {
				w.click_button = input.last_mouse_button
			}
			if w.click_button == input.last_mouse_button && time.since(w.click_time) <= DOUBLE_CLICK_TIME {
				w.click_count = (w.click_count + 1) % MAX_CLICK_COUNT
			} else {
				w.click_count = 0
			}
			w.click_button = input.last_mouse_button
			w.click_time = time.now()
			press_id = w.id
		}
	} else {
		if last_hover_id == w.id {
			w.state += {.Lost_Hover}
		}
		if press_id == w.id {
			if .Draggable not_in w.options {
				press_id = 0
			}
		}
		if .Draggable not_in w.options {
			w.click_count = 0
		}
	}
	// Press
	if press_id == w.id {
		w.state += {.Pressed}
		if last_press_id != w.id {
			w.state += {.Got_Press}
		}
		// Just released buttons
		released_buttons := input.last_mouse_bits - input.mouse_bits
		if released_buttons != {} {
			for button in Mouse_Button {
				if button == w.click_button {
					w.state += {.Clicked}
					break
				}
			}
			w.state += {.Lost_Press}
			press_id = 0
		}
		dragging = .Draggable in w.options
	} else if last_press_id == w.id {
		w.state += {.Lost_Press}
	}
	// Focus
	if focus_id == w.id {
		w.state += {.Focused}
		if last_focus_id != w.id {
			w.state += {.Got_Focus}
		}
	} else if last_focus_id == w.id {
		w.state += {.Lost_Focus}
	}
}

update_widget :: proc(w: ^Widget) {
	// Prepare widget
	w.state = {}
	w.bits += {.Stay_Alive}
	if core.disabled {
		w.bits += {.Disabled}
	} else {
		w.bits -= {.Disabled}
	}
	if painter.this_frame && get_clip(current_layer().box, w.box) != .Full {
		w.bits += {.Should_Paint}
	} else {
		w.bits -= {.Should_Paint}
	}

	core.last_box = w.box
	// Get input
	if !core.disabled {
		widget_agent_update_state(&core.widget_agent, w)
	}
}

// Main widget functionality
@(deferred_out=_do_widget)
do_widget :: proc(id: Id, options: Widget_Options = {}) -> (self: ^Widget, ok: bool) {
	// Check if clipped
	self, ok = widget_agent_assert(&core.widget_agent, id)
	if !ok {
		return
	}
	self.options = options
	widget_agent_push(&core.widget_agent, self)
	return
}

@private
_do_widget :: proc(self: ^Widget, ok: bool) {
	if ok {
		assert(self != nil)
		// Pop widget stack
		widget_agent_pop(&core.widget_agent)
		// Update the parent layer's content box
		self.layer.content_box = update_bounding_box(self.layer.content_box, self.box)
		// Update group if there is one
		if core.group_stack.height > 0 {
			stack_top_ref(&core.group_stack).state += self.state
		}
		// Display tooltip if there is one
		if core.next_tooltip != nil {
			if self.state >= {.Hovered} {
				tooltip_box(self.id, core.next_tooltip.?.text, self.box, core.next_tooltip.?.box_side, 10)
			}
			core.next_tooltip = nil
		}
	}
}

// Helper functions
current_widget :: proc(loc := #caller_location) -> ^Widget {
	assert(core.widget_agent.current_widget != nil, "There is no current widget", loc)
	return core.widget_agent.current_widget
}

last_widget :: proc(loc := #caller_location) -> ^Widget {
	assert(core.widget_agent.last_widget != nil, "There is no previous widget", loc)
	return core.widget_agent.last_widget
}

widget_clicked :: proc(using self: ^Widget, button: Mouse_Button, times: int = 1) -> bool {
	return .Clicked in state && click_button == button && click_count >= times - 1
}

Tooltip_Info :: struct {
	text: string,
	box_side: Box_Side,
}

attach_tooltip :: proc(text: string, side: Box_Side) {
	core.next_tooltip = Tooltip_Info({
		text = text,
		box_side = side,
	})
}

tooltip :: proc(id: Id, text: string, origin: [2]f32, align: [2]Alignment, side: Maybe(Box_Side) = nil) {
	text_size := measure_text({
		text = text,
		font = style.font.title,
		size = style.text_size.title,
	})
	PADDING :: 3
	size := text_size + PADDING * 2
	box: Box
	switch align.x {
		case .Near: box.low.x = origin.x
		case .Far: box.low.x = origin.x - size.x
		case .Middle: box.low.x = origin.x - size.x / 2
	}
	switch align.y {
		case .Near: box.low.y = origin.y
		case .Far: box.low.y = origin.y - size.y
		case .Middle: box.low.y = origin.y - size.y / 2
	}
	box.high = box.low + size
	if layer, ok := begin_layer({
		placement = box, 
		id = id,
		options = {.No_Scroll_X, .No_Scroll_Y},
	}); ok {
		layer.order = .Tooltip
		BLACK :: Color{0, 0, 0, 255}
		paint_rounded_box_fill(layer.box, style.tooltip_rounding, {0, 0, 0, 255})
		if side, ok := side.?; ok {
			SIZE :: 5
			#partial switch side {
				case .Bottom: 
				c := (layer.box.high.x + layer.box.low.x) / 2
				paint_triangle_fill({c - SIZE, layer.box.low.y}, {c + SIZE, layer.box.low.y}, {c, layer.box.low.y - SIZE}, BLACK)
				case .Top:
				c := (layer.box.high.x + layer.box.low.x) / 2
				paint_triangle_fill({c - SIZE, layer.box.high.y}, {c, layer.box.high.y + SIZE}, {c + SIZE, layer.box.high.y}, BLACK)
				case .Right:
				c := (layer.box.low.y + layer.box.high.y) / 2
				paint_triangle_fill({layer.box.low.x, c - SIZE}, {layer.box.low.x, c + SIZE}, {layer.box.low.x - SIZE, c}, BLACK)
				case .Left:
				c := (layer.box.low.y + layer.box.high.y) / 2
				paint_triangle_fill({layer.box.high.x, c - SIZE}, {layer.box.high.x + SIZE, c}, {layer.box.high.x, c + SIZE}, BLACK)
			}
		}
		paint_text(
			layer.box.low + PADDING, 
			{font = style.font.title, size = style.text_size.title, text = text}, 
			{}, 
			255,
			)
		end_layer(layer)
	}
}

tooltip_box ::proc(id: Id, text: string, anchor: Box, side: Box_Side, offset: f32) {
	origin: [2]f32
	align: [2]Alignment
	switch side {
		case .Bottom:		
		origin.x = (anchor.low.x + anchor.high.x) / 2
		origin.y = anchor.high.y + offset
		align.x = .Middle
		align.y = .Near
		case .Left:
		origin.x = anchor.low.x - offset
		origin.y = (anchor.low.y + anchor.high.y) / 2
		align.x = .Near
		align.y = .Middle
		case .Right:
		origin.x = anchor.high.x - offset
		origin.y = (anchor.low.y + anchor.high.y) / 2
		align.x = .Far
		align.y = .Middle
		case .Top:
		origin.x = (anchor.low.x + anchor.high.x) / 2
		origin.y = anchor.low.y - offset
		align.x = .Middle
		align.y = .Far
	}
	tooltip(id, text, origin, align, side)
}

// Labels
Label :: union {
	string,
	rune,
}

Paint_Label_Info :: struct {
	align: [2]Alignment,
	clip_box: Maybe(Box),
}

get_size_for_label :: proc(l: ^Layout, label: Label) -> Exact {
	return measure_label(label).x + get_layout_height(l) + get_exact_margin(l, .Left) + get_exact_margin(l, .Right)
}

paint_label :: proc(label: Label, origin: [2]f32, color: Color, align: Text_Align, baseline: Text_Baseline) -> [2]f32 {
	switch variant in label {
		case string: 	
		return paint_text(origin, {font = style.font.label, size = style.text_size.label, text = variant}, {align = align, baseline = baseline}, color)

		case rune: 		
		return paint_aligned_rune(style.font.label, style.text_size.label, rune(variant), linalg.floor(origin), color, {.Middle, .Middle})
	}
	return {}
}

paint_label_box :: proc(label: Label, box: Box, color: Color, align: Text_Align, baseline: Text_Baseline) {
	origin: [2]f32 = box.low
	#partial switch align {
		case .Right: origin.x += width(box)
		case .Middle: origin.x += width(box) * 0.5
	}
	#partial switch baseline {
		case .Bottom: origin.y += height(box)
		case .Middle: origin.y += height(box) * 0.5
	}
	paint_label(label, origin, color, align, baseline)
}

measure_label :: proc(label: Label) -> (size: [2]f32) {
	switch variant in label {
		case string: 
		size = measure_text({
			text = variant,
			font = style.font.label,
			size = style.text_size.label, 
		})

		case rune:
		font := &painter.atlas.fonts[style.font.label]
		if font_size, ok := get_font_size(font, style.text_size.label); ok {
			if glyph, ok := get_font_glyph(font, font_size, rune(variant)); ok {
				size = glyph.src.high - glyph.src.low
			}
		}
	}
	return
}

// Just a line
do_divider :: proc(size: f32) {
	layout := current_layout()
	box := cut_box(&layout.box, placement.side, Exact(1))
	paint_box_fill(box, style.color.accent[1])
}

/*
	Progress bar
*/
do_progress_bar :: proc(value: f32) {
	box := layout_next(current_layout())
	radius := height(box) * 0.5
	paint_rounded_box_fill(box, radius, style.color.base[1])
	paint_rounded_box_fill({box.low, {box.low.x + width(box) * clamp(value, 0, 1), box.high.y}}, radius, style.color.accent[1])
}

//TODO: Re-implement
/*
Image_Fitting :: enum {
	Width,
	Height,
}
Image_Info :: struct {
	image: Image_Index,
	fit: Maybe(Image_Fitting),
	color: Maybe(Color),
}
do_image :: proc(info: Image_Info) {
	box := layout_next(current_layout())
	size := linalg.array_cast(painter.images[info.image].size, f32)
	if info.fit == .Width {
		if size.x > box.w {
			size.y *= box.w / size.x
			size.x = box.w 
		}
	} else if info.fit == .Height {
		if size.y > box.h {
			size.x *= box.h / size.y
			size.y = box.h
		}
	}
	set_next_box(box)
	if do_frame({
		layout_size = size,
		options = {.No_Scroll_Margin_X},
	}) {
		placement.size = size.y
		image_box := layout_next(current_layout())
		paint_image(info.image, {0, 0, 1, 1}, image_box, info.color.? or_else 255)
		layer := current_layer()
		layer.content_box = update_bounding_box(layer.content_box, image_box)
	}
}
*/
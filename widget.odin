/*
	How to program a widget
		Create -> Set box -> Animate -> Update -> Paint -> Result
*/
package maui

import "core:fmt"
import "core:math"
import "core:runtime"
import "core:unicode/utf8"
import "core:math/ease"
import "core:math/linalg"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:time"

MAX_WIDGET_TIMERS :: 3

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
	core.paint_next_frame = true
	ok = true
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
	for widget, i in &list {
		if .Stay_Alive in widget.bits {
			widget.bits -= {.Stay_Alive}
		} else {
			for key, value in widget.layer.contents {
				if key == widget.id {
					delete_key(&widget.layer.contents, key)
				}
			}
			free(widget)
			ordered_remove(&list, i)
		}
	}
}

widget_agent_update_ids :: proc(using self: ^Widget_Agent) {
	last_hover_id = hover_id
	last_press_id = press_id
	last_focus_id = focus_id
	hover_id = next_hover_id
	if core.dragging && press_id != 0 {
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
}

update_widget_hover :: proc(wdg: ^Widget, condition: bool) {
	if core.layer_agent.hover_id == wdg.layer.id && condition {
		core.widget_agent.next_hover_id = wdg.id
	}
}
widget_agent_update_state :: proc(using self: ^Widget_Agent, layer_agent: ^Layer_Agent, wdg: ^Widget) {
	assert(wdg != nil)
	// If hovered
	if hover_id == wdg.id {
		wdg.state += {.Hovered}
		if last_hover_id != wdg.id {
			wdg.state += {.Got_Hover}
		}
		pressed_buttons := input.mouse_bits - input.last_mouse_bits
		if pressed_buttons != {} {
			if wdg.click_count == 0 {
				wdg.click_button = input.last_mouse_button
			}
			if wdg.click_button == input.last_mouse_button && time.since(wdg.click_time) <= DOUBLE_CLICK_TIME {
				wdg.click_count = (wdg.click_count + 1) % MAX_CLICK_COUNT
			} else {
				wdg.click_count = 0
			}
			wdg.click_button = input.last_mouse_button
			wdg.click_time = time.now()
			press_id = wdg.id
		}
	} else {
		if last_hover_id == wdg.id {
			wdg.state += {.Lost_Hover}
		}
		if press_id == wdg.id {
			if .Draggable in wdg.options {
				if .Pressed not_in wdg.state {
					press_id = 0
				}
			} else  {
				press_id = 0
			}
		}
		wdg.click_count = 0
	}
	// Press
	if press_id == wdg.id {
		wdg.state += {.Pressed}
		if last_press_id != wdg.id {
			wdg.state += {.Got_Press}
		}
		// Just released buttons
		released_buttons := input.last_mouse_bits - input.mouse_bits
		if released_buttons != {} {
			for button in Mouse_Button {
				if button == wdg.click_button {
					wdg.state += {.Clicked}
					break
				}
			}
			wdg.state += {.Lost_Press}
			press_id = 0
		}
		core.dragging = .Draggable in wdg.options
	} else if last_press_id == wdg.id {
		wdg.state += {.Lost_Press}
	}
	// Focus
	if focus_id == wdg.id {
		wdg.state += {.Focused}
		if last_focus_id != wdg.id {
			wdg.state += {.Got_Focus}
		}
	} else if last_focus_id == wdg.id {
		wdg.state += {.Lost_Focus}
	}
}

update_widget :: proc(self: ^Widget) {
	// Prepare widget
	self.state = {}
	self.bits += {.Stay_Alive}
	if core.disabled {
		self.bits += {.Disabled}
	} else {
		self.bits -= {.Disabled}
	}
	if core.paint_this_frame || core.painted_last_frame {
		self.bits += {.Should_Paint}
	} else {
		self.bits -= {.Should_Paint}
	}

	core.last_box = self.box
	// Get input
	if !core.disabled {
		widget_agent_update_state(&core.widget_agent, &core.layer_agent, self)
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
		widget_agent_pop(&core.widget_agent)
		// Shade over the widget if it is disabled
		if .Disabled in self.bits {
			paint_disable_shade(self.box)
		}
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

attach_tooltip :: proc(text: string, side: Box_Side) {
	core.next_tooltip = Tooltip_Info({
		text = text,
		box_side = side,
	})
}

paint_disable_shade :: proc(box: Box) {
	paint_box_fill(box, get_color(.Base, DISABLED_SHADE_ALPHA))
}

tooltip :: proc(id: Id, text: string, origin: [2]f32, align: [2]Alignment) {
	text_size := measure_text({
		text = text,
		font = painter.style.title_font,
		size = painter.style.title_font_size,
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
		box = box, 
		id = id,
		options = {.No_Scroll_X, .No_Scroll_Y},
	}); ok {
		layer.order = .Tooltip
		paint_rounded_box_fill(layer.box, 3, get_color(.Tooltip_Fill))
		paint_rounded_box_stroke(layer.box, 3, 1, get_color(.Tooltip_Stroke))
		paint_text(
			layer.box.low + PADDING, 
			{font = painter.style.title_font, size = painter.style.title_font_size, text = text}, 
			{align = .Left}, 
			get_color(.Tooltip_Text),
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
	tooltip(id, text, origin, align)
}

// Labels
Label :: union {
	string,
	Icon,
}

Paint_Label_Info :: struct {
	align: [2]Alignment,
	clip_box: Maybe(Box),
}

paint_label :: proc(label: Label, origin: [2]f32, color: Color, align: Text_Align, baseline: Text_Baseline) -> [2]f32 {
	switch variant in label {
		case string: 	
		return paint_text(origin, {font = painter.style.button_font, size = painter.style.button_font_size, text = variant}, {align = align, baseline = baseline}, color)

		case Icon: 		
		//return paint_aligned_icon(painter.style.button_font, rune(variant)), linalg.floor(origin), color, info.align)
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
			font = painter.style.button_font,
			size = painter.style.button_font_size, 
		})

		case Icon:
		font := &painter.atlas.fonts[painter.style.button_font]
		if font_size, ok := get_font_size(font, painter.style.button_font_size); ok {
			if glyph, ok := get_font_glyph(font, font_size, rune(variant)); ok {
				size = glyph.src.high - glyph.src.low
			}
		}
	}
	return
}


Nav_Menu_Option_Info :: struct {
	index: int,
	icon: Icon,
	name: string,
}
Nav_Menu_Section_Info :: struct {
	name: string,
}
Nav_Menu_Item_Info :: union {
	Nav_Menu_Option_Info,
	Nav_Menu_Section_Info,
}

Nav_Menu_Info :: struct {
	current_index: int,
	items: []Nav_Menu_Item_Info,
}

do_nav_menu :: proc(info: Nav_Menu_Info, loc := #caller_location) -> (result: Maybe(int)) {

	option_counter: int 

	for &item_union, i in info.items {
		push_id(i)
		switch item in item_union {
			case Nav_Menu_Option_Info: 
			placement.size = Exact(30)
			if self, ok := do_widget(hash(loc)); ok {
				self.box = layout_next(current_layout())
				self.box.high.y += 1
				hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
				state_time := animate_bool(&self.timers[1], info.current_index == item.index, 0.15)
				update_widget(self)
				if .Should_Paint in self.bits {
					box := self.box

					stroke_color := alpha_blend_colors(get_color(.Base), get_color(.Intense), 0.5 * (1 - hover_time))
					if state_time < 1 {
						if option_counter == 0  {
							paint_box_fill({box.low, {box.high.x, box.high.y + 1}}, stroke_color)
						}
						paint_box_fill({{box.low.x, box.high.y - 1}, box.high}, stroke_color)
					}

					fill_color := fade(alpha_blend_colors(get_color(.Base), get_color(.Intense), min(0.5 + state_time, 1)), 1 if info.current_index == item.index else hover_time)
					paint_right_ribbon_fill(box, fill_color)

					text_color := blend_colors(get_color(.Intense, 0.5 + hover_time), get_color(.Base), state_time)
					paint_aligned_icon(painter.style.button_font, painter.style.button_font_size, item.icon, center(self.box), text_color, {.Middle, .Middle})
					paint_text(
						{self.box.low.x + height(self.box) * ease.cubic_in_out(state_time) * 0.3, center_y(self.box)}, 
						{text = item.name, font = painter.style.default_font, size = painter.style.default_font_size}, 
						{align = .Left, baseline = .Middle},
						text_color,
						)
				}
				
				if widget_clicked(self, .Left) {
					result = item.index
				}
			}
			option_counter += 1

			case Nav_Menu_Section_Info:
			option_counter = 0
			placement.align.x = .Middle
			space(Exact(20))
			//TODO: Re-implement this
			/*do_text({
				text = item.name,
				fit = true,
				font = .Label,
				color = get_color(.Intense, 0.5),
			})*/
			space(Exact(6))
		}
		
		pop_id()
	}
	return
}

// [SECTION] BOOLEAN CONTROLS
Check_Box_Status :: enum u8 {
	On,
	Off,
	Unknown,
}

Check_Box_State :: union {
	bool,
	^bool,
	Check_Box_Status,
}

Check_Box_Info :: struct {
	state: Check_Box_State,
	text: Maybe(string),
	text_side: Maybe(Box_Side),
}

evaluate_checkbox_state :: proc(state: Check_Box_State) -> bool {
	active: bool
	switch v in state {
		case bool:
		active = v

		case ^bool:
		active = v^

		case Check_Box_Status:
		active = v != .Off
	}
	return active
}

//#Info fields
// - `state` Either a `bool`, a `^bool` or one of `{.on, .off, .unknown}`
// - `text` If defined, the check box will display text on `text_side` of itself
// - `text_side` The side on which text will appear (defaults to left)
do_checkbox :: proc(info: Check_Box_Info, loc := #caller_location) -> (change, new_state: bool) {
	SIZE :: 22
	HALF_SIZE :: SIZE / 2

	// Check if there is text
	has_text := info.text != nil

	// Default orientation
	text_side := info.text_side.? or_else .Left

	// Determine total size
	size, text_size: [2]f32
	if has_text {
		text_size = measure_text({font = painter.style.default_font, size = painter.style.default_font_size, text = info.text.?})
		if text_side == .Bottom || text_side == .Top {
			size.x = max(SIZE, text_size.x)
			size.y = SIZE + text_size.y
		} else {
			size.x = SIZE + text_size.x + WIDGET_TEXT_OFFSET * 2
			size.y = SIZE
		}
	} else {
		size = SIZE
	}
	layout := current_layout()
	//placement.size = size.x if layout.side == .Left || layout.side == .Right else size.y

	// Widget
	if self, ok := do_widget(hash(loc)); ok {
		using self
		self.box = use_next_box() or_else layout_next_child(layout, size)
		update_widget(self)
		// Determine state
		active := evaluate_checkbox_state(info.state)
		// Animate
		hover_time := animate_bool(&self.timers[0], .Hovered in state, 0.15)
		state_time := animate_bool(&self.timers[1], active, 0.3)
		// Painting
		if .Should_Paint in bits {
			icon_box: Box
			if has_text {
				switch text_side {
					case .Left: 	
					icon_box = {box.low, SIZE}
					case .Right: 	
					icon_box = {{box.high.x - SIZE, box.low.y}, SIZE}
					case .Top: 		
					icon_box = {{center_x(box) - HALF_SIZE, box.high.y - SIZE}, SIZE}
					case .Bottom: 	
					icon_box = {{center_x(box) - HALF_SIZE, box.low.y}, SIZE}
				}
				icon_box.high += icon_box.low
			} else {
				icon_box = box
			}

			// Paint box
			paint_rounded_box_fill(box, 5, get_color(.Base_Shade, 0.1 * hover_time))
			if active {
				paint_rounded_box_fill(icon_box, 5, alpha_blend_colors(get_color(.Intense), get_color(.Intense_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1))
			} else {
				paint_rounded_box_fill(icon_box, 5, blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), 0.1 if .Pressed in self.state else 0))
				paint_rounded_box_stroke(icon_box, 5, 2, blend_colors(get_color(.Widget), get_color(.Widget_Stroke), hover_time))
			}
			center := box_center(icon_box)

			// Paint icon
			if active || state_time == 1 {
				real_state := info.state.(Check_Box_Status) or_else .On
				center := box_center(icon_box)
				scale := ease.back_out(state_time) * HALF_SIZE * 0.5
				#partial switch real_state {
					case .Unknown: 
					a, b: [2]f32 = {-1, 0} * scale, {1, 0} * scale
					paint_line(center + a, center + b, 2, get_color(.Text))
					case .On: 
					a, b, c: [2]f32 = {-1, -0.047} * scale, {-0.333, 0.619} * scale, {1, -0.713} * scale
					stroke_path({center + a, center + b, center + c}, false, 1, get_color(.Text))
				}
			}

			// Paint text
			if has_text {
				switch text_side {
					case .Left: 	
					paint_text({icon_box.high.x + WIDGET_TEXT_OFFSET, center.y - text_size.y / 2}, {text = info.text.?, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text))
					case .Right: 	
					paint_text({icon_box.low.x - WIDGET_TEXT_OFFSET, center.y - text_size.y / 2}, {text = info.text.?, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text))
					case .Top: 		
					paint_text(box.low, {text = info.text.?, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text))
					case .Bottom: 	
					paint_text({box.low.x, box.high.y - text_size.y}, {text = info.text.?, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text))
				}
			}
		}
		// Result
		if .Clicked in state && click_button == .Left {
			switch state in info.state {
				case bool:
				new_state = !state

				case ^bool:
				state^ = !state^
				new_state = state^

				case Check_Box_Status:
				if state != .On {
					new_state = true
				}
			}
			change = true
		}
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

do_checkbox_bit_set :: proc(set: ^$S/bit_set[$E;$U], bit: E, text: string, loc := #caller_location) -> bool {
	if set == nil {
		return false
	}
	if change, _ := do_checkbox({
		state = .on if bit in set else .off, 
		text = text,
	}, loc); change {
		set^ = set^ ~ {bit}
		return true
	}
	return false
}

do_checkbox_bit_set_header :: proc(set: ^$S/bit_set[$E;$U], text: string, loc := #caller_location) -> bool {
	if set == nil {
		return false
	}
	state := Check_Box_Status.off
	elementCount := card(set^)
	if elementCount == len(E) {
		state = .on
	} else if elementCount > 0 {
		state = .unknown
	}
	if change, new_value := do_checkbox({state = state, text = text}, loc); change {
		if new_value {
			for element in E {
				incl(set, element)
			}
		} else {
			set^ = {}
		}
		return true
	}
	return false
}

Toggle_Switch_State :: union #no_nil {
	bool,
	^bool,
}

Toggle_Switch_Info :: struct {
	state: Toggle_Switch_State,
	off_icon,
	on_icon: Maybe(Icon),
}

// Sliding toggle switch
do_toggle_switch :: proc(info: Toggle_Switch_Info, loc := #caller_location) -> (new_state: bool) {
	state := info.state.(bool) or_else info.state.(^bool)^
	new_state = state
	WIDTH :: 40
	HEIGHT :: 28
	if self, ok := do_widget(hash(loc)); ok {
		self.box = layout_next_child(current_layout(), {WIDTH, HEIGHT})
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.15)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, 0.15)
		how_on := animate_bool(&self.timers[2], state, 0.2, .Quadratic_In_Out)
		update_widget(self)
		// Painting
		if .Should_Paint in self.bits {
			base_box: Box = {{self.box.low.x, self.box.low.y + 4}, {self.box.high.x, self.box.high.y - 4}}
			base_radius := height(base_box) * 0.5
			start: [2]f32 = {base_box.low.x + base_radius, center_y(base_box)}
			MOVE :: WIDTH - HEIGHT
			knob_center := start + {MOVE * (how_on if state else how_on), 0}

			if how_on < 1 {
				paint_rounded_box_fill(base_box, base_radius, get_color(.Widget_Back))
				paint_rounded_box_stroke(base_box, base_radius, 1, get_color(.Widget_Stroke, 0.5))
			}
			if how_on > 0 {
				if how_on < 1 {
					paint_rounded_box_fill({base_box.low, {knob_center.x, base_box.high.y}}, base_radius, get_color(.Intense))
				} else {
					paint_rounded_box_fill(base_box, base_radius, get_color(.Intense))
				}
				
			}
			
			if hover_time > 0 {
				paint_circle_fill(knob_center, 18, 18, get_color(.Base_Shade, BASE_SHADE_ALPHA * hover_time))
			}
			if press_time > 0 {
				if .Pressed in self.state {
					paint_circle_fill(knob_center, 12 + 6 * press_time, 18, get_color(.Base_Shade, BASE_SHADE_ALPHA))
				} else {
					paint_circle_fill(knob_center, 18, 18, get_color(.Base_Shade, BASE_SHADE_ALPHA * press_time))
				}
			}
			paint_circle_fill(knob_center, 11, 10, get_color(.Widget_Back))
			paint_ring_fill_texture(knob_center, 10, 11, blend_colors(get_color(.Widget_Stroke, 0.5), get_color(.Intense), how_on))
			if how_on < 1 && info.off_icon != nil {
				paint_aligned_icon(painter.style.button_font, painter.style.button_font_size, info.off_icon.?, knob_center, get_color(.Intense, 1 - how_on), {.Middle, .Middle})
			}
			if how_on > 0 && info.on_icon != nil {
				paint_aligned_icon(painter.style.button_font, painter.style.button_font_size, info.on_icon.?, knob_center, get_color(.Intense, how_on), {.Middle, .Middle})
			}
		}
		// Invert state on click
		if .Clicked in self.state {
			new_state = !state
			#partial switch v in info.state {
				case ^bool: v^ = new_state
			}
		}
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))

	}
	return
}

// Radio buttons
Radio_Button_Info :: struct {
	on: bool,
	text: string,
	text_side: Maybe(Box_Side),
}

do_radio_button :: proc(info: Radio_Button_Info, loc := #caller_location) -> (clicked: bool) {
	SIZE :: 22
	RADIUS :: SIZE / 2
	// Determine total size
	text_side := info.text_side.? or_else .Left
	text_size := measure_text({text = info.text, font = painter.style.default_font, size = painter.style.default_font_size})
	size: [2]f32
	if text_side == .Bottom || text_side == .Top {
		size.x = max(SIZE, text_size.x)
		size.y = SIZE + text_size.y
	} else {
		size.x = SIZE + text_size.x + WIDGET_TEXT_OFFSET * 2
		size.y = SIZE
	}
	// The widget
	if self, ok := do_widget(hash(loc)); ok {
		self.box = use_next_box() or_else layout_next_child(current_layout(), size)
		update_widget(self)
		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
		state_time := animate_bool(&self.timers[1], info.on, 0.24)
		// Graphics
		if .Should_Paint in self.bits {
			center: [2]f32
			switch text_side {
				case .Left: 	
				center = {self.box.low.x + RADIUS, self.box.low.y + RADIUS}
				case .Right: 	
				center = {self.box.high.x - RADIUS, self.box.low.y + RADIUS}
				case .Top: 		
				center = {center_x(self.box), self.box.high.y - RADIUS}
				case .Bottom: 	
				center = {center_x(self.box), self.box.low.y + RADIUS}
			}
			if hover_time > 0 {
				paint_pill_fill_h(self.box, get_color(.Base_Shade, hover_time * 0.1))
			}
			paint_circle_fill_texture(center, RADIUS, blend_colors(alpha_blend_colors(get_color(.Widget_Back), get_color(.Widget_Shade), 0.1 if .Pressed in self.state else 0), alpha_blend_colors(get_color(.Intense), get_color(.Intense_Shade), 0.2 if .Pressed in self.state else hover_time * 0.1), state_time))
			if info.on {
				paint_circle_fill(center, ease.quadratic_in_out(state_time) * 6, 18, get_color(.Widget_Back, state_time))
			}
			if state_time < 1 {
				paint_ring_fill_texture(center, RADIUS - 2, RADIUS, get_color(.Widget_Stroke, 0.5 + 0.5 * hover_time))
			}
			switch text_side {
				case .Left: 	
				paint_text({self.box.low.x + SIZE + WIDGET_TEXT_OFFSET, center.y - text_size.y / 2}, {text = info.text, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text, 1))
				case .Right: 	
				paint_text({self.box.low.x, center.y - text_size.y / 2}, {text = info.text, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text, 1))
				case .Top: 		
				paint_text(self.box.low, {text = info.text, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text, 1))
				case .Bottom: 	
				paint_text({self.box.low.x, self.box.high.y - text_size.y}, {text = info.text, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left}, get_color(.Text, 1))
			}
		}
		// Click result
		clicked = .Clicked in self.state && self.click_button == .Left
		update_widget_hover(self, point_in_box(input.mouse_point, self.box))
	}
	return
}

// Helper functions
do_enum_radio_buttons :: proc(
	value: $T, 
	text_side: Box_Side = .Left, 
	loc := #caller_location,
) -> (new_value: T) {
	new_value = value
	push_id(hash(loc))
	for member in T {
		push_id(hash_int(int(member)))
			if do_radio_button({
				on = member == value, 
				text = tmp_print(member), 
				text_side = text_side,
			}) {
				new_value = member
			}
		pop_id()
	}
	pop_id()
	return
}

/*
	Combo box
*/
Tree_Node_Info :: struct{
	text: string,
	size: f32,
}

@(deferred_out=_do_tree_node)
do_tree_node :: proc(info: Tree_Node_Info, loc := #caller_location) -> (active: bool) {
	if self, ok := do_widget(hash(loc)); ok {
		using self
		self.box = use_next_box() or_else layout_next(current_layout())
		if state & {.Hovered} != {} {
			core.cursor = .Hand
		}

		// Animation
		hover_time := animate_bool(&self.timers[0], .Hovered in state, 0.15)
		state_time := animate_bool(&self.timers[1], .Active in bits, 0.15)
		update_widget(self)
		// Paint
		if .Should_Paint in bits {
			color := style_intense_shaded(hover_time)
			paint_aligned_icon(painter.style.button_font, painter.style.button_font_size, .Chevron_Down if .Active in bits else .Chevron_Right, center(box), color, {.Middle, .Middle})
			paint_text({box.low.x + height(box), center_y(box)}, {text = info.text, font = painter.style.default_font, size = painter.style.default_font_size}, {align = .Left, baseline = .Middle}, color)
		}

		// Invert state on click
		if .Clicked in state {
			bits = bits ~ {.Active}
		}

		// Begin layer
		if state_time > 0 {
			box := cut(.Top, info.size * state_time)
			layer: ^Layer
			layer, active = begin_layer({
				box = box, 
				layout_size = [2]f32{0, info.size}, 
				id = id, 
				options = {.Attached, .Clip_To_Parent, .No_Scroll_Y}, 
			})
		}
	}
	return 
}
@private 
_do_tree_node :: proc(active: bool) {
	if active {
		layer := current_layer()
		end_layer(layer)
	}
}

Card_Result :: struct {
	clicked: bool,
}
CARD_ROUNDNESS :: 8
// Cards are interactable boxes that contain other widgets
@(deferred_out=_do_card)
do_card :: proc(loc := #caller_location) -> (result: Card_Result, ok: bool) {
	if self, widget_ok := do_widget(hash(loc)); widget_ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.2)
		press_time := animate_bool(&self.timers[1], .Pressed in self.state, 0.15)
		update_widget(self)
		layout_box := move_box(self.box, math.floor(clamp(hover_time - press_time, 0, 1) * -5))
		if hover_time > 0 {
			paint_rounded_box_fill(self.box, CARD_ROUNDNESS, get_color(.Shadow))
		}
		paint_rounded_box_fill(layout_box, CARD_ROUNDNESS, get_color(.Intense))

		push_layout(layout_box)
		push_color(.Text, get_color(.Text_Inverted))

		result.clicked = widget_clicked(self, .Left, 1)
		ok = true
	}
	return
}

@private 
_do_card :: proc(_: Card_Result, ok: bool) {
	if ok {
		pop_layout()
		pop_color()
	}
}

// Just a line
do_divider :: proc(size: f32) {
	layout := current_layout()
	box := cut_box(&layout.box, placement.side, Exact(1))
	paint_box_fill(box, get_color(.Base_Stroke))
}

/*
	Sections
*/
Section_Title :: union {
	string,
	Check_Box_Info,
}

Section_Result :: struct {
	changed, new_state: bool,
}

@(deferred_out=_do_section)
do_section :: proc(title: Section_Title, loc := #caller_location) -> (result: Section_Result, ok: bool) {
	box := layout_next(current_layout())

	if title == nil {
		paint_box_stroke(box, 1, get_color(.Base_Stroke))
	} else {
		switch type in title {
			case string:
			text_size := measure_text({text = type, font = painter.style.title_font, size = painter.style.title_font_size})
			paint_widget_frame(box, WIDGET_TEXT_OFFSET - WIDGET_TEXT_MARGIN, text_size.x + WIDGET_TEXT_MARGIN * 2, 1, get_color(.Base_Stroke))
			paint_text({box.low.x + WIDGET_TEXT_OFFSET, box.low.y - text_size.y / 2}, {text = type, font = painter.style.title_font, size = painter.style.title_font_size}, {align = .Left}, get_color(.Text))

			case Check_Box_Info:
			push_layout({{box.low.x + WIDGET_TEXT_OFFSET, box.low.y}, {box.high.x - WIDGET_TEXT_OFFSET, box.low.y}})
			placement.side = .Left; placement.align.y = .Middle
			result.changed, result.new_state = do_checkbox(type, loc)
			if !evaluate_checkbox_state(type.state) {
				core.disabled = true
			}
			pop_layout()
			paint_widget_frame(box, WIDGET_TEXT_OFFSET - WIDGET_TEXT_MARGIN, height(core.last_box) + WIDGET_TEXT_MARGIN * 2, 1, get_color(.Base_Stroke))
		}
	}

	push_layout(box)
	ok = true
	return
}

@private _do_section :: proc(_: Section_Result, ok: bool) {
	if ok {
		core.disabled = false
		pop_layout()
	}
}

// Scroll bars for scrolling bars
Scrollbar_Info :: struct {
	value,
	low,
	high,
	knob_size: f32,
	vertical: bool,
}

do_scrollbar :: proc(info: Scrollbar_Info, loc := #caller_location) -> (changed: bool, new_value: f32) {
	new_value = info.value
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		update_widget(self)
		i := int(info.vertical)
		box := transmute([4]f32)self.box

		range := box[2 + i] - info.knob_size
		value_range := (info.high - info.low) if info.high > info.low else 1

		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)

		knob_box := box
		knob_box[i] += range * clamp((info.value - info.low) / value_range, 0, 1)
		knob_box[2 + i] = min(info.knob_size, box[2 + i])
		// Painting
		if .Should_Paint in self.bits {
			ROUNDNESS :: 4
			paint_box_fill(transmute(Box)box, get_color(.Scrollbar))
			paint_box_fill(shrink_box(transmute(Box)knob_box, 1), blend_colors(get_color(.Scroll_Thumb), get_color(.Scroll_Thumb_Shade), (2 if .Pressed in self.state else hover_time) * 0.1))
			paint_box_stroke(transmute(Box)knob_box, 1, get_color(.Base_Stroke))
			paint_box_stroke(transmute(Box)box, 1, get_color(.Base_Stroke))
		}
		// Dragging
		if .Got_Press in self.state {
			if point_in_box(input.mouse_point, transmute(Box)knob_box) {
				core.drag_anchor = input.mouse_point - ([2]f32)({knob_box.x, knob_box.y})
				self.bits += {.Active}
			}/* else {
				normal := clamp((input.mouse_point[i] - box[i]) / range, 0, 1)
				new_value = low + (high - low) * normal
				changed = true
			}*/
		}
		if self.bits >= {.Active} {
			normal := clamp(((input.mouse_point[i] - core.drag_anchor[i]) - box[i]) / range, 0, 1)
			new_value = info.low + (info.high - info.low) * normal
			changed = true
		}
		if self.state & {.Lost_Press, .Lost_Focus} != {} {
			self.bits -= {.Active}
		}
	}
	return
}


Chip_Info :: struct {
	text: string,
	clip_box: Maybe(Box),
}

do_chip :: proc(info: Chip_Info, loc := #caller_location) -> (clicked: bool) {
	if self, ok := do_widget(hash(loc)); ok {
		using self
		layout := current_layout()
		if placement.side == .Left || placement.side == .Right {
			self.box = layout_next_of_size(current_layout(), get_size_for_label(layout, info.text))
		} else {
			self.box = layout_next(current_layout())
		}
		hover_time := animate_bool(&self.timers[0], .Hovered in state, 0.1)
		update_widget(self)
		// Graphics
		if .Should_Paint in bits {
			fill_color: Color
			fill_color = style_widget_shaded(2 if .Pressed in self.state else hover_time)
			if clip, ok := info.clip_box.?; ok {
				paint_pill_fill_clipped_h(self.box, clip, fill_color)
				paint_text(center(box), {text = info.text, font = painter.style.title_font, size = painter.style.title_font_size}, {align = .Middle, baseline = .Middle}, get_color(.Text)) 
			} else {
				paint_pill_fill_h(self.box, fill_color)
				paint_text(center(box), {text = info.text, font = painter.style.title_font, size = painter.style.title_font_size}, {align = .Middle, baseline = .Middle}, get_color(.Text))
			}
		}
		clicked = .Clicked in state && click_button == .Left
	}
	return
}

Toggled_Chip_Info :: struct {
	text: string,
	state: bool,
	row_spacing: Maybe(f32),
}

do_toggled_chip :: proc(info: Toggled_Chip_Info, loc := #caller_location) -> (clicked: bool) {
	if self, ok := do_widget(hash(loc)); ok {
		using self
		// Layouteth
		layout := current_layout()
		text_info: Text_Info = {
			text = info.text, 
			font = painter.style.title_font, 
			size = painter.style.title_font_size,
		}
		state_time := animate_bool(&self.timers[0], info.state, 0.15)
		size: [2]f32
		if placement.side == .Left || placement.side == .Right {
			size = measure_text(text_info) + {get_layout_height(layout), 0}
			size.x += size.y * state_time
			if size.x > width(layout.box) {
				pop_layout()
				if info.row_spacing != nil {
					cut(.Top, info.row_spacing.?)
				}
				push_layout(cut(.Top, height(layout.box)))
				placement.side = .Left
			}
		}
		self.box = layout_next_of_size(layout, size.x)
		// Update thyself
		update_widget(self)
		// Hover thyselfest
		hover_time := animate_bool(&self.timers[1], .Hovered in state, 0.1)
		// Graphicseth
		if .Should_Paint in bits {
			color := blend_colors(get_color(.Widget_Stroke), get_color(.Accent), state_time)
			if info.state {
				paint_pill_fill_h(self.box, get_color(.Accent, 0.2 if .Pressed in state else 0.1))
			} else {
				paint_pill_fill_h(self.box, get_color(.Base_Shade, 0.2 if .Pressed in state else 0.1 * hover_time))
			}
			paint_pill_stroke_h(self.box, 2 if info.state else 1, color)
			if state_time > 0 {
				paint_aligned_icon(painter.style.title_font, painter.style.title_font_size, .Check, {box.high.x + height(box) / 2, center_y(box)}, fade(color, state_time), {.Near, .Middle})
				paint_text({box.high.x - height(box) / 2, center_y(box)}, text_info, {align = .Middle, baseline = .Middle}, color) 
			} else {
				paint_text(center(box), text_info, {align = .Middle, baseline = .Middle}, color) 
			}
		}
		clicked = .Clicked in state && click_button == .Left
	}
	return
}

// Navigation tabs
Tab_Info :: struct {
	state: bool,
	label: Label,
	side: Maybe(Box_Side),
	has_close_button: bool,
	show_divider: bool,
}

Tab_Result :: struct {
	self: ^Widget,
	clicked,
	closed: bool,
}

do_tab :: proc(info: Tab_Info, loc := #caller_location) -> (result: Tab_Result) {
	if self, ok := do_widget(hash(loc)); ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		// Default connecting side
		side := info.side.? or_else .Bottom
		// Animations
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
		state_time := animate_bool(&self.timers[1], info.state, 0.1)
		update_widget(self)
		label_box := self.box
		if info.has_close_button {
			set_next_box(shrink_box(cut_box_right(&label_box, height(label_box)), 4))
		}

		ROUNDNESS :: 7
		if self.bits >= {.Should_Paint} {
			paint_rounded_box_corners_fill(self.box, ROUNDNESS, side_corners(side), get_color(.Base, 1 if info.state else 0.5 * hover_time))

			opacity: f32 = 0.5 + min(state_time + hover_time, 1)
			paint_rounded_box_corners_fill(self.box, ROUNDNESS, {.Top_Left, .Top_Right}, get_color(.Base_Shade, (1 - state_time) * 0.1))
			paint_rounded_box_sides_stroke(self.box, ROUNDNESS, 1, {.Left, .Top, .Bottom, .Right} - {side}, get_color(.Base_Stroke, opacity))
			if info.state {
				paint_box_fill({{self.box.low.x + 1, self.box.high.y}, {self.box.high.x - 1, self.box.high.y + 1}}, get_color(.Base))
			}

			paint_label(info.label, {self.box.low.x + height(self.box) * 0.25, center_y(self.box)}, get_color(.Text, opacity), .Left, .Middle)
		}

		if info.has_close_button {
			if do_button({
				label = Icon.Close,
				style = .Subtle,
			}) {
				result.closed = true
			}
		}

		result.self = self
		result.clicked = !info.state && widget_clicked(self, .Left, 1)
	}
	return
}

do_enum_tabs :: proc(value: $T, tab_size: f32, loc := #caller_location) -> (new_value: T) { 
	new_value = value
	box := layout_next(current_layout())
	if do_layout_box(box) {
		placement.side = .Left
		if tab_size == 0 {
			placement.size = Relative(1.0 / f32(len(T)))
		} else {
			placement.size = tab_size
		}
		for member in T {
			push_id(int(member))
				if do_tab({
					state = member == value, 
					label = text_capitalize(fprint(member)), 
				}, loc).clicked {
					new_value = member
				}
			pop_id()
		}
	}
	return
}

/*
	Progress bar
*/
do_progress_bar :: proc(value: f32) {
	box := layout_next(current_layout())
	radius := height(box) * 0.5
	paint_rounded_box_fill(box, radius, get_color(.Widget_Back))
	paint_rounded_box_fill({box.low, {box.low.x + width(box) * clamp(value, 0, 1), box.high.y}}, radius, get_color(.Accent))
}

/*
	Simple selectable list item	
*/
List_Item_Result :: struct {
	self: ^Widget,
	clicked: bool,
}

@(deferred_out=_do_list_item)
do_list_item :: proc(active: bool, loc := #caller_location) -> (result: List_Item_Result, ok: bool) {
	if self, widget_ok := do_widget(hash(loc)); widget_ok {
		self.box = use_next_box() or_else layout_next(current_layout())
		hover_time := animate_bool(&self.timers[0], .Hovered in self.state, 0.1)
		update_widget(self)
		if active {
			paint_box_fill(self.box, get_color(.Widget))
		} else if hover_time > 0 {
			paint_box_fill(self.box, get_color(.Widget_Shade, BASE_SHADE_ALPHA * hover_time))
		}

		result = {
			clicked = .Clicked in self.state && self.click_button == .Left,
			self = self,
		}
		ok = get_clip(core.clip_box, self.box) != .Full
		if ok {
			push_layout(self.box).side = .Left
		}
	}
	return
}

@private 
_do_list_item :: proc(_: List_Item_Result, ok: bool) {
	if ok {
		pop_layout()
	}
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
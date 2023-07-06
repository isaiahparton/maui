package maui
// Core stuff
import "core:fmt"
import "core:math"
import "core:runtime"
import "core:unicode/utf8"
import "core:math/linalg"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:time"

// For easings
import rl "vendor:raylib"

// General purpose booleans
Widget_Bit :: enum {
	// Widget thrown away if 0
	stay_alive,
	// For independently toggled widgets
	active,
	// If the widget is diabled (duh)
	disabled,
	// For attached menus (maybe remove)
	//TODO: remove this
	menu_open,
	// Should be painted this frame
	should_paint,
}

Widget_Bits :: bit_set[Widget_Bit]

// Behavior options
Widget_Option :: enum {
	// The widget does not receive input if 1
	static,
	// The widget will maintain focus, hover and press state if
	// the mouse is held after clicking even when not hovered
	draggable,
	// If the widget can be selected with the keyboard
	can_key_select,
}

Widget_Options :: bit_set[Widget_Option]

// Interaction state
Widget_Status :: enum {
	// Just got status
	got_hover,
	got_focus,
	got_press,
	// Has status
	hovered,
	focused,
	pressed,
	// Just lost status
	lost_hover,
	lost_focus,
	lost_press,
	// Textbox change
	changed,
	// Pressed and released
	clicked,
}

Widget_State :: bit_set[Widget_Status]

// Universal control data (stoopid get rid of it)
Widget :: struct {
	id: 			Id,
	box: 			Box,
	bits: 			Widget_Bits,
	options: 		Widget_Options,
	state: 			Widget_State,
	click_button:  	Mouse_Button,
	click_time: 	time.Time,
	click_count: 	int,
	// Parent layer
	layer: 			^Layer,
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

widget_agent_assert :: proc(using self: ^Widget_Agent, id: Id, box: Box, options: Widget_Options) -> (widget: ^Widget, ok: bool) {
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
	//last_widget = stack[stack_height - 1]
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
		if .stay_alive in widget.bits {
			widget.bits -= {.stay_alive}
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
		if key_pressed(.enter) {
			press_id = hover_id
		}
	}
	next_hover_id = 0
	if mouse_pressed(.left) {
		press_id = hover_id
		focus_id = press_id
	}
}

widget_agent_update_state :: proc(using self: ^Widget_Agent, layer_agent: ^Layer_Agent, widget: ^Widget) {
	assert(widget != nil)
	// Request hover status
	if point_in_box(input.mouse_point, widget.box) && core.layer_agent.hover_id == widget.layer.id {
		next_hover_id = widget.id
	}
	// If hovered
	if hover_id == widget.id {
		widget.state += {.hovered}
		if last_hover_id != widget.id {
			widget.state += {.got_hover}
		}
		pressed_buttons := input.mouse_bits - input.last_mouse_bits
		if pressed_buttons != {} {
			if widget.click_count == 0 {
				widget.click_button = input.last_mouse_button
			}
			if widget.click_button == input.last_mouse_button && time.since(widget.click_time) <= DOUBLE_CLICK_TIME {
				widget.click_count = (widget.click_count + 1) % MAX_CLICK_COUNT
			} else {
				widget.click_count = 0
			}
			widget.click_button = input.last_mouse_button
			widget.click_time = time.now()
			press_id = widget.id
		}
	} else {
		if last_hover_id == widget.id {
			widget.state += {.lost_hover}
		}
		if press_id == widget.id {
			if .draggable in widget.options {
				if .pressed not_in widget.state {
					press_id = 0
				}
			} else  {
				press_id = 0
			}
		}
		widget.click_count = 0
	}
	// Press
	if press_id == widget.id {
		widget.state += {.pressed}
		if last_press_id != widget.id {
			widget.state += {.got_press}
		}
		// Just released buttons
		released_buttons := input.last_mouse_bits - input.mouse_bits
		if released_buttons != {} {
			for button in Mouse_Button {
				if button == widget.click_button {
					widget.state += {.clicked}
					break
				}
			}
			widget.state += {.lost_press}
			press_id = 0
		}
		core.dragging = .draggable in widget.options
	} else if last_press_id == widget.id {
		widget.state += {.lost_press}
	}
	// Focus
	if focus_id == widget.id {
		widget.state += {.focused}
		if last_focus_id != widget.id {
			widget.state += {.got_focus}
		}
	} else if last_focus_id == widget.id {
		widget.state += {.lost_focus}
	}
}

// Main widget functionality
@(deferred_out=_do_widget)
do_widget :: proc(id: Id, box: Box, options: Widget_Options = {}) -> (self: ^Widget, ok: bool) {
	// Check if clipped
	self, ok = widget_agent_assert(&core.widget_agent, id, box, options)
	if !ok {
		return
	}
	widget_agent_push(&core.widget_agent, self)

	// Prepare widget
	self.box = box
	self.state = {}
	self.options = options
	self.bits += {.stay_alive}
	if core.disabled {
		self.bits += {.disabled}
	} else {
		self.bits -= {.disabled}
	}
	if core.paint_this_frame || core.painted_last_frame {
		self.bits += {.should_paint}
	} else {
		self.bits -= {.should_paint}
	}

	core.last_box = box
	// Get input
	if !core.disabled {
		widget_agent_update_state(&core.widget_agent, &core.layer_agent, self)
	}
	return
}

@private
_do_widget :: proc(self: ^Widget, ok: bool) {
	if ok {
		assert(self != nil)
		widget_agent_pop(&core.widget_agent)
		// Shade over the widget if it is disabled
		if .disabled in self.bits {
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
			if self.state >= {.hovered} {
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
	return .clicked in state && click_button == button && click_count >= times - 1
}

attach_tooltip :: proc(text: string, side: Box_Side) {
	core.next_tooltip = Tooltip_Info({
		text = text,
		box_side = side,
	})
}

paint_disable_shade :: proc(box: Box) {
	paint_box_fill(box, get_color(.base, DISABLED_SHADE_ALPHA))
}

tooltip :: proc(id: Id, text: string, origin: [2]f32, align: [2]Alignment) {
	font_data := get_font_data(.label)
	text_size := measure_string(font_data, text)
	PADDING_X :: 4
	PADDING_Y :: 2
	box: Box = {0, 0, text_size.x + PADDING_X * 2, text_size.y + PADDING_Y * 2}
	switch align.x {
		case .near: box.x = origin.x
		case .far: box.x = origin.x - box.w
		case .middle: box.x = origin.x - box.w / 2
	}
	switch align.y {
		case .near: box.y = origin.y
		case .far: box.y = origin.y - box.h
		case .middle: box.y = origin.y - box.h / 2
	}
	if layer, ok := begin_layer({
		box = box, 
		id = id,
		options = {.no_scroll_x, .no_scroll_y},
	}); ok {
		layer.order = .tooltip
		paint_box_fill(layer.box, get_color(.tooltip_fill))
		paint_box_stroke(layer.box, 1, get_color(.tooltip_stroke))
		paint_string(font_data, text, {layer.box.x + PADDING_X, layer.box.y + PADDING_Y}, get_color(.tooltip_text))
		end_layer(layer)
	}
}

tooltip_box ::proc(id: Id, text: string, anchor_box: Box, side: Box_Side, offset: f32) {
	origin: [2]f32
	align: [2]Alignment
	switch side {
		case .bottom:		
		origin.x = anchor_box.x + anchor_box.w / 2
		origin.y = anchor_box.y + anchor_box.h + offset
		align.x = .middle
		align.y = .near
		case .left:
		origin.x = anchor_box.x - offset
		origin.y = anchor_box.y + anchor_box.h / 2
		align.x = .near
		align.y = .middle
		case .right:
		origin.x = anchor_box.x + anchor_box.w - offset
		origin.y = anchor_box.y + anchor_box.h / 2
		align.x = .far
		align.y = .middle
		case .top:
		origin.x = anchor_box.x + anchor_box.w / 2
		origin.y = anchor_box.y - offset
		align.x = .middle
		align.y = .far
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

paint_label :: proc(label: Label, origin: [2]f32, color: Color, info: Paint_Label_Info) -> [2]f32 {
	switch variant in label {
		case string: 	
		return paint_string(get_font_data(.default), variant, origin, color, {
			align = info.align, 
			clip_box = info.clip_box,
		})

		case Icon: 		
		return paint_aligned_glyph(get_glyph_data(get_font_data(.header), rune(variant)), linalg.floor(origin), color, info.align)
	}
	return {}
}

paint_label_box :: proc(label: Label, box: Box, color: Color, align: [2]Alignment) {
	origin: [2]f32 = {box.x, box.y}
	#partial switch align.x {
		case .far: origin.x += box.w
		case .middle: origin.x += box.w / 2
	}
	#partial switch align.y {
		case .far: origin.y += box.h
		case .middle: origin.y += box.h / 2
	}
	paint_label(label, origin, color, {align = align})
}

measure_label :: proc(label: Label) -> (size: [2]f32) {
	switch variant in label {
		case string: 
		size = measure_string(get_font_data(.default), variant)

		case Icon:
		glyph := get_glyph_data(get_font_data(.header), rune(variant))
		size = {glyph.src.w, glyph.src.h}
	}
	return
}

/*
	Buttons for navigation
*/
do_navbar_option :: proc(active: bool, icon: Icon, text: string, loc := #caller_location) -> (clicked: bool) {
	if self, ok := do_widget(hash(loc), layout_next(current_layout())); ok {
		push_id(self.id) 
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.1)
			state_time := animate_bool(hash_int(1), active, 0.15)
		pop_id()

		if .should_paint in self.bits {
			paint_box_fill(self.box, fade(255, min(hover_time + state_time, 1) * 0.25))
			paint_aligned_icon(get_font_data(.default), icon, {self.box.x + self.box.h / 2, self.box.y + self.box.h / 2}, 1, get_color(.base), {.middle, .middle})
			paint_aligned_string(get_font_data(.default), text, {self.box.x + self.box.h * rl.EaseCubicInOut(state_time, 1, 0.3, 1), self.box.y + self.box.h / 2}, get_color(.base), {.near, .middle})
		}
		
		clicked = widget_clicked(self, .left)
	}
	return
}

/*
	[SECTION] BOOLEAN CONTROLS
*/
Check_Box_Status :: enum u8 {
	on,
	off,
	unknown,
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
		active = v != .off
	}
	return active
}

//#Info fields
// - `state` Either a `bool`, a `^bool` or one of `{.on, .off, .unknown}`
// - `text` If defined, the check box will display text on `text_side` of itself
// - `text_side` The side on which text will appear (defaults to left)
do_checkbox :: proc(info: Check_Box_Info, loc := #caller_location) -> (change, new_state: bool) {
	SIZE :: 20
	HALF_SIZE :: SIZE / 2

	// Check if there is text
	has_text := info.text != nil

	// Default orientation
	text_side := info.text_side.? or_else .left

	// Determine total size
	size, text_size: [2]f32
	if has_text {
		text_size = measure_string(get_font_data(.default), info.text.?)
		if text_side == .bottom || text_side == .top {
			size.x = max(SIZE, text_size.x)
			size.y = SIZE + text_size.y
		} else {
			size.x = SIZE + text_size.x + WIDGET_TEXT_OFFSET
			size.y = SIZE
		}
	} else {
		size = SIZE
	}

	// Widget
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next_child(current_layout(), size)); ok {
		using self

		// Determine on state
		active := evaluate_checkbox_state(info.state)

		push_id(id) 
			hover_time := animate_bool(hash_int(0), .hovered in state, 0.15)
			state_time := animate_bool(hash_int(1), active, 0.20)
		pop_id()

		// Painting
		if .should_paint in bits {
			icon_box: Box
			if has_text {
				switch text_side {
					case .left: 	
					icon_box = {box.x, box.y, SIZE, SIZE}
					case .right: 	
					icon_box = {box.x + box.w - SIZE, box.y, SIZE, SIZE}
					case .top: 		
					icon_box = {box.x + box.w / 2 - HALF_SIZE, box.y + box.h - SIZE, SIZE, SIZE}
					case .bottom: 	
					icon_box = {box.x + box.w / 2 - HALF_SIZE, box.y, SIZE, SIZE}
				}
			} else {
				icon_box = box
			}

			// Paint box
			paint_rounded_box_fill(box, 3, get_color(.base_shade, 0.1 * hover_time))
			if active {
				paint_rounded_box_fill(icon_box, 3, alpha_blend_colors(get_color(.intense), get_color(.intense_shade), 0.2 if .pressed in self.state else hover_time * 0.1))
			} else {
				paint_rounded_box_fill(icon_box, 3, alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), 0.1 if .pressed in self.state else 0))
				paint_rounded_box_stroke(icon_box, 3, true, get_color(.widget_stroke, 0.5 + 0.5 * hover_time))
			}
			center := box_center(icon_box)

			// Paint icon
			if active || state_time == 1 {
				real_state := info.state.(Check_Box_Status) or_else .on
				paint_aligned_icon(get_font_data(.default), .Remove if real_state == .unknown else .Check, center, state_time, get_color(.button_text), {.middle, .middle})
			}

			// Paint text
			if has_text {
				switch text_side {
					case .left: 	
					paint_string(get_font_data(.default), info.text.?, {icon_box.x + icon_box.w + WIDGET_TEXT_OFFSET, center.y - text_size.y / 2}, get_color(.text, 1))
					case .right: 	
					paint_string(get_font_data(.default), info.text.?, {icon_box.x - WIDGET_TEXT_OFFSET, center.y - text_size.y / 2}, get_color(.text, 1))
					case .top: 		
					paint_string(get_font_data(.default), info.text.?, {box.x, box.y}, get_color(.text, 1))
					case .bottom: 	
					paint_string(get_font_data(.default), info.text.?, {box.x, box.y + box.h - text_size.y}, get_color(.text, 1))
				}
			}
		}
		// Result
		if .clicked in state && click_button == .left {
			switch state in info.state {
				case bool:
				new_state = !state

				case ^bool:
				state^ = !state^
				new_state = state^

				case Check_Box_Status:
				if state != .on {
					new_state = true
				}
			}
			change = true
		}
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
	if self, ok := do_widget(hash(loc), layout_next_child(current_layout(), {40, 28})); ok {

		// Animation
		push_id(self.id) 
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.15)
			press_time := animate_bool(hash_int(1), .pressed in self.state, 0.15)
			how_on := animate_bool(hash_int(2), state, 0.2)
		pop_id()

		// Painting
		if .should_paint in self.bits {
			base_box: Box = {self.box.x, self.box.y + 4, self.box.w, self.box.h - 8}
			base_radius := base_box.h / 2
			start: [2]f32 = {base_box.x + base_radius, base_box.y + base_box.h / 2}
			move := base_box.w - base_box.h
			thumb_center := start + {move * (rl.EaseQuadInOut(how_on, 0, 1, 1) if state else rl.EaseQuadInOut(how_on, 0, 1, 1)), 0}

			if how_on < 1 {
				paint_rounded_box_fill(base_box, base_radius, get_color(.widget_bg))
				paint_rounded_box_stroke(base_box, base_radius, true, get_color(.widget_stroke, 0.5))
			}
			if how_on > 0 {
				if how_on < 1 {
					paint_rounded_box_fill({base_box.x, base_box.y, thumb_center.x - base_box.x, base_box.h}, base_radius, get_color(.intense))
				} else {
					paint_rounded_box_fill(base_box, base_radius, get_color(.intense))
				}
				
			}
			
			if hover_time > 0 {
				paint_circle_fill(thumb_center, 18, 18, get_color(.base_shade, BASE_SHADE_ALPHA * hover_time))
			}
			if press_time > 0 {
				if .pressed in self.state {
					paint_circle_fill(thumb_center, 12 + 6 * press_time, 18, get_color(.base_shade, BASE_SHADE_ALPHA))
				} else {
					paint_circle_fill(thumb_center, 18, 18, get_color(.base_shade, BASE_SHADE_ALPHA * press_time))
				}
			}
			paint_circle_fill(thumb_center, 11, 10, get_color(.widget_bg))
			paint_circle_stroke_texture(thumb_center, 22, true, blend_colors(get_color(.widget_stroke, 0.5), get_color(.intense), how_on))
			if how_on < 1 && info.off_icon != nil {
				paint_aligned_icon(get_font_data(.default), info.off_icon.?, thumb_center, 1, get_color(.intense, 1 - how_on), {.middle, .middle})
			}
			if how_on > 0 && info.on_icon != nil {
				paint_aligned_icon(get_font_data(.default), info.on_icon.?, thumb_center, 1, get_color(.intense, how_on), {.middle, .middle})
			}
		}
		// Invert state on click
		if .clicked in self.state {
			new_state = !state
			#partial switch v in info.state {
				case ^bool: v^ = new_state
			}
		}
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
	SIZE :: 20
	HALF_SIZE :: SIZE / 2
	// Determine total size
	text_side := info.text_side.? or_else .left
	text_size := measure_string(get_font_data(.default), info.text)
	size: [2]f32
	if text_side == .bottom || text_side == .top {
		size.x = max(SIZE, text_size.x)
		size.y = SIZE + text_size.y
	} else {
		size.x = SIZE + text_size.x + WIDGET_TEXT_OFFSET * 2
		size.y = SIZE
	}
	// The widget
	if self, ok := do_widget(hash(loc), layout_next_child(current_layout(), size)); ok {
		// Animation
		push_id(self.id) 
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.1)
			state_time := animate_bool(hash_int(1), info.on, 0.24)
		pop_id()
		// Graphics
		if .should_paint in self.bits {
			center: [2]f32
			switch text_side {
				case .left: 	
				center = {self.box.x + HALF_SIZE, self.box.y + HALF_SIZE}
				case .right: 	
				center = {self.box.x + self.box.w - HALF_SIZE, self.box.y + HALF_SIZE}
				case .top: 		
				center = {self.box.x + self.box.w / 2, self.box.y + self.box.h - HALF_SIZE}
				case .bottom: 	
				center = {self.box.x + self.box.w / 2, self.box.y + HALF_SIZE}
			}
			if hover_time > 0 {
				paint_rounded_box_fill(self.box, HALF_SIZE, get_color(.base_shade, hover_time * 0.1))
			}
			paint_circle_fill_texture(center, SIZE, blend_colors(alpha_blend_colors(get_color(.widget_bg), get_color(.widget_shade), 0.1 if .pressed in self.state else 0), alpha_blend_colors(get_color(.intense), get_color(.intense_shade), 0.2 if .pressed in self.state else hover_time * 0.1), state_time))
			if info.on {
				paint_circle_fill_texture(center, rl.EaseQuadInOut(state_time, 0, 12, 1), get_color(.widget_bg, state_time))
			}
			if state_time < 1 {
				paint_circle_stroke_texture(center, SIZE, true, get_color(.widget_stroke, 0.5 + 0.5 * hover_time))
			}
			switch text_side {
				case .left: 	
				paint_string(get_font_data(.default), info.text, {self.box.x + SIZE + WIDGET_TEXT_OFFSET, center.y - text_size.y / 2}, get_color(.text, 1))
				case .right: 	
				paint_string(get_font_data(.default), info.text, {self.box.x, center.y - text_size.y / 2}, get_color(.text, 1))
				case .top: 		
				paint_string(get_font_data(.default), info.text, {self.box.x, self.box.y}, get_color(.text, 1))
				case .bottom: 	
				paint_string(get_font_data(.default), info.text, {self.box.x, self.box.y + self.box.h - text_size.y}, get_color(.text, 1))
			}
		}
		// Click result
		clicked = .clicked in self.state && self.click_button == .left
	}
	return
}

// Helper functions
do_enum_radio_buttons :: proc(
	value: $T, 
	text_side: Box_Side = .left, 
	loc := #caller_location,
) -> (new_value: T) {
	new_value = value
	for member in T {
		push_id(hash_int(int(member)))
			if do_radio_button({
				on = member == value, 
				text = text_capitalize(format(member)), 
				text_side = text_side,
			}) {
				new_value = member
			}
		pop_id()
	}
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
	sharedId := hash(loc)
	if self, ok := do_widget(sharedId, use_next_box() or_else layout_next(current_layout())); ok {
		using self

		if state & {.hovered} != {} {
			core.cursor = .hand
		}

		// Animation
		push_id(id) 
			hover_time := animate_bool(hash_int(0), .hovered in state, 0.15)
			state_time := animate_bool(hash_int(1), .active in bits, 0.15)
		pop_id()

		// Paint
		if .should_paint in bits {
			color := style_intense_shaded(hover_time)
			paint_rotating_arrow({box.x + box.h / 2, box.y + box.h / 2}, 8, 1 - state_time, color)
			paint_aligned_string(get_font_data(.default), info.text, {box.x + box.h, box.y + box.h / 2}, color, {.near, .middle})
		}

		// Invert state on click
		if .clicked in state {
			bits = bits ~ {.active}
		}

		// Begin layer
		if state_time > 0 {
			box := cut(.top, info.size * state_time)
			layer: ^Layer
			layer, active = begin_layer({
				box = box, 
				layout_size = [2]f32{0, info.size}, 
				id = id, 
				options = {.attached, .clip_to_parent, .no_scroll_y}, 
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

// Cards are interactable boxangles that contain other widgets
@(deferred_out=_do_card)
do_card :: proc(
	text: string, 
	sides: Box_Sides = {}, 
	loc := #caller_location,
) -> (clicked, ok: bool) {
	if self, widget_ok := do_widget(hash(loc), layout_next(current_layout())); widget_ok {
		push_id(self.id)
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.15)
			press_time := animate_bool(hash_int(1), .pressed in self.state, 0.1)
		pop_id()

		if hover_time > 0 {
			paint_box_fill(self.box, style_base_shaded((hover_time + press_time) * 0.75))
		}
		paint_box_stroke(self.box, 1, get_color(.base_stroke))
		paint_aligned_string(get_font_data(.default), text, {self.box.x + self.box.h * 0.25, self.box.y + self.box.h / 2}, get_color(.text), {.near, .middle})

		push_layout(self.box)

		clicked = .clicked in self.state && self.click_button == .left
		ok = true
	}
	return
}

@private 
_do_card :: proc(clicked, ok: bool) {
	if ok {
		pop_layout()
	}
}

// Just a line
do_divider :: proc(size: f32) {
	layout := current_layout()
	box := box_cut(&layout.box, layout.side, size)
	if layout.side == .left || layout.side == .right {
		paint_box_fill({box.x + math.floor(box.w / 2), box.y, 1, box.h}, get_color(.base_stroke))
	} else {
		paint_box_fill({box.x, box.y + math.floor(box.h / 2), box.w, 1}, get_color(.base_stroke))
	}
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

	switch type in title {
		case nil:
		paint_box_stroke(box, 1, get_color(.base_stroke))

		case string:
		font := get_font_data(.default)
		text_size := measure_string(font, type)
		paint_widget_frame(box, WIDGET_TEXT_OFFSET - WIDGET_TEXT_MARGIN, text_size.x + WIDGET_TEXT_MARGIN * 2, 1, get_color(.base_stroke))
		paint_string(get_font_data(.default), type, {box.x + WIDGET_TEXT_OFFSET, box.y - text_size.y / 2}, get_color(.text))

		case Check_Box_Info:
		push_layout({box.x + WIDGET_TEXT_OFFSET, box.y, box.w - WIDGET_TEXT_OFFSET * 2, 0})
		set_side(.left); set_align_y(.middle)
		result.changed, result.new_state = do_checkbox(type, loc)
		if !evaluate_checkbox_state(type.state) {
			core.disabled = true
		}
		pop_layout()
		paint_widget_frame(box, WIDGET_TEXT_OFFSET - WIDGET_TEXT_MARGIN, core.last_box.w + WIDGET_TEXT_MARGIN * 2, 1, get_color(.base_stroke))
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
	thumb_size: f32,
	vertical: bool,
}

do_scrollbar :: proc(info: Scrollbar_Info, loc := #caller_location) -> (changed: bool, new_value: f32) {
	new_value = info.value
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(current_layout()), {.draggable}); ok {

		i := int(info.vertical)
		box := transmute([4]f32)self.box

		range := box[2 + i] - info.thumb_size
		value_range := (info.high - info.low) if info.high > info.low else 1

		hover_time := animate_bool(self.id, .hovered in self.state, 0.1)

		thumb_box := box
		thumb_box[i] += range * clamp((info.value - info.low) / value_range, 0, 1)
		thumb_box[2 + i] = min(info.thumb_size, box[2 + i])
		// Painting
		if .should_paint in self.bits {
			ROUNDNESS :: 4
			paint_box_fill(transmute(Box)box, get_color(.scrollbar))
			paint_box_fill(shrink_box(transmute(Box)thumb_box, 1), blend_colors(get_color(.scroll_thumb), get_color(.scroll_thumb_shade), (2 if .pressed in self.state else hover_time) * 0.1))
			paint_box_stroke(transmute(Box)thumb_box, 1, get_color(.base_stroke))
			paint_box_stroke(transmute(Box)box, 1, get_color(.base_stroke))
		}
		// Dragging
		if .got_press in self.state {
			if point_in_box(input.mouse_point, transmute(Box)thumb_box) {
				core.drag_anchor = input.mouse_point - ([2]f32)({thumb_box.x, thumb_box.y})
				self.bits += {.active}
			}/* else {
				normal := clamp((input.mouse_point[i] - box[i]) / range, 0, 1)
				new_value = low + (high - low) * normal
				changed = true
			}*/
		}
		if self.bits >= {.active} {
			normal := clamp(((input.mouse_point[i] - core.drag_anchor[i]) - box[i]) / range, 0, 1)
			new_value = info.low + (info.high - info.low) * normal
			changed = true
		}
		if self.state & {.lost_press, .lost_focus} != {} {
			self.bits -= {.active}
		}
	}
	return
}


Chip_Info :: struct {
	text: string,
}

do_chip :: proc(info: Chip_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	font_data := get_font_data(.label)
	if layout.side == .left || layout.side == .right {
		layout.size = measure_string(font_data, info.text).x + layout.box.h + layout.margin[.left] + layout.margin[.right]
	}
	if self, ok := do_widget(hash(loc), layout_next(layout)); ok {
		using self
		hover_time := animate_bool(self.id, .hovered in state, 0.1)
		// Graphics
		if .should_paint in bits {
			fill_color: Color
			fill_color = style_widget_shaded(2 if .pressed in self.state else hover_time)
			paint_pill_fill_h(self.box, fill_color)
			paint_aligned_string(font_data, info.text, {box.x + box.w / 2, box.y + box.h / 2}, get_color(.text), {.middle, .middle}) 
		}
		clicked = .clicked in state && click_button == .left
	}
	return
}

Toggled_Chip_Info :: struct {
	text: string,
	state: bool,
	row_spacing: Maybe(f32),
}

do_toggled_chip :: proc(info: Toggled_Chip_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	font_data := get_font_data(.label)
	id := hash(loc)
	state_time := animate_bool(id, info.state, 0.15)
	if layout.side == .left || layout.side == .right {
		min_size := measure_string(font_data, info.text).x + layout.box.h + layout.margin[.left] + layout.margin[.right]
		min_size += font_data.size * state_time
		if min_size > layout.box.w {
			pop_layout()
			if info.row_spacing != nil {
				cut(.top, info.row_spacing.?)
			}
			push_layout(cut(.top, layout.box.h))
			set_side(.left)
		}
		set_size(min_size)
	}
	if self, ok := do_widget(id, layout_next(layout)); ok {
		using self
		push_id(self.id)
			hover_time := animate_bool(hash(int(1)), .hovered in state, 0.1)
		pop_id()
		// Graphics
		if .should_paint in bits {
			color := blend_colors(get_color(.widget_stroke), get_color(.accent), state_time)
			if info.state {
				paint_pill_fill_h(self.box, get_color(.accent, 0.2 if .pressed in state else 0.1))
			} else {
				paint_pill_fill_h(self.box, get_color(.base_shade, 0.2 if .pressed in state else 0.1 * hover_time))
			}
			paint_pill_stroke_h(self.box, !info.state, color)
			if state_time > 0 {
				paint_aligned_icon(font_data, .Check, {box.x + box.h / 2, box.y + box.h / 2}, 1, fade(color, state_time), {.near, .middle})
				paint_aligned_string(font_data, info.text, {box.x + box.w - box.h / 2, box.y + box.h / 2}, color, {.far, .middle}) 
			} else {
				paint_aligned_string(font_data, info.text, {box.x + box.w / 2, box.y + box.h / 2}, color, {.middle, .middle}) 
			}
		}
		clicked = .clicked in state && click_button == .left
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
	clicked,
	closed: bool,
}

do_tab :: proc(info: Tab_Info, loc := #caller_location) -> (result: Tab_Result) {
	layout := current_layout()
	horizontal := layout.side == .top || layout.side == .bottom
	if self, ok := do_widget(hash(loc), use_next_box() or_else layout_next(layout)); ok {
		// Default connecting side
		side := info.side.? or_else .bottom
		// Animations
		push_id(self.id)
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.1)
			state_time := animate_bool(hash_int(1), info.state, 0.15)
		pop_id()

		label_box := self.box
		if info.has_close_button {
			set_next_box(shrink_box(box_cut_right(&label_box, label_box.h), 4))
		}

		ROUNDNESS :: 7
		if self.bits >= {.should_paint} {
			paint_rounded_box_corners_fill(self.box, ROUNDNESS, side_corners(side), get_color(.base, 1 if info.state else 0.5 * hover_time))

			if info.show_divider && !info.state {
				paint_box_fill({
					self.box.x + self.box.w - 1,
					self.box.y + ROUNDNESS,
					1,
					self.box.h - ROUNDNESS * 2,
				}, get_color(.widget_stroke, 0.5))
			}

			paint_label(info.label, {self.box.x + self.box.h * 0.25, self.box.y + self.box.h / 2}, get_color(.text), {
				align = {.near, .middle}, 
				clip_box = label_box,
			})
		}

		if info.has_close_button {
			if do_button({
				label = Icon.Close,
				style = .subtle,
			}) {
				result.closed = true
			}
		}

		result.clicked = !info.state && widget_clicked(self, .left, 1)
	}
	return
}

do_enum_tabs :: proc(value: $T, tab_size: f32, loc := #caller_location) -> (new_value: T) { 
	new_value = value
	box := layout_next(current_layout())
	if do_layout_box(box) {
		set_side(.left)
		if tab_size == 0 {
			set_size(1.0 / f32(len(T)), true)
		} else {
			set_size(tab_size)
		}
		for member in T {
			push_id(int(member))
				if do_tab({
					state = member == value, 
					label = text_capitalize(format(member)), 
				}, loc).clicked {
					new_value = member
				}
			pop_id()
		}
	}
	return
}

//TODO(isaiah): Find a solution for 'fit' attrib
Text_Info :: struct {
	text: string,
	fit: bool,
	font: Maybe(Font_Index),
	color: Maybe(Color),
}

do_text :: proc(info: Text_Info) {
	font_data := get_font_data(info.font.? or_else .default)
	layout := current_layout()
	text_size := measure_string(font_data, info.text)
	if info.fit {
		layout_fit(layout, text_size)
	}
	box := layout_next_child(layout, text_size)
	if core.paint_this_frame && get_clip(current_layer().box, box) != .full {
		paint_string(font_data, info.text, {box.x, box.y}, fade(info.color.? or_else get_color(.text), 0.5 if core.disabled else 1))
	}
	layer := current_layer()
	layer.content_box = update_bounding_box(layer.content_box, box)
}

Text_Box_Info :: struct {
	text: string,
	font: Maybe(Font_Index),
	align: [2]Maybe(Alignment),
	options: String_Paint_Options,
	color: Maybe(Color),
}

do_text_box :: proc(info: Text_Box_Info) {
	font_data := get_font_data(info.font.? or_else .default)
	box := layout_next(current_layout())
	if core.paint_this_frame && get_clip(current_layer().box, box) != .full {
		paint_contained_string(
			font_data, 
			info.text, 
			{box.x + box.h * 0.25, box.y, box.w - box.h * 0.5, box.h},
			info.color.? or_else get_color(.text),
			{
				align = {
					info.align.x.? or_else .near, 
					info.align.y.? or_else .near, 
				},
				wrap = .wrap in info.options,
				word_wrap = .word_wrap in info.options,
			},
			)
	}
	layer := current_layer()
	layer.content_box = update_bounding_box(layer.content_box, box)
}

glyph_icon :: proc(font: Font_Index, icon: Icon) {
	font_data := get_font_data(font)
	box := layout_next(current_layout())
	paint_aligned_glyph(get_glyph_data(font_data, rune(icon)), {box.x + box.w / 2, box.y + box.h / 2}, get_color(.text), {.middle, .middle})
}

/*
	Progress bar
*/
do_progress_bar :: proc(value: f32) {
	box := layout_next(current_layout())
	radius := box.h / 2
	paint_rounded_box_fill(box, radius, get_color(.widget_bg))
	paint_rounded_box_fill({box.x, box.y, box.w * clamp(value, 0, 1), box.h}, radius, get_color(.accent))
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
	if self, widget_ok := do_widget(hash(loc), use_next_box() or_else layout_next(current_layout())); widget_ok {
		hover_time := animate_bool(self.id, .hovered in self.state, 0.1)
		if active {
			paint_box_fill(self.box, get_color(.widget))
		} else if hover_time > 0 {
			paint_box_fill(self.box, get_color(.widget_shade, BASE_SHADE_ALPHA * hover_time))
		}

		result = {
			clicked = .clicked in self.state && self.click_button == .left,
			self = self,
		}
		ok = true
		if ok {
			push_layout(self.box).side = .left
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
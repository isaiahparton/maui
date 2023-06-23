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
	click_count: 	int,
	// Parent layer
	layer: 			^Layer,
}
// Main widget functionality
@(deferred_out=_widget)
widget :: proc(id: Id, box: Box, options: Widget_Options = {}) -> (^Widget, bool) {
	// Check if clipped
	if get_clip(core.clip_box, box) == .full {
		return nil, false
	}
	// Check for an existing widget
	layer := current_layer()
	self, ok := layer.contents[id]
	// Allocate a new widget
	if !ok {
		self = new(Widget)
		self^ = {
			id = id,
			layer = layer,
		}
		assert(self.layer != nil)
		append(&core.widgets, self)
		layer.contents[id] = self
		core.paint_next_frame = true
	}

	assert(self != nil)
	core.current_widget = self

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
	if core.paintThisFrame || core.paintLastFrame {
		self.bits += {.should_paint}
	} else {
		self.bits -= {.should_paint}
	}
	// Get input
	if !core.disabled {
		using self
		// Request hover status
		if point_in_box(input.mouse_point, box) && core.hovered_layer == layer.id {
			core.next_hover_id = id
		}
		// If hovered
		if core.hover_id == id {
			state += {.hovered}
			if core.last_hover_id != id {
				state += {.got_hover}
			}
			pressed_buttons := input.mouse_bits - input.last_mouse_bits
			if pressed_buttons != {} {
				if click_count == 0 {
					click_button = input.last_mouse_button
				}
				if click_button == input.last_mouse_button && time.since(input.last_click_time[click_button]) <= DOUBLE_CLICK_TIME {
					click_count = (click_count + 1) % MAX_CLICK_COUNT
				} else {
					click_count = 0
				}
				click_button = input.last_mouse_button
				core.press_id = id
			}
			// Just released buttons
			released_buttons := input.last_mouse_bits - input.mouse_bits
			if released_buttons != {} {
				for button in Mouse_Button {
					if button == click_button {
						state += {.clicked}
						break
					}
				}
				if core.press_id == id {
					core.press_id = 0
				}
			}
		} else {
			if core.prevHoverId == id {
				state += {.lostHover}
			}
			if core.press_id == id {
				if .draggable in options {
					if .pressed not_in state {
						core.press_id = 0
					}
				} else  {
					core.press_id = 0
				}
			}
			click_count = 0
		}
		// Press
		if core.press_id == id {
			state += {.pressed}
			if core.last_press_id != id {
				state += {.got_press}
			}
			core.dragging = .draggable in options
		} else if core.last_press_id == id {
			state += {.lost_press}
		}
		// Focus
		if core.focusId == id {
			state += {.focused}
			if core.last_focus_id != id {
				state += {.got_focus}
			}
		} else if core.last_focus_id == id {
			state += {.lost_focus}
		}
	}
	return self, true
}
@private
_widget :: proc(self: ^Widget, ok: bool) {
	if ok {
		// No nils never
		assert(self != nil)
		// Shade over the widget if it is disabled
		if .disabled in self.bits {
			paint_disable_shade(self.box)
		}
		// Update the parent layer's content box
		self.layer.content_box = update_bounding_box(self.layer.content_box, self.box)
		// Update group if there is one
		if core.group_depth > 0 {
			core.groups[core.group_depth - 1].state += self.state
		}
		// Display tooltip if there is one
		if core.tooltip_was_attached {
			core.tooltip_was_attached = false
			if self.state >= {.hovered} {
				tooltip_box(self.id, core.tooltip_text, self.box, core.tooltip_side, 10)
			}
		}
	}
}

// Helper functions
current_widget :: proc() -> ^Widget {
	return core.currentWidget
}
widget_clicked :: proc(using self: ^Widget, button: Mouse_Button, times: int = 1) -> bool {
	return .clicked in state && click_button == button && click_count >= times - 1
}
attach_tooltip :: proc(text: string, side: Box_Side) {
	core.tooltip_was_attached = true
	core.tooltip_text = text
	core.tooltip_side = side
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
	}); ok {
		layer.order = .tooltip
		paint_box_fill(layer.box, get_color(.tooltipFill))
		paint_box_stroke(layer.box, 1, get_color(.tooltipStroke))
		paint_string(font_data, text, {layer.box.x + PADDING_X, layer.box.y + PADDING_Y}, get_color(.tooltipText))
		end_layer(layer)
	}
}
tooltip_box ::proc(id: Id, text: string, anchorBox: Box, side: Box_Side, offset: f32) {
	origin: [2]f32
	alignX, alignY: Alignment
	switch side {
		case .bottom:		
		origin.x = anchorBox.x + anchorBox.w / 2
		origin.y = anchorBox.y + anchorBox.h + offset
		alignX = .middle
		alignY = .near
		case .left:
		origin.x = anchorBox.x - offset
		origin.y = anchorBox.y + anchorBox.h / 2
		alignX = .near
		alignY = .middle
		case .right:
		origin.x = anchorBox.x + anchorBox.w - offset
		origin.y = anchorBox.y + anchorBox.h / 2
		alignX = .far
		alignY = .middle
		case .top:
		origin.x = anchorBox.x + anchorBox.w / 2
		origin.y = anchorBox.y - offset
		alignX = .middle
		alignY = .far
	}
	tooltip(id, text, origin, alignX, alignY)
}

// Labels
Label :: union {
	string,
	Icon,
}

paint_label :: proc(label: Label, origin: [2]f32, color: Color, alignX, alignY: Alignment) -> [2]f32 {
	switch variant in label {
		case string: 	
		return paint_aligned_string(get_font_data(.default), variant, origin, color, alignX, alignY)

		case Icon: 		
		return paint_aligned_glyph(get_glyph_data(get_font_data(.header), rune(variant)), linalg.floor(origin), color, alignX, alignY)
	}
	return {}
}
paint_label_box :: proc(label: Label, box: Box, color: Color, alignX, alignY: Alignment) {
	origin: [2]f32 = {box.x, box.y}
	#partial switch alignX {
		case .near: origin.x += box.h * 0.25
		case .far: origin.x += box.w - box.h * 25
		case .middle: origin.x += box.w / 2
	}
	#partial switch alignY {
		case .far: origin.y += box.h
		case .middle: origin.y += box.h / 2
	}
	PaintLabel(label, origin, color, alignX, alignY)
}
measure_label :: proc(label: Label) -> (size: [2]f32) {
	switch variant in label {
		case string: 
		size = measure_string(get_font_data(.default), variant)

		case Icon:
		glyph := get_glyph_data(get_font_data(.header), rune(variant))
		size = {glyph.source.w, glyph.source.h}
	}
	return
}

/*
	Buttons for navigation
*/
nav_option :: proc(active: bool, icon: Icon, text: string, loc := #caller_location) -> (clicked: bool) {
	if self, ok := widget(hash(loc), layout_next(current_layout())); ok {
		push_id(self.id) 
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.1)
			state_time := animate_bool(hash_int(1), active, 0.15)
		pop_id()

		if .should_paint in self.bits {
			paint_box_fill(self.box, fade(255, min(hover_time + state_time, 1) * 0.25))
			paint_aligned_icon(get_font_data(.default), icon, {self.box.x + self.box.h / 2, self.box.y + self.box.h / 2}, get_color(.base), .middle, .middle)
			paint_aligned_string(get_font_data(.default), text, {self.box.x + self.box.h * rl.EaseCubicInOut(state_time, 1, 0.3, 1), self.box.y + self.box.h / 2}, get_color(.base), .near, .middle)
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
//#Info fields
// - `state` Either a `bool`, a `^bool` or one of `{.on, .off, .unknown}`
// - `text` If defined, the check box will display text on `text_side` of itself
// - `text_side` The side on which text will appear (defaults to left)
checkbox :: proc(info: Check_Box_Info, loc := #caller_location) -> (change, new_state: bool) {
	SIZE :: 20
	HALF_SIZE :: SIZE / 2
	TEXT_OFFSET :: 5

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
			size.x = SIZE + text_size.x + TEXT_OFFSET * 2
			size.y = SIZE
		}
	} else {
		size = SIZE
	}

	// Widget
	if self, ok := Widget(hash(loc), use_next_box() or_else layout_next_child(current_layout(), size)); ok {
		using self

		// Determine on state
		active: bool
		switch state in info.state {
			case bool:
			active = state

			case ^bool:
			active = state^

			case Check_Box_Status:
			active = state != .off
		}

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
				paint_rounded_box_fill(icon_box, 3, AlphaBlend(get_color(.intense), get_color(.intense_shade), 0.2 if .pressed in self.state else hover_time * 0.1))
			} else {
				paint_rounded_box_fill(icon_box, 3, AlphaBlend(get_color(.widget_bg), get_color(.widget_shade), 0.1 if .pressed in self.state else 0))
				paint_rounded_box_stroke(icon_box, 3, true, get_color(.widget_stroke, 0.5 + 0.5 * hover_time))
			}
			center := BoxCenter(icon_box)

			// Paint icon
			if active || state_time == 1 {
				real_state := info.state.(Check_Box_Status) or_else .on
				paint_aligned_icon(get_font_data(.default), .remove if real_state == .unknown else .check, center, state_time, get_color(.button_text), {.middle, .middle})
			}

			// Paint text
			if has_text {
				switch text_side {
					case .left: 	
					paint_string(get_font_data(.default), info.text.?, {icon_box.x + icon_box.w + TEXT_OFFSET, center.y - text_size.y / 2}, get_color(.text, 1))
					case .right: 	
					paint_string(get_font_data(.default), info.text.?, {icon_box.x - TEXT_OFFSET, center.y - text_size.y / 2}, get_color(.text, 1))
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
checkbox_bit_set :: proc(set: ^$S/bit_set[$E;$U], bit: E, text: string, loc := #caller_location) -> bool {
	if set == nil {
		return false
	}
	if change, _ := checkbox({
		state = .on if bit in set else .off, 
		text = text,
	}, loc); change {
		set^ = set^ ~ {bit}
		return true
	}
	return false
}
checkbox_bit_set_header :: proc(set: ^$S/bit_set[$E;$U], text: string, loc := #caller_location) -> bool {
	if set == nil {
		return false
	}
	state := Check_Box_StatusStatus.off
	elementCount := card(set^)
	if elementCount == len(E) {
		state = .on
	} else if elementCount > 0 {
		state = .unknown
	}
	if change, newValue := checkbox({state = state, text = text}, loc); change {
		if newValue {
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
toggle_switch :: proc(info: Toggle_Switch_Info, loc := #caller_location) -> (new_state: bool) {
	state := info.state.(bool) or_else info.state.(^bool)^
	new_state = state
	if self, ok := widget(hash(loc), layout_next_child(current_layout(), {40, 28})); ok {

		// Animation
		push_id(self.id) 
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.15)
			press_time := animate_bool(hash_int(1), .pressed in self.state, 0.15)
			how_on := animate_bool(hash_int(2), state, 0.25)
		pop_id()

		// Painting
		if .should_paint in self.bits {
			base_box: Box = {self.box.x, self.box.y + 4, self.box.w, self.box.h - 8}
			base_radius := base_box.h / 2
			start: [2]f32 = {base_box.x + base_radius, base_box.y + base_box.h / 2}
			move := base_box.w - base_box.h
			thumb_center := start + {move * (rl.EaseBackOut(how_on, 0, 1, 1) if state else rl.EaseBackIn(how_on, 0, 1, 1)), 0}

			if how_on < 1 {
				paint_rounded_box_fill(base_box, base_radius, get_color(.widget_bg))
				paint_rounded_box_stroke(base_box, base_radius, false, get_color(.intense))
			}
			if how_on > 0 {
				if how_on < 1 {
					paint_rounded_box_fill({base_box.x, base_box.y, thumb_center.x - base_box.x, base_box.h}, base_radius, get_color(.intense))
				} else {
					paint_rounded_box_fill(base_box, base_radius, get_color(.intense))
				}
				
			}
			
			if hover_time > 0 {
				paint_circle_fill(thumb_center, 18, 14, get_color(.base_shade, BASE_SHADE_ALPHA * hover_time))
			}
			if press_time > 0 {
				if .pressed in self.state {
					paint_circle_fill(thumb_center, 12 + 6 * press_time, 14, get_color(.base_shade, BASE_SHADE_ALPHA))
				} else {
					paint_circle_fill(thumb_center, 18, 14, get_color(.base_shade, BASE_SHADE_ALPHA * press_time))
				}
			}
			paint_circle_fill(thumb_center, 11, 10, get_color(.base))
			paint_ring_fill(thumb_center, 10, 12, 18, get_color(.intense))
			if how_on < 1 && info.off_icon != nil {
				paint_aligned_icon(get_font_data(.default), info.off_icon.?, thumb_center, get_color(.intense, 1 - how_on), .middle, .middle)
			}
			if how_on > 0 && info.on_icon != nil {
				paint_aligned_icon(get_font_data(.default), info.on_icon.?, thumb_center, get_color(.intense, how_on), .middle, .middle)
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
radio_button :: proc(info: Radio_Button_Info, loc := #caller_location) -> (clicked: bool) {
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
	if self, ok := widget(hash(loc), layout_next_child(current_layout(), size)); ok {
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
enum_radio_buttons :: proc(
	value: $T, 
	text_side: Box_Side = .left, 
	loc := #caller_location,
) -> (newValue: T) {
	newValue = value
	for member in T {
		push_id(hash_int(int(member)))
			if radio_button({
				on = member == value, 
				text = text_capitalize(format(member)), 
				text_side = text_side,
			}) {
				newValue = member
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
@(deferred_out=_tree_node)
tree_node :: proc(info: Tree_Node_Info, loc := #caller_location) -> (active: bool) {
	sharedId := hash(loc)
	if self, ok := widget(sharedId, use_next_box() or_else layout_next(current_layout())); ok {
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
			paint_aligned_string(get_font_data(.default), info.text, {box.x + box.h, box.y + box.h / 2}, color, .near, .middle)
		}

		// Invert state on click
		if .clicked in state {
			bits = bits ~ {.active}
		}

		// Begin layer
		if state_time > 0 {
			box := Cut(.top, info.size * state_time)
			layer: ^Layer
			layer, active = begin_layer({
				box = box, 
				layoutSize = [2]f32{0, info.size}, 
				id = id, 
				options = {.attached, .clipToParent, .noScrollMarginX, .noScrollY}, 
			})
		}
	}
	return 
}
@private 
_tree_node :: proc(active: bool) {
	if active {
		layer := current_layer()
		end_layer(layer)
	}
}

// Cards are interactable boxangles that contain other widgets
@(deferred_out=_card)
card :: proc(
	text: string, 
	sides: Box_Sides = {}, 
	loc := #caller_location,
) -> (clicked, ok: bool) {
	if self, widget_ok := widget(hash(loc), layout_next(current_layout())); widget_ok {
		push_id(self.id)
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.15)
			press_time := animate_bool(hash_int(1), .pressed in self.state, 0.1)
		pop_id()

		if hover_time > 0 {
			paint_box_fill(box, style_base_shaded((hover_time + press_time) * 0.75))
		}
		paint_box_fillLines(box, 1, get_color(.baseStroke))
		paint_aligned_string(get_font_data(.default), text, {box.x + box.h * 0.25, box.y + box.h / 2}, get_color(.text), .near, .middle)

		push_layout(box)

		clicked = .clicked in state && click_button == .left
		ok = true
	}
	return
}
@private 
_card :: proc(clicked, ok: bool) {
	if ok {
		pop_layout()
	}
}

/*
	Widget divider
*/
widget_divider :: proc() {
	using layout := current_layout()
	#partial switch side {
		case .left: paint_box_fill({box.x, box.y + 10, 1, box.h - 20}, get_color(.baseStroke))
		case .right: paint_box_fill({box.x + box.w, box.y + 10, 1, box.h - 20}, get_color(.baseStroke))
	}
}

// Just a line
divider :: proc(size: f32) {
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
@(deferred_out=_section)
section :: proc(label: string, sides: Box_Sides) -> (ok: bool) {
	box := layout_next(current_layout())

	paint_box_stroke(box, 1, get_color(.baseStroke))
	if len(label) != 0 {
		font := get_font_data(.default)
		text_size := measure_string(font, label)
		paint_box_fill({box.x + box.h * 0.25 - 2, box.y, text_size.x + 4, 1}, get_color(.base))
		paint_string(get_font_data(.default), label, {box.x + box.h * 0.25, box.y - text_size.y / 2}, get_color(.text))
	}

	push_layout(box)
	shrink(20)
	return true
}
@private _section :: proc(ok: bool) {
	if ok {
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
scrollbar :: proc(info: Scrollbar_Info, loc := #caller_location) -> (changed: bool, newValue: f32) {
	newValue = info.value
	if self, ok := widget(hash(loc), use_next_box() or_else layout_next(current_layout()), {.draggable}); ok {
		using self
		i := int(info.vertical)
		box := transmute([4]f32)box

		range := box[2 + i] - info.thumb_size
		value_range := (info.high - info.low) if info.high > info.low else 1

		hover_time := animate_bool(self.id, .hovered in state, 0.1)

		thumb_box := box
		thumb_box[i] += range * clamp((info.value - info.low) / value_range, 0, 1)
		thumb_box[2 + i] = info.thumb_size
		// Painting
		if .should_paint in bits {
			ROUNDNESS :: 4
			paint_box_fill(transmute(Box)box, get_color(.scrollbar))
			paint_box_fill(shrink_box(transmute(Box)thumb_box, 1), blend_colors(get_color(.scrollThumb), get_color(.scrollThumbShade), (2 if .pressed in state else hover_time) * 0.1))
			paint_box_stroke(transmute(Box)thumb_box, 1, get_color(.baseStroke))
			paint_box_stroke(transmute(Box)box, 1, get_color(.baseStroke))
		}
		// Dragging
		if .gotPress in state {
			if point_in_box(input.mouse_point, transmute(Box)thumb_box) {
				core.dragAnchor = input.mouse_point - [2]f32({thumb_box.x, thumb_box.y})
				bits += {.active}
			}/* else {
				normal := clamp((input.mouse_point[i] - box[i]) / range, 0, 1)
				newValue = low + (high - low) * normal
				changed = true
			}*/
		}
		if bits >= {.active} {
			normal := clamp(((input.mouse_point[i] - core.dragAnchor[i]) - box[i]) / range, 0, 1)
			newValue = info.low + (info.high - info.low) * normal
			changed = true
		}
		if .lostPress in state {
			bits -= {.active}
		}
	}
	return
}


Chip_Info :: struct {
	text: string,
}
chip :: proc(info: Chip_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	font_data := get_font_data(.label)
	if layout.side == .left || layout.side == .right {
		layout.size = measure_string(font_data, info.text).x + layout.box.h + layout.margin * 2
	}
	if self, ok := Widget(hash(loc), layout_next(layout)); ok {
		using self
		hover_time := animate_bool(self.id, .hovered in state, 0.1)
		// Graphics
		if .should_paint in bits {
			fill_color: Color
			fill_color = style_widget_shaded(2 if .pressed in self.state else hover_time)
			paint_pill_fill_h(self.box, fill_color)
			paint_aligned_string(font_data, info.text, {box.x + box.w / 2, box.y + box.h / 2}, get_color(.text), .middle, .middle) 
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
toggled_chip :: proc(info: Toggled_Chip_Info, loc := #caller_location) -> (clicked: bool) {
	layout := current_layout()
	font_data := get_font_data(.label)
	id := hash(loc)
	state_time := animate_bool(id, info.state, 0.15)
	if layout.side == .left || layout.side == .right {
		minSize := measure_string(font_data, info.text).x + layout.box.h + layout.margin * 2
		minSize += font_data.size * state_time
		if minSize > layout.box.w {
			pop_layout()
			if info.row_spacing != nil {
				cut(.top, info.row_spacing.?)
			}
			push_layout(cut(.top, layout.box.h))
			set_side(.left)
		}
		set_size(minSize)
	}
	if self, ok := widget(id, layout_next(layout)); ok {
		using self
		push_id(self.id)
			hover_time := animate_bool(hash(int(1)), .hovered in state, 0.1)
		pop_id()
		// Graphics
		if .should_paint in bits {
			color := BlendColors(get_color(.widget_stroke), get_color(.accent), state_time)
			if info.state {
				paint_pill_fill_h(self.box, get_color(.accent, 0.2 if .pressed in state else 0.1))
			} else {
				paint_pill_fill_h(self.box, get_color(.base_shade, 0.2 if .pressed in state else 0.1 * hover_time))
			}
			paint_pill_stroke_h(self.box, !info.state, color)
			if state_time > 0 {
				paint_aligned_icon(font_data, .check, {box.x + box.h / 2, box.y + box.h / 2}, fade(color, state_time), .near, .middle)
				paint_aligned_string(font_data, info.text, {box.x + box.w - box.h / 2, box.y + box.h / 2}, color, .far, .middle) 
			} else {
				paint_aligned_string(font_data, info.text, {box.x + box.w / 2, box.y + box.h / 2}, color, .middle, .middle) 
			}
		}
		clicked = .clicked in state && click_button == .left
	}
	return
}

// Navigation tabs
Tab_Info :: struct {
	active: bool,
	label: Label,
	side: Maybe(Box_Side),
}
tab :: proc(info: Tab_Info, loc := #caller_location) -> (result: bool) {
	layout := current_layout()
	horizontal := layout.side == .top || layout.side == .bottom
	if self, ok := widget(hash(loc), use_next_box() or_else layout_next(layout)); ok {
		// Default connecting side
		side := info.side.? or_else .bottom
		// Animations
		push_id(self.id)
			hover_time := animate_bool(hash_int(0), .hovered in self.state, 0.1)
			state_time := animate_bool(hash_int(1), info.active, 0.15)
		pop_id()

		if self.bits >= {.should_paint} {
			paint_rounded_box_corners_fill(self.box, 10, side_corners(side), get_color(.base, 1 if info.active else 0.5 * hover_time))
			center: [2]f32 = {self.box.x + self.box.w / 2, self.box.y + self.box.h / 2}
			text_size := paint_label(info.label, center, get_color(.text), .middle, .middle)
			size := text_size.x
			if state_time > 0 {
				if info.active {
					size *= state_time
				}
				accentBox: Box
				THICKNESS :: 4
				switch side {
					case .top: 		accentBox = {center.x - size / 2, self.box.y, size, THICKNESS}
					case .bottom: 	accentBox = {center.x - size / 2, self.box.y + self.box.h - THICKNESS, size, THICKNESS}
					case .left: 	accentBox = {self.box.x, center.y - size / 2, size, THICKNESS}
					case .right: 	accentBox = {self.box.x + self.box.y - THICKNESS, center.y - size / 2, size, THICKNESS}
				}
				paint_box_fill(accentBox, get_color(.accent, 1 if info.active else state_time))
			}
		}

		result = .pressed in self.state
	}
	return
}
enum_tabs :: proc(value: $T, tabSize: f32, loc := #caller_location) -> (newValue: T) { 
	newValue = value
	box := layout_next(current_layout())
	if layout, ok := layout_box(box); ok {
		layout.size = (layout.box.w / f32(len(T))) if tabSize == 0 else tabSize; layout.side = .left
		for member in T {
			push_id(int(member))
				if Tab({
					active = member == value, 
					label = text_capitalize(format(member)), 
				}, loc) {
					newValue = member
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
text :: proc(info: Text_Info) {
	assert(core.current_layer != nil)
	font_data := get_font_data(info.font.? or_else .default)
	layout := current_layout()
	text_size := measure_string(font_data, info.text)
	if info.fit {
		layout_fit(layout, text_size)
	}
	box := layout_next_child(layout, text_size)
	if get_clip(core.current_layer.box, box) != .full {
		paint_string(font_data, info.text, {box.x, box.y}, info.color.? or_else get_color(.text))
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
text_box :: proc(info: Text_Box_Info) {
	assert(core.current_layer != nil)
	font_data := get_font_data(info.font.? or_else .default)
	box := layout_next(current_layout())
	if get_clip(core.current_layer.box, box) != .full {
		paint_contained_strnig(
			font_data, 
			info.text, 
			{box.x + box.h * 0.25, box.y, box.w - box.h * 0.5, box.h}, 
			info.options, 
			info.align.x.? or_else .near, 
			info.align.y.? or_else .near, 
			info.color.? or_else get_color(.text),
			)
	}
	layer := current_layer()
	layer.content_box = update_bounding_box(layer.content_box, box)
}

glyph_icon :: proc(font: Font_Index, icon: Icon) {
	font_data := get_font_data(font)
	box := layout_next(current_layout())
	paint_aligned_glyph(get_glyph_data(font_data, rune(icon)), {box.x + box.w / 2, box.y + box.h / 2}, get_color(.text), .middle, .middle)
}

/*
	Progress bar
*/
progress_bar :: proc(value: f32) {
	box := layout_next(current_layout())
	radius := box.h / 2
	paint_rounded_box_fill(box, radius, get_color(.widget_bg))
	paint_rounded_box_fill({box.x, box.y, box.w * clamp(value, 0, 1), box.h}, radius, get_color(.accent))
}

/*
	Simple selectable list item	
*/
@(deferred_out=_list_item)
list_item :: proc(active: bool, loc := #caller_location) -> (clicked, ok: bool) {
	box := layout_next(current_layout())
	if get_clip(core.clipBox, box) != .full {
		if self, widget_ok := widget(hash(loc), box); widget_ok {
			hover_time := animate_bool(self.id, .hovered in self.state, 0.1)
			if active {
				paint_box_fill(self.box, get_color(.widget))
			} else if hover_time > 0 {
				paint_box_fill(self.box, get_color(.widget_shade, BASE_SHADE_ALPHA * hover_time))
			}

			clicked = .clicked in self.state && self.click_button == .left
			ok = true
			if ok {
				push_layout(self.box).side = .left
			}
		}
	}
	return
}
@private _list_item :: proc(selected, ok: bool) {
	if ok {
		pop_layout()
	}
}
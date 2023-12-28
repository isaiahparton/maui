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
DEFAULT_WIDGET_HOVER_TIME :: 0.15
DEFAULT_WIDGET_PRESS_TIME :: 0.1
// General purpose bit flags
Widget_Bit :: enum {
	// Widget thrown away if no
	Stay_Alive,
	// For independently toggled widgets
	Active,
	// If the widget is disabled
	Disabled,
	// For attached menus
	Menu_Open,
	// Should be painted this frame
	Should_Paint,
	// Negative number in numeric fields
	Negative,
}
Widget_Bits :: bit_set[Widget_Bit;u8]
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
Widget_Options :: bit_set[Widget_Option;u8]
// Interaction state
Widget_Status :: enum {
	// Has status
	Hovered,
	Focused,
	Pressed,
	// Data modified
	Changed,
	// Pressed and released
	Clicked,
}
Widget_State :: bit_set[Widget_Status;u8]
/*
	Generic info for calling widgets	
*/
Generic_Widget_Info :: struct {
	disabled: bool,
	id: Maybe(Id),
	box: Maybe(Box),
	tooltip: Maybe(Tooltip_Info),
	options: Widget_Options,
}
Generic_Widget_Result :: struct {
	id: Id,
	box: Box,
	state,
	last_state: Widget_State,
	press_count: Maybe(int),
	time_held: Maybe(time.Duration),
	time_hovered: Maybe(time.Duration),
}
/*
	Generic widget state
*/
Widget :: struct {
	id: Id,
	box: Box,
	bits: Widget_Bits,
	options: Widget_Options,
	state,
	last_state: Widget_State,
	click_button: Mouse_Button,
	click_time: time.Time,
	click_count: int,
	// Parent layer (set each frame when widget is invoked)
	layer: ^Layer,
}
/*
	Store widgets and manage their interaction state
*/
Widget_Agent :: struct {
	list: [dynamic]^Widget,
	stack: Stack(^Widget, 8),
	current_widget: ^Widget,
	// Drag anchor
	drag_anchor: Maybe([2]f32),
	last_hover_id, 
	next_hover_id, 
	hover_id, 
	last_press_id, 
	press_id, 
	next_focus_id,
	focus_id,
	last_focus_id: Id,
	// Action timestamps
	press_time,
	hover_time: time.Time,
}
/*
	Ensure that a widget with this id exists
*/
get_widget :: proc(id: Id) -> (wgt: ^Widget, ok: bool) {
	layer := current_layer()
	wgt, ok = layer.contents[id]
	if !ok {
		// Allocate a new widget
		wgt = new(Widget)
		wgt^ = {
			id = id,
		}
		// Add the widget to the list
		append(&list, wgt)
		// Assign the widget to the layer
		layer.contents[id] = wgt
		// Paint the next frame
		ctx.painter.next_frame = true
		// Debug info
		when ODIN_DEBUG && PRINT_DEBUG_EVENTS {
			fmt.printf("+ Widget %x\n", id)
		}
		ok = true
	}
	wdt.layer = layer
	return
}
/*
	Free the memory belonging to a widget agent
*/
destroy_widget_agent :: proc(using self: ^Widget_Agent) {
	for entry in list {
		free(entry)
	}
	delete(list)
}
/*
	Update general ids of widget agent
*/
update_widget_agent :: proc(using self: ^Widget_Agent) {
	last_hover_id = hover_id
	last_press_id = press_id
	last_focus_id = focus_id
	hover_id = next_hover_id
	// Make sure dragged idgets are hovered
	if drag_anchor != nil && press_id != 0 {
		hover_id = press_id
	}
	// Keyboard navigation
	if ctx.is_key_selecting {
		hover_id = focus_id
		if key_pressed(.Enter) {
			press_id = hover_id
		}
	}
	// Reset next hover id so if nothing is hovered nothing will be hovered
	next_hover_id = 0
	// Press whatever is hovered and focus what is pressed
	if mouse_pressed(.Left) {
		press_id = hover_id
		focus_id = press_id
	}
	// Reset drag status
	drag_anchor = nil
	// Free unused widgets
	for widget, i in &list {
		if .Stay_Alive in widget.bits {
			widget.bits -= {.Stay_Alive}
		} else {
			when ODIN_DEBUG && PRINT_DEBUG_EVENTS {
				fmt.printf("- Widget %x\n", widget.id)
			}
			// Remove the record from parent layer
			for key, value in widget.layer.contents {
				if key == widget.id {
					delete_key(&widget.layer.contents, key)
				}
			}
			// Free memory
			free(widget)
			// Remove from list
			ordered_remove(&list, i)
			// Make sure we paint the next frame
			ctx.painter.next_frame = true
		}
	}
}
/*
	Try to update a widget's hover state
*/
update_widget_hover :: proc(wdg: ^Widget, condition: bool) {
	if !(ctx.widget_agent.dragging && wdg.id != ctx.widget_agent.hover_id) && ctx.layer_agent.hover_id == wdg.layer.id && condition {
		ctx.widget_agent.next_hover_id = wdg.id
	}
}
/*
	Update the interaction state of a widget
	TODO: Move this
*/
update_widget_state :: proc(wdg: ^Widget) {
	using ctx.widget_agent
	// If hovered
	if hover_id == wdg.id {
		wdg.state += {.Hovered}
		if last_hover_id != wdg.id {
			hover_time = time.now()
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
		if press_id == wdg.id {
			if .Draggable not_in wdg.options {
				press_id = 0
			}
		}
		if .Draggable not_in wdg.options {
			wdg.click_count = 0
		}
	}
	// Press
	if press_id == wdg.id {
		wdg.state += {.Pressed}
		// Just released buttons
		released_buttons := input.last_mouse_bits - input.mouse_bits
		if released_buttons != {} {
			for button in Mouse_Button {
				if button == wdg.click_button {
					wdg.state += {.Clicked}
					break
				}
			}
			press_id = 0
		}
		if .Draggable in wdg.options && .Pressed not_in wdg.last_state {
			drag_anchor = input.mouse_point
		}
	}
	// Focus
	if focus_id == wdg.id {
		wdg.state += {.Focused}
	}
}
/*
	Simply update the state of the widget for this frame
*/
update_widget :: proc(wdg: ^Widget) {
	// Prepare widget
	wdg.state = {}
	wdg.bits += {.Stay_Alive}
	if ctx.disabled {
		wdg.bits += {.Disabled}
	} else {
		wdg.bits -= {.Disabled}
	}
	if ctx.painter.this_frame && get_clip(current_layer().box, wdg.box) != .Full {
		wdg.bits += {.Should_Paint}
	} else {
		wdg.bits -= {.Should_Paint}
	}

	ctx.last_box = wdg.box
	// Get input
	if !ctx.disabled {
		widget_agent_update_state(&ctx.widget_agent, w)
	}
}
/*
	Context deferred helper proc pair for unique widgets
*/
@(deferred_out=_do_widget)
do_widget :: proc(id: Id, options: Widget_Options = {}, tooltip: Maybe(Tooltip_Info) = nil) -> (wgt: ^Widget, ok: bool) {
	// Check if clipped
	wgt = get_widget(id) or_return
	// Deploy tooltip
	if tooltip, ok := tooltip; ok { 
		if wgt.state >= {.Hovered} && time.since(ctx.widget_agent.hover_time) > time.Millisecond * 500 {
			tooltip_box(wgt.id, tooltip.?.text, wgt.box, tooltip.?.box_side, 10)
		}
	}
	wgt.options = options
	return
}
@private
_do_widget :: proc(wgt: ^Widget, ok: bool) {
	if ok {
		// Pop widget stack
		widget_agent_pop(&ctx.widget_agent)
		// Update the parent layer's content box
		wgt.layer.content_box = update_bounding_box(wgt.layer.content_box, wgt.box)
	}
}
// Helper procs
widget_clicked :: proc(using self: ^Widget, button: Mouse_Button, times: int = 1) -> bool {
	return .Clicked in state && click_button == button && click_count >= times - 1
}
/*
	Tooltips
*/
Tooltip_Info :: struct {
	text: string,
	box_side: Box_Side,
}
/*
	Deploy a tooltip layer aligned to a given side of the origin
*/
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
/*
	Helper proc for displaying a tooltip attached to a box
*/
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
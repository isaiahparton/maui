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
//
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
	self: Maybe(^Widget),
}
/*
	If a widget was pressed and released without being unhovered
*/
was_clicked :: proc(result: Generic_Widget_Result, button: Mouse_Button = .Left, times: int = 0) -> bool {
	widget := result.self.?
	return .Clicked in widget.state && widget.click_button == button && widget.click_count >= times
}
is_hovered :: proc(result: Generic_Widget_Result) -> bool {
	widget := result.self.?
	return .Hovered in widget.state
}
was_hovered :: proc(result: Generic_Widget_Result, duration: time.Duration) -> bool {
	widget := result.self.?
	return time.since(widget.click_time) >= duration
}
was_changed :: proc(result: Generic_Widget_Result) -> bool {
	widget := result.self.?
	return .Changed in widget.state
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
	click_time,
	hover_time,
	press_time: time.Time,
	click_button: Mouse_Button,
	click_count: int,
	// Used for animations
	timers: [3]f32,
	// Parent layer (set each frame when widget is invoked)
	layer: ^Layer,
	// user data
	data: rawptr,
}
/*
	Store widgets and manage their interaction state
*/
Widget_Agent :: struct {
	list: [dynamic]^Widget,
	stack: Stack(^Widget, 8),
	// Drag anchor
	dragging: bool,
	drag_offset: [2]f32,
	last_hover_id, 
	next_hover_id, 
	hover_id, 
	last_press_id, 
	press_id, 
	next_focus_id,
	focus_id,
	last_focus_id: Id,
}
require_data :: proc(widget: ^Widget, type: typeid) -> rawptr {
	if widget.data == nil {
		widget.data, _ = mem.alloc(size_of(type))
	}
	return widget.data
}
destroy_widget :: proc(widget: ^Widget) {
	if widget.data != nil {
		mem.free(widget.data)
	}
}
/*
	Ensure that a widget with this id exists
	IMPORTANT: Must always return a valid ^Widget
*/
get_widget :: proc(ui: ^UI, id: Id) -> (^Widget, Generic_Widget_Result) {
	layer := current_layer(ui)
	widget, ok := layer.contents[id]
	if !ok {
		// Allocate a new widget
		widget = new(Widget)
		widget^ = {
			id = id,
		}
		// Add the widget to the list
		append(&ui.widgets.list, widget)
		// Assign the widget to the layer
		layer.contents[id] = widget
		// Paint the next frame
		ui.painter.next_frame = true
		// Debug info
		when ODIN_DEBUG && PRINT_DEBUG_EVENTS {
			fmt.printf("+ Widget %x\n", id)
		}
	}
	widget.bits += {.Stay_Alive}
	widget.layer = layer

	return widget, Generic_Widget_Result{self = widget}
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
update_widgets :: proc(ui: ^UI) {
	ui.widgets.last_hover_id = ui.widgets.hover_id
	ui.widgets.last_press_id = ui.widgets.press_id
	ui.widgets.last_focus_id = ui.widgets.focus_id
	ui.widgets.hover_id = ui.widgets.next_hover_id
	// Make sure dragged idgets are hovered
	if ui.drag_anchor != nil && ui.widgets.press_id != 0 {
		ui.widgets.hover_id = ui.widgets.press_id
	}
	// Keyboard navigation
	if ui.is_key_selecting {
		ui.widgets.hover_id = ui.widgets.focus_id
		if key_pressed(ui.io, .Enter) {
			ui.widgets.press_id = ui.widgets.hover_id
		}
	}
	// Reset next hover id so if nothing is hovered nothing will be hovered
	ui.widgets.next_hover_id = 0
	// Press whatever is hovered and focus what is pressed
	if mouse_pressed(ui.io, .Left) {
		ui.widgets.press_id = ui.widgets.hover_id
		ui.widgets.focus_id = ui.widgets.press_id
	}
	// Reset drag status
	ui.drag_anchor = nil
	// Free unused widgets
	for widget, i in &ui.widgets.list {
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
			ordered_remove(&ui.widgets.list, i)
			// Make sure we paint the next frame
			ui.painter.next_frame = true
		}
	}
}
/*
	Try to update a widget's hover state
*/
update_widget_hover :: proc(ui: ^UI, widget: ^Widget, condition: bool) {
	if !(ui.widgets.dragging && widget.id != ui.widgets.hover_id) && ui.layers.hover_id == widget.layer.id && condition {
		ui.widgets.next_hover_id = widget.id
	}
}
/*
	Update the interaction state of a widget
	TODO: Move this
*/
update_widget_state :: proc(ui: ^UI, widget: ^Widget) {
	// If hovered
	widget.last_state = widget.state
	widget.state = {}
	// Mouse hover
	if ui.widgets.hover_id == widget.id {
		// Add hovered state
		widget.state += {.Hovered}
		// Set time of hover
		if ui.widgets.last_hover_id != widget.id {
			widget.hover_time = time.now()
		}
		// Clicking
		pressed_buttons := ui.io.mouse_bits - ui.io.last_mouse_bits
		if pressed_buttons != {} {
			if widget.click_count == 0 {
				widget.click_button = ui.io.last_mouse_button
			}
			if widget.click_button == ui.io.last_mouse_button && time.since(widget.click_time) <= DOUBLE_CLICK_TIME {
				widget.click_count = (widget.click_count + 1) % MAX_CLICK_COUNT
			} else {
				widget.click_count = 0
			}
			widget.click_button = ui.io.last_mouse_button
			widget.click_time = time.now()
			ui.widgets.press_id = widget.id
		}
	} else {
		if ui.widgets.press_id == widget.id {
			if .Draggable not_in widget.options {
				ui.widgets.press_id = 0
			}
		}
		if .Draggable not_in widget.options {
			widget.click_count = 0
		}
	}
	// Press
	if ui.widgets.press_id == widget.id {
		widget.state += {.Pressed}
		// Just released buttons
		released_buttons := ui.io.last_mouse_bits - ui.io.mouse_bits
		if released_buttons != {} {
			for button in Mouse_Button {
				if button == widget.click_button {
					widget.state += {.Clicked}
					break
				}
			}
			ui.widgets.press_id = 0
		}
	}
	// Focus
	if ui.widgets.focus_id == widget.id {
		widget.state += {.Focused}
	}
}
/*
	Simply update the state of the widget for this frame
*/
update_widget :: proc(ui: ^UI, widget: ^Widget) {
	// Prepare widget
	if ui.painter.this_frame && get_clip(current_layer(ui).box, widget.box) != .Full {
		widget.bits += {.Should_Paint}
	} else {
		widget.bits -= {.Should_Paint}
	}
	ui.last_box = widget.box
	// Get input
	if .Disabled not_in widget.bits {
		update_widget_state(ui, widget)
	}
}
/*
	Context deferred helper proc pair for unique widgets
*/
/*@(deferred_in_out=_do_widget)
do_widget :: proc(ui: ^UI, id: Id, options: Widget_Options = {}, tooltip: Maybe(Tooltip_Info) = nil) -> (wgt: ^Widget, ok: bool) {
	// Check if clipped
	wgt = get_widget(ui, id) or_return
	// Deploy tooltip
	if tooltip, ok := tooltip.?; ok { 
		if wgt.state >= {.Hovered} && time.since(ui.widgets.hover_time) > time.Millisecond * 500 {
			tooltip_box(wgt.id, tooltip.text, wgt.box, tooltip.box_side, 10)
		}
	}
	wgt.options = options
	return
}
@private
_do_widget :: proc(ui: ^UI, _: Id, _: Widget_Options, _: Maybe(Tooltip_Info), wgt: ^Widget, ok: bool) {
	if ok {
		// Update the parent layer's content box
		wgt.layer.content_box = update_bounding_box(wgt.layer.content_box, wgt.box)
	}
}*/
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
tooltip :: proc(ui: ^UI, id: Id, text: string, origin: [2]f32, align: [2]Alignment, side: Maybe(Box_Side) = nil) {
	text_size := measure_text(ui.painter, {
		text = text,
		font = ui.style.font.title,
		size = ui.style.text_size.title,
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
	if layer, ok := begin_layer(ui, {
		placement = box, 
		id = id,
		options = {.No_Scroll_X, .No_Scroll_Y},
	}); ok {
		layer.order = .Tooltip
		BLACK :: Color{0, 0, 0, 255}
		paint_rounded_box_fill(ui.painter, layer.box, ui.style.tooltip_rounding, {0, 0, 0, 255})
		if side, ok := side.?; ok {
			SIZE :: 5
			#partial switch side {
				case .Bottom: 
				c := (layer.box.high.x + layer.box.low.x) / 2
				paint_triangle_fill(ui.painter, {c - SIZE, layer.box.low.y}, {c + SIZE, layer.box.low.y}, {c, layer.box.low.y - SIZE}, BLACK)
				case .Top:
				c := (layer.box.high.x + layer.box.low.x) / 2
				paint_triangle_fill(ui.painter, {c - SIZE, layer.box.high.y}, {c, layer.box.high.y + SIZE}, {c + SIZE, layer.box.high.y}, BLACK)
				case .Right:
				c := (layer.box.low.y + layer.box.high.y) / 2
				paint_triangle_fill(ui.painter, {layer.box.low.x, c - SIZE}, {layer.box.low.x, c + SIZE}, {layer.box.low.x - SIZE, c}, BLACK)
				case .Left:
				c := (layer.box.low.y + layer.box.high.y) / 2
				paint_triangle_fill(ui.painter, {layer.box.high.x, c - SIZE}, {layer.box.high.x + SIZE, c}, {layer.box.high.x, c + SIZE}, BLACK)
			}
		}
		paint_text(
			ui.painter,
			layer.box.low + PADDING, 
			{font = ui.style.font.title, size = ui.style.text_size.title, text = text},
			255,
			)
		end_layer(ui, layer)
	}
}
/*
	Helper proc for displaying a tooltip attached to a box
*/
tooltip_box ::proc(ui: ^UI, id: Id, text: string, anchor: Box, side: Box_Side, offset: f32) {
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
	tooltip(ui, id, text, origin, align, side)
}
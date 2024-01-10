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
DEFAULT_WIDGET_DISABLE_TIME :: 0.2
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
animate :: proc(ui: ^UI, value, duration: f32, condition: bool) -> f32 {
	value := value
	if condition {
		if value < 1 {
			ui.painter.next_frame = true
			value = min(1, value + ui.delta_time * (1 / duration))
		}
	} else if value > 0 {
		ui.painter.next_frame = true
		value = max(0, value - ui.delta_time * (1 / duration))
	}
	return value
}
/*
	Widget variants
*/
Widget_Variant :: union {
	Button_Widget_Variant,
	Check_Box_Widget_Variant,
	List_Item_Widget_Variant,
}
destroy_widget_variant :: proc(variant: ^Widget_Variant) {
	#partial switch &type in variant {
		case Button_Widget_Variant:	destroy_button_widget_variant(&type)
	}
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
	// User action timestamps
	click_time,
	hover_time,
	press_time: time.Time,
	click_button: Mouse_Button,
	click_count: int,
	// Parent layer (set each frame when widget is invoked)
	layer: ^Layer,
	// user data
	variant: Widget_Variant,
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
/*
	Ensure that a widget with this id exists
	IMPORTANT: Must always return a valid ^Widget
*/
get_widget :: proc(ui: ^UI, info: Generic_Widget_Info, loc: runtime.Source_Code_Location) -> (^Widget, Generic_Widget_Result) {
	id := info.id.? or_else hash(ui, loc)
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
	if info.disabled {
		widget.bits += {.Disabled}
	} else {
		widget.bits -= {.Disabled}
	}
	widget.layer = layer

	return widget, Generic_Widget_Result{self = widget}
}
/*
	Free the memory belonging to a widget agent
*/
destroy_widget_agent :: proc(using self: ^Widget_Agent) {
	for widget in list {
		destroy_widget_variant(&widget.variant)
		free(widget)
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
	for &widget, i in ui.widgets.list {
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
			destroy_widget_variant(&widget.variant)
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
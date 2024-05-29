package maui
import "core:runtime"
// Frame info
Frame_Info :: struct {
	using info: Generic_Widget_Info,
	layer_options: Layer_Options,
	fill_color: Maybe(Color),
	scrollbar_padding: Maybe(f32),
	gradient_size: f32,
}
@(deferred_in_out=_frame)
frame :: proc(ui: ^UI, info: Frame_Info, loc := #caller_location) -> (ok: bool) {
	layer: ^Layer
	layer, ok = begin_layer(ui, {
		placement = info.box.? or_else next_box(ui),
		scrollbar_padding = 0,
		id = hash(ui, loc),
		grow = .Down,
		options = info.layer_options + {.Clip_To_Parent, .Attached, .No_Sorting},
	})
	if ok {
		cut(ui, .Top, info.gradient_size)
	}
	return
}
@private
_frame :: proc(ui: ^UI, info: Frame_Info, _: runtime.Source_Code_Location, ok: bool) {
	if ok {
		assert(ui.layers.current != nil)
		if info.gradient_size > 0 {
			cut(ui, .Top, info.gradient_size)
			// paint_gradient_box_v(ui.painter, get_box_top(ui.layers.current.box, info.gradient_size), ui.style.color.foreground[0], fade(ui.style.color.foreground[0], 0))
			// paint_gradient_box_v(ui.painter, get_box_bottom(ui.layers.current.box, info.gradient_size), fade(ui.style.color.foreground[0], 0), ui.style.color.foreground[0])
		}
		end_layer(ui, ui.layers.current)
	}
}
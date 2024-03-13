package maui
import "core:runtime"
// Frame info
Frame_Info :: struct {
	using info: Generic_Widget_Info,
	layer_options: Layer_Options,
	fill_color: Maybe(Color),
	scrollbar_padding: Maybe(f32),
}
@(deferred_in_out=_frame)
frame :: proc(ui: ^UI, info: Frame_Info, loc := #caller_location) -> (ok: bool) {
	layer: ^Layer
	layer, ok = begin_layer(ui, {
		placement = info.box.? or_else layout_next(current_layout(ui)),
		scrollbar_padding = 0,
		id = hash(ui, loc),
		grow = .Down,
		options = info.layer_options + {.Clip_To_Parent, .Attached, .No_Sorting},
	})
	if ok {
		paint_box_inner_gradient(ui.painter, layer.box, 0, 56, {}, fade(ui.style.color.substance[1], 0.25))
	}
	return
}
@private
_frame :: proc(ui: ^UI, _: Frame_Info, _: runtime.Source_Code_Location, ok: bool) {
	if ok {
		assert(ui.layers.current != nil)
		paint_box_stroke(ui.painter, ui.layers.current.box, 1, ui.style.color.substance[1])
		end_layer(ui, ui.layers.current)
	}
}
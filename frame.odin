package maui
import "core:runtime"
// Frame info
Frame_Info :: struct {
	using info: Generic_Widget_Info,
	layer_info: Layer_Info,
	fill_color: Maybe(Color),
	scrollbar_padding: Maybe(f32),
	gradient_size: f32,
}
@(deferred_in_out=_frame)
frame :: proc(ui: ^UI, info: Frame_Info, loc := #caller_location) -> (ok: bool) {
	layer: ^Layer
	layer_info := info.layer_info
	layer_info.placement = info.box.? or_else next_box(ui)
	layer_info.id = hash(ui, loc)
	layer_info.grow = .Down
	layer_info.options += {.Clip_To_Parent, .Attached, .No_Sorting}
	layer, ok = begin_layer(ui, layer_info)
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
			paint_gradient_box_v(ui.painter, get_box_top(ui.layers.current.box, info.gradient_size), ui.style.color.background, fade(ui.style.color.background, 0))
			paint_gradient_box_v(ui.painter, get_box_bottom(ui.layers.current.box, info.gradient_size), fade(ui.style.color.background, 0), ui.style.color.background)
		}
		end_layer(ui, ui.layers.current)
	}
}
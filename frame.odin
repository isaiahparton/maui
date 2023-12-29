package maui
import "core:runtime"

// Frame info
Frame_Info :: struct {
	using info: Generic_Widget_Info,
	layer_options: Layer_Options,
	fill_color: Maybe(Color),
	scrollbar_padding: Maybe(f32),
}

@(deferred_in_out=_do_frame)
do_frame :: proc(ui: ^UI, info: Frame_Info, loc := #caller_location) -> (ok: bool) {
	layer: ^Layer
	layer, ok = begin_layer(ui, {
		placement = info.box.? or_else layout_next(current_layout(ui)),
		scrollbar_padding = 0,//info.scrollbar_padding.? or_else 0,
		id = hash(ui, loc),
		grow = .Bottom,
		options = info.layer_options + {.Clip_To_Parent, .Attached, .No_Sorting},
	})
	if ok {
		paint_box_fill(&ui.painter, layer.box, info.fill_color.? or_else ui.style.color.base[1])
	}
	return
}

@private
_do_frame :: proc(ui: ^UI, _: Frame_Info, _: runtime.Source_Code_Location, ok: bool) {
	if ok {
		assert(ui.layers.current != nil)
		paint_box_stroke(&ui.painter, ui.layers.current.box, 1, ui.style.color.substance[1])
		end_layer(ui, ui.layers.current)
	}
}
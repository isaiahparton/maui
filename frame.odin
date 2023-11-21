package maui

// Frame info
Frame_Info :: struct {
	options: Layer_Options,
	fill_color: Maybe(Color),
	scrollbar_padding: Maybe(f32),
}

@(deferred_out=_do_frame)
do_frame :: proc(info: Frame_Info, loc := #caller_location) -> (ok: bool) {
	self: ^Layer
	box := use_next_box() or_else layout_next(current_layout())
	self, ok = begin_layer({
		placement = box,
		scrollbar_padding = 0,//info.scrollbar_padding.? or_else 0,
		id = hash(loc),
		extend = .Bottom,
		options = info.options + {.Clip_To_Parent, .Attached, .No_Sorting},
	})
	if ok {
		paint_box_fill(self.box, info.fill_color.? or_else style.color.base[1])
	}
	return
}

@private
_do_frame :: proc(ok: bool) {
	if ok {
		assert(core.layer_agent.current_layer != nil)
		paint_box_stroke(core.layer_agent.current_layer.box, 1, style.color.substance[1])
		end_layer(core.layer_agent.current_layer)
	}
}
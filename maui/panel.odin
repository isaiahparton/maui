package maui

PanelOption :: enum {
	title,
	resizable,
}
PanelOptions :: bit_set[PanelOption]
PanelStatus :: enum {
	closed,
	resizing,
	moving,
	fitToContent,
	shouldClose,
}
PanelState :: bit_set[PanelStatus]
PanelData :: struct {
	options: PanelOptions,
	state: PanelState,
	// Inherited stuff
	layer: ^LayerData,
	// Native stuff
	id: Id,
	body: Rect,
}

/*
	What the user uses
*/
Panel :: proc(loc := #caller_location) -> (panel: ^PanelData, ok: bool) {
	return BeginPanelEx(HashId(loc))
}
@private _Panel :: proc(panel: ^PanelData, ok: bool) {
	if ok {
		EndPanel(panel)
	}
}

@private BeginPanelEx :: proc(id: Id) -> (^PanelData, bool) {
	using ctx

	using panel, ok := CreateOrGetPanel(id)
	if !ok {
		return nil, false
	}

	/*
		Draw the layer body and title bar if needed
	*/
	DrawRect(layer.body, GetColor(.widgetBase, 1))

	PushId(id)

	/*
		Handle title bar
	*/
	if .title in options {
		titleRect := Rect{layer.body.x, layer.body.y, layer.body.w, PANEL_TITLE_SIZE}

		if Layout(titleRect) {
			CutSide(.right)
			CutSize(titleRect.h)
			if IconButtonEx(.close) {
				state += {.shouldClose}
			}
		}

		if hoveredLayer == index && VecVsRect(input.mousePos, titleRect) {
			if MousePressed(.left) {
				state += {.moving}
				dragAnchor = Vector{layer.body.x, layer.body.y} - input.mousePos
			}
		}
	}

	/*
		Handle resizing
	*/


	return panel, true
}
EndPanel :: proc(using panel: ^PanelData) {
	DrawRectLines(layer.body, ctx.style.outline, GetColor(1, 1))

	if .resizing in state {
		layer.body.w = max(input.mousePos.x - layer.body.x, 240)
		layer.body.h = max(input.mousePos.y - layer.body.y, 120)
		if MouseReleased(.left) {
			state -= {.resizing}
		}
	}
	if .moving in state {
		newPos := input.mousePos + ctx.dragAnchor
		layer.body.x = clamp(newPos.x, 0, ctx.size.x - layer.body.w)
		layer.body.y = clamp(newPos.y, 0, ctx.size.y - layer.body.h)
		if MouseReleased(.left) {
			state -= {.moving}
		}
	}
	if .fitToContent in options {
		layer.body.w = layer.contentSize.x
		layer.body.h = layer.contentSize.y
	}
}



GetCurrentPanel :: proc() -> ^PanelData {
	assert(ctx.panelDepth > 0)
	return ctx.panelStack[ctx.panelDepth]
}
CreateOrGetPanel :: proc(id: Id) -> (^PanelData, bool) {
	unimplemented()
	return nil, false
}
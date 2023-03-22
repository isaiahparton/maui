package maui

WindowOption :: enum {
	title,
	resizable,
	fitToContent,
}
WindowOptions :: bit_set[WindowOption]
WindowStatus :: enum {
	resizing,
	moving,
	shouldClose,
}
WindowState :: bit_set[WindowStatus]
WindowData :: struct {
	options: WindowOptions,
	state: WindowState,
	// Inherited stuff
	layer: ^LayerData,
	// Native stuff
	id: Id,
	body: Rect,
	// Dividers
	dividers: map[Id]f32,
}

/*
	What the user uses
*/
Window :: proc(loc := #caller_location) -> (window: ^WindowData, ok: bool) {
	return BeginWindowEx(HashId(loc))
}
@private _Window :: proc(window: ^WindowData, ok: bool) {
	if ok {
		EndWindow(window)
	}
}

@private BeginWindowEx :: proc(id: Id) -> (^WindowData, bool) {
	using ctx

	using window, ok := CreateOrGetWindow(id)
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
		titleRect := Rect{layer.body.x, layer.body.y, layer.body.w, 30}

		if hoveredLayer == layer.id && VecVsRect(input.mousePos, titleRect) {
			if MousePressed(.left) {
				state += {.moving}
				dragAnchor = Vec2{layer.body.x, layer.body.y} - input.mousePos
			}
		}
	}

	/*
		Handle resizing
	*/


	return window, true
}
EndWindow :: proc(using window: ^WindowData) {
	DrawRectLines(layer.body, ctx.style.outline, GetColor(.outlineBase, 1))

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



GetCurrentWindow :: proc() -> ^WindowData {
	assert(ctx.windowDepth > 0)
	return ctx.windowStack[ctx.windowDepth]
}
CreateOrGetWindow :: proc(id: Id) -> (window: ^WindowData, ok: bool) {
	window, ok = ctx.windowMap[id]
	if !ok {
		for i in 0 ..< MAX_WINDOWS {
			if !ctx.windowExists[i] {
				ctx.windowExists[i] = true
				window = &ctx.windows[i]
				ctx.windowMap[id] = window
				ok = true
				break
			}
		}
	}

	return
}
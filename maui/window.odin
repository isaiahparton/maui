package maui
import "core:fmt"

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
@(deferred_out=_Window)
Window :: proc(loc := #caller_location) -> (window: ^WindowData, ok: bool) {
	return BeginWindowEx(HashId(loc))
}
@private _Window :: proc(window: ^WindowData, ok: bool) {
	if ok {
		EndWindow(window)
	}
}

@private BeginWindowEx :: proc(id: Id) -> (window: ^WindowData, ok: bool) {
	using ctx

	window, ok = CreateOrGetWindow(id)
	using window
	if !ok {
		return
	}

	/*
		Draw the layer body and title bar if needed
	*/
	layer, ok = BeginLayer(body, id, {})
	PushId(id)

	PaintRoundedRect(body, 10, GetColor(.windowBase, 1))

	/*
		Handle title bar
	*/
	if .title in options {
		titleRect := GetRectTop(body, 40)

		PaintRoundedRectEx(titleRect, 10, {.topLeft, .topRight}, GetColor(.widgetBase, 1))

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
	PushLayout({body.x, body.y + 40, body.w, body.h - 40})

	return
}
EndWindow :: proc(using window: ^WindowData) {
	//PaintRoundedRectOutline(window.body, 10, {255, 255, 255, 255})

	PopId()
	PopLayout()
	EndLayer(window.layer)

	if .resizing in state {
		body.w = max(input.mousePos.x - body.x, 240)
		body.h = max(input.mousePos.y - body.y, 120)
		if MouseReleased(.left) {
			state -= {.resizing}
		}
	}
	if .moving in state {
		newPos := input.mousePos + ctx.dragAnchor
		body.x = clamp(newPos.x, 0, ctx.size.x - body.w)
		body.y = clamp(newPos.y, 0, ctx.size.y - body.h)
		if MouseReleased(.left) {
			state -= {.moving}
		}
	}
	if .fitToContent in options {
		body.w = layer.contentSize.x
		body.h = layer.contentSize.y
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
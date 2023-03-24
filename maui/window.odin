package maui
import "core:fmt"
import "core:math"

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
	shouldCollapse,
	collapsed,
	new,
}
WindowState :: bit_set[WindowStatus]
WindowData :: struct {
	options: WindowOptions,
	state: WindowState,
	// Inherited stuff
	layer: ^LayerData,
	// Native stuff
	id: Id,
	name: string,
	body: Rect,
	// Dividers
	dividers: map[Id]f32,
	// Collapse
	howCollapsed: f32,
}

/*
	What the user uses
*/
@(deferred_out=_Window)
Window :: proc(loc := #caller_location) -> (window: ^WindowData, ok: bool) {
	return BeginWindowEx(HashId(loc), {}, {})
}
@private _Window :: proc(window: ^WindowData, ok: bool) {
	EndWindow(window)
}

@private BeginWindowEx :: proc(id: Id, pRect: Rect, pOptions: WindowOptions) -> (window: ^WindowData, ok: bool) {
	using ctx

	window, ok = CreateOrGetWindow(id)
	using window
	if !ok {
		return
	}

	if .new in state {
		state -= {.new}
		if pRect != {} {
			body = pRect
		}
		options = pOptions
	}

	/*
		Draw the layer body and title bar if needed
	*/
	layerRect := body
	layerRect.h -= (layerRect.h - WINDOW_TITLE_SIZE) * howCollapsed

	layer, ok = BeginLayer(layerRect, id, {})
	PushId(id)

	drawRect := body

	/*
		Handle title bar
	*/
	if .title in options {
		titleRect := CutRectTop(&drawRect, WINDOW_TITLE_SIZE)

		PaintRoundedRectEx(titleRect, WINDOW_ROUNDNESS, {.topLeft, .topRight}, GetColor(.widgetBase, 1))

		baseline := titleRect.y + titleRect.h / 2
		PaintCollapseArrow({titleRect.x + titleRect.h / 2, baseline}, 10, howCollapsed, {255, 255, 255, 255})
		DrawAlignedString(GetFontData(.header), name, {titleRect.x + titleRect.h, baseline}, GetColor(.textBright, 1), .near, .middle)

		if hoveredLayer == layer.id && VecVsRect(input.mousePos, titleRect) {
			if MousePressed(.left) {
				state += {.moving}
				dragAnchor = Vec2{layer.body.x, layer.body.y} - input.mousePos
			}
			if MousePressed(.right) {
				if .shouldCollapse in state {
					state -= {.shouldCollapse}
				} else {
					state += {.shouldCollapse}
				}
			}
		}
	}

	layoutRect := drawRect
	drawRect.h *= (1 - howCollapsed)

	/*
		Draw body
	*/
	if .title in options {
		PaintRoundedRectEx(drawRect, WINDOW_ROUNDNESS, {.bottomLeft, .bottomRight}, GetColor(.windowBase, 1))
	} else {
		PaintRoundedRect(drawRect, WINDOW_ROUNDNESS, GetColor(.windowBase, 1))
	}

	if .shouldCollapse in state {
		howCollapsed = min(1, howCollapsed + deltaTime * 7)
	} else {
		howCollapsed = max(0, howCollapsed - deltaTime * 7)
	}

	if howCollapsed >= 1 {
		state += {.collapsed}
	} else {
		state -= {.collapsed}
	}

	/*
		Handle resizing
	*/
	if .collapsed in state {
		ok = false
	} else {
		PushLayout(layoutRect, .attach if .fitToContent in options else .cut)
	}

	return
}
EndWindow :: proc(using window: ^WindowData) {
	//PaintRoundedRectOutline(window.body, 10, {255, 255, 255, 255})

	PopId()
	if .collapsed not_in state {
		PopLayout()
	}

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
		body.x = newPos.x
		body.y = newPos.y
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
				ctx.windows[i] = {id = id, state = {.new}}
				window = &ctx.windows[i]
				ctx.windowMap[id] = window
				ok = true
				break
			}
		}
	}
	return
}
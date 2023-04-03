package maui
import "core:fmt"
import "core:math"

WindowBit :: enum {
	stayAlive,
}
WindowBits :: bit_set[WindowBit]
WindowOption :: enum {
	title,
	resizable,
	closable,
	collapsable,
}
WindowOptions :: bit_set[WindowOption]
WindowStatus :: enum {
	resizing,
	moving,
	shouldClose,
	shouldCollapse,
	collapsed,
	initialized,
}
WindowState :: bit_set[WindowStatus]
WindowData :: struct {
	options: WindowOptions,
	state: WindowState,
	bits: WindowBits,
	// for resizing
	dragSide: Side,
	dragAnchor: f32,
	// minimum layout size
	minLayoutSize: Vec2,
	// Inherited stuff
	layer: ^LayerData,
	// Native stuff
	id: Id,
	name: string,
	// Current occupying rectangle
	rect, drawRect: Rect,
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
WithPlacement :: proc(window: ^WindowData, rect: Rect) {
	if .initialized not_in window.state {
		window.rect = rect
	}
}
WithDefaultOptions :: proc(window: ^WindowData, options: WindowOptions) {
	if .initialized not_in window.state {
		window.options = options
	}
}
WithTitle :: proc(window: ^WindowData, name: string) {
	if .initialized not_in window.state {
		window.name = name
		window.options += {.title}
	}
}

/*
	Internal window logic
*/
@private BeginWindowEx :: proc(pId: Id, pRect: Rect, pOptions: WindowOptions) -> (window: ^WindowData, ok: bool) {
	window, ok = CreateOrGetWindow(pId)
	using window
	if !ok {
		return
	}

	bits += {.stayAlive}

	if .initialized not_in state {
		if pRect != {} {
			rect = pRect
		}
		options = pOptions
	}

	/*
		Draw the layer body and title bar if needed
	*/
	layerRect := rect
	layerRect.h -= (layerRect.h - WINDOW_TITLE_SIZE) * howCollapsed

	layer, ok = BeginLayer(layerRect, id, {})
	PushId(id)

	drawRect = rect
	layoutRect := rect

	/*
		Draw body
	*/
	if .collapsed not_in state {
		PaintRoundedRect(drawRect, WINDOW_ROUNDNESS, GetColor(.windowBase, 1))
	}

	/*
		Resizing
	*/
	if .resizable in options {
		topHover := VecVsRect(input.mousePos, {rect.x, rect.y, rect.w, 3})
		leftHover := VecVsRect(input.mousePos, {rect.x, rect.y, 3, rect.h})
		bottomHover := VecVsRect(input.mousePos, {rect.x, rect.y + rect.h - 3, rect.w, 3})
		rightHover := VecVsRect(input.mousePos, {rect.x + rect.w - 3, rect.y, 3, rect.h})
		if topHover || bottomHover {
			ctx.cursor = .resizeNS
		}
		if leftHover || rightHover {
			ctx.cursor = .resizeEW
		}
		if MousePressed(.left) {
			if topHover {
				state += {.resizing}
				dragSide = .top
				dragAnchor = rect.y + rect.h
			} else if leftHover {
				state += {.resizing}
				dragSide = .left
				dragAnchor = rect.x + rect.w
			} else if bottomHover {
				state += {.resizing}
				dragSide = .bottom
			} else if rightHover {
				state += {.resizing}
				dragSide = .right
			}
		}
	}

	/*
		Handle title bar
	*/
	if .title in options {
		titleRect := CutRectTop(&layoutRect, WINDOW_TITLE_SIZE)

		if .collapsed in state {
			PaintRoundedRect(titleRect, WINDOW_ROUNDNESS, GetColor(.widgetBase, 1))
		} else {
			PaintRoundedRectEx(titleRect, WINDOW_ROUNDNESS, {.topLeft, .topRight}, GetColor(.widgetBase, 1))
		}

		baseline := titleRect.y + titleRect.h / 2
		textOffset := titleRect.h * 0.25
		canCollapse := .collapsable in options || .collapsed in state
		if canCollapse {
			PaintCollapseArrow({titleRect.x + titleRect.h / 2, baseline}, 8, howCollapsed, GetColor(.textBright, 1))
			textOffset = titleRect.h * 0.85
		}
		PaintAlignedString(GetFontData(.default), name, {titleRect.x + textOffset, baseline}, GetColor(.textBright, 1), .near, .middle)

		if .resizing not_in state && ctx.hoveredLayer == layer.id && VecVsRect(input.mousePos, titleRect) {
			if MousePressed(.left) {
				state += {.moving}
				ctx.dragAnchor = Vec2{layer.body.x, layer.body.y} - input.mousePos
			}
			if canCollapse && MousePressed(.right) {
				if .shouldCollapse in state {
					state -= {.shouldCollapse}
				} else {
					state += {.shouldCollapse}
				}
			}
		}

		if .closable in options {
			SetNextRect(ChildRect(GetRectRight(titleRect, titleRect.h), {30, 30}, .middle, .middle))
			if IconButtonEx(.close) {
				state += {.shouldClose}
			}
		}
	} else {
		state -= {.shouldCollapse}
	}

	drawRect.h -= layoutRect.h * howCollapsed

	if .shouldCollapse in state {
		howCollapsed = min(1, howCollapsed + ctx.deltaTime * 7)
	} else {
		howCollapsed = max(0, howCollapsed - ctx.deltaTime * 7)
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
		layoutRect.w = max(layoutRect.w, minLayoutSize.x)
		layoutRect.h = max(layoutRect.h, minLayoutSize.y)
		PushLayout(layoutRect)
	}

	return
}
@private EndWindow :: proc(using window: ^WindowData) {
	state += {.initialized}

	/*
		Window decoration
	*/
	PaintRoundedRectOutline(drawRect, WINDOW_ROUNDNESS, true, GetColor(.text, 1))

	// Drop window context
	if .collapsed not_in state {
		PopLayout()
	}
	PopId()
	EndLayer(layer)

	/*
		Handle window manipulation
	*/
	if .resizing in state {
		switch dragSide {
			case .bottom:
			rect.h = input.mousePos.y - rect.y
			ctx.cursor = .resizeNS
			case .left:
			rect.x = input.mousePos.x
			rect.w = dragAnchor - input.mousePos.x
			ctx.cursor = .resizeEW
			case .right:
			rect.w = input.mousePos.x - rect.x
			ctx.cursor = .resizeEW
			case .top:
			rect.y = input.mousePos.y
			rect.h = dragAnchor - input.mousePos.y
			ctx.cursor = .resizeNS
		}
		rect.w = max(rect.w, minLayoutSize.x)
		rect.h = max(rect.h, minLayoutSize.y)
		if MouseReleased(.left) {
			state -= {.resizing}
		}
	}
	if .moving in state {
		ctx.cursor = .resizeAll
		newOrigin := input.mousePos + ctx.dragAnchor
		rect.x = newOrigin.x
		rect.y = newOrigin.y
		if MouseReleased(.left) {
			state -= {.moving}
		}
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
				ctx.windows[i] = {id = id}
				window = &ctx.windows[i]
				ctx.windowMap[id] = window
				ok = true
				break
			}
		}
	}
	return
}
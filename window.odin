package maui
import "core:fmt"
import "core:math"

WindowBit :: enum {
	stayAlive,
	close,
}
WindowBits :: bit_set[WindowBit]
WindowOption :: enum {
	title,
	resizable,
	closable,
	collapsable,
	close_on_unfocus,
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
	dragSide: RectSide,
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
	// Collapse
	howCollapsed: f32,
}

/*
	What the user uses
*/
@(deferred_out=_Window)
Window :: proc(name, title: string, rect: Rect, options: WindowOptions) -> (window: ^WindowData, ok: bool) {
	return BeginWindowEx(HashId(name), title, rect, options)
}
@private
_Window :: proc(window: ^WindowData, ok: bool) {
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
@private BeginWindowEx :: proc(_id: Id, _title: string, _rect: Rect, _options: WindowOptions) -> (window: ^WindowData, ok: bool) {
	if window, ok = ctx.windowMap[_id]; ok {
		using window

		bits += {.stayAlive}

		if .initialized not_in state {
			if _rect != {} {
				rect = _rect
			}
			options = _options
			name = _title
		}

		layerRect := rect
		layerRect.h -= ((layerRect.h - WINDOW_TITLE_SIZE) if .title in options else layerRect.h) * howCollapsed

		layer, ok = BeginLayer(layerRect, {}, id, {})
		layer.order = .floating
		PushId(id)

		drawRect = layerRect
		layoutRect := rect
		// Body
		if .collapsed not_in state {
			PaintRoundedRect(drawRect, WINDOW_ROUNDNESS, GetColor(.foreground))
		}

		// Get resize click
		if .resizable in options {
			topHover := VecVsRect(input.mousePoint, {rect.x, rect.y, rect.w, 3})
			leftHover := VecVsRect(input.mousePoint, {rect.x, rect.y, 3, rect.h})
			bottomHover := VecVsRect(input.mousePoint, {rect.x, rect.y + rect.h - 3, rect.w, 3})
			rightHover := VecVsRect(input.mousePoint, {rect.x + rect.w - 3, rect.y, 3, rect.h})
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

		// Draw title bar and get movement dragging
		if .title in options {
			titleRect := CutRectTop(&layoutRect, WINDOW_TITLE_SIZE)

			// Draw title rectangle
			if .collapsed in state {
				PaintRoundedRect(titleRect, WINDOW_ROUNDNESS, GetColor(.widgetBase, 1))
			} else {
				PaintRoundedRectEx(titleRect, WINDOW_ROUNDNESS, {.topLeft, .topRight}, GetColor(.widgetBase, 1))
			}

			// Title bar decoration
			baseline := titleRect.y + titleRect.h / 2
			textOffset := titleRect.h * 0.25
			canCollapse := .collapsable in options || .collapsed in state
			if canCollapse {
				PaintCollapseArrow({titleRect.x + titleRect.h / 2, baseline}, 8, howCollapsed, GetColor(.text, 1))
				textOffset = titleRect.h * 0.85
			}
			PaintStringAligned(GetFontData(.default), name, {titleRect.x + textOffset, baseline}, GetColor(.text, 1), .near, .middle)
			if .closable in options {
				SetNextRect(ChildRect(GetRectRight(titleRect, titleRect.h), {24, 24}, .middle, .middle))
				if Button(.close) {
					bits += {.close}
				}
			}
			if .resizing not_in state && ctx.hoveredLayer == layer.id && VecVsRect(input.mousePoint, titleRect) {
				if ctx.hoverId == 0 && MousePressed(.left) {
					state += {.moving}
					ctx.dragAnchor = Vec2{layer.body.x, layer.body.y} - input.mousePoint
				}
				if canCollapse && MousePressed(.right) {
					if .shouldCollapse in state {
						state -= {.shouldCollapse}
					} else {
						state += {.shouldCollapse}
					}
				}
			}
		} else {
			state -= {.shouldCollapse}
		}

		// Interpolate collapse
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

		// Push layout if necessary
		if .collapsed in state {
			ok = false
		} else {
			layoutRect.w = max(layoutRect.w, minLayoutSize.x)
			layoutRect.h = max(layoutRect.h, minLayoutSize.y)
			PushLayout(layoutRect)
		}
	}
	return
}
@private EndWindow :: proc(using window: ^WindowData) {
	if window == nil {
		return
	}

	state += {.initialized}
	// Outline
	PaintRoundedRectOutline(drawRect, WINDOW_ROUNDNESS, true, GetColor(.text, 1))

	// Drop window context
	if .collapsed not_in state {
		PopLayout()
	}
	PopId()
	EndLayer(layer)

	// Handle resizing
	if .resizing in state {
		switch dragSide {
			case .bottom:
			rect.h = input.mousePoint.y - rect.y
			ctx.cursor = .resizeNS
			case .left:
			rect.x = input.mousePoint.x
			rect.w = dragAnchor - input.mousePoint.x
			ctx.cursor = .resizeEW
			case .right:
			rect.w = input.mousePoint.x - rect.x
			ctx.cursor = .resizeEW
			case .top:
			rect.y = input.mousePoint.y
			rect.h = dragAnchor - input.mousePoint.y
			ctx.cursor = .resizeNS
		}
		rect.w = max(rect.w, minLayoutSize.x)
		rect.h = max(rect.h, minLayoutSize.y)
		if MouseReleased(.left) {
			state -= {.resizing}
		}
	}

	// Handle movement
	if .moving in state {
		ctx.cursor = .resizeAll
		newOrigin := input.mousePoint + ctx.dragAnchor
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
		window, ok = CreateWindow(id)
	}
	return
}
CreateWindow :: proc(id: Id) -> (window: ^WindowData, ok: bool) {
	for i in 0 ..< MAX_WINDOWS {
		if !ctx.windowExists[i] {
			ctx.windowExists[i] = true
			ctx.windows[i] = {
				id = id,
			}
			window = &ctx.windows[i]
			ok = true
			ctx.windowMap[id] = window
			break
		}
	}
	return
}
OpenWindow :: proc(name: string) {
	id := HashId(name)
	window, ok := ctx.windowMap[id]
	if !ok {
		window, ok = CreateWindow(id)
	}
}
CloseWindow :: proc(name: string) {
	id := HashId(name)
	if window, ok := ctx.windowMap[id]; ok {
		window.bits += {.close}
	}
}
CloseCurrentWindow :: proc() {
	if ctx.windowDepth > 0 {
		ctx.windowStack[ctx.windowDepth - 1].bits += {.close}
	}
}
ToggleWindow :: proc(name: string) {
	id := HashId(name)
	window, ok := ctx.windowMap[id]
	if ok {
		window.bits += {.close}
	} else {
		window, ok = CreateWindow(id)
	}
}
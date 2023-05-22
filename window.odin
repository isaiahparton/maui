package maui
import "core:fmt"
import "core:math"

WindowBit :: enum {
	stayAlive,
	initialized,
	resizing,
	moving,
	shouldClose,
	shouldCollapse,
	collapsed,
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
WindowData :: struct {
	// Native stuff
	title: string,
	id: Id,
	options: WindowOptions,
	bits: WindowBits,
	// for resizing
	dragSide: RectSide,
	dragAnchor: f32,
	// minimum layout size
	minLayoutSize: Vec2,
	// Inherited stuff
	layer: ^LayerData,
	// Current occupying rectangle
	rect, drawRect: Rect,
	// Collapse
	howCollapsed: f32,
}

/*
	What the user uses
*/
@(deferred_out=_Window)
Window :: proc(title: string, rect: Rect, options: WindowOptions, loc := #caller_location) -> (ok: bool) {
	return BeginWindowEx(HashId(loc), title, rect, options)
}
@private
_Window :: proc(ok: bool) {
	EndWindow(ctx.currentWindow)
}

/*
	Internal window logic
*/
@private 
BeginWindowEx :: proc(id: Id, title: string, rect: Rect, options: WindowOptions) -> (ok: bool) {
	window: ^WindowData
	if window, ok = CreateOrGetWindow(id); ok {
		ctx.currentWindow = window
		window.bits += {.stayAlive}
		// Initialize window
		if .initialized not_in window.bits {
			if rect != {} {
				window.rect = rect
			}
			window.options = options
			window.title = title
		}

		layerRect := window.rect
		layerRect.h -= ((layerRect.h - WINDOW_TITLE_SIZE) if .title in window.options else layerRect.h) * window.howCollapsed

		window.layer, ok = BeginLayer(layerRect, {}, id, {.shadow})
		window.layer.order = .floating

		window.drawRect = layerRect
		layoutRect := window.rect
		// Body
		if .collapsed not_in window.bits {
			PaintRoundedRect(window.drawRect, WINDOW_ROUNDNESS, GetColor(.foreground))
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
					window.bits += {.resizing}
					window.dragSide = .top
					window.dragAnchor = rect.y + rect.h
				} else if leftHover {
					window.bits += {.resizing}
					window.dragSide = .left
					window.dragAnchor = rect.x + rect.w
				} else if bottomHover {
					window.bits += {.resizing}
					window.dragSide = .bottom
				} else if rightHover {
					window.bits += {.resizing}
					window.dragSide = .right
				}
			}
		}
		// Draw title bar and get movement dragging
		if .title in window.options {
			titleRect := CutRectTop(&layoutRect, WINDOW_TITLE_SIZE)
			// Draw title rectangle
			if .collapsed in window.bits {
				PaintRoundedRect(titleRect, WINDOW_ROUNDNESS, GetColor(.widgetBase, 1))
			} else {
				PaintRoundedRectEx(titleRect, WINDOW_ROUNDNESS, {.topLeft, .topRight}, GetColor(.widgetBase, 1))
			}
			// Title bar decoration
			baseline := titleRect.y + titleRect.h / 2
			textOffset := titleRect.h * 0.25
			canCollapse := .collapsable in window.options || .collapsed in window.bits
			if canCollapse {
				PaintCollapseArrow({titleRect.x + titleRect.h / 2, baseline}, 8, window.howCollapsed, GetColor(.text))
				textOffset = titleRect.h * 0.85
			}
			PaintStringAligned(GetFontData(.default), title, {titleRect.x + textOffset, baseline}, GetColor(.text), .near, .middle)
			if .closable in options {
				SetNextRect(ChildRect(GetRectRight(titleRect, titleRect.h), {24, 24}, .middle, .middle))
				if Button(.close) {
					window.bits += {.shouldClose}
				}
			}
			if .resizing not_in window.bits && ctx.hoveredLayer == window.layer.id && VecVsRect(input.mousePoint, titleRect) {
				if ctx.hoverId == 0 && MousePressed(.left) {
					window.bits += {.moving}
					ctx.dragAnchor = Vec2{window.layer.body.x, window.layer.body.y} - input.mousePoint
				}
				if canCollapse && MousePressed(.right) {
					if .shouldCollapse in window.bits {
						window.bits -= {.shouldCollapse}
					} else {
						window.bits += {.shouldCollapse}
					}
				}
			}
		} else {
			window.bits -= {.shouldCollapse}
		}
		// Interpolate collapse
		if .shouldCollapse in window.bits {
			window.howCollapsed = min(1, window.howCollapsed + ctx.deltaTime * 7)
		} else {
			window.howCollapsed = max(0, window.howCollapsed - ctx.deltaTime * 7)
		}
		if window.howCollapsed >= 1 {
			window.bits += {.collapsed}
		} else {
			window.bits -= {.collapsed}
		}
		// Push layout if necessary
		if .collapsed in window.bits {
			ok = false
		} else {
			layoutRect.w = max(layoutRect.w, window.minLayoutSize.x)
			layoutRect.h = max(layoutRect.h, window.minLayoutSize.y)
			PushLayout(layoutRect)
		}
	}
	return
}
// Called for every 'BeginWindow' call
@private 
EndWindow :: proc(using window: ^WindowData) {
	if window != nil {
		bits += {.initialized}
		// Outline
		PaintRoundedRectOutline(drawRect, WINDOW_ROUNDNESS, true, GetColor(.outlineBase))
		// Handle resizing
		if .resizing in bits {
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
			rect.w = max(rect.w, 120)
			rect.h = max(rect.h, 240)
			if MouseReleased(.left) {
				bits -= {.resizing}
			}
		}
		// Handle movement
		if .moving in bits {
			ctx.cursor = .resizeAll
			newOrigin := input.mousePoint + ctx.dragAnchor
			rect.x = newOrigin.x
			rect.y = newOrigin.y
			if MouseReleased(.left) {
				bits -= {.moving}
			}
		}
		// End window body layout
		if .collapsed not_in bits {
			PopLayout()
		}
		// End layer
		EndLayer(layer)
	}
}

CurrentWindow :: proc() -> ^WindowData {
	return ctx.currentWindow
}
CreateOrGetWindow :: proc(id: Id) -> (window: ^WindowData, ok: bool) {
	window, ok = ctx.windowMap[id]
	if !ok {
		window, ok = CreateWindow(id)
	}
	return
}
CreateWindow :: proc(id: Id) -> (window: ^WindowData, ok: bool) {
	window = new(WindowData)
	window^ = {
		id = id,
	}
	append(&ctx.windows, window)
	ctx.windowMap[id] = window
	ok = true
	return
}
DeleteWindow :: proc(window: ^WindowData) {
	free(window)
}
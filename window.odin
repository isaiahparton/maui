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
	static,
	closable,
	collapsable,
	closeWhenUnfocused,
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
			window.bits += {.initialized}
			if rect != {} {
				window.rect = rect
			}
			window.options = options
			window.title = title
		}
		// Layer body
		layerRect := window.rect
		layerRect.h -= ((layerRect.h - WINDOW_TITLE_SIZE) if .title in window.options else layerRect.h) * window.howCollapsed
		// Begin window layer
		layerOptions: LayerOptions = {.shadow}
		if (window.howCollapsed > 0 && window.howCollapsed < 1) || (window.howCollapsed == 1 && .shouldCollapse not_in window.bits) {
			layerOptions += {.forceClip}
		}
		window.layer, ok = BeginLayer(layerRect, {}, id, layerOptions)
		window.layer.order = .floating
		// Visual rect
		window.drawRect = layerRect
		// Inner layout rect
		layoutRect := window.rect
		// Body
		if .collapsed not_in window.bits {
			PaintRoundedRect(window.drawRect, WINDOW_ROUNDNESS, GetColor(.foreground))
		}
		// Get resize click
		if .resizable in window.options && .collapsed not_in window.bits {
			RESIZE_MARGIN :: 5
			topHover 		:= VecVsRect(input.mousePoint, GetRectTop(window.rect, RESIZE_MARGIN))
			leftHover 		:= VecVsRect(input.mousePoint, GetRectLeft(window.rect, RESIZE_MARGIN))
			bottomHover 	:= VecVsRect(input.mousePoint, GetRectBottom(window.rect, RESIZE_MARGIN))
			rightHover 		:= VecVsRect(input.mousePoint, GetRectRight(window.rect, RESIZE_MARGIN))
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
					window.dragAnchor = window.rect.y + window.rect.h
				} else if leftHover {
					window.bits += {.resizing}
					window.dragSide = .left
					window.dragAnchor = window.rect.x + window.rect.w
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
			if .closable in window.options {
				SetNextRect(ChildRect(GetRectRight(titleRect, titleRect.h), {24, 24}, .middle, .middle))
				PushId(window.id)
				if Button(.close) {
					window.bits += {.shouldClose}
				}
				PopId()
			}
			if .resizing not_in window.bits && ctx.hoveredLayer == window.layer.id && VecVsRect(input.mousePoint, titleRect) {
				if .static not_in window.options && ctx.hoverId == 0 && MousePressed(.left) {
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
		// Outline
		PaintRoundedRectOutline(drawRect, WINDOW_ROUNDNESS, true, GetColor(.outlineBase))
		// Handle resizing
		if .resizing in bits {
			minSize: Vec2 = {180, 240}
			switch dragSide {
				case .bottom:
				rect.h = input.mousePoint.y - rect.y
				ctx.cursor = .resizeNS
				case .left:
				rect.x = min(input.mousePoint.x, dragAnchor - minSize.x)
				rect.w = dragAnchor - input.mousePoint.x
				ctx.cursor = .resizeEW
				case .right:
				rect.w = input.mousePoint.x - rect.x
				ctx.cursor = .resizeEW
				case .top:
				rect.y = min(input.mousePoint.y, dragAnchor - minSize.y)
				rect.h = dragAnchor - input.mousePoint.y
				ctx.cursor = .resizeNS
			}
			rect.w = max(rect.w, minSize.x)
			rect.h = max(rect.h, minSize.y)
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
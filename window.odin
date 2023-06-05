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
	// If the window has an extra layer for decoration
	decorated,
}
WindowBits :: bit_set[WindowBit]
WindowOption :: enum {
	// Removes all decoration
	undecorated,
	// Gives the window a title bar to move it
	title,
	// Lets the user resize the window
	resizable,
	// Disallows dragging
	static,
	// Shows a close button on the title bar
	closable,
	// Allows collapsing by right-click
	collapsable,
	// The window can't resize below its layout size
	fitToLayout,
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

	// Main layer
	layer: ^LayerData,
	// Decoration layer
	decorLayer: ^LayerData,

	// Current occupying rectangle
	rect, drawRect: Rect,
	// Collapse
	howCollapsed: f32,
}

WindowInfo :: struct {
	title: string,
	rect: Rect,
	layoutSize: Maybe(Vec2),
	minSize: Maybe(Vec2),
	options: WindowOptions,
	layerOptions: LayerOptions,
}
@(deferred_out=_Window)
Window :: proc(info: WindowInfo, loc := #caller_location) -> (ok: bool) {
	self: ^WindowData
	id := HashId(loc)
	if self, ok = CreateOrGetWindow(id); ok {
		ctx.currentWindow = self
		self.bits += {.stayAlive}
		
		// Initialize self
		if .initialized not_in self.bits {
			if info.rect != {} {
				self.rect = info.rect
			}
		}
		self.options = info.options
		self.title = info.title
		self.minLayoutSize = info.layoutSize.? or_else self.minLayoutSize
		
		if .shouldCollapse in self.bits {
			self.howCollapsed = min(1, self.howCollapsed + ctx.deltaTime * 4)
		} else {
			self.howCollapsed = max(0, self.howCollapsed - ctx.deltaTime * 4)
		}
		if self.howCollapsed >= 1 {
			self.bits += {.collapsed}
		} else {
			self.bits -= {.collapsed}
		}

		// Layer body
		self.drawRect = self.rect
		self.drawRect.h -= ((self.drawRect.h - WINDOW_TITLE_SIZE) if .title in self.options else self.drawRect.h) * self.howCollapsed

		// Decoration layer
		if self.decorLayer, ok = BeginLayer({
			rect = self.drawRect,
			id = HashId(rawptr(&self.id), size_of(Id)),
			order = .floating,
			options = {.shadow},
		}); ok {
			// Body
			if .collapsed not_in self.bits {
				PaintRoundedRect(self.drawRect, WINDOW_ROUNDNESS, GetColor(.base))
			}
			// Draw title bar and get movement dragging
			if .title in self.options {
				titleRect := Cut(.top, WINDOW_TITLE_SIZE)
				// Draw title rectangle
				if .collapsed in self.bits {
					PaintRoundedRect(titleRect, WINDOW_ROUNDNESS, GetColor(.widgetBackground))
				} else {
					PaintRoundedRectEx(titleRect, WINDOW_ROUNDNESS, {.topLeft, .topRight}, GetColor(.widgetBackground))
				}
				// Title bar decoration
				baseline := titleRect.y + titleRect.h / 2
				textOffset := titleRect.h * 0.25
				canCollapse := .collapsable in self.options || .collapsed in self.bits
				if canCollapse {
					PaintCollapseArrow({titleRect.x + titleRect.h / 2, baseline}, 8, self.howCollapsed, GetColor(.text))
					textOffset = titleRect.h
				}
				PaintStringAligned(GetFontData(.default), self.title, {titleRect.x + textOffset, baseline}, GetColor(.text), .near, .middle)
				if .closable in self.options {
					SetNextRect(ChildRect(GetRectRight(titleRect, titleRect.h), {24, 24}, .middle, .middle))
					if Button({
						label = Icon.close, 
						align = .middle, 
						subtle = true,
					}) {
						self.bits += {.shouldClose}
					}
				}
				if .resizing not_in self.bits && ctx.hoveredLayer == self.decorLayer.id && VecVsRect(input.mousePoint, titleRect) {
					if .static not_in self.options && ctx.hoverId == 0 && MousePressed(.left) {
						self.bits += {.moving}
						ctx.dragAnchor = Vec2{self.decorLayer.rect.x, self.decorLayer.rect.y} - input.mousePoint
					}
					if canCollapse && MousePressed(.right) {
						if .shouldCollapse in self.bits {
							self.bits -= {.shouldCollapse}
						} else {
							self.bits += {.shouldCollapse}
						}
					}
				}
			} else {
				self.bits -= {.shouldCollapse}
			}
		}
		
		innerRect := self.drawRect
		CutRect(&innerRect, .top, WINDOW_TITLE_SIZE)

		if .initialized not_in self.bits {
			self.minLayoutSize = {innerRect.w, innerRect.h}
			self.bits += {.initialized}
		}

		layerOptions := info.layerOptions + {.attached}
		if (self.howCollapsed > 0 && self.howCollapsed < 1) || (self.howCollapsed == 1 && .shouldCollapse not_in self.bits) {
			layerOptions += {.forceClip, .noScrollY}
			ctx.paintNextFrame = true
		}

		// Push layout if necessary
		if .collapsed in self.bits {
			ok = false
		} else {
			self.layer, ok = BeginLayer({
				rect = innerRect,
				innerRect = ShrinkRect(innerRect, 10),
				id = id, 
				options = layerOptions,
				layoutSize = self.minLayoutSize,
				order = .background,
			})
		}

		// Get resize click
		if .resizable in self.options && self.decorLayer.state >= {.hovered} && .collapsed not_in self.bits {
			RESIZE_MARGIN :: 5
			topHover 		:= VecVsRect(input.mousePoint, GetRectTop(self.rect, RESIZE_MARGIN))
			leftHover 		:= VecVsRect(input.mousePoint, GetRectLeft(self.rect, RESIZE_MARGIN))
			bottomHover 	:= VecVsRect(input.mousePoint, GetRectBottom(self.rect, RESIZE_MARGIN))
			rightHover 		:= VecVsRect(input.mousePoint, GetRectRight(self.rect, RESIZE_MARGIN))
			if topHover || bottomHover {
				ctx.cursor = .resizeNS
				ctx.hoverId = 0
			}
			if leftHover || rightHover {
				ctx.cursor = .resizeEW
				ctx.hoverId = 0
			}
			if MousePressed(.left) {
				if topHover {
					self.bits += {.resizing}
					self.dragSide = .top
					self.dragAnchor = self.rect.y + self.rect.h
				} else if leftHover {
					self.bits += {.resizing}
					self.dragSide = .left
					self.dragAnchor = self.rect.x + self.rect.w
				} else if bottomHover {
					self.bits += {.resizing}
					self.dragSide = .bottom
				} else if rightHover {
					self.bits += {.resizing}
					self.dragSide = .right
				}
			}
		}
	}
	return
}
@private
_Window :: proc(ok: bool) {
	if true {
		using self := ctx.currentWindow
		// End main layer
		if .collapsed not_in bits {
			// Outline
			PaintRoundedRectOutline(self.drawRect, WINDOW_ROUNDNESS, true, GetColor(.baseStroke))
			EndLayer(layer)
		}
		PaintRoundedRectOutline(self.drawRect, WINDOW_ROUNDNESS, true, GetColor(.baseStroke))
		// End decor layer
		EndLayer(decorLayer)
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
		// Handle resizing
		WINDOW_SNAP_DISTANCE :: 10
		if .resizing in bits {
			minSize: Vec2 = self.minLayoutSize if .fitToLayout in self.options else {180, 240}
			switch dragSide {
				case .bottom:
				anchor := input.mousePoint.y
				for other in &ctx.windows {
					if other != self {
						if abs(input.mousePoint.y - other.rect.y) < WINDOW_SNAP_DISTANCE {
							anchor = other.rect.y
						}
					}
				}
				self.rect.h = anchor - rect.y
				ctx.cursor = .resizeNS

				case .left:
				anchor := input.mousePoint.x
				for other in &ctx.windows {
					if other != self {
						if abs(input.mousePoint.x - (other.rect.x + other.rect.w)) < WINDOW_SNAP_DISTANCE {
							anchor = other.rect.x + other.rect.w
						}
					}
				}
				self.rect.x = min(anchor, self.dragAnchor - minSize.x)
				self.rect.w = self.dragAnchor - anchor
				ctx.cursor = .resizeEW

				case .right:
				anchor := input.mousePoint.x
				for other in &ctx.windows {
					if other != self {
						if abs(input.mousePoint.x - other.rect.x) < WINDOW_SNAP_DISTANCE {
							anchor = other.rect.x
						}
					}
				}
				self.rect.w = anchor - rect.x
				ctx.cursor = .resizeEW

				case .top:
				anchor := input.mousePoint.y
				for other in &ctx.windows {
					if other != self {
						if abs(input.mousePoint.y - (other.rect.y + other.rect.h)) < WINDOW_SNAP_DISTANCE {
							anchor = other.rect.y + other.rect.h
						}
					}
				}
				self.rect.y = min(anchor, self.dragAnchor - minSize.y)
				self.rect.h = self.dragAnchor - anchor
				ctx.cursor = .resizeNS
			}
			self.rect.w = max(self.rect.w, minSize.x)
			self.rect.h = max(self.rect.h, minSize.y)
			if MouseReleased(.left) {
				self.bits -= {.resizing}
			}
		}
	}
}


CurrentWindow :: proc() -> ^WindowData {
	return ctx.currentWindow
}
CreateOrGetWindow :: proc(id: Id) -> (self: ^WindowData, ok: bool) {
	self, ok = ctx.windowMap[id]
	if !ok {
		self, ok = CreateWindow(id)
	}
	return
}
CreateWindow :: proc(id: Id) -> (self: ^WindowData, ok: bool) {
	self = new(WindowData)
	self^ = {
		id = id,
	}
	append(&ctx.windows, self)
	ctx.windowMap[id] = self
	ok = true
	return
}
DeleteWindow :: proc(self: ^WindowData) {
	free(self)
}
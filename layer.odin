package maui
import "core:fmt"
import "core:math/linalg"
/*
	Layers are the root of all gui

	Each self contains a command buffer for draw calls made in that self.
*/

// Layer interaction state
LayerStatus :: enum {
	gotHover,
	hovered,
	lostHover,
	focused,
}
LayerState :: bit_set[LayerStatus]
// General purpose booleans
LayerBit :: enum {
	// If the layer should stay alive
	stayAlive,
	// If the layer requires clipping
	clipped,
	// If the layer requires scrollbars on either axis
	scrollX,
	scrollY,
	// If the layer was dismissed by an input
	dismissed,
	// If the layer pushed to the id stack this frame
	pushedId,
}
LayerBits :: bit_set[LayerBit]
// Options
LayerOption :: enum {
	// If the layer is attached (fixed) to it's parent
	attached,
	// Shadows for windows (must be drawn before clip command)
	shadow,
	// If the layer is spawned with 0 or 1 opacity
	invisible,
	// Disallow scrolling on either axis
	noScrollX,
	noScrollY,
	// Scroll bars won't affect layout size
	noScrollMarginX,
	noScrollMarginY,
	// Doesn't push the self's id to the stack
	noPushId,
	// Forces the self to clip its contents
	forceClip,
	// Forces the self to fit inside its parent
	clipToParent,
}
LayerOptions :: bit_set[LayerOption]
/*
	Layers for layers
*/
LayerOrder :: enum {
	// Allways in the background, fixed order
	background,
	// Free floating layers, dynamic order
	floating,
	// Allways in the foreground, fixed order
	tooltip,
	// Spetial self for debug drawing
	debug,
}
/*
	Each self's data
*/
LayerData :: struct {
	reserved: bool,
	parent: ^LayerData,
	children: [dynamic]^LayerData,

	// Base Data
	id: Id,
	// Internal state
	bits: LayerBits,
	// User options
	options: LayerOptions,
	// The layer's own state
	state,
	nextState: LayerState,

	// The painting opacity of all the layer's paint commands
	opacity: f32,

	// Viewport rectangle
	rect: Rect,

	// Rectangle on which scrollbars are anchored
	innerRect: Rect,

	// Inner layout size
	layoutSize: Vec2,

	// Content bounding box
	contentRect: Rect,

	// Negative content offset
	scroll, scrollTarget: Vec2,

	// draw order
	order: LayerOrder,

	// list index
	index: int,

	// controls on this self
	contents: map[Id]^WidgetData,

	// draw commands for this self
	commands: [COMMAND_BUFFER_SIZE]u8,
	commandOffset: int,

	// Clip command stored for use after
	// contents are already drawn
	clipCommand: ^CommandClip,

	// Scroll bars
	xScrollTime,
	yScrollTime: f32,
}

CurrentLayer :: proc() -> ^LayerData {
	assert(ctx.layerDepth > 0)
	return ctx.layerStack[ctx.layerDepth - 1]
}
CreateLayer :: proc(id: Id, options: LayerOptions) -> (self: ^LayerData, ok: bool) {
	// Allocate a new self
	for i in 0..<LAYER_ARENA_SIZE {
		if !ctx.layerArena[i].reserved {
			self = &ctx.layerArena[i]
			break
		}
	}
	//self = new(LayerData)
	self^ = {
		reserved = true,
		id = id,
		opacity = 0 if .invisible in options else 1,
	}
	// Append the new self
	append(&ctx.layers, self)
	ctx.layerMap[id] = self
	// Handle self attachment
	if ctx.layerDepth > 0 {
		parent := CurrentLayer() if .attached in options else ctx.rootLayer
		append(&parent.children, self)
		self.parent = parent
		self.index = len(parent.children)
	}
	// Will sort layers this frame
	ctx.sortLayers = true
	ok = true
	return
}
DeleteLayer :: proc(self: ^LayerData) {
	delete(self.contents)
	delete(self.children)
	self.reserved = false
}
CreateOrGetLayer :: proc(id: Id, options: LayerOptions) -> (self: ^LayerData, ok: bool) {
	self, ok = ctx.layerMap[id]
	if !ok {
		self, ok = CreateLayer(id, options)
	}
	return
}

// Frame info
FrameInfo :: struct {
	layoutSize: Vec2,
	options: LayerOptions,
	fillColor: Maybe(Color),
	scrollbarPadding: Maybe(f32),
}
@(deferred_out=_Frame)
Frame :: proc(info: FrameInfo, loc := #caller_location) -> (ok: bool) {
	self: ^LayerData
	rect := LayoutNext(CurrentLayout())
	self, ok = BeginLayer({
		rect = rect,
		innerRect = ShrinkRect(rect, info.scrollbarPadding.? or_else 0),
		layoutSize = info.layoutSize, 
		id = HashId(loc), 
		options = info.options + {.clipToParent, .attached},
	})
	return
}
@private
_Frame :: proc(ok: bool) {
	if ok {
		PaintRectLines(ctx.currentLayer.rect, 1, GetColor(.baseStroke))
		EndLayer(ctx.currentLayer)
	}
}

LayerInfo :: struct {
	rect: Maybe(Rect),
	innerRect: Maybe(Rect),
	layoutSize: Maybe(Vec2),
	order: Maybe(LayerOrder),
	options: LayerOptions,
	id: Maybe(Id),
}
@(deferred_out=_Layer)
Layer :: proc(info: LayerInfo, loc := #caller_location) -> (self: ^LayerData, ok: bool) {
	info := info
	info.id = info.id.? or_else HashId(loc)
	return BeginLayer(info)
}
@private
_Layer :: proc(self: ^LayerData, ok: bool) {
	if ok {
		EndLayer(self)
	}
}
// Begins a new layer, the layer is created if it doesn't exist
// and is managed internally
@private 
BeginLayer :: proc(info: LayerInfo, loc := #caller_location) -> (self: ^LayerData, ok: bool) {
	if self, ok = CreateOrGetLayer(info.id.? or_else panic("Must define a self id", loc), info.options); ok {
		assert(self != nil)

		// Push layer stack
		ctx.layerStack[ctx.layerDepth] = self
		ctx.layerDepth += 1
		ctx.currentLayer = self

		self.order = info.order.? or_else self.order

		// Update user options
		self.options = info.options

		// Begin id context for layer contents
		if .noPushId not_in self.options {
			PushId(self.id)
			self.bits += {.pushedId}
		} else {
			self.bits -= {.pushedId}
		}

		// Reset stuff
		self.bits += {.stayAlive}
		self.commandOffset = 0

		// Get rect
		self.rect = info.rect.? or_else self.rect
		self.innerRect = info.innerRect.? or_else self.rect

		// Hovering and stuff
		self.state = self.nextState
		self.nextState = {}
		if ctx.hoveredLayer == self.id {
			self.state += {.hovered}
			if ctx.prevHoveredLayer != self.id {
				self.state += {.gotHover}
			}
		} else if ctx.prevHoveredLayer == self.id {
			self.state += {.lostHover}
		}
		if ctx.focusedLayer == self.id {
			self.state += {.focused}
		}

		// Attachment
		if .attached in self.options {
			assert(self.parent != nil)
			parent := self.parent
			for parent != nil {
				parent.nextState += self.state
				if .attached not_in parent.options {
					break
				}
				parent = parent.parent
			}
		}

		// Update clip status
		self.bits -= {.clipped}
		if .clipToParent in self.options && self.parent != nil && !RectContainsRect(self.parent.rect, self.rect) {
			self.rect = ClampRect(self.rect, self.parent.rect)
		}

		// Shadows
		if .shadow in self.options {
			PaintRoundedRect(TranslateRect(self.rect, SHADOW_OFFSET), WINDOW_ROUNDNESS, GetColor(.shadow))
		}
		self.clipCommand = PushCommand(self, CommandClip)
		self.clipCommand.rect = ctx.fullscreenRect

		// Get layout size
		self.layoutSize = info.layoutSize.? or_else {}
		self.layoutSize = {
			max(self.layoutSize.x, self.rect.w),
			max(self.layoutSize.y, self.rect.h),
		}

		// Detect scrollbar necessity
		SCROLL_LERP_SPEED :: 7

		// Horizontal scrolling
		if self.layoutSize.x > self.rect.w && .noScrollX not_in self.options {
			self.bits += {.scrollX}
			self.xScrollTime = min(1, self.xScrollTime + ctx.deltaTime * SCROLL_LERP_SPEED)
		} else {
			self.bits -= {.scrollX}
			self.xScrollTime = max(0, self.xScrollTime - ctx.deltaTime * SCROLL_LERP_SPEED)
		}
		if .noScrollMarginY not_in self.options && self.layoutSize.y <= self.rect.h {
			self.layoutSize.y -= self.xScrollTime * SCROLL_BAR_SIZE
		}
		if self.xScrollTime > 0 && self.xScrollTime < 1 {
			ctx.paintNextFrame = true
		}

		// Vertical scrolling
		if self.layoutSize.y > self.rect.h && .noScrollY not_in self.options {
			self.bits += {.scrollY}
			self.yScrollTime = min(1, self.yScrollTime + ctx.deltaTime * SCROLL_LERP_SPEED)
		} else {
			self.bits -= {.scrollY}
			self.yScrollTime = max(0, self.yScrollTime - ctx.deltaTime * SCROLL_LERP_SPEED)
		}
		if .noScrollMarginX not_in self.options && self.layoutSize.x <= self.rect.w {
			self.layoutSize.x -= self.yScrollTime * SCROLL_BAR_SIZE
		}
		if self.yScrollTime > 0 && self.yScrollTime < 1 {
			ctx.paintNextFrame = true
		}
		self.contentRect = {self.rect.x + self.rect.w, self.rect.y + self.rect.h, 0, 0}

		// Layers currently have their own layouts, but this is subject to change
		layoutRect: Rect = {
			self.rect.x - self.scroll.x,
			self.rect.y - self.scroll.y,
			self.layoutSize.x,
			self.layoutSize.y,
		}
		PushLayout(layoutRect)
	}
	return
}
// Called for every 'BeginLayer' that is called
@private 
EndLayer :: proc(self: ^LayerData) {
	if self != nil {
		// Debug stuff
		when ODIN_DEBUG {
			if .showWindow in ctx.debugBits && self.id != 0 && ctx.debugLayer == self.id {
				PaintRect(self.rect, {255, 0, 255, 20})
				PaintRectLines(self.rect, 1, {255, 0, 255, 255})
			}
		}

		// Detect clipping
		if (self.rect != ctx.fullscreenRect && !RectContainsRect(self.rect, self.contentRect)) || .forceClip in self.options {
			self.bits += {.clipped}
		}

		// End layout
		PopLayout()

		// Handle scrolling
		SCROLL_SPEED :: 16
		SCROLL_STEP :: 55

		// Maximum scroll offset
		maxScroll: Vec2 = {
			max(self.layoutSize.x - self.rect.w, 0),
			max(self.layoutSize.y - self.rect.h, 0),
		}

		// Update scroll offset
		if ctx.hoveredLayer == self.id {
			self.scrollTarget -= input.mouseScroll * SCROLL_STEP
		}
		self.scrollTarget.x = clamp(self.scrollTarget.x, 0, maxScroll.x)
		self.scrollTarget.y = clamp(self.scrollTarget.y, 0, maxScroll.y)
		if linalg.floor(self.scrollTarget - self.scroll) != {} {
			ctx.paintNextFrame = true
		}
		self.scroll += (self.scrollTarget - self.scroll) * SCROLL_SPEED * ctx.deltaTime

		// Manifest scroll bars
		if self.xScrollTime > 0 {
			rect := GetRectBottom(self.innerRect, self.xScrollTime * SCROLL_BAR_SIZE)
			rect.w -= self.yScrollTime * SCROLL_BAR_SIZE
			rect.h -= SCROLL_BAR_PADDING
			rect.x += SCROLL_BAR_PADDING
			rect.w -= SCROLL_BAR_PADDING * 2
			SetNextRect(rect)
			if changed, newValue := ScrollBar({
				value = self.scroll.x, 
				low = 0, 
				high = maxScroll.x, 
				thumbSize = max(SCROLL_BAR_SIZE * 2, rect.w * self.rect.w / self.layoutSize.x),
			}); changed {
				self.scroll.x = newValue
				self.scrollTarget.x = newValue
			}
		}
		if self.yScrollTime > 0 {
			rect := GetRectRight(self.innerRect, self.yScrollTime * SCROLL_BAR_SIZE)
			rect.h -= self.xScrollTime * SCROLL_BAR_SIZE
			rect.w -= SCROLL_BAR_PADDING
			rect.y += SCROLL_BAR_PADDING
			rect.h -= SCROLL_BAR_PADDING * 2
			SetNextRect(rect)
			if change, newValue := ScrollBar({
				value = self.scroll.y, 
				low = 0, 
				high = maxScroll.y, 
				thumbSize = max(SCROLL_BAR_SIZE * 2, rect.h * self.rect.h / self.layoutSize.y), 
				vertical = true,
			}); change {
				self.scroll.y = newValue
				self.scrollTarget.y = newValue
			}
		}

		// Handle content clipping
		if .clipped in self.bits {
			// Apply clipping
			assert(self.clipCommand != nil)
			self.rect.h = max(0, self.rect.h)
			self.clipCommand.rect = self.rect
		}
		// Push a new clip command to end clipping
		PushCommand(self, CommandClip).rect = ctx.fullscreenRect
		
		if .attached in self.options {
			UpdateLayerContentRect(self.parent, self.innerRect)
		}
		
		// End id context
		if .pushedId in self.bits {
			PopId()
		}
	}
	ctx.layerDepth -= 1
	if ctx.layerDepth > 0 {
		ctx.currentLayer = ctx.layerStack[ctx.layerDepth - 1]
	}
}
UpdateLayerContentRect :: proc(self: ^LayerData, rect: Rect) {
	self.contentRect.x = min(self.contentRect.x, rect.x)
	self.contentRect.y = min(self.contentRect.y, rect.y)
	self.contentRect.w = max(self.contentRect.w, (rect.x + rect.w) - self.contentRect.x)
	self.contentRect.h = max(self.contentRect.h, (rect.y + rect.h) - self.contentRect.y)
}

Clip :: enum {
	none,		// completely visible
	partial,	// partially visible
	full,		// hidden
}
CheckClip :: proc(clip, rect: Rect) -> Clip {
	if rect.x > clip.x + clip.w || rect.x + rect.w < clip.x ||
	   rect.y > clip.y + clip.h || rect.y + rect.h < clip.y { 
		return .full 
	}
	if rect.x >= clip.x && rect.x + rect.w <= clip.x + clip.w &&
	   rect.y >= clip.y && rect.y + rect.h <= clip.y + clip.h { 
		return .none
	}
	return .partial
}
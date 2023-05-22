package maui
import "core:fmt"
/*
	Layers are the root of all gui

	Each layer contains a command buffer for draw calls made in that layer.
*/

/*
	General purpose booleans
*/
LayerBit :: enum {
	stayAlive,
	clipped,
	submit,
	scrollX,
	scrollY,
	childHovered,
	dismissed,
}
LayerBits :: bit_set[LayerBit]
// Options
LayerOption :: enum {
	attached,
	outlined,
	shadow,
	invisible,
	noScrollX,
	noScrollY,
	noScrollMarginX,
	noScrollMarginY,
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
	// Spetial layer for debug drawing
	debug,
}
/*
	Each layer's data
*/
LayerData :: struct {
	parent: ^LayerData,
	// Children are always stored directly after parent layer
	childCount: int,
	// Base Data
	id: Id,
	bits: LayerBits,
	options: LayerOptions,
	body: Rect,
	opacity: f32,
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
	// controls on this layer
	contents: map[Id]int,
	// draw commands for this layer
	commands: [COMMAND_BUFFER_SIZE]u8,
	commandOffset: int,
	// Clip command stored for use after
	// contents are already drawn
	clipCommand: ^CommandClip,
}

GetCurrentLayer :: proc() -> ^LayerData {
	using ctx
	return layerStack[layerDepth - 1]
}
GetLayer :: proc(name: string) -> (layer: ^LayerData, ok: bool) {
	using ctx
	layer, ok = layerMap[HashId(name)]
	return
}
CreateLayer :: proc(id: Id, options: LayerOptions) -> (layer: ^LayerData, ok: bool) {
	// Allocate a new layer
	layer = new(LayerData)
	layer^ = {
		id = id,
		opacity = 0 if .invisible in options else 1,
	}
	append(&ctx.layers, layer)
	ctx.layerMap[id] = layer
	ctx.sortLayers = true
	ok = true
	return
}
DeleteLayer :: proc(layer: ^LayerData) {
	delete(layer.contents)
	free(layer)
}
CreateOrGetLayer :: proc(id: Id, options: LayerOptions) -> (layer: ^LayerData, ok: bool) {
	layer, ok = ctx.layerMap[id]
	if !ok {
		layer, ok = CreateLayer(id, options)
	}
	if ok {
		// Handle layer attachment
		if .attached in options {
			parent := GetCurrentLayer()
			layer.parent = parent
			layer.order = parent.order
			layer.index = parent.index + parent.childCount
			parent.childCount += 1
		}
	}
	return
}

// Begins a new layer, the layer is created if it doesn't exist
// and is managed internally
@private 
BeginLayer :: proc(rect: Rect, size: Vec2, id: Id, options: LayerOptions) -> (layer: ^LayerData, ok: bool) {
	if layer, ok = CreateOrGetLayer(id, options); ok {
		// Begin id context for layer contents
		PushId(id)
		// Push layer stack
		ctx.layerStack[ctx.layerDepth] = layer
		ctx.layerDepth += 1
		// Update user options
		layer.options = options
		// Reset stuff
		layer.bits += {.stayAlive}
		layer.bits -= {.submit, .childHovered}
		layer.commandOffset = 0
		layer.childCount = 0
		// Apply rectangle
		if rect != {} {
			layer.body = rect
		} else {
			layer.body = ctx.fullscreenRect
		}
		// Shadows
		if .shadow in options {
			PaintRoundedRect(TranslateRect(layer.body, 7), WINDOW_ROUNDNESS, GetColor(.shade, 0.15))
		}
		// Update clip status
		if layer.body != ctx.fullscreenRect && !RectContainsRect(layer.body, layer.contentRect) {
			layer.clipCommand = PushCommand(layer, CommandClip)
			layer.bits += {.clipped}
		} else {
			layer.bits -= {.clipped}
		}
		// Get layout size
		layer.layoutSize = {
			max(size.x, layer.body.w),
			max(size.y, layer.body.h),
		}
		// Detect scrollbar necessity
		if layer.layoutSize.x > layer.body.w && .noScrollX not_in layer.options {
			layer.bits += {.scrollX}
			if .noScrollMarginY not_in layer.options {
				layer.layoutSize.y -= SCROLL_BAR_SIZE
			}
		} else {
			layer.bits -= {.scrollX}
		}
		if layer.layoutSize.y > layer.body.h && .noScrollY not_in layer.options {
			layer.bits += {.scrollY}
			if .noScrollMarginX not_in layer.options {
				layer.layoutSize.x -= SCROLL_BAR_SIZE
			}
		} else {
			layer.bits -= {.scrollY}
		}
		layer.contentRect = {layer.body.x + layer.body.w, layer.body.y + layer.body.h, 0, 0}
		// Begin layout
		PushLayout({layer.body.x - layer.scroll.x, layer.body.y - layer.scroll.y, layer.layoutSize.x, layer.layoutSize.y})
	}
	return
}
// Called for every 'BeginLayer' that is called
@private 
EndLayer :: proc(layer: ^LayerData) {
	if layer != nil {
		// Debug stuff
		when ODIN_DEBUG {
			if ctx.debugLayer == layer.id {
				PaintRect(layer.body, {255, 0, 255, 20})
				PaintRectLines(layer.body, 1, {255, 0, 255, 255})
			}
		}
		// End layout
		PopLayout()
		// Handle content clipping
		if .clipped in layer.bits {
			// Since clipping is required, update the previous command to fit the layer
			layer.clipCommand.rect = layer.body
			// Scrolling constants (put these elsewhere maybe)
			SCROLL_SPEED :: 16
			SCROLL_STEP :: 55
			// Maximum scroll offset
			maxScroll: Vec2 = {
				max(layer.layoutSize.x - layer.body.w, 0),
				max(layer.layoutSize.y - layer.body.h, 0),
			}
			// Update scroll offset
			if ctx.hoveredLayer == layer.id {
				layer.scrollTarget -= input.mouseScroll * SCROLL_STEP
			}
			layer.scrollTarget.x = clamp(layer.scrollTarget.x, 0, maxScroll.x)
			layer.scrollTarget.y = clamp(layer.scrollTarget.y, 0, maxScroll.y)
			layer.scroll += (layer.scrollTarget - layer.scroll) * SCROLL_SPEED * ctx.deltaTime
			// Manifest scroll bars
			if .scrollX in layer.bits {
				rect := GetRectBottom(layer.body, SCROLL_BAR_SIZE)
				if .scrollY in layer.bits {
					rect.w -= SCROLL_BAR_SIZE
				}
				rect.h -= SCROLL_BAR_PADDING
				rect.x += SCROLL_BAR_PADDING
				rect.w -= SCROLL_BAR_PADDING * 2
				SetNextRect(rect)
				if change, newValue := ScrollBar(layer.scroll.x, 0, maxScroll.x, max(SCROLL_BAR_SIZE * 2, rect.w * layer.body.w / layer.layoutSize.x), false); change {
					layer.scroll.x = newValue
					layer.scrollTarget.x = newValue
				}
			}
			if .scrollY in layer.bits {
				rect := GetRectRight(layer.body, SCROLL_BAR_SIZE)
				if .scrollX in layer.bits {
					rect.h -= SCROLL_BAR_SIZE
				}
				rect.w -= SCROLL_BAR_PADDING
				rect.y += SCROLL_BAR_PADDING
				rect.h -= SCROLL_BAR_PADDING * 2
				SetNextRect(rect)
				if change, newValue := ScrollBar(layer.scroll.y, 0, maxScroll.y, max(SCROLL_BAR_SIZE * 2, rect.h * layer.body.h / layer.layoutSize.y), true); change {
					layer.scroll.y = newValue
					layer.scrollTarget.y = newValue
				}
			}
			// Push a new clip command to end clipping
			PushCommand(layer, CommandClip).rect = ctx.fullscreenRect
		}
		// End id context
		PopId()
	}
	ctx.layerDepth -= 1
}
UpdateLayerContentRect :: proc(layer: ^LayerData, rect: Rect) {
	layer.contentRect.x = min(layer.contentRect.x, rect.x)
	layer.contentRect.y = min(layer.contentRect.y, rect.y)
	layer.contentRect.w = max(layer.contentRect.w, (rect.x + rect.w) - layer.contentRect.x)
	layer.contentRect.h = max(layer.contentRect.h, (rect.y + rect.h) - layer.contentRect.y)
}

@(deferred_out=_Layer)
Layer :: proc(rect: Rect, size: Vec2, options: LayerOptions, loc := #caller_location) -> (layer: ^LayerData, ok: bool) {
	return BeginLayer(rect, size, HashId(loc), options)
}
@private
_Layer :: proc(layer: ^LayerData, ok: bool) {
	if ok {
		EndLayer(layer)
	}
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

/*
	Layer uses
*/
@(deferred_out=_Frame)
Frame :: proc(size: Vec2, options: LayerOptions, loc := #caller_location) -> (layer: ^LayerData, ok: bool) {
	layer, ok = BeginLayer(LayoutNext(GetCurrentLayout()), size, HashId(loc), options + {.attached})
	if ok {
		PaintRect(layer.body, GetColor(.backing))
	}
	return
}
@private
_Frame :: proc(layer: ^LayerData, ok: bool) {
	if ok {
		EndLayer(layer)
	}
}
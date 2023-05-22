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
	background,
	floating,
	frame,
	popup,
	tooltip,
}
/*
	Each layer's data
*/
LayerData :: struct {
	parent: ^LayerData,
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
	for i in 0 ..< MAX_LAYERS {
		if !ctx.layerExists[i] {
			ctx.layerExists[i] = true

			delete(ctx.layers[i].contents)
			ctx.layers[i] = {}

			layer = &ctx.layers[i]
			ok = true
			if options >= {.invisible} {
				layer.opacity = 0
			} else {
				layer.opacity = 1
			}

			ctx.layerMap[id] = layer
			if .attached in options {
				inject_at(&ctx.layerList, GetCurrentLayer().index + 1, i)
			} else {
				append(&ctx.layerList, i)
			}

			break
		}
	}
	return
}
CreateOrGetLayer :: proc(id: Id, options: LayerOptions) -> (layer: ^LayerData, ok: bool) {
	layer, ok = ctx.layerMap[id]
	if !ok {
		layer, ok = CreateLayer(id, options)
	}
	return
}

// TODO: Closing layers
@private BeginLayer :: proc(rect: Rect, size: Vec2, id: Id, options: LayerOptions) -> (layer: ^LayerData, ok: bool) {
	if layer, ok = CreateOrGetLayer(id, options); ok {
		PushId(id)

		// Push layer stack
		ctx.layerStack[ctx.layerDepth] = layer
		ctx.layerDepth += 1

		// Update layer data
		layer.bits += {.stayAlive}
		layer.bits -= {.submit, .childHovered}

		layer.options = options
		layer.id = id
		layer.commandOffset = 0

		if .attached in options && ctx.layerDepth > 1 {
			layer.parent = ctx.layerStack[ctx.layerDepth - 2]
		} else {
			layer.parent = nil
		}

		if rect != {} {
			layer.body = rect
		} else {
			layer.body = ctx.fullscreenRect
		}

		if layer.body != ctx.fullscreenRect && !RectContainsRect(layer.body, layer.contentRect) {
			layer.clipCommand = PushCommand(layer, CommandClip)
			layer.bits += {.clipped}
		} else {
			layer.bits -= {.clipped}
		}

		layer.layoutSize = {
			max(size.x, layer.body.w),
			max(size.y, layer.body.h),
		}

		// Detect scrollbar necessity
		if layer.layoutSize.x > layer.body.w && layer.options < {.noScrollX} {
			layer.bits += {.scrollX}
			if .noScrollMarginY not_in layer.options {
				layer.layoutSize.y -= SCROLL_BAR_SIZE
			}
		} else {
			layer.bits -= {.scrollX}
		}
		if layer.layoutSize.y > layer.body.h && layer.options < {.noScrollY} {
			layer.bits += {.scrollY}
			if .noScrollMarginX not_in layer.options {
				layer.layoutSize.x -= SCROLL_BAR_SIZE
			}
		} else {
			layer.bits -= {.scrollY}
		}

		// Reset content rect
		layer.contentRect = {layer.body.x + layer.body.w, layer.body.y + layer.body.h, 0, 0}

		// Begin layout
		PushLayout({layer.body.x - layer.scroll.x, layer.body.y - layer.scroll.y, layer.layoutSize.x, layer.layoutSize.y})
	}
	return
}
@private EndLayer :: proc(layer: ^LayerData) {
	using ctx

	when ODIN_DEBUG {
		if debugLayer == layer.id {
			PaintRect(layer.body, {255, 0, 255, 20})
			PaintRectLines(layer.body, 1, {255, 0, 255, 255})
		}
	}
	
	PopLayout()

	// Handle content clipping
	if .clipped in layer.bits {
		layer.clipCommand.rect = layer.body
		PushCommand(layer, CommandClip).rect = fullscreenRect

		SCROLL_SPEED :: 16
		SCROLL_STEP :: 55

		maxScroll: Vec2 = {
			max(layer.layoutSize.x - layer.body.w, 0),
			max(layer.layoutSize.y - layer.body.h, 0),
		}

		// Update scroll offset
		if hoveredLayer == layer.id {
			layer.scrollTarget -= input.mouseScroll * SCROLL_STEP
		}
		layer.scrollTarget.x = clamp(layer.scrollTarget.x, 0, maxScroll.x)
		layer.scrollTarget.y = clamp(layer.scrollTarget.y, 0, maxScroll.y)
		layer.scroll += (layer.scrollTarget - layer.scroll) * SCROLL_SPEED * ctx.deltaTime

		// Scroll bars
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
	}
	PopId()

	layerDepth -= 1
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
@private _Layer :: proc(layer: ^LayerData, ok: bool) {
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
	layer, ok = BeginLayer(LayoutNext(GetCurrentLayout()), size, HashId(loc), options)
	if ok {
		layer.order = .frame
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
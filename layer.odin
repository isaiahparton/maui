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
}
LayerBits :: bit_set[LayerBit]
// Options
LayerOption :: enum {
	outlined,
	noScrollX,
	noScrollY,
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
	index: i32,
	// controls on this layer
	contents: map[Id]i32,
	// draw commands for this layer
	commands: [COMMAND_BUFFER_SIZE]u8,
	commandOffset: i32,
	// Clip command stored for use after
	// contents are already drawn
	clipCommand: ^CommandClip,
}

GetCurrentLayer :: proc() -> ^LayerData {
	using ctx
	return layerStack[layerDepth - 1]
}
GetLayer :: proc(name: string) -> ^LayerData {
	using ctx
	layer, ok := layerMap[HashId(name)]
	if ok {
		return layer
	}
	return nil
}
CreateOrGetLayer :: proc(id: Id) -> (layer: ^LayerData, ok: bool) {
	using ctx
	layer, ok = layerMap[id]
	if !ok {
		for i in 0 ..< MAX_LAYERS {
			if !layerExists[i] {
				layerExists[i] = true

				delete(layers[i].contents)
				layers[i] = {opacity=1}

				layer = &layers[i]
				ok = true

				layerMap[id] = layer
				append(&layerList, i32(i))

				break
			}
		}
	}
	return
}

// TODO: Closing layers
@private BeginLayer :: proc(rect: Rect, size: Vec2, id: Id, options: LayerOptions) -> (layer: ^LayerData, ok: bool) {
	// Find or create layer
	layer, ok = CreateOrGetLayer(id)
	if !ok {
		return
	}

	// Push layer stack
	ctx.layerStack[ctx.layerDepth] = layer
	ctx.layerDepth += 1

	// Update layer data
	layer.bits += {.stayAlive}
	layer.options = options
	layer.id = id
	layer.commandOffset = 0
	if rect != {} {
		layer.body = rect
	} else {
		layer.body = ctx.fullscreenRect
	}

	PushId(id)
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
	if layer.contentRect.w > layer.body.w && layer.options < {.noScrollX} {
		layer.layoutSize.y -= SCROLL_BAR_SIZE
		layer.bits += {.scrollX}
	} else {
		layer.bits -= {.scrollX}
	}
	if layer.contentRect.h > layer.body.h && layer.options < {.noScrollY} {
		layer.layoutSize.x -= SCROLL_BAR_SIZE
		layer.bits += {.scrollY}
	} else {
		layer.bits -= {.scrollY}
	}

	// Reset content rect
	layer.contentRect = {layer.body.x + layer.body.w, layer.body.y + layer.body.h, 0, 0}

	// Begin layout
	PushLayout({layer.body.x - layer.scroll.x, layer.body.y - layer.scroll.y, layer.layoutSize.x, layer.layoutSize.y})
	return
}
@private EndLayer :: proc(layer: ^LayerData) {
	using ctx

	when ODIN_DEBUG {
		if .showLayers in options {
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
			max(layer.contentRect.w - layer.body.w + SCROLL_BAR_SIZE, 0),
			max(layer.contentRect.h - layer.body.h + SCROLL_BAR_SIZE, 0),
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
			if change, newValue := ScrollBarH(layer.scroll.x, 0, maxScroll.x, max(SCROLL_BAR_SIZE * 2, rect.w * layer.body.w / layer.layoutSize.x)); change {
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
			if change, newValue := ScrollBarV(layer.scroll.y, 0, maxScroll.y, max(SCROLL_BAR_SIZE * 2, rect.h * layer.body.h / layer.layoutSize.y)); change {
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
Layer :: proc(rect: Rect, size: Vec2, loc := #caller_location) -> (layer: ^LayerData, ok: bool) {
	return BeginLayer(rect, size, HashId(loc), {})
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
Frame :: proc(size: Vec2, loc := #caller_location) -> (layer: ^LayerData, ok: bool) {
	layer, ok = BeginLayer(LayoutNext(GetCurrentLayout()), size, HashId(loc), {})
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
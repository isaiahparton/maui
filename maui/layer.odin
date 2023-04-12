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
}
LayerBits :: bit_set[LayerBit]
/*
	Layers for layers
*/
LayerOrder :: enum {
	background,
	floating,
	popup,
	tooltip,
}
/*
	Each layer's data
*/
LayerData :: struct {
	id: Id,
	bits: LayerBits,
	body: Rect,
	// Content bounding box
	contentRect: Rect,
	// Negative content offset
	scroll: Vec2,
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
		for i in 0..<MAX_LAYERS {
			if !layerExists[i] {
				layerExists[i] = true
				layers[i] = {}

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
@private BeginLayer :: proc(rect: Rect, size: Vec2, id: Id, options: LayerBits) -> (layer: ^LayerData, ok: bool) {
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
	layer.id = id
	layer.commandOffset = 0
	if rect != {} {
		layer.body = rect
	}

	PushId(id)
	if !RectContainsRect(layer.body, layer.contentRect) {
		layer.clipCommand = PushCommand(CommandClip)
		layer.bits += {.clipped}
	} else {
		layer.bits -= {.clipped}
	}

	layer.contentRect = {layer.body.x + layer.body.w, layer.body.y + layer.body.h, 0, 0}

	layoutSize := size if size != {} else {layer.body.w, layer.body.h}
	PushLayout({layer.body.x - layer.scroll.x, layer.body.y - layer.scroll.y, layoutSize.x, layoutSize.y})

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

	if .clipped in layer.bits {
		layer.clipCommand.rect = layer.body
		PushCommand(CommandClip).rect = fullscreenRect

		//TODO: Smooth scrolling
		layer.scroll -= input.mouseScroll * 50
	}
	PopId()

	layerDepth -= 1
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
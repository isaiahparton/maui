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
	layoutSize: Vec2,
	// draw order
	order: LayerOrder,
	// list index
	index: i32,
	// controls on this layer
	contents: map[Id]i32,
	// draw commands for this layer
	commands: [COMMAND_BUFFER_SIZE]u8,
	commandOffset: i32,
}

LayerOptions :: struct {
	origin, size: AnyVec2,
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

@private BeginLayer :: proc(rect: Rect, id: Id, options: LayerBits) -> (layer: ^LayerData, ok: bool) {
	using ctx
	
	/*
		Find or create the layer
	*/
	layer, ok = CreateOrGetLayer(id)
	if !ok {
		return
	}

	/*
		Update layer stack
	*/
	layerStack[layerDepth] = layer
	layerDepth += 1

	/*
		Update layer values
	*/
	layer.bits += {.stayAlive}
	layer.id = id
	layer.commandOffset = 0
	if rect != {} {
		layer.body = rect
	}

	PushId(id)
	BeginClip(layer.body)

	return
}
@private EndLayer :: proc(layer: ^LayerData) {
	using ctx

	when ODIN_DEBUG {
		if .showLayers in options {
			PaintRectLines(layer.body, 1, {255, 0, 255, 255})
		}
	}

	EndClip()
	PopId()

	layerDepth -= 1
}

@(deferred_out=_Layer)
Layer :: proc(rect: Rect, loc := #caller_location) -> (layer: ^LayerData, ok: bool) {
	return BeginLayer(rect, HashId(loc), {})
}
@private _Layer :: proc(layer: ^LayerData, ok: bool) {
	if ok {
		EndLayer(layer)
	}
}
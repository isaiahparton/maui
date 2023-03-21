package maui
import "core:fmt"
/*
	Layers are the root of all gui

	Each layer contains a command buffer for draw calls made in that layer.
*/

LayerBit :: enum {
	stayAlive,
}
LayerBits :: bit_set[LayerBit]
LayerOrder :: enum {
	background,
	floating,
	tooltip,
}
LayerData :: struct {
	id: Id,
	bits: LayerBits,
	body: Rect,
	layoutSize, contentSize: Vector,
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
	origin, size: AnyVector,
}

GetCurrentLayer :: proc() -> ^LayerData {
	using ctx
	return &layers[layerStack[layerDepth - 1]]
}
GetLayer :: proc(name: string) -> ^LayerData {
	using ctx
	idx, ok := layerMap[HashId(name)]
	if ok {
		return &layers[idx]
	}
	return nil
}
CreateOrGetLayer :: proc(id: Id) -> (^LayerData, i32) {
	using ctx
	index, ok := layerMap[id]
	if !ok {
		index = -1
		for i in 0..<MAX_LAYERS {
			if !layerExists[i] {
				layerExists[i] = true
				layers[i] = {}
				index = i32(i)
				layerMap[id] = index
				append(&layerList, index)
				break
			}
		}
	}
	if index >= 0 {
		return &layers[index], index
	}
	return nil, index
}

@private BeginLayer :: proc(rect: Rect, id: Id, options: LayerBits) -> (^LayerData, bool) {
	using ctx

	/*
		Find or create the layer
	*/
	layer, index := CreateOrGetLayer(id)
	if layer == nil {
		return nil, false
	}

	/*
		Update layer stack
	*/
	layerStack[layerDepth] = index
	layerDepth += 1

	/*
		Update layer values
	*/
	//layer.options += options + {.stayAlive}
	layer.id = id
	layer.commandOffset = 0
	if rect != {} {
		layer.body = rect
	}

	PushId(id)
	PushFrame(layer.body, {})
	BeginClip(layer.body)

	layer.contentSize = {}

	return layer, true
}
@private EndLayer :: proc(layer: ^LayerData) {
	using ctx
	EndClip()
	PopId()
	PopFrame()

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
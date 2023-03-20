package maui
import "core:fmt"
/*
	Layers are the root of all gui

	Each layer contains a command buffer for draw calls made in that layer.

	Things that have a layer:
	* Windows
	* Panels
	* Scroll Areas
*/
PANEL_TITLE_SIZE :: 30

LayerBit :: enum {
	title,
	resizable,
	moveable,
	floating,
	autoFit,
	fixedLayout,
	stayAlive,
}
LayerBits :: bit_set[LayerBit]
LayerStatus :: enum {
	resizing,
	moving,
	shouldClose,
}
LayerState :: bit_set[LayerStatus]

LayerData :: struct {
	id: Id,
	title: string,
	bits: LayerBits,
	state: LayerState,
	body: Rect,
	layoutSize, contentSize: Vector,
	// draw order
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
DefineLayer :: proc(name: string, options: LayerOptions, space: Vector = {}) {
	using ctx
	id := HashId(name)
	layer, index := CreateOrGetLayer(id)
	if layer == nil {
		return
	}
	layer.title = name
	layer.body = {
		ToAbsolute(options.origin.x, f32(size.x)),
		ToAbsolute(options.origin.y, f32(size.y)),
		ToAbsolute(options.size.x, f32(size.x)),
		ToAbsolute(options.size.y, f32(size.y)),
	}
	layer.body.x -= layer.body.w / 2
	layer.body.y -= layer.body.h / 2
	layer.layoutSize = {layer.body.w, layer.body.h}
}
ToAbsolute :: proc(v: Value, f: f32 = 0) -> f32 {
	switch t in v {
		case Absolute:
		return f32(t)
		case Relative:
		return t * f
	}
	return 0
}

@private BeginLayerEx :: proc(rect: Rect, id: Id, bits: LayerBits) -> (^LayerData, bool) {
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
	layer.bits += bits + {.stayAlive}
	layer.id = id
	layer.commandOffset = 0
	if rect != {} {
		layer.body = rect
	}

	/*
		Define the frame
	*/
	frameRect := layer.body
	if .fixedLayout in layer.bits {
		frameRect.w = layer.layoutSize.x
		frameRect.h = layer.layoutSize.y
	}
	if .title in layer.bits {
		frameRect.y += PANEL_TITLE_SIZE
		frameRect.h -= PANEL_TITLE_SIZE
	}
	PushFrame(frameRect, {})
	BeginClip(layer.body)

	/*
		Draw the layer body and title bar if needed
	*/
	DrawRect(layer.body, GetColor(0, 1))
	if .title in layer.bits {
		titleRect := Rect{layer.body.x, layer.body.y, layer.body.w, PANEL_TITLE_SIZE}
		DrawRect(titleRect, GetColor(5, 1))
		DrawRect({layer.body.x, layer.body.y + PANEL_TITLE_SIZE - ctx.style.outline, layer.body.w, ctx.style.outline}, GetColor(1, 1))
		DrawAlignedString(ctx.font, layer.title, {frameRect.x + 10, frameRect.y - 15}, GetColor(1, 1), .near, .middle)
	}
	if .resizable in layer.bits {
		a := Vector{layer.body.x + layer.body.w - 1, layer.body.y + layer.body.h - 1}
		b := Vector{a.x, a.y - 30}
		c := Vector{a.x - 30, a.y}
		DrawTriangle(a, b, c, GetColor(5, 1))
		DrawLine(b, c, ctx.style.outline, GetColor(1, 1))
	}

	PushId(id)

	/*
		Handle title bar
	*/
	if .title in layer.bits {
		titleRect := Rect{layer.body.x, layer.body.y, layer.body.w, PANEL_TITLE_SIZE}

		if Layout(titleRect) {
			CutSide(.right)
			CutSize(titleRect.h)
			if IconButtonEx(.close) {
				layer.state += {.shouldClose}
			}
		}

		if hoveredLayer == index && VecVsRect(input.mousePos, titleRect) {
			if MousePressed(.left) {
				layer.state += {.moving}
				dragAnchor = Vector{layer.body.x, layer.body.y} - input.mousePos
			}
		}
	}

	/*
		Handle resizing
	*/
	if .resizable in layer.bits {
		grabRect := Rect{layer.body.x + layer.body.w - 30, layer.body.y + layer.body.h - 30, 30, 30}
		if hoveredLayer == index && VecVsRect(input.mousePos, grabRect) {
			if MousePressed(.left) {
				layer.state += {.resizing}
			}
		}
	}

	layer.contentSize = {}

	return layer, true
}
@private BeginLayer :: proc(rect: Rect, name: string) -> (^LayerData, bool) {
	return BeginLayerEx(rect, HashId(name), {})
}
@private EndLayer :: proc() {
	using ctx

	layer := GetCurrentLayer()

	DrawRectLines(layer.body, ctx.style.outline, GetColor(1, 1))

	if .resizing in layer.state {
		layer.body.w = max(input.mousePos.x - layer.body.x, 240)
		layer.body.h = max(input.mousePos.y - layer.body.y, 120)
		if MouseReleased(.left) {
			layer.state -= {.resizing}
		}
	}
	if .moving in layer.state {
		newPos := input.mousePos + dragAnchor
		layer.body.x = clamp(newPos.x, 0, ctx.size.x - layer.body.w)
		layer.body.y = clamp(newPos.y, 0, ctx.size.y - layer.body.h)
		if MouseReleased(.left) {
			layer.state -= {.moving}
		}
	}
	if .autoFit in layer.bits {
		layer.body.w = layer.contentSize.x
		layer.body.h = layer.contentSize.y
	}

	EndClip()

	layerDepth -= 1

	PopId()
	PopFrame()
}

@(deferred_out=_Layer)
Layer :: proc(rect: Rect, name: string, bits: LayerBits) -> (layer: ^LayerData, ok: bool) {
	return BeginLayerEx(rect, HashId(name), bits)
}
@private _Layer :: proc(_: ^LayerData, ok: bool) {
	if ok {
		EndLayer()
	}
}

/*
	Extensions of the layer
*/
@(deferred_out=_Window)
Window :: proc(name: string, bits: LayerBits) -> (layer: ^LayerData, ok: bool) {
	return BeginLayerEx({}, HashId(name), bits + {.floating, .title})
}
@private _Window :: proc(_: ^LayerData, ok: bool) {
	if ok {
		EndLayer()
	}
}
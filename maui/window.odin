package maui
/*package maui

WindowOption :: enum {
	title,
	resizable,
}
WindowOptions :: bit_set[WindowOption]
WindowStatus :: enum {
	closed,
	
}
WindowData :: struct {
	// Inherited stuff
	layer: ^LayerData,
	// Native stuff
	id: Id,
	options: WindowOptions,
	state: WindowState,
	body: Rect,
}

@private BeginWindowEx :: proc(name: string) -> (^WindowData, bool) {
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
}*/
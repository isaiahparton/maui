package maui
import "core:fmt"
/*
	Panels are the root of all gui

	Panels can be windows or just the entire screen, but you need a panel before anything else
	setup will look something like this:

	if panel("GetColor_picker") {
		if layout(cut_top(50)) {
			cut_side(.left)
			if button("!#", .check) {
				
			}
		}
	}
*/
PANEL_TITLE_SIZE :: 30

PanelBit :: enum {
	title,
	resizable,
	moveable,
	floating,
	autoFit,
	fixedLayout,
	stayAlive,
}
PanelBits :: bit_set[PanelBit]
PanelStatus :: enum {
	resizing,
	moving,
}
PanelState :: bit_set[PanelStatus]
PanelData :: struct {
	id: Id,
	title: string,
	bits: PanelBits,
	state: PanelState,
	head, tail: ^Command,
	body: Rect,
	layoutSize, contentSize: Vector,
	// draw order
	index: i32,
	// controls on this panel
	contents: map[Id]i32,
}

PanelOptions :: struct {
	origin, size: AnyVector,
}

GetCurrentPanel :: proc() -> ^PanelData {
	using ctx
	return &panels[panelStack[panelDepth - 1]]
}
GetPanel :: proc(name: string) -> ^PanelData {
	using ctx
	idx, ok := panelMap[HashId(name)]
	if ok {
		return &panels[idx]
	}
	return nil
}
CreateOrGetPanel :: proc(id: Id) -> (^PanelData, i32) {
	using ctx
	index, ok := panelMap[id]
	if !ok {
		index = -1
		for i in 0..<MAX_PANELS {
			if !panelExists[i] {
				panelExists[i] = true
				panels[i] = {}
				index = i32(i)
				panelMap[id] = index
				append(&panelList, index)
				break
			}
		}
	}
	if index >= 0 {
		return &panels[index], index
	}
	return nil, index
}
DefinePanel :: proc(name: string, options: PanelOptions, space: Vector = {}) {
	using ctx
	id := HashId(name)
	panel, index := CreateOrGetPanel(id)
	if panel == nil {
		return
	}

	panel.title = name
	panel.body = {
		ToAbsolute(options.origin.x, f32(size.x)),
		ToAbsolute(options.origin.y, f32(size.y)),
		ToAbsolute(options.size.x, f32(size.x)),
		ToAbsolute(options.size.y, f32(size.y)),
	}
	panel.layoutSize = {panel.body.w, panel.body.h}
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

@private BeginPanelEx :: proc(rect: Rect, id: Id, bits: PanelBits) -> bool {
	using ctx

	/*
		Find or create the panel
	*/
	panel, index := CreateOrGetPanel(id)
	if panel == nil {
		return false
	}

	/*
		Update panel stack
	*/
	panelStack[panelDepth] = index
	panelDepth += 1

	/*
		Update panel values
	*/
	panel.bits += bits + {.stayAlive}
	panel.id = id
	panel.head = PushJump(nil)
	panel.body = rect

	/*
		Define the frame
	*/
	frameRect := panel.body
	if .fixedLayout in panel.bits {
		frameRect.w = panel.layoutSize.x
		frameRect.h = panel.layoutSize.y
	}
	if .title in panel.bits {
		frameRect.y += PANEL_TITLE_SIZE
		frameRect.h -= PANEL_TITLE_SIZE
	}
	PushFrame(frameRect, {})
	BeginClip(panel.body)

	/*
		Draw the panel body and title bar if needed
	*/
	DrawRect(panel.body, GetColor(0, 1))
	if .title in panel.bits {
		titleRect := Rect{panel.body.x, panel.body.y, panel.body.w, PANEL_TITLE_SIZE}
		DrawRect(titleRect, GetColor(5, 1))
		DrawRect({panel.body.x, panel.body.y + PANEL_TITLE_SIZE - ctx.style.outline, panel.body.w, ctx.style.outline}, GetColor(1, 1))
		DrawAlignedString(ctx.font, panel.title, {frameRect.x + 10, frameRect.y - 15}, GetColor(1, 1), .near, .middle)
	}
	if .resizable in panel.bits {
		a := Vector{panel.body.x + panel.body.w - 1, panel.body.y + panel.body.h - 1}
		b := Vector{a.x, a.y - 30}
		c := Vector{a.x - 30, a.y}
		DrawTriangle(a, b, c, GetColor(5, 1))
		DrawLine(b, c, ctx.style.outline, GetColor(1, 1))
	}

	PushId(id)

	/*
		Handle title bar
	*/
	if .title in panel.bits {
		titleRect := Rect{panel.body.x, panel.body.y, panel.body.w, PANEL_TITLE_SIZE}

		if Layout(titleRect) {
			CutSide(.right)
			CutSize(titleRect.h)
			if IconButtonEx(.close) {
				panel.bits -= {.stayAlive}
			}
		}

		if hoveredPanel == index && VecVsRect(input.mousePos, titleRect) {
			if MousePressed(.left) {
				panel.state += {.moving}
				dragAnchor = Vector{panel.body.x, panel.body.y} - input.mousePos
			}
		}
	}

	/*
		Handle resizing
	*/
	if .resizable in panel.bits {
		grabRect := Rect{panel.body.x + panel.body.w - 30, panel.body.y + panel.body.h - 30, 30, 30}
		if hoveredPanel == index && VecVsRect(input.mousePos, grabRect) {
			if MousePressed(.left) {
				panel.state += {.resizing}
			}
		}
	}

	panel.contentSize = {}

	return true
}
@private BeginPanel :: proc(rect: Rect, name: string) -> bool {
	return BeginPanelEx(rect, HashId(name), {})
}
@private EndPanel :: proc() {
	using ctx

	/*
		Define the panel's jump commands for ordered drawing
	*/
	panel := GetCurrentPanel()
	DrawRectLines(panel.body, ctx.style.outline, GetColor(1, 1))
	panel.tail = PushJump(nil)
	panel.head.variant.(^CommandJump).dst = (^Command)(&ctx.commands[ctx.commandOffset])

	if .resizing in panel.state {
		panel.body.w = max(input.mousePos.x - panel.body.x, 240)
		panel.body.h = max(input.mousePos.y - panel.body.y, 120)
		if MouseReleased(.left) {
			panel.state -= {.resizing}
		}
	}
	if .moving in panel.state {
		newPos := input.mousePos + dragAnchor
		panel.body.x = clamp(newPos.x, 0, ctx.size.x - panel.body.w)
		panel.body.y = clamp(newPos.y, 0, ctx.size.y - panel.body.h)
		if MouseReleased(.left) {
			panel.state -= {.moving}
		}
	}
	if .autoFit in panel.bits {
		panel.body.w = panel.contentSize.x
		panel.body.h = panel.contentSize.y
	}

	panelDepth -= 1

	PopId()
	PopFrame()
	EndClip()
}

@(deferred_out=_Panel)
Panel :: proc(rect: Rect, name: string, bits: PanelBits) -> (ok: bool) {
	return BeginPanelEx(rect, HashId(name), bits)
}
@private _Panel :: proc(ok: bool) {
	if ok {
		EndPanel()
	}
}

/*
	Extensions of the panel
*/
@(deferred_out=_Window)
Window :: proc(name: string, bits: PanelBits) -> (ok: bool) {
	return BeginPanelEx({}, HashId(name), bits + {.floating, .title})
}
@private _Window :: proc(ok: bool) {
	if ok {
		EndPanel()
	}
}
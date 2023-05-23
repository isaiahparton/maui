package maui

import "core:fmt"
import "core:runtime"
import "core:sort"
import "core:slice"
import "core:reflect"

import "core:strconv"
import "core:unicode"
import "core:unicode/utf8"

import "core:math"
import "core:math/linalg"

import rl "vendor:raylib"

CursorType :: enum {
	none = -1,
	default,
	arrow,
	beam,
	crosshair,
	hand,
	resizeEW,
	resizeNS,
	resizeNWSE,
	resizeNESW,
	resizeAll,
	disabled,
}

RENDER_TIMEOUT 		:: 0.5

FMT_BUFFER_COUNT 	:: 16
FMT_BUFFER_SIZE 	:: 128

MAX_GROUPS 			:: 8
MAX_STYLES			:: 4
MAX_CLIP_RECTS 		:: #config(MAUI_MAX_CLIP_RECTS, 8)
MAX_CONTROLS 		:: #config(MAUI_MAX_CONTROLS, 1024)
MAX_LAYERS 			:: #config(MAUI_MAX_LAYERS, 32)
MAX_WINDOWS 		:: #config(MAUI_MAX_WINDOWS, 32)
// Maximum layout depth (times you can call PushLayout())
MAX_LAYOUTS 		:: #config(MAUI_MAX_LAYOUTS, 32)
// Size of each layer's command buffer
COMMAND_BUFFER_SIZE :: #config(MAUI_COMMAND_BUFFER_SIZE, 256 * 1024)
// Size of id stack (times you can call PushId())
ID_STACK_SIZE 		:: 32
// Repeating key press
KEY_REPEAT_DELAY 	:: 0.5
KEY_REPEAT_RATE 	:: 30
ALL_CORNERS: RectCorners = {.topLeft, .topRight, .bottomLeft, .bottomRight}

DOUBLE_CLICK_TIME :: 0.25

Id 		:: distinct u32

Vec2 	:: [2]f32
Vec3 	:: [3]f32
Vec4 	:: [4]f32
Color 	:: [4]u8

Animation :: struct {
	keepAlive: bool,
	value: f32,
}

Rect :: struct {
	x, y, w, h: f32,
}

RectSide :: enum {
	top,
	bottom,
	left,
	right,
}
RectSides :: bit_set[RectSide;u8]

RectCorner :: enum {
	topLeft,
	topRight,
	bottomRight,
	bottomLeft,
}
RectCorners :: bit_set[RectCorner;u8]

Scribe :: struct {
	index, length, anchor: int,
	prev_index, prev_length: int,
	buffer: [dynamic]u8,
	offset: Vec2,
}

Group :: struct {
	state: WidgetState,
}

@private
DebugMode :: enum {
	layers,
	windows,
	controls,
}

DebugBit :: enum {
	showWindow,
}
DebugBits :: bit_set[DebugBit]
Context :: struct {
	debugBits: DebugBits,
	debugMode: DebugMode,

	groupDepth: int,
	groups: [MAX_GROUPS]Group,

	// Context
	time,
	deltaTime,
	renderTime: f32,
	disabled, dragging, shouldRender, keySelect: bool,
	size: Vec2,
	lastRect, fullscreenRect: Rect,

	attachTooltip: bool,
	tooltipText: string,
	tooltipSide: RectSide,

	firstClick, doubleClick: bool,
	doubleClickTimer: f32,

	// Each text input being edited
	scribe: Scribe,
	numberText: []u8,
	cursor: CursorType,
	style: Style,

	idStack: [ID_STACK_SIZE]Id,
	idCount: int,

	animations: map[Id]Animation,

	// Retained control data
	controls: [MAX_CONTROLS]Widget,
	controlExists: [MAX_CONTROLS]bool,
	lastWidget: int,
	controlCount: int,

	// Internal window data
	windows: 			[dynamic]^WindowData,
	windowMap: 			map[Id]^WindowData,
	// Window context stack
	windowStack: 		[MAX_WINDOWS]^WindowData,
	windowDepth: 		int,
	// Current window data
	currentWindow:		^WindowData,

	rootLayer: 			^LayerData,
	// Internal layer data
	layers: 			[dynamic]^LayerData,
	layerMap: 			map[Id]^LayerData,
	// Layer context stack
	layerStack: 		[MAX_LAYERS]^LayerData,
	layerDepth: 		int,
	// Layer ordering helpers
	layerOrderCount: 	[LayerOrder]int,
	sortLayers:			bool,
	prevTopLayer, topLayer: Id,
	// Current layer being drawn (used only by 'NextCommand')
	hotLayer: int,
	// Current layer state
	nextHoveredLayer, hoveredLayer, focusedLayer: Id,
	debugLayer: Id,

	// Used for dragging stuff
	dragAnchor: Vec2,

	// Layout
	layouts: [MAX_LAYOUTS]LayoutData,
	layoutDepth: int,
	layoutExpand: bool,

	clipRect: Rect,

	// Next control options
	nextId: Id,
	nextRect: Rect,
	setNextRect: bool,

	focusIndex: int,

	// Widget interactions
	lastIndex: int,
	prevHoverId, 
	nextHoverId, 
	hoverId, 
	prevPressId, 
	pressId, 
	focusId,
	prevFocusId: Id,
}

BackendGetClipboardString: proc() -> string = ---
BackendSetClipboardString: proc(string) = ---

GetClipboardString :: proc() -> string {
	if BackendGetClipboardString != nil {
		return BackendGetClipboardString()
	}
	return {}
}
SetClipboardString :: proc(str: string) {
	if BackendSetClipboardString != nil {
		BackendSetClipboardString(str)
	}
}

Enable :: proc(){
	ctx.disabled = false
}
Disable :: proc(){
	ctx.disabled = true
}

GetLastWidget :: proc() -> ^Widget {
	using ctx
	return &controls[lastWidget]
}

BeginGroup :: proc() {
	using ctx
	groups[groupDepth] = {}
	groupDepth += 1
}
EndGroup :: proc() -> ^Group {
	using ctx
	groupDepth -= 1
	return &groups[groupDepth]
}

/*
	Rectangle manipulation
*/
SideCorners :: proc(sides: RectSides) -> RectCorners {
	corners: RectCorners = ALL_CORNERS
	if .top in sides {
		corners -= {.topLeft, .topRight}
	}
	if .bottom in sides {
		corners -= {.bottomLeft, .bottomRight}
	}
	if .left in sides {
		corners -= {.topLeft, .bottomLeft}
	}
	if .right in sides {
		corners -= {.topRight, .bottomRight}
	}
	return corners
}
VecVsRect :: proc(v: Vec2, r: Rect) -> bool {
	return (v.x >= r.x) && (v.x <= r.x + r.w) && (v.y >= r.y) && (v.y <= r.y + r.h)
}
RectVsRect :: proc(a, b: Rect) -> bool {
	return (a.x + a.w >= b.x) && (a.x <= b.x + b.w) && (a.y + a.h >= b.y) && (a.y <= b.y + b.h)
}
// B is contained entirely within A
RectContainsRect :: proc(a, b: Rect) -> bool {
	return (b.x >= a.x) && (b.x + b.w <= a.x + a.w) && (b.y >= a.y) && (b.y + b.h <= a.y + a.h)
}
ExpandRect :: proc(rect: Rect, amount: f32) -> Rect {
	return {rect.x - amount, rect.y - amount, rect.w + amount * 2, rect.h + amount * 2}
}
TranslateRect :: proc(r: Rect, v: Vec2) -> Rect {
	return {r.x + v.x, r.y + v.y, r.w, r.h}
}

/*
	Color manipulation
*/
NormalizeColor :: proc(color: Color) -> [4]f32 {
    return {f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255}
}
SetColorBrightness :: proc(color: Color, value: f32) -> Color {
	delta := clamp(i32(255.0 * value), -255, 255)
	return {
		cast(u8)clamp(i32(color.r) + delta, 0, 255),
		cast(u8)clamp(i32(color.g) + delta, 0, 255),
		cast(u8)clamp(i32(color.b) + delta, 0, 255),
		color.a,
	}
}
ColorToHSV :: proc(color: Color) -> Vec4 {
	hsva := linalg.vector4_rgb_to_hsl(linalg.Vector4f32{f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0})
	return hsva.xyzw
}
ColorFromHSV :: proc(hue, saturation, value: f32) -> Color {
    rgba := linalg.vector4_hsl_to_rgb(hue, saturation, value, 1.0)
    return {u8(rgba.r * 255.0), u8(rgba.g * 255.0), u8(rgba.b * 255.0), u8(rgba.a * 255.0)}
}
Fade :: proc(color: Color, alpha: f32) -> Color {
	return {color.r, color.g, color.b, u8(f32(color.a) * alpha)}
}
BlendColors :: proc(bg, fg: Color, amount: f32) -> (result: Color) {
	if amount <= 0 {
		result = bg
	} else if amount >= 1 {
		result = fg
	} else {
		result = bg + {
			u8((f32(fg.r) - f32(bg.r)) * amount),
			u8((f32(fg.g) - f32(bg.g)) * amount),
			u8((f32(fg.b) - f32(bg.b)) * amount),
			u8((f32(fg.a) - f32(bg.a)) * amount),
		}
	}
	return
}
BlendThreeColors :: proc(first, second, third: Color, time: f32) -> (result: Color) {
	if time <= 0 {
		result = first
	} else if time == 1 {
		result = second
	} else if time >= 2 {
		result = third
	} else {
		firstTime := min(1, time)
		result = first + {
			u8((f32(second.r) - f32(first.r)) * firstTime),
			u8((f32(second.g) - f32(first.g)) * firstTime),
			u8((f32(second.b) - f32(first.b)) * firstTime),
			u8((f32(second.a) - f32(first.a)) * firstTime),
		}
		if time > 1 {
			secondTime := time - 1
			result += {
				u8((f32(third.r) - f32(second.r)) * secondTime),
				u8((f32(third.g) - f32(second.g)) * secondTime),
				u8((f32(third.b) - f32(second.b)) * secondTime),
				u8((f32(third.a) - f32(second.a)) * secondTime),
			}
		}
	}
	return
}

/*
	Unique id creation
*/
HashId :: proc {
	HashIdFromString,
	HashIdFromRawptr,
	HashIdFromUintptr,
	HashIdFromBytes,
	HashIdFromLoc,
	HashIdFromInt,
}
HashIdFromInt :: #force_inline proc(num: int) -> Id {
	num := num
	return HashIdFromBytes(([^]u8)(&num)[:size_of(num)])
}
HashIdFromString :: #force_inline proc(str: string) -> Id { 
	return HashIdFromBytes(transmute([]byte)str) 
}
HashIdFromRawptr :: #force_inline proc(data: rawptr, size: int) -> Id { 
	return HashIdFromBytes(([^]u8)(data)[:size])  
}
HashIdFromUintptr :: #force_inline proc(ptr: uintptr) -> Id { 
	ptr := ptr
	return HashIdFromBytes(([^]u8)(&ptr)[:size_of(ptr)])  
}
HashIdFromBytes :: proc(bytes: []byte) -> Id {
	/* 32bit fnv-1a hash */
	HASH_INITIAL :: 2166136261
	Hash :: proc(hash: ^Id, data: []byte) {
		size := len(data)
		cptr := ([^]u8)(raw_data(data))
		for ; size > 0; size -= 1 {
			hash^ = Id(u32(hash^) ~ u32(cptr[0])) * 16777619
			cptr = cptr[1:]
		}
	}
	id := ctx.idStack[ctx.idCount - 1] if ctx.idCount > 0 else HASH_INITIAL
	Hash(&id, bytes)
	return id
}
HashIdFromLoc :: proc(loc: runtime.Source_Code_Location) -> Id {
	loc := loc
	LOCATION_DATA_SIZE :: size_of(runtime.Source_Code_Location) - size_of(string)
	return HashId(rawptr(&loc), LOCATION_DATA_SIZE)
}
PushId :: proc(id: Id) {
	assert(ctx.idCount < ID_STACK_SIZE, "PushId() id stack is full!")
	ctx.idStack[ctx.idCount] = id
	ctx.idCount += 1
}
PopId :: proc() {
	assert(ctx.idCount > 0, "PopId() id stack already empty!")
	ctx.idCount -= 1
}

/*
	Animation management
*/
AnimateBool :: proc(id: Id, condition: bool, duration: f32) -> f32 {
	if id not_in ctx.animations {
		ctx.animations[id] = {}
	}
	animation := &ctx.animations[id]
	animation.keepAlive = true
	if condition {
		animation.value = min(1, animation.value + ctx.deltaTime / duration)
	} else {
		animation.value = max(0, animation.value - ctx.deltaTime / duration)
	}
	return animation.value
}
GetAnimation :: proc(id: Id) -> ^f32 {
	if id not_in ctx.animations {
		ctx.animations[id] = {}
	}
	animation := &ctx.animations[id]
	animation.keepAlive = true
	return &animation.value
}

/*
	The global state

	TODO(isaiah): Add manual state swapping
*/
SetNextId :: proc(id: Id) {
	ctx.nextId = id
}
UseNextId :: proc() -> (id: Id, ok: bool) {
	id = ctx.nextId
	ok = ctx.nextId != 0
	return
}

GetScreenPoint :: proc(h, v: f32) -> Vec2 {
	return {h * f32(ctx.size.x), v * f32(ctx.size.y)}
}
SetScreenSize :: proc(w, h: f32) {
	ctx.size = {w, h}
}

Init :: proc() -> bool {
	ctx = new(Context)
	ctx.style.colors = COLOR_SCHEME_LIGHT
	// Load graphics
	if !InitPainter() {
		fmt.print("failed to initialize painter module\n")
		return false
	}
	return true
}
Uninit :: proc() {
	delete(ctx.scribe.buffer)
	delete(ctx.animations)
	delete(ctx.windowMap)
	// Free layer data
	for layer in ctx.layers {
		DeleteLayer(layer)
	}
	delete(ctx.layerMap)
	delete(ctx.layers)

	UninitPainter()

	free(ctx)
}

NewFrame :: proc() {
	using ctx

	cursor = .default

	input.runeCount = 0
	// Try tell the user what went wrong if
	// a stack overflow occours
	assert(layoutDepth == 0, "You forgot to PopLayout()")
	assert(layerDepth == 0, "You forgot to PopLayer()")
	assert(idCount == 0, "You forgot to PopId()")
	// Reset fullscreen rect
	fullscreenRect = {0, 0, size.x, size.y}

	for id, animation in &animations {
		if animation.keepAlive {
			animation.keepAlive = false
		} else {
			delete_key(&animations, id)
		}
	}

	newKeys := input.keyBits - input.prevKeyBits
	oldKey := input.lastKey
	for key in Key {
		if key in newKeys && key != input.lastKey {
			input.lastKey = key
			break
		}
	}
	if input.lastKey != oldKey {
		input.keyHoldTimer = 0
	}

	input.keyPulse = false
	if input.lastKey in input.keyBits {
		input.keyHoldTimer += deltaTime
	} else {
		input.keyHoldTimer = 0
	}
	if input.keyHoldTimer >= KEY_REPEAT_DELAY {
		if input.keyPulseTimer > 0 {
			input.keyPulseTimer -= deltaTime
		} else {
			input.keyPulseTimer = 1.0 / KEY_REPEAT_RATE
			input.keyPulse = true
		}
	}
	// Update control interaction ids
	prevHoverId = hoverId
	prevPressId = pressId
	prevFocusId = focusId
	hoverId = nextHoverId
	if dragging && pressId != 0 {
		hoverId = pressId
	}
	if keySelect {
		hoverId = focusId
		if KeyPressed(.enter) {
			pressId = hoverId
		}
	}
	nextHoverId = 0
	if MousePressed(.left) {
		pressId = hoverId
		focusId = pressId
	}

	renderTime = max(0, renderTime - deltaTime)
	time += deltaTime
	// Begin root layer
	rootLayer, _ = BeginLayer(ctx.fullscreenRect, {}, 0, {})
	// Tab through input fields
	//TODO(isaiah): Add better keyboard navigation with arrow keys
	if KeyPressed(.tab) && focusIndex >= 0 {
		array: [dynamic]int
		defer delete(array)

		anchor: int
		for i in 0..<MAX_CONTROLS {
			if controlExists[i] {
				if i == focusIndex {
					anchor = len(array)
				}
				if .keySelect in controls[i].options && .disabled not_in controls[i].bits {
					append(&array, i)
				}
			}
		}

		if len(array) > 1 {
			slice.sort_by(array[:], proc(i, j: int) -> bool {
				rect_i := ctx.controls[i].body
				rect_j := ctx.controls[j].body
				if rect_i.y == rect_j.y {
					if rect_i.x < rect_j.x {
						return true
					}
				} else if rect_i.y < rect_j.y {
					return true
				}
				return false
			})
			ctx.focusId = controls[array[(anchor + 1) % len(array)]].id
			ctx.keySelect = true
		}
	}
	focusIndex = -1

	dragging = false
	doubleClick = false
	if MousePressed(.left) {
		if firstClick {
			doubleClick = true
			firstClick = false
		} else {
			firstClick = true
		}
	}
	if prevHoverId != hoverId || doubleClickTimer > DOUBLE_CLICK_TIME {
		firstClick = false
	}
	if firstClick {
		doubleClickTimer += deltaTime
	} else {
		doubleClickTimer = 0
	}

	if input.mousePoint - input.prevMousePoint != {} {
		keySelect = false
	}

	clipRect = fullscreenRect

	// Reset input bits
	input.prevKeyBits = input.keyBits
	input.prevMouseBits = input.mouseBits
	input.prevMousePoint = input.mousePoint

	shouldRender = renderTime > 0
}
EndFrame :: proc() {
	using ctx
	// Built-in debug window
	when ODIN_DEBUG {
		debugLayer = 0
		if KeyDown(.control) && KeyPressed(.backspace) {
			debugBits ~= {.showWindow}
		}
		if debugBits >= {.showWindow} {
			if Window("Debug", {0, 0, 500, 700}, {.collapsable, .closable, .title, .resizable}) {
				if CurrentWindow().bits >= {.shouldClose} {
					debugBits -= {.showWindow}
				}

				SetSize(30)
				debugMode = EnumTabs(debugMode, 0)

				Shrink(10); SetSize(24)
				if debugMode == .layers {
					_DebugLayerWidget(ctx.rootLayer)
				} else if debugMode == .windows {
					for id, window in windowMap {
						PushId(window.id)
							if Collapser(Format(window.id), 20) {
								Cut(.left, 30); SetSize(20)
								Text(.label, StringFormat("index: %i", window.layer.index), false)
							}
							if GetLastWidget().state & {.focused, .hovered} != {} {
								debugLayer = window.layer.id
							}
						PopId()
					}
				}
			}
		}
	}
	// End the root layer
	EndLayer(rootLayer)
	// Decide if rendering is needed next frame
	if input.prevMousePoint != input.mousePoint || input.prevKeyBits != input.keyBits|| input.prevMouseBits != input.mouseBits || input.mouseScroll != {} {
		renderTime = RENDER_TIMEOUT
	}
	// Delete unused controls
	for i in 0..<MAX_CONTROLS {
		if controlExists[i] {
			control := &controls[i]
			if .stayAlive in control.bits {
				control.bits -= {.stayAlive}
			} else {
				controlExists[i] = false
			}
			controlCount += 1
		}
	}
	// Delete unused windows
	for window, i in windows {
		if .stayAlive in window.bits {
			window.bits -= {.stayAlive}
		} else {
			ordered_remove(&windows, i)
			delete_key(&windowMap, window.id)
			DeleteWindow(window)
		}
	}
	// Determine hovered layer and reorder if needed
	layerOrderCount = {}
	sortedLayer: ^LayerData
	hoveredLayer = 0
	for layer, i in layers {
		layerOrderCount[layer.order] += 1
		if VecVsRect(input.mousePoint, layer.body) {
			hoveredLayer = layer.id
			if MousePressed(.left) {
				// If the layer is attached, find its first parent
				child := layer
				for child.parent != nil {
					topLayer = child.id
					sortedLayer = child
					if child.options >= {.attached} {
						child = child.parent
					} else {
						break
					}
				}
			}
		}
		if .stayAlive in layer.bits {
			layer.bits -= {.stayAlive}
		} else {
			ordered_remove(&layers, i)
			delete_key(&layerMap, layer.id)
			if layer.parent != nil {
				for child, i in layer.parent.children {
					if child == layer {
						ordered_remove(&layer.parent.children, i)
						break
					}
				}
			}
			DeleteLayer(layer)
			sortLayers = true
		}
	}
	// If 'topLayer' has changed, reorder the layers
	if topLayer != prevTopLayer {
		for child in sortedLayer.parent.children {
			if child.order == sortedLayer.order {
				if child.id == topLayer {
					child.index = len(sortedLayer.parent.children)
				} else {
					child.index -= 1
				}
			}
		}
		sortLayers = true
		prevTopLayer = topLayer
	}
	// Sort the layers
	if sortLayers {
		sortLayers = false

		tempLayers := slice.clone(layers[:])
		defer delete(tempLayers)

		clear(&layers)
		SortLayer(&layers, rootLayer)
	}
	// Reset rendered layer
	hotLayer = 0
}
_CountLayerChildren :: proc(layer: ^LayerData) -> int {
	count: int
	for child in layer.children {
		count += 1 + _CountLayerChildren(child)
	}
	return count
}
_DebugLayerWidget :: proc(layer: ^LayerData) {
	PushId(layer.id)
	if Collapser(Format(layer.id), f32(_CountLayerChildren(layer)) * 24) {
		Cut(.left, 24); SetSize(24)
		for child in layer.children {
			_DebugLayerWidget(child)
		}
	}
	if GetLastWidget().state >= {.hovered} {
		ctx.debugLayer = layer.id
	}
	PopId()
}
SortLayer :: proc(list: ^[dynamic]^LayerData, layer: ^LayerData) {
	append(list, layer)
	if len(layer.children) > 0 {
		slice.sort_by(layer.children[:], proc(a, b: ^LayerData) -> bool {
			if a.order == b.order {
				return a.index < b.index
			}
			return int(a.order) < int(b.order)
		})
		for child in layer.children do SortLayer(list, child)
	}
}
ShouldRender :: proc() -> bool {
	return ctx.shouldRender
}

/*
	Text input
*/
ScribeInsertString :: proc(str: string) {
	using ctx.scribe
	if length > 0 {
		remove_range(&buffer, index, index + length)
		length = 0
	}
	inject_at_elem_string(&buffer, index, str)
	index += len(str)
}
ScribeInsertRunes :: proc(runes: []rune) {
	str := utf8.runes_to_string(runes)
	ScribeInsertString(str)
	delete(str)
}
ScribeBackspace :: proc(){
	using ctx.scribe
	if length == 0 {
		if index > 0 {
			end := index
			_, size := utf8.decode_last_rune_in_bytes(buffer[:index])
			index -= size
			remove_range(&buffer, index, end)
		}
	} else {
		remove_range(&buffer, index, index + length)
		length = 0
	}
}
IsSeperator :: proc(glyph: u8) -> bool {
	return glyph == ' ' || glyph == '\n' || glyph == '\t' || glyph == '\\' || glyph == '/'
}
FindNextSeperator :: proc(slice: []u8) -> int {
	for i in 1 ..< len(slice) {
		if IsSeperator(slice[i]) {
			return i
		}
	}
	return len(slice) - 1
}
FindLastSeperator :: proc(slice: []u8) -> int {
	for i in len(slice) - 1 ..= 1 {
		if IsSeperator(slice[i]) {
			return i
		}
	}
	return 0
}

//@private
ctx : ^Context
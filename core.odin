package maui

import "core:fmt"
import "core:runtime"
import "core:sort"
import "core:slice"
import "core:reflect"
import "core:time"

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

TEMP_BUFFER_COUNT 	:: 2
GROUP_STACK_SIZE 	:: 32
MAX_CLIP_RECTS 		:: #config(MAUI_MAX_CLIP_RECTS, 32)
MAX_CONTROLS 		:: #config(MAUI_MAX_CONTROLS, 1024)
LAYER_STACK_SIZE 	:: #config(MAUI_LAYER_STACK_SIZE, 32)
WINDOW_STACK_SIZE 	:: #config(MAUI_WINDOW_STACK_SIZE, 32)
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

DOUBLE_CLICK_TIME :: time.Millisecond * 250

Vec2 	:: [2]f32
Vec3 	:: [3]f32
Vec4 	:: [4]f32
Color 	:: [4]u8

Animation :: struct {
	keepAlive: bool,
	value: f32,
}

TextBuffer :: struct {
	keepAlive: bool,
	buffer: [dynamic]u8,
}

Scribe :: struct {
	index, length, anchor: int,
	prev_index, prev_length: int,
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
	// Widget groups collect information from widgets inside them
	groupDepth: 	int,
	groups: 		[GROUP_STACK_SIZE]Group,
	// Context
	time,
	deltaTime,
	renderTime: f32,
	renderFrames: int,
	disabled, dragging, shouldRender, keySelect: bool,
	size: Vec2,
	lastRect, fullscreenRect: Rect,
	// Values to be used by the next widget
	attachTooltip: bool,
	tooltipText: string,
	tooltipSide: RectSide,
	// Text editing/selecting state
	scribe: Scribe,
	// Temporary text buffers
	textBuffers: map[Id]TextBuffer,
	// Mouse cursor type
	cursor: CursorType,
	// Hash stack
	idStack: [ID_STACK_SIZE]Id,
	idCount: int,
	// Retained animation values
	animations: map[Id]Animation,
	// Retained control data
	widgets: 			[dynamic]^WidgetData,
	currentWidget:  	^WidgetData,
	// Internal window data
	windows: 			[dynamic]^WindowData,
	windowMap: 			map[Id]^WindowData,
	// Window context stack
	windowStack: 		[WINDOW_STACK_SIZE]^WindowData,
	windowDepth: 		int,
	// Current window data
	currentWindow:		^WindowData,
	// First layer
	rootLayer: 			^LayerData,
	// Internal layer data
	layers: 			[dynamic]^LayerData,
	layerMap: 			map[Id]^LayerData,
	// Layer context stack
	layerStack: 		[LAYER_STACK_SIZE]^LayerData,
	layerDepth: 		int,
	// Layer ordering helpers
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
	// Current clip rect
	clipRect: Rect,
	// Next control options
	nextId: Id,
	nextRect: Rect,
	setNextRect: bool,
	// Widget interactions
	prevHoverId, 
	nextHoverId, 
	hoverId, 
	prevPressId, 
	pressId, 
	nextFocusId,
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

@(deferred_none=_Enabled)
Enabled :: proc(condition: bool) -> bool {
	if !condition {
		ctx.disabled = true
	}
	return true
}
@private
_Enabled :: proc() {
	ctx.disabled = false
}

CurrentWidget :: proc() -> ^WidgetData {
	assert(ctx.currentWidget != nil, "There is no widget")
	return ctx.currentWidget
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

GetTextBuffer :: proc(id: Id) -> ^[dynamic]u8 {
	value, ok := &ctx.textBuffers[id]
	if !ok {
		value = map_insert(&ctx.textBuffers, id, TextBuffer({}))
		ok = true
	}
	value.keepAlive = true
	return &value.buffer
}

/*
	Animation management
*/
AnimateBool :: proc(id: Id, condition: bool, duration: f32) -> f32 {
	if id not_in ctx.animations {
		ctx.animations[id] = {
			value = f32(int(condition)),
		}
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
	if ctx == nil {
		ctx = new(Context)
		// Load graphics
		if !InitPainter() {
			return false
		}
		return true
	}
	return false
}
Uninit :: proc() {
	if ctx != nil {
		// Free widgets
		for widget in &ctx.widgets {
			free(&widget)
		}
		delete(ctx.widgets)
		// Free text buffers
		for _, value in ctx.textBuffers {
			delete(value.buffer)
		}
		delete(ctx.textBuffers)
		// Free animation pool
		delete(ctx.animations)
		// Free window data
		for window in ctx.windows {
			DeleteWindow(window)
		}
		delete(ctx.windowMap)
		delete(ctx.windows)
		// Free layer data
		for layer in ctx.layers {
			DeleteLayer(layer)
		}
		delete(ctx.layerMap)
		delete(ctx.layers)
		//
		UninitPainter()
		//
		free(ctx)
	}
}
NewFrame :: proc() {
	using ctx

	cursor = .default
	renderFrames = max(0, renderFrames - 1)
	input.runeCount = 0
	// Try tell the user what went wrong if
	// a stack overflow occours
	assert(layoutDepth == 0, "You forgot to PopLayout()")
	assert(layerDepth == 0, "You forgot to PopLayer()")
	assert(idCount == 0, "You forgot to PopId()")
	// Reset fullscreen rect
	fullscreenRect = {0, 0, size.x, size.y}
	// Delete unused animations
	for id, animation in &animations {
		if animation.keepAlive {
			animation.keepAlive = false
		} else {
			delete_key(&animations, id)
		}
	}
	// Free and delete unused text buffers
	for key, value in &textBuffers {
		if value.keepAlive {
			value.keepAlive = false
		} else {
			delete(value.buffer)
			delete_key(&textBuffers, key)
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
	rootLayer, _ = BeginLayer(ctx.fullscreenRect, {}, 0, {.noPushId})
	// Tab through input fields
	//TODO(isaiah): Add better keyboard navigation with arrow keys
	if KeyPressed(.tab) && ctx.focusId != 0 {
		array: [dynamic]^WidgetData
		defer delete(array)

		anchor: int
		for widget in &widgets {
			if .keySelect in widget.options && .disabled not_in widget.bits {
				if widget.id == ctx.focusId {
					anchor = len(array)
				}
				append(&array, widget)
			}
		}

		if len(array) > 1 {
			slice.sort_by(array[:], proc(a, b: ^WidgetData) -> bool {
				if a.body.y == b.body.y {
					if a.body.x < b.body.x {
						return true
					}
				} else if a.body.y < b.body.y {
					return true
				}
				return false
			})
			ctx.focusId = array[(anchor + 1) % len(array)].id
			ctx.keySelect = true
		}
	}

	dragging = false

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
							Button(
								label = Format(window.id), 
								align = .near,
							)
							if CurrentWidget().state >= {.hovered} {
								debugLayer = window.layer.id
							}
						PopId()
					}
				} else if debugMode == .controls {
					Text(.monospace, TextFormat("Layer: %i", hoveredLayer), true)
					Space(20)
					Text(.monospace, TextFormat("Hovered: %i", hoverId), true)
					Text(.monospace, TextFormat("Focused: %i", focusId), true)
					Text(.monospace, TextFormat("Pressed: %i", pressId), true)
					Space(20)
					Text(.monospace, TextFormat("Count: %i", len(widgets)), true)
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
	for widget, i in &widgets {
		if .stayAlive in widget.bits {
			widget.bits -= {.stayAlive}
		} else {
			for key, value in widget.layer.contents {
				if key == widget.id {
					delete_key(&widget.layer.contents, key)
				}
			}
			free(widget)
			ordered_remove(&widgets, i)
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
	sortedLayer: ^LayerData
	hoveredLayer = 0
	for layer, i in layers {
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
		Button(
			label = Format(layer.id),
			align = .near,
		)
		if CurrentWidget().state >= {.hovered} {
			ctx.debugLayer = layer.id
		}
	PopId()
	if len(layer.children) > 0 {
		Cut(.left, 24); SetSize(24)
	}
	for child in layer.children {
		_DebugLayerWidget(child)
	}
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
	return ctx.shouldRender || ctx.renderFrames > 0
}

//@private
ctx : ^Context
/*
	/// Core components of ui ///

	# Layer
		Container for controls, handles clipping and scrolling, drawn in order

		+---------------+
		|				|
		|				|
		|		+-----------+
		|		|			|
		+-------|			|
				|			|
				+-----------+

	# Window
		A floating, movable, collapseable and resizable decorated layer

		+-----------------+-+
		| titlebar		  |X|
		+-----------------+-+
		|					|
		|					|
		|					|
		+-------------------+

	# Menu
		A floating layer attached to a control

		+--------+------------+
		| menu > | option 1   |
		+--------+ option 2   +----------+
				 | menu >	  | option 1 |
				 | option 3   | option 2 |
				 +------------+----------+

	# Layout
		A rectangle in which controls and other layouts are placed

		+-----------+-------+
		|			|	B	|
		|	  A 	+-------+
		|			|	C	|
		+-----------+-------+

		B is cut from the right side of A
		C is cut from the bottom of B
*/
package maui

import "core:fmt"
import "core:runtime"
import "core:sort"
import "core:slice"

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

FMT_BUFFER_COUNT :: 16
FMT_BUFFER_SIZE :: 128

MAX_CLIP_RECTS :: #config(MAUI_MAX_CLIP_RECTS, 8)
MAX_CONTROLS :: #config(MAUI_MAX_CONTROLS, 128)
MAX_LAYERS :: #config(MAUI_MAX_LAYERS, 16)
MAX_WINDOWS :: #config(MAUI_MAX_WINDOWS, 32)
MAX_FRAMES :: #config(MAUI_MAX_FRAMES, 32)
// Maximum layout depth (times you can call PushLayout())
MAX_LAYOUTS :: #config(MAUI_MAX_LAYOUTS, 32)
// Size of each layer's command buffer
COMMAND_BUFFER_SIZE :: #config(MAUI_COMMAND_BUFFER_SIZE, 256 * 1024)
// Size of id stack (times you can call PushId())
ID_STACK_SIZE :: 8
// Repeating key press
KEY_REPEAT_DELAY :: 0.5
KEY_REPEAT_RATE :: 30
ALL_CORNERS: RectCorners = {.topLeft, .topRight, .bottomLeft, .bottomRight}

DOUBLE_CLICK_TIME :: 0.25

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

Id :: distinct u32

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Color :: [4]u8

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
	buffer: [dynamic]u8,
	offset: Vec2,
	move: int,
}

ContextOption :: enum {
	showLayouts,
	showLayers,
	showDebugWindow,
}
ContextOptions :: bit_set[ContextOption]
Context :: struct {
	allocator: runtime.Allocator,
	options: ContextOptions,

	// Context
	time,
	deltaTime,
	renderTime: f32,
	disabled, dragging, setMouse, shouldRender: bool,
	size, setMousePoint: Vec2,
	lastRect, fullscreenRect: Rect,

	firstClick, doubleClick: bool,
	doubleClickTimer: f32,

	// Each text input being edited
	scribe: Scribe,
	numberText: []u8,
	cursor: CursorType,
	style: Style,

	idStack: [ID_STACK_SIZE]Id,
	idCount: i32,

	animations: map[Id]Animation,

	// Retained control data
	controls: [MAX_CONTROLS]Control,
	controlExists: [MAX_CONTROLS]bool,
	lastControl: i32,

	// Retained window data
	windows: [MAX_WINDOWS]WindowData,
	windowExists: [MAX_WINDOWS]bool,
	windowMap: map[Id]^WindowData,
	windowStack: [MAX_WINDOWS]^WindowData,
	windowDepth: i32,

	// Retained layer data
	layers: [MAX_LAYERS]LayerData,
	layerExists: [MAX_LAYERS]bool,
	// Ordered list for sorting
	layerMap: map[Id]^LayerData,
	layerList: [dynamic]i32,
	layerStack: [MAX_LAYERS]^LayerData,
	// Current layer on top of list
	topLayer, prevTopLayer: i32,
	// Current layer being drawn
	hotLayer: i32,
	// Index stack for layers within layers
	layerDepth: i32,
	// Current layer state
	nextHoveredLayer, hoveredLayer, focusedLayer: Id,

	// Used for dragging stuff
	dragAnchor: Vec2,

	// Layout
	layouts: [MAX_LAYOUTS]LayoutData,
	layoutDepth: i32,
	layoutExpand: bool,

	clipRect: Rect,

	// Next control options
	nextId: Id,
	nextRect: Rect,
	setNextRect: bool,

	focusIndex: i32,

	// Control interactions
	lastIndex: i32,
	prevHoverId, 
	nextHoverId, 
	hoverId, 
	prevPressId, 
	pressId, 
	focusId,
	prevFocusId: Id,
}

Enable :: proc(){
	ctx.disabled = false
}
Disable :: proc(){
	ctx.disabled = true
}

GetLastControl :: proc() -> ^Control {
	using ctx
	return &controls[lastControl]
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
	/*
		Set up default context and set style
	*/
	ctx = new(Context)

	//TODO(isaiah): do something with this!
	ctx.style.colors = COLOR_SCHEME_LIGHT
	
	/*
		Set up painter and load atlas
	*/
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
	delete(ctx.layerMap)
	delete(ctx.layerList)
	for layer in &ctx.layers {
		delete(layer.contents)
	}

	UninitPainter()

	free(ctx)
}

Prepare :: proc() {
	using ctx

	PopLayout()

	/*
		This decides if the frame should be drawn
	*/
	if input.prevMousePoint != input.mousePoint || input.keyBits != {} || input.mouseBits != {} || input.mouseScroll != {} {
		renderTime = 1
	}
	for i in 0 ..< MAX_CONTROLS {
		if controlExists[i] {
			control := &controls[i]
			if .stayAlive in control.bits {
				control.bits -= {.stayAlive}
			} else {
				controlExists[i] = false
			}
		}
	}

	/*
		Delete unused window data
	*/
	for i in 0 ..< MAX_WINDOWS {
		if windowExists[i] {
			window := &windows[i]
			if .stayAlive in window.bits {
				window.bits -= {.stayAlive}
			} else {
				windowExists[i] = false
				delete_key(&windowMap, window.id)
			}
		}
	}

	if topLayer != prevTopLayer {
		index := layerList[topLayer]
		copy(layerList[topLayer:], layerList[topLayer + 1:])
		layerList[prevTopLayer] = index

		slice.sort_by(layerList[:], proc(a, b: i32) -> bool {
			return int(layers[a].order) < int(layers[b].order)
		})
	}
	topLayer = i32(len(layerList) - 1)
	prevTopLayer = topLayer

	/*
		Sort the draw order of layers
		decide which layer is hovered
		and delete unused layer data
	*/
	hoveredLayer = 0
	for layerIndex, index in layerList {
		if layerExists[layerIndex] {
			layer := &layers[layerIndex]
			if VecVsRect(input.mousePoint, layer.body) {
				hoveredLayer = layer.id
				if MousePressed(.left) {
					topLayer = i32(index)
				}
			}
			if .stayAlive in layer.bits {
				layer.bits -= {.stayAlive}
			} else {
				layerExists[layerIndex] = false
				ordered_remove(&layerList, index)
				delete_key(&layerMap, layer.id)
			}
		}
	}

	hotLayer = 0
}
Refresh :: proc() {
	using ctx

	cursor = .default

	input.runeCount = 0
	setMouse = false

	assert(layoutDepth == 0, "You forgot to PopLayout()")
	assert(layerDepth == 0, "You forgot to PopLayer()")
	assert(idCount == 0, "You forgot to PopId()")

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

	prevHoverId = hoverId
	prevPressId = pressId
	prevFocusId = focusId
	hoverId = nextHoverId
	if dragging && pressId != 0 {
		hoverId = pressId
	}
	nextHoverId = 0

	/*
		Update focused widget
	*/
	if MousePressed(.left) {
		pressId = hoverId
		focusId = pressId
	}

	renderTime = max(0, renderTime - deltaTime)
	time += deltaTime

	free_all(allocator)

	PushLayout({0, 0, size.x, size.y})

	/*
		Built-in debug menus
	*/
	when ODIN_DEBUG {
		if KeyDown(.control) && KeyPressed(.backspace) {
			if .showDebugWindow in options {
				options -= {.showDebugWindow}
			} else {
				options += {.showDebugWindow}
			}
		}
		if .showDebugWindow in options {
			if window, ok := Window(); ok {
				WithPlacement(window, {0, 0, 300, 400})
				WithDefaultOptions(window, {.collapsable, .closable})
				WithTitle(window, "Debug options")

				Shrink(10)
				SetSize(30)
				CheckBoxBitSetHeader(&options, "")
				for option in ContextOption {
					PushId(HashIdFromInt(int(option)))
						CheckBoxBitSet(&options, option, Format(option))
					PopId()
				}
			}
		}
	}

	if KeyPressed(.tab) && ctx.focusIndex >= 0 {
		rect := ctx.controls[ctx.focusIndex].body
		next := ctx.focusId
		for i in 0 ..< MAX_CONTROLS {
			if !ctx.controlExists[i] || ctx.focusIndex == i32(i) {
				continue
			}
			control := &ctx.controls[i]
			if (control.body.x > rect.x || control.body.y > rect.y) && control.options >= {.tabSelect} {
				next = control.id
			}
		}
		if next == ctx.focusId {
			for i in 0 ..< MAX_CONTROLS {
				if !ctx.controlExists[i] || ctx.focusIndex == i32(i) {
					continue
				}
				control := &ctx.controls[i]
				if control.options >= {.tabSelect} {
					next = control.id
					break
				}
			}
		}
		ctx.focusId = next
	}
	focusIndex = -1

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

	// Reset input bits
	input.prevKeyBits = input.keyBits
	input.prevMouseBits = input.mouseBits
	input.prevMousePoint = input.mousePoint

	shouldRender = renderTime > 0
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
/*
	/// Core components of ui ///

	# Layer
		Container for controls, drawn in order, rendered contents are clipped to body

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

	# Frame
		A scrollable area, or graph viewport
		Pushes a layer, whos contents are offset
		according to the frame's state

		+-----------------------+-+
		| Lorem ipsum dolor    	|#|
		| sit amet, consectetur	|#|
		| adipiscing elit, sed  |#|
		| do eiusmod tempor 	| |
		| incididu ut labore et | |
		| ut labore et dolore	| |
		| magna aliqua. Ut enim | |
		| ad minim veniam, quis | |
		+-----------------------+-+

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
import "core:strconv"
import "core:slice"
import rl "vendor:raylib"

CursorType :: enum {
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
/*
	Window style settings
*/
WINDOW_ROUNDNESS :: 10
WINDOW_TITLE_SIZE :: 40
/*
	Widget style settings
*/
WIDGET_HEIGHT :: 30
WIDGET_ROUNDNESS :: 5

MAX_CONTROLS :: #config(MAUI_MAX_CONTROLS, 128)
MAX_LAYERS :: #config(MAUI_MAX_LAYERS, 16)
MAX_WINDOWS :: #config(MAUI_MAX_WINDOWS, 32)
MAX_FRAMES :: #config(MAUI_MAX_FRAMES, 32)
// Maximum layout depth (times you can call PushLayout())
MAX_LAYOUTS :: #config(MAUI_MAX_LAYOUTS, 32)
// Size of each layer's command buffer
COMMAND_BUFFER_SIZE :: #config(MAUI_COMMAND_BUFFER_SIZE, 32 * 1024)
// Size of id stack (times you can call PushId())
ID_STACK_SIZE :: 8

Absolute :: i32
Relative :: f32
Value :: union {
	Absolute,
	Relative,
}
Vec2 :: [2]f32
AnyVec2 :: [2]Value

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

Color :: [4]u8
ColorIndex :: enum {
	windowBase,

	// Background of text inputs and toggle switches
	backing,

	// Clickable things
	widgetBase,
	widgetHover,
	widgetPress,

	// Outline
	outlineBase,
	outlineHover,
	outlinePress,

	// Some bright accent color that stands out
	accent,

	iconBase,
	text,
	textBright,
}
GetColor :: proc(index: ColorIndex, alpha: f32) -> Color {
	color := ctx.style.colors[index]
	return {color.r, color.g, color.b, u8(f32(color.a) * alpha)}
}
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

/*
	Lerpage
*/
ControlTimer :: proc(condition: bool, value, decrease, increase: f32) -> f32 {
	if condition {
		return min(1, value + increase * ctx.deltaTime)
	}
	return max(0, value - decrease * ctx.deltaTime)
}

/*
	Rectangles
*/
Rect :: struct {
	x, y, w, h: f32,
}
TranslateRect :: proc(r: Rect, v: Vec2) -> Rect {
	return {r.x + v.x, r.y + v.y, r.w, r.h}
}

/*
	A hashed id to uniquely identify stuff
*/
Id :: distinct u32

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

Animation :: struct {
	keepAlive: bool,
	value: f32,
}
/*
	The global state

	TODO(isaiah): Add manual state swapping
*/
Style :: struct {
	colors: [ColorIndex]Color,
}
Context :: struct {
	allocator: runtime.Allocator,

	time,
	deltaTime,
	renderTime: f32,
	disabled: bool,
	size: Vec2,

	cursor: CursorType,
	style: Style,

	idStack: [ID_STACK_SIZE]Id,
	idCount: i32,

	animations: map[Id]Animation,

	// Retained control data
	controls: [MAX_CONTROLS]Control,
	controlExists: [MAX_CONTROLS]bool,

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
	contentSize: Vec2,
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

	// Retained frame data
	frames: [MAX_FRAMES]FrameData,
	frameExists: [MAX_FRAMES]bool,
	frameMap: map[Id]i32,
	frameIndex: i32,

	// Layout
	layouts: [MAX_LAYOUTS]LayoutData,
	layoutDepth: i32,
	layoutExpand: bool,

	// Next control options
	nextId: Id,
	nextRect: Rect,
	setNextRect: bool,

	prevHoverId, 
	nextHoverId, 
	hoverId, 
	prevPressId, 
	pressId, 
	focusId: Id,
}

SetNextRect :: proc(rect: Rect) {
	ctx.setNextRect = true
	ctx.nextRect = rect
}
UseNextRect :: proc() -> (rect: Rect, ok: bool) {
	rect = ctx.nextRect
	ok = ctx.setNextRect
	ctx.setNextRect = false
	return
}

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

ParseColor :: proc(text: string) -> (color: Color) {
	if text[0] != '#' || (len(text) != 9 && len(text) != 7) {
		return
	}
	color.a = 255
	for i in 0 ..< (len(text) - 1) / 2 {
		j := i * 2 + 1
		value, yes := strconv.parse_u64_of_base(text[j:j + 2], 16)
		if yes {
			color[i] = u8(value)
		}
	}
	return
}

Init :: proc() {
	/*
		Set up default context and set style
	*/
	ctx = new(Context)

	//TODO(isaiah): do something with this!
	ctx.style.colors[.accent] = ParseColor("#3578F3")
	ctx.style.colors[.windowBase] = {28, 28, 28, 255}
	ctx.style.colors[.backing] = {18, 18, 18, 255}
	ctx.style.colors[.iconBase] = ParseColor("#858585")
	ctx.style.colors[.widgetBase] = ParseColor("#2F2F2F")
	ctx.style.colors[.widgetHover] = ParseColor("#373639")
	ctx.style.colors[.widgetPress] = ParseColor("#575659")
	ctx.style.colors[.textBright] = {255, 255, 255, 255}
	ctx.style.colors[.text] = {200, 200, 200, 255}
	/*
		Set up painter and load atlas
	*/
	painter = new(Painter)
	GenAtlas(painter)
}
Prepare :: proc() {
	using ctx

	PopLayout()

	/*
		This decides if the frame should be drawn
	*/
	if input.prevMousePos != input.mousePos || input.keyBits != {} || input.mouseBits != {} {
		renderTime = 1
	}
	for i in 0 ..< MAX_CONTROLS {
		if controlExists[i] {
			control := &controls[i]
			if .stayAlive in control.bits {

				if control.state & {.hovered, .down} != {} {
					renderTime = 1
				}

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
			if VecVsRect(input.mousePos, layer.body) {
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

	assert(layoutDepth == 0, "You forgot to PopLayout()")
	assert(layerDepth == 0, "You forgot to PopLayer()")
	assert(idCount == 0, "You forgot to PopId()")

	for id, animation in &animations {
		if animation.keepAlive {
			animation.keepAlive = false
		} else {
			delete_key(&animations, id)
		}
	}

	prevHoverId = hoverId
	prevPressId = pressId
	hoverId = nextHoverId
	nextHoverId = 0

	input.prevKeyBits = input.keyBits
	input.prevMouseBits = input.mouseBits
	input.prevMousePos = input.mousePos

	renderTime = max(0, renderTime - deltaTime)
	time += deltaTime

	free_all(allocator)

	PushLayout({0, 0, size.x, size.y})
}
ShouldRender :: proc() -> bool {
	return ctx.renderTime > 0
}

SCRIBE_BUFFER_COUNT :: 16
SCRIBE_BUFFER_SIZE :: 128
Scribe :: struct {
	buffers: [SCRIBE_BUFFER_COUNT][SCRIBE_BUFFER_SIZE]u8,
	index: u8,
}
@private scribe := Scribe{}
StringFormat :: proc(text: string, args: ..any) -> string {
	str := fmt.bprintf(scribe.buffers[scribe.index][:], text, ..args)
	scribe.index = (scribe.index + 1) % SCRIBE_BUFFER_COUNT
	return str
}
Format :: proc(args: ..any) -> string {
	str := fmt.bprint(scribe.buffers[scribe.index][:], ..args)
	scribe.index = (scribe.index + 1) % SCRIBE_BUFFER_COUNT
	return str
}
Join :: proc(args: ..string) -> string {
	size := 0
	buffer := &scribe.buffers[scribe.index]
	for arg in args {
		copy(buffer[size:size + len(arg)], arg[:])
		size += len(arg)
	}
	str := string(buffer[:size])
	scribe.index = (scribe.index + 1) % SCRIBE_BUFFER_COUNT
	return str
}

BlendColors :: proc(bg, fg: Color, amount: f32) -> (result: Color) {
	if amount == 0 {
		result = bg
	} else if amount == 1 {
		result = fg
	} else {
		diff := fg - bg
		result = bg + {
			u8(f32(diff.r) * amount),
			u8(f32(diff.g) * amount),
			u8(f32(diff.b) * amount),
			u8(f32(diff.a) * amount),
		}
	}
	return
}

//@private
ctx : ^Context
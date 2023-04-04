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
import "core:unicode/utf8"
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
WIDGET_HEIGHT :: 36
WIDGET_ROUNDNESS :: 5
WIDGET_TEXT_OFFSET :: 5

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
// Repeating key press
KEY_REPEAT_DELAY :: 0.5
KEY_REPEAT_RATE :: 24

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
	widgetShade,
	widgetHover,
	widgetPress,

	// Outline
	outlineBase,
	outlineShade,
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

// Style
Style :: struct {
	colors: [ColorIndex]Color,
}
StyleGetWidgetColor :: proc(hover, press: f32) -> Color {
	return BlendThreeColors(ctx.style.colors[.widgetBase], ctx.style.colors[.widgetHover], ctx.style.colors[.widgetPress], hover + press)
}

/*
	The global state

	TODO(isaiah): Add manual state swapping
*/
ContextOption :: enum {
	showLayouts,
	showLayers,
	showDebugWindow,
}
ContextOptions :: bit_set[ContextOption]
Context :: struct {
	allocator: runtime.Allocator,
	options: ContextOptions,

	time,
	deltaTime,
	renderTime: f32,
	disabled, dragging: bool,
	size: Vec2,
	lastRect: Rect,

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
	focusId,
	prevFocusId: Id,
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

Init :: proc() {
	/*
		Set up default context and set style
	*/
	ctx = new(Context)

	//TODO(isaiah): do something with this!
	{
		using ctx.style
		colors[.accent] = {53, 120, 243, 255}
		colors[.windowBase] = {28, 28, 28, 255}
		colors[.backing] = {18, 18, 18, 255}
		colors[.iconBase] = {192, 192, 192, 255}
		colors[.widgetBase] = {50, 50, 50, 255}
		colors[.widgetHover] = {65, 64, 67, 255}
		colors[.widgetPress] = {77, 76, 79, 255}
		colors[.widgetShade] = {255, 255, 255, 255}

		colors[.outlineBase] = {80, 80, 80, 255}

		colors[.textBright] = {255, 255, 255, 255}
		colors[.text] = {200, 200, 200, 255}
	}
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

	input.runeCount = 0

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
				CheckBoxBitSetHeader(&options, "")
				for option in ContextOption {
					PushId(HashIdFromInt(int(option)))
						CheckBoxBitSet(&options, option, Format(option))
					PopId()
				}
			}
		}
	}

	// Reset input bits
	input.prevKeyBits = input.keyBits
	input.prevMouseBits = input.mouseBits
	input.prevMousePos = input.mousePos
}
ShouldRender :: proc() -> bool {
	return ctx.renderTime > 0
}

/*
	Text input
*/
Scribe :: struct {
	index, length, anchor: int,
	buffer: [dynamic]u8,
}
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

/*
	Safe text formatting for short-term usage
*/
FMT_BUFFER_COUNT :: 16
FMT_BUFFER_SIZE :: 128
@private fmtBuffers: [FMT_BUFFER_COUNT][FMT_BUFFER_SIZE]u8
@private fmtBufferIndex: u8
StringFormat :: proc(text: string, args: ..any) -> string {
	str := fmt.bprintf(fmtBuffers[fmtBufferIndex][:], text, ..args)
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
SPrintF :: proc(text: string, args: ..any) -> []u8 {
	str := fmt.bprintf(fmtBuffers[fmtBufferIndex][:], text, ..args)
	slice := fmtBuffers[fmtBufferIndex][:len(str)]
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return slice
}
Format :: proc(args: ..any) -> string {
	str := fmt.bprint(fmtBuffers[fmtBufferIndex][:], ..args)
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}
Join :: proc(args: ..string) -> string {
	size := 0
	buffer := &fmtBuffers[fmtBufferIndex]
	for arg in args {
		copy(buffer[size:size + len(arg)], arg[:])
		size += len(arg)
	}
	str := string(buffer[:size])
	fmtBufferIndex = (fmtBufferIndex + 1) % FMT_BUFFER_COUNT
	return str
}

/*
	Color manipulation
*/
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

//@private
ctx : ^Context
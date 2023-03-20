package maui

import "core:fmt"
import "core:runtime"
import "core:sort"

MAX_CONTROLS :: #config(MAUI_MAX_CONTROLS, 128)
MAX_PANELS :: #config(MAUI_MAX_PANELS, 8)
MAX_FRAMES :: #config(MAUI_MAX_FRAMES, 32)
MAX_LAYOUTS :: #config(MAUI_MAX_LAYOUTS, 32)
ID_STACK_SIZE :: 8
COMMAND_STACK_SIZE :: #config(MAUI_COMMAND_STACK_SIZE, 64 * 1024)

Absolute :: i32
Relative :: f32
Value :: union {
	Absolute,
	Relative,
}
Vector :: [2]f32
AnyVector :: [2]Value

VecVsRect :: proc(v: Vector, r: Rect) -> bool {
	return (v.x >= r.x) && (v.x <= r.x + r.w) && (v.y >= r.y) && (v.y <= r.y + r.h)
}
RectVsRect :: proc(a, b: Rect) -> bool {
	return (a.x + a.w >= b.x) && (a.x <= b.x + b.w) && (a.y + a.h >= b.y) && (a.y <= b.y + b.h)
}
// A contains B
RectContainsRect :: proc(a, b: Rect) -> bool {
	return (b.x >= a.x) && (b.x + b.w <= a.x + a.w) && (b.y >= a.y) && (b.y + b.h <= a.y + a.h)
}

Color :: [4]u8 
GetColor :: proc(index: int, alpha: f32) -> Color {
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
TranslateRect :: proc(r: Rect, v: Vector) -> Rect {
	return {r.x + v.x, r.y + v.y, r.w, r.h}
}

/*
	A hashed id to uniquely identify stuff
*/
Id :: distinct u32

@private HASH_LOOKUP_TABLE :: [256]u32 {
	0x00000000,0x77073096,0xEE0E612C,0x990951BA,0x076DC419,0x706AF48F,0xE963A535,0x9E6495A3,0x0EDB8832,0x79DCB8A4,0xE0D5E91E,0x97D2D988,0x09B64C2B,0x7EB17CBD,0xE7B82D07,0x90BF1D91,
	0x1DB71064,0x6AB020F2,0xF3B97148,0x84BE41DE,0x1ADAD47D,0x6DDDE4EB,0xF4D4B551,0x83D385C7,0x136C9856,0x646BA8C0,0xFD62F97A,0x8A65C9EC,0x14015C4F,0x63066CD9,0xFA0F3D63,0x8D080DF5,
	0x3B6E20C8,0x4C69105E,0xD56041E4,0xA2677172,0x3C03E4D1,0x4B04D447,0xD20D85FD,0xA50AB56B,0x35B5A8FA,0x42B2986C,0xDBBBC9D6,0xACBCF940,0x32D86CE3,0x45DF5C75,0xDCD60DCF,0xABD13D59,
	0x26D930AC,0x51DE003A,0xC8D75180,0xBFD06116,0x21B4F4B5,0x56B3C423,0xCFBA9599,0xB8BDA50F,0x2802B89E,0x5F058808,0xC60CD9B2,0xB10BE924,0x2F6F7C87,0x58684C11,0xC1611DAB,0xB6662D3D,
	0x76DC4190,0x01DB7106,0x98D220BC,0xEFD5102A,0x71B18589,0x06B6B51F,0x9FBFE4A5,0xE8B8D433,0x7807C9A2,0x0F00F934,0x9609A88E,0xE10E9818,0x7F6A0DBB,0x086D3D2D,0x91646C97,0xE6635C01,
	0x6B6B51F4,0x1C6C6162,0x856530D8,0xF262004E,0x6C0695ED,0x1B01A57B,0x8208F4C1,0xF50FC457,0x65B0D9C6,0x12B7E950,0x8BBEB8EA,0xFCB9887C,0x62DD1DDF,0x15DA2D49,0x8CD37CF3,0xFBD44C65,
	0x4DB26158,0x3AB551CE,0xA3BC0074,0xD4BB30E2,0x4ADFA541,0x3DD895D7,0xA4D1C46D,0xD3D6F4FB,0x4369E96A,0x346ED9FC,0xAD678846,0xDA60B8D0,0x44042D73,0x33031DE5,0xAA0A4C5F,0xDD0D7CC9,
	0x5005713C,0x270241AA,0xBE0B1010,0xC90C2086,0x5768B525,0x206F85B3,0xB966D409,0xCE61E49F,0x5EDEF90E,0x29D9C998,0xB0D09822,0xC7D7A8B4,0x59B33D17,0x2EB40D81,0xB7BD5C3B,0xC0BA6CAD,
	0xEDB88320,0x9ABFB3B6,0x03B6E20C,0x74B1D29A,0xEAD54739,0x9DD277AF,0x04DB2615,0x73DC1683,0xE3630B12,0x94643B84,0x0D6D6A3E,0x7A6A5AA8,0xE40ECF0B,0x9309FF9D,0x0A00AE27,0x7D079EB1,
	0xF00F9344,0x8708A3D2,0x1E01F268,0x6906C2FE,0xF762575D,0x806567CB,0x196C3671,0x6E6B06E7,0xFED41B76,0x89D32BE0,0x10DA7A5A,0x67DD4ACC,0xF9B9DF6F,0x8EBEEFF9,0x17B7BE43,0x60B08ED5,
	0xD6D6A3E8,0xA1D1937E,0x38D8C2C4,0x4FDFF252,0xD1BB67F1,0xA6BC5767,0x3FB506DD,0x48B2364B,0xD80D2BDA,0xAF0A1B4C,0x36034AF6,0x41047A60,0xDF60EFC3,0xA867DF55,0x316E8EEF,0x4669BE79,
	0xCB61B38C,0xBC66831A,0x256FD2A0,0x5268E236,0xCC0C7795,0xBB0B4703,0x220216B9,0x5505262F,0xC5BA3BBE,0xB2BD0B28,0x2BB45A92,0x5CB36A04,0xC2D7FFA7,0xB5D0CF31,0x2CD99E8B,0x5BDEAE1D,
	0x9B64C2B0,0xEC63F226,0x756AA39C,0x026D930A,0x9C0906A9,0xEB0E363F,0x72076785,0x05005713,0x95BF4A82,0xE2B87A14,0x7BB12BAE,0x0CB61B38,0x92D28E9B,0xE5D5BE0D,0x7CDCEFB7,0x0BDBDF21,
	0x86D3D2D4,0xF1D4E242,0x68DDB3F8,0x1FDA836E,0x81BE16CD,0xF6B9265B,0x6FB077E1,0x18B74777,0x88085AE6,0xFF0F6A70,0x66063BCA,0x11010B5C,0x8F659EFF,0xF862AE69,0x616BFFD3,0x166CCF45,
	0xA00AE278,0xD70DD2EE,0x4E048354,0x3903B3C2,0xA7672661,0xD06016F7,0x4969474D,0x3E6E77DB,0xAED16A4A,0xD9D65ADC,0x40DF0B66,0x37D83BF0,0xA9BCAE53,0xDEBB9EC5,0x47B2CF7F,0x30B5FFE9,
	0xBDBDF21C,0xCABAC28A,0x53B39330,0x24B4A3A6,0xBAD03605,0xCDD70693,0x54DE5729,0x23D967BF,0xB3667A2E,0xC4614AB8,0x5D681B02,0x2A6F2B94,0xB40BBE37,0xC30C8EA1,0x5A05DF1B,0x2D02EF8D,
}

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
	return HashId(rawptr(&loc), size_of(loc))
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
	The global state

	TODO(isaiah): Add manual state swapping
*/
Style :: struct {
	colors: [6]Color,
	outline: f32,
}
Context :: struct {
	allocator: runtime.Allocator,

	time,
	deltaTime,
	renderTime: f32,
	
	disabled: bool,
	size: Vector,
	style: Style,

	idStack: [ID_STACK_SIZE]Id,
	idCount: i32,

	// fonts
	font: FontData,

	// Retained control data
	controls: [MAX_CONTROLS]Control,
	controlExists: [MAX_CONTROLS]bool,

	// Retained panel data
	panels: [MAX_PANELS]PanelData,
	panelExists: [MAX_PANELS]bool,
	panelMap: map[Id]i32,
	// Ordered list for sorting
	panelList: [dynamic]i32,
	// Index stack for panels within panels
	panelDepth: i32,
	panelStack: [MAX_PANELS]i32,
	// Current panel state
	nextHoveredPanel, hoveredPanel, focusedPanel: i32,
	hoverIndex: i32,
	movingPanel, sizingPanel: bool,
	dragAnchor: Vector,

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

	// render commands
	commands: [COMMAND_STACK_SIZE]byte,
	commandOffset: i32,
}

SetNextRect :: proc(rect: Rect) {
	ctx.setNextRect = true
	ctx.nextRect = rect
}
UseNextRect :: proc() -> (rect: Rect, ok: bool) {
	rect = ctx.nextRect
	ok = ctx.setNextRect
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

GetScreenPoint :: proc(h, v: f32) -> Vector {
	return {h * f32(ctx.size.x), v * f32(ctx.size.y)}
}
SetScreenSize :: proc(w, h: f32) {
	ctx.size = {w, h}
}

Init :: proc() {
	ctx = new(Context)

	ctx.style.colors = {
		{255, 255, 255, 255},
		{10, 10, 10, 255},
		{15, 235, 90, 255},
		{255, 0, 180, 255},
		{0, 255, 180, 255},
		{231, 232, 252, 255},
	}
	ctx.style.outline = 1

	success := false
	ctx.font, success = LoadFont("fonts/Inconsolata_Condensed-SemiBold.ttf", 24, 100)
	assert(success, "Failed to load default font")
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

				if (control.state & {.hovered, .down} != {}) || (control.hoverTime > 0) || (control.pressTime > 0) {
					renderTime = 1
				}

				control.bits -= {.stayAlive}
			} else {
				controlExists[i] = false
			}
		}
	}

	if !ShouldRender() {
		return
	}

	/*
		Reorder the panel list if needed
	*/
	top := len(panelList) - 1
	prevTop := top
	for panelIndex, index in panelList {
		panel := &panels[panelIndex]
		if !panelExists[panelIndex] {
			ordered_remove(&panelList, index)
			delete_key(&panelMap, panel.id)
			continue
		}
		panel.index = i32(index)
		if VecVsRect(input.mousePos, panel.body) {
			if MousePressed(.left) && (.floating in panel.bits) {
				top = index
			}
			hoveredPanel = i32(panelIndex)
		}
	}
	sort.quick_sort_proc(panelList[:], proc(a, b: i32) -> int {
		aA := int(.floating in panels[a].bits)
		bB := int(.floating in panels[b].bits)
		return aA - bB
		})
	if top != prevTop {
		index := panelList[top]
		copy(panelList[top:], panelList[top + 1:])
		panelList[prevTop] = index
	}

	/*
		Sort the draw order of panels
		decide which panel is hovered
	*/
	hoveredPanel = 0
	for i in 0 ..< len(panelList) {
		panel := &panels[panelList[i]]
		if VecVsRect(input.mousePos, panel.body) {
			hoveredPanel = panelMap[panel.id]
		}
		/* if this is the first container then make the first command jump to it.
		** otherwise set the previous container's tail to jump to this one */
		if i == 0 {
			cmd := (^CommandJump)(&commands)
			cmd.dst = rawptr(uintptr(panel.head) + size_of(CommandJump))
		} else {
			prevPanel := &panels[panelList[i - 1]]
			prevPanel.tail.variant.(^CommandJump).dst = rawptr(uintptr(panel.head) + size_of(CommandJump))
		}
		/* make the last container's tail jump to the end of command list */
		if i == len(panelList) - 1 {
			panel.tail.variant.(^CommandJump).dst = rawptr(&commands[commandOffset])
		}
	}

	for i in 0..<MAX_PANELS {
		if panelExists[i] {
			panel := &panels[i]
			if .stayAlive in panel.bits {
				panel.bits -= {.stayAlive}
			} else {
				panelExists[i] = false
			}
		}
	}
}
Refresh :: proc() {
	using ctx

	assert(layoutDepth == 0, "You forgot to PopLayout()")
	assert(panelDepth == 0)
	assert(idCount == 0)

	commandOffset = 0

	prevHoverId = hoverId
	prevPressId = pressId
	hoverId = nextHoverId
	nextHoverId = 0

	input.prevKeyBits = input.keyBits
	input.prevMouseBits = input.mouseBits
	input.prevMousePos = input.mousePos

	renderTime = max(0, renderTime - deltaTime)

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

//@private
ctx : ^Context
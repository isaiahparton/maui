/*
	TODO: Implement descrete text formatting and painting options
*/

package maui

import "core:runtime"
import "core:os"

import "core:math"
import "core:math/bits"
import "core:math/linalg"

import "core:fmt"

import "core:unicode"
import "core:unicode/utf8"

import ttf "vendor:stb/truetype"

TEXT_BREAK :: "..."

Font_Handle :: int

// The different uses of fonts

Font_Size :: struct {
	ascent,
	line_gap,
	scale: f32,
	glyphs: map[rune]Glyph_Data,
	// Helpers
	break_size: f32,
}
Font :: struct {
	data: ttf.fontinfo,
	sizes: map[f32]Font_Size,
}
Glyph_Data :: struct {
	image: Image,
	src: Box,
	offset: [2]f32,
	advance: f32,
}

Icon :: enum rune {
	Cloud 						= 0xEB9C,
	Hard_Drive 				= 0xF394,
	Sliders 					= 0xEC9C,
	Tree_Nodes 				= 0xEF90,
	Ball_Pen  				= 0xEA8D,
	More_Horizontal 	= 0xEF78,
	Code 							= 0xeba8,
	Github 						= 0xedca,
	Check 						= 0xEB7A,
	Error 						= 0xECA0,
	Close 						= 0xEB98,
	Heart 						= 0xEE0E,
	Alert 						= 0xEA20,
	Edit 							= 0xEC7F,
	Home 							= 0xEE18,
	Server 						= 0xF0DF,
	Add 							= 0xEA12,
	Undo 							= 0xEA58,
	Shopping_Cart 		= 0xF11D,
	Attach_File				= 0xEA84,
	Remove 						= 0xF1AE,
	Delete 						= 0xEC1D,
	User 							= 0xF25F,
	Format_Italic			= 0xe23f,
	Format_Bold				= 0xe238,
	Format_Underline	= 0xe249,
	Chevron_Down 			= 0xEA4E,
	Chevron_Left 			= 0xEA64,
	Chevron_Right 		= 0xEA6E,
	Chevron_Up				= 0xEA78,
	Folder 						= 0xED57,
	Admin 						= 0xEA14,
	Shopping_Basket 	= 0xF11A,
	Shopping_Bag 			= 0xF115,
	Receipt 					= 0xEAC2,
	File_Paper 				= 0xECF8,
	File_New 					= 0xECC2,
	Calendar 					= 0xEB20,
	Inventory 				= 0xF1C6,
	History 					= 0xEE17,
	Copy 							= 0xECD2,
	Checkbox_Multiple	= 0xEB88,
	Eye 							= 0xECB4,
	Eye_Off 					= 0xECB6,
	Box 							= 0xF2F3,
	Archive 					= 0xEA47,
	Cog 							= 0xF0ED,
	Group 						= 0xEDE2,
	Flow_Chart 				= 0xEF59,
	Pie_Chart 				= 0xEFF5,
	Keyboard 					= 0xEE74,
	Spreadsheet				= 0xECDE,
	Contact_Book 			= 0xEBCB,
	Pin 							= 0xF038,
	Unpin 						= 0xF376,
	Filter 						= 0xED26,
	Filter_Off 				= 0xED28,
	Search 						= 0xF0CD,
	Printer 					= 0xF028,
	Draft_Fill 				= 0xEC5B,
	Check_List 				= 0xEEB9,
	Numbers 					= 0xEFA9,
	Refund 						= 0xF067,
	Wallet 						= 0xF2AB,
	Bank_Card 				= 0xEA91,
}

FMT_BUFFER_COUNT 		:: 16
FMT_BUFFER_SIZE 		:: 256
// Text formatting for short term usage
// each string is valid until it's home buffer is reused
@private fmt_buffers: [FMT_BUFFER_COUNT][FMT_BUFFER_SIZE]u8
@private fmt_buffer_index: u8

tmp_print :: proc(args: ..any) -> string {
	str := fmt.bprint(fmt_buffers[fmt_buffer_index][:], ..args)
	fmt_buffer_index = (fmt_buffer_index + 1) % FMT_BUFFER_COUNT
	return str
}
tmp_printf :: proc(text: string, args: ..any) -> string {
	str := fmt.bprintf(fmt_buffers[fmt_buffer_index][:], text, ..args)
	fmt_buffer_index = (fmt_buffer_index + 1) % FMT_BUFFER_COUNT
	return str
}
tmp_join :: proc(args: []string, sep := " ") -> string {
	size := 0
	buffer := &fmt_buffers[fmt_buffer_index]
	for arg, index in args {
		copy(buffer[size:size + len(arg)], arg[:])
		size += len(arg)
		if index < len(args) - 1 {
			copy(buffer[size:size + len(sep)], sep[:])
			size += len(sep)
		}
	}
	str := string(buffer[:size])
	fmt_buffer_index = (fmt_buffer_index + 1) % FMT_BUFFER_COUNT
	return str
}
tmp_print_real :: proc(text: string) -> string {
	text := text
	for i := len(text) - 1; i >= 0; i -= 1 {
		if text[i] != '0' {
			if text[i] == '.' {
				text = text[:i]
			}
			break
		} else {
			text = text[:i]
		}
	}
	return text
}
tmp_print_bit_set :: proc(set: $S/bit_set[$E;$U], sep := " ") -> string {
	size := 0
	buffer := &fmt_buffers[fmt_buffer_index]
	count := 0
	max := card(set)
	for member in E {
		if member not_in set {
			continue
		}
		name := fprint(member)
		copy(buffer[size:size + len(name)], name[:])
		size += len(name)
		if count < max - 1 {
			copy(buffer[size:size + len(sep)], sep[:])
			size += len(sep)
		}
		count += 1
	}
	str := string(buffer[:size])
	fmt_buffer_index = (fmt_buffer_index + 1) % FMT_BUFFER_COUNT
	return str
}

Text_Align :: enum {
	Left,
	Middle,
	Right,
}
Text_Baseline :: enum {
	Top,
	Middle,
	Bottom,
}
Text_Info :: struct {
	font: Font_Handle,
	text: string,
	align: Text_Align,
	baseline: Text_Baseline,
	size: f32,
	line_limit: Maybe(f32),
	word_wrap: bool,
}
Text_Iterator :: struct {
	// Font
	font: ^Font,
	size: ^Font_Size,
	// Ending
	tail: Maybe(int),
	// Current line size
	line_limit: Maybe(f32),
	line_size: f32,
	new_line: bool,
	// Glyph offset
	offset: [2]f32,
	// Current codepoint and glyph data
	codepoint: rune,
	glyph: ^Glyph_Data,
	// Current byte index
	next_word,
	index,
	next_index: int,
	// Do offset
	do_offset: bool,
}
make_text_iterator :: proc(info: Text_Info) -> (it: Text_Iterator) {
	it.font = &painter.fonts[info.font]
	it.size, _ = get_font_size(it.font, info.size)
	it.line_limit = info.line_limit
	return
}
iterate_text :: proc(it: ^Text_Iterator, info: Text_Info) -> bool {
	
	// Update index
	it.index = it.next_index
	// Decode next codepoint
	codepoint, bytes := utf8.decode_rune(info.text[it.index:])
	// Update next index
	it.next_index += bytes
	// Update horizontal offset with last glyph
	if it.new_line {
		it.line_size = 0
	}
	if it.glyph != nil {
		it.offset.x += it.glyph.advance
		it.line_size += it.glyph.advance
	}
	// Get current glyph data
	if glyph, ok := get_font_glyph(it.font, it.size, codepoint); ok {
		it.glyph = glyph
	}
	space: f32 = it.glyph.advance if it.glyph != nil else 0
	if info.word_wrap && it.next_index >= it.next_word && codepoint != ' ' {
		for i := it.next_word; i < len(info.text); {
			c, b := utf8.decode_rune(info.text[i:])
			if g, ok := get_font_glyph(it.font, it.size, codepoint); ok {
				space += g.advance
			}
			if c == ' ' {
				it.next_word = i + b
				break
			}
			i += b
		}
	}

	it.new_line = false
	new_line := false
	if codepoint == '\n' || (it.line_limit != nil && it.line_size + space >= it.line_limit.?) {
		new_line = true
	}
	// Update vertical offset
	if new_line {
		it.new_line = true
		it.offset.y += it.size.ascent + it.size.line_gap
	}
	// Reset offset if new line
	if it.do_offset && (new_line || it.index == 0) {
		it.offset.x = 0
		#partial switch info.align {
			case .Center: it.offset.x -= measure_next_line(info, it^) / 2
			case .Right: it.offset.x -= measure_next_line(info, it^)
		}
	}
	it.codepoint = codepoint
	
	return it.index < len(info.text)
}

/*
	String processing procedures
*/
measure_next_line :: proc(info: Text_Info, it: Text_Iterator) -> f32 {
	it := it
	it.do_offset = false
	for iterate_text(&it, info) {
		if it.new_line {
			break
		}
	}
	return it.line_size
}
measure_next_word :: proc(info: Text_Info, it: Text_Iterator) -> (size: f32, end: int) {
	it := it
	it.do_offset = false
	it.line_size = 0
	for iterate_text(&it, info) {
		if it.codepoint == ' ' {
			break
		}
	}
	return it.line_size, it.next_index
}
measure_text :: proc(info: Text_Info) -> [2]f32 {
	size: [2]f32
	it := make_text_iterator(info)
	for iterate_text(&it, info) {
		size.x = max(size.x, it.line_size)
		if it.new_line {
			size.y += it.size.ascent
		}
	}
	size.y += it.size.ascent
	return size
}
// Load a font and store it in the given document
load_font :: proc(painter: ^Painter, file: string) -> (handle: Font_Handle, success: bool) {
	font: Font
	if file_data, ok := os.read_entire_file(file); ok {
		if ttf.InitFont(&font.data, transmute([^]u8)(transmute(runtime.Raw_Slice)file_data).data, 0) {
			for i in 0..<MAX_FONTS {
				if !painter.font_exists[i] {
					painter.font_exists[i] = true
					painter.fonts[i] = font
					// Add the font to the atlas
					default_runes: []rune = {32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 0x2022}
					for r in default_runes {
						
					}

					handle = Font_Handle(i)
					success = true
					break
				}
			}
		}
	}
	return
}
// Get the data for a given pixel size of the font
get_font_size :: proc(font: ^Font, size: f32) -> (data: ^Font_Size, ok: bool) {
	data, ok = &font.sizes[size]
	if !ok {
		data = map_insert(&font.sizes, size, Font_Size{})
		// Compute glyph scale
		data.scale = ttf.ScaleForPixelHeight(&font.data, f32(size))
		// Compute vertical metrics
		ascent, descent, line_gap: i32
		ttf.GetFontVMetrics(&font.data, &ascent, &descent, &line_gap)
		data.baseline = f32(f32(ascent) * data.scale)
		data.line_gap = f32(f32(line_gap) * data.scale)
		// Yup
		ok = true
	}
	return
}
// First creates the glyph if it doesn't exist, then returns its data
get_font_glyph :: proc(font: ^Font, size: ^Font_Size, codepoint: rune) -> (data: ^Glyph_Data, success: bool) {
	// Try fetching from map
	glyph_data, found_glyph := &size.glyphs[codepoint]
	// If the glyph doesn't exist, we create and render it
	if !found_glyph {
		// Get codepoint index
		index := ttf.FindGlyphIndex(&font.data, codepoint)
		// Get metrics
		advance, left_side_bearing: i32
		ttf.GetGlyphHMetrics(&font.data, index, &advance, &left_side_bearing)
		// Generate bitmap
		image_width, image_height, glyph_offset_x, glyph_offset_y: i32
		image_data := ttf.GetGlyphBitmap(
			&font.data, 
			size.scale, 
			size.scale, 
			index,
			&image_width,
			&image_height,
			&glyph_offset_x,
			&glyph_offset_y,
			)
		image: Image 
		if image_data != nil {
			image = {
				data = transmute([]u8)runtime.Raw_Slice({data = image_data, len = int(image_width * image_height)}),
				channels = 1,
				width = int(image_width),
				height = int(image_height),
			}
		}
		// Set glyph data
		glyph_data = map_insert(&size.glyphs, codepoint, Glyph_Data({
			image = image,
			offset = {f32(glyph_offset_x), f32(glyph_offset_y) + size.ascent},
			advance = f32(f32(advance) * size.scale),
		}))
		success = true
	} else {
		success = true
	}
	data = glyph_data
	return
}

paint_and_save_text :: proc(info: Text_Info, buffer: ^[dynamic]Vertex) -> [2]f32 {
	
}

paint_aligned_icon :: proc(font: Font_Handle, icon: Icon, origin: [2]f32, size: f32, color: Color, align: [2]Alignment) -> [2]f32 {
	glyph := get_glyph_data(font_data, rune(icon))
	box := glyph.src
	box.w *= size
	box.h *= size
	switch align.x {
		case .Far: box.x = origin.x - box.w
		case .Middle: box.x = origin.x - box.w / 2
		case .Near: box.x = origin.x
	}
	switch align.y {
		case .Far: box.y = origin.y - box.h
		case .Middle: box.y = origin.y - box.h / 2
		case .Near: box.y = origin.y
	}
	paint_texture(painter.atlas_agent.texture, glyph.src, box, color)
	return {box.w, box.h}
}

// Draw a glyph, mathematically clipped to 'clipBox'
paint_clipped_glyph :: proc(glyph: Glyph_Data, origin: [2]f32, clip: Box, color: Color) {
	src := glyph.src
	dst := Box{ 
			f32(i32(origin.x + glyph.offset.x)), 
			f32(i32(origin.y + glyph.offset.y)), 
			src.w, 
			src.h,
	}
	if dst.x < clip.x {
		delta := clip.x - dst.x
		dst.w -= delta
		dst.x += delta
		src.x += delta
	}
	if dst.y < clip.y {
		delta := clip.y - dst.y
		dst.h -= delta
		dst.y += delta
		src.y += delta
	}
	if dst.x + dst.w > clip.x + clip.w {
		dst.w = (clip.x + clip.w) - dst.x
	}
	if dst.y + dst.h > clip.y + clip.h {
		dst.h = (clip.y + clip.h) - dst.y
	}
	src.w = dst.w
	src.h = dst.h
	if src.w <= 0 || src.h <= 0 {
		return
	}
	paint_texture(painter.atlas_agent.texture, src, dst, color)
}

// Advanced interactive text
Selectable_Text_Bit :: enum {
	Password,
	Mutable,
	Select_All,
	No_Paint,
}

Selectable_Text_Bits :: bit_set[Selectable_Text_Bit]

Selectable_Text_Info :: struct {
	font_data: ^Font,
	data: []u8,
	box: Box,
	view_offset: [2]f32,
	bits: Selectable_Text_Bits,
	padding: [2]f32,
	align: [2]Alignment,
}

Selectable_Text_Result :: struct {
	text_size,
	view_offset: [2]f32,
	line_count: int,
	font: ^Font,
}

//TODO: Fix cursor appearing for one frame on previously focused widget when selecting another
// Displays clipped, selectable text that can be copied to clipboard
selectable_text :: proc(widget: ^Widget, info: Selectable_Text_Info) -> (result: Selectable_Text_Result) {
	assert(widget != nil)
	result.view_offset = info.view_offset
	// Alias scribe state
	state := &core.typing_agent
	// Should paint?
	should_paint := .Should_Paint in widget.bits && .No_Paint not_in info.bits
	// For calculating hovered glyph
	hover_index := 0
	min_dist: f32 = math.F32_MAX
	// Determine text origin
	origin: [2]f32 = {info.box.x, info.box.y}
	// Get text size if necessary
	text_size: [2]f32
	if info.align.x != .Near || info.align.y != .Near {
		text_size = measure_string(info.font_data, string(info.data))
	}
	// Handle alignment
	switch info.align.x {
		case .Near: origin.x += info.padding.x
		case .Middle: origin.x += info.box.w / 2 - text_size.x / 2
		case .Far: origin.x += info.box.w - text_size.x - info.padding.x
	}
	switch info.align.y {
		case .Near: origin.y += info.padding.y
		case .Middle: origin.y += info.box.h / 2 - text_size.y / 2
		case .Far: origin.y += info.box.h - text_size.y - info.padding.y
	}
	// Offset view when currently focused
	if .Got_Focus not_in widget.state {
		origin -= info.view_offset
	}
	point := origin
	// Total text size
	size: [2]f32
	// Cursor start and end position
	cursor_low: [2]f32 = 3.40282347E+38
	cursor_high: [2]f32
	// Reset view offset when just focused
	if .Got_Focus in widget.state {
		result.view_offset = {}
	}
	if .Focused in widget.state {
		// Content copy
		if key_down(.Control) {
			if key_pressed(.C) {
				if state.length > 0 {
					set_clipboard_string(string(info.data[state.index:][:state.length]))
				} else {
					set_clipboard_string(string(info.data[:]))
				}
			}
		}
	}
	// Draw chippies
	if core.chips.height > 0 {
		if do_layout_box(move_box(info.box, -info.view_offset)) {
			placement.side = .Left; placement.margin = {.Left = Exact(5), .Top = Exact(5), .Bottom = Exact(5), .Right = Exact(0)}
			for i in 0..<core.chips.height {
				push_id(i)
					if do_chip({
						text = core.chips.items[i].text,
						clip_box = info.box,
					}) {
						core.chips.items[i].clicked = true
					}
				pop_id()
			}
			point.x += info.box.w - current_layout().box.w - 5
		}
	}
	// Iterate over the bytes
	for index := 0; index <= len(info.data); {
		// Decode the next glyph
		bytes := 1
		glyph: rune
		if index < len(info.data) {
			glyph, bytes = utf8.decode_rune_in_bytes(info.data[index:])
		}
		// Password placeholder glyph
		if .Password in info.bits {
			glyph = '•'
		}
		is_tab := glyph == '\t'
		// Get glyph data
		glyph_data := get_glyph_data(info.font_data, 32 if is_tab else glyph)
		glyph_width := glyph_data.advance + GLYPH_SPACING
		if is_tab {
			TAB_SPACES :: 3
			glyph_width *= TAB_SPACES
		}
		highlight := false
		// Draw cursors
		if should_paint && .Focused in widget.state && .Got_Focus not_in widget.state {
			// Draw cursor/selection if allowed
			if state.length == 0 {
				if state.index == index && point.x >= info.box.x && point.x < info.box.x + info.box.w {
					// Bar cursor
					cursor_point := linalg.floor(point)
					cursor_point.y = max(cursor_point.y, info.box.y)
					paint_box_fill(
						box = clip_box({
							cursor_point.x, 
							cursor_point.y, 
							1, 
							info.font_data.size,
						}, info.box), 
						color = get_color(.Text),
						)
				}
			} else if index >= state.index && index < state.index + state.length {
				// Selection
				cursor_point := linalg.floor(point)
				paint_box_fill(
					box = clip_box({
						cursor_point.x, 
						cursor_point.y, 
						glyph_width,
						info.font_data.size,
					}, info.box), 
					color = get_color(.Text),
					)
				highlight = true
			}
		}
		// Decide the hovered glyph
		glyph_point := point + {0, info.font_data.size / 2}
		dist := linalg.length(glyph_point - input.mouse_point)
		if dist < min_dist {
			min_dist = dist
			hover_index = index
		}
		if .Focused in widget.state {
			if index == state.index {
				cursor_low = point - origin
			}
			if index == state.index + state.length {
				cursor_high = (point + {0, info.font_data.size}) - origin
			}
		}
		// Anything past here requires a valid glyph
		if index == len(info.data) {
			break
		}
		// Draw the glyph
		if glyph == '\n' {
			point.x = origin.x
			point.y += info.font_data.size
			size.y += info.font_data.size
			result.line_count += 1
		} else if should_paint && glyph != '\t' && glyph != ' ' {
			paint_clipped_glyph(glyph_data, point, info.box, get_color(.Text_Inverted if highlight else .Text, 1))
		}
		// Finished, move index and point
		point.x += glyph_width
		size.x = max(size.x, point.x - origin.x)
		index += bytes
	}
	// Handle initial text selection
	if .Select_All in info.bits {
		if .Got_Focus in widget.state {
			state.index = 0
			state.anchor = 0
			state.length = len(info.data)
		}
	}
	// Text selection by clicking
	if .Got_Press in widget.state {
		if widget.click_count == 1 {
			// Select the hovered word
			// Move index to the beginning of the hovered word
			for i := min(state.index, len(info.data) - 1); ; i -= 1 {
				if i == 0 {
					state.index = 0
					break
				} else if is_seperator(info.data[i]) {
					state.index = i + 1
					break
				}
			}
			// Find length of the word
			for j := state.index + 1; ; j += 1 {
				if j >= len(info.data) - 1 {
					state.length = len(info.data) - state.index
					break
				} else if is_seperator(info.data[j]) {
					state.length = j - state.index
					break
				}
			}
		} else if widget.click_count == 2 {
			// Select everything
			state.index = 0
			state.anchor = 0
			state.length = len(info.data)
		} else {
			// Normal select
			state.index = hover_index
			state.anchor = hover_index
			state.length = 0
		}
	}
	// Get desired bounds for cursor
	inner_size: [2]f32 = {info.box.w, info.box.h} - info.padding * 2
	// View offset
	if widget.state >= {.Pressed} && widget.click_count == 0 {
		// Selection by dragging
		if hover_index < state.anchor {
			state.index = hover_index
			state.length = state.anchor - hover_index
		} else {
			state.index = state.anchor
			state.length = hover_index - state.anchor
		}
		// Offset view by dragging
		DRAG_SPEED :: 15
		if size.x > info.box.w {
			if input.mouse_point.x < info.box.x {
				result.view_offset.x -= (info.box.x - input.mouse_point.x) * DRAG_SPEED * core.delta_time
			} else if input.mouse_point.x > info.box.x + info.box.w {
				result.view_offset.x += (input.mouse_point.x - (info.box.x + info.box.w)) * DRAG_SPEED * core.delta_time
			}
		}
		if size.y > info.box.h && result.line_count > 0 {
			if input.mouse_point.y < info.box.y {
				result.view_offset.y -= (info.box.y - input.mouse_point.y) * DRAG_SPEED * core.delta_time
			} else if input.mouse_point.y > info.box.y + info.box.h {
				result.view_offset.y += (input.mouse_point.y - (info.box.y + info.box.h)) * DRAG_SPEED * core.delta_time
			}
		}
		core.paint_next_frame = true
	} else if .Focused in widget.state && .Lost_Press not_in widget.state {
		// Handle view offset
		if state.index != state.last_index || state.length != state.last_length {
			if cursor_low.x < result.view_offset.x {
				result.view_offset.x = cursor_low.x
			}
			if cursor_low.y < result.view_offset.y {
				result.view_offset.y = cursor_low.y
			}
			if cursor_high.x > result.view_offset.x + inner_size.x {
				result.view_offset.x = cursor_high.x - inner_size.x
			}
			if cursor_high.y + info.font_data.size > result.view_offset.y + inner_size.y {
				result.view_offset.y = (cursor_high.y + info.font_data.size) - inner_size.y
			}
		}
		state.index = clamp(state.index, 0, len(info.data))
		state.length = clamp(state.length, 0, len(info.data) - state.index)
		state.last_index = state.index
		state.last_length = state.length
	}
	// Clamp view offset
	if size.x >= inner_size.x {
		result.view_offset.x = clamp(result.view_offset.x, 0, (size.x - info.box.w) + info.padding.x * 2)
	} else {
		result.view_offset.x = 0
	}
	if size.y >= inner_size.y {
		result.view_offset.y = clamp(result.view_offset.y, 0, (size.y - info.box.h) + info.padding.y * 2 + info.font_data.size)
	} else {
		result.view_offset.y = 0
	}
	result.text_size = size
	result.font_data = info.font_data
	return
}
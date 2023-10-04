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
	descent,
	line_gap,
	scale: f32,
	glyphs: map[rune]Glyph_Data,
	// Helpers
	break_size: f32,
}
destroy_font_size :: proc(using self: ^Font_Size) {
	for _, &glyph in glyphs {
		destroy_glyph_data(&glyph)
	}
	delete(glyphs)
}
Font :: struct {
	data: ttf.fontinfo,
	sizes: map[f32]Font_Size,
}
destroy_font :: proc(using self: ^Font) {
	for _, &size in sizes {
		destroy_font_size(&size)
	}
}
Glyph_Data :: struct {
	image: Image,
	src: Box,
	offset: [2]f32,
	advance: f32,
}
destroy_glyph_data :: proc(using self: ^Glyph_Data) {
	destroy_image(&image)
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
trim_zeroes :: proc(text: string) -> string {
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

Text_Wrap :: enum {
	None,
	Regular,
	Word,
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
	// What font to use
	font: Font_Handle,
	// What size
	size: f32,
	// What text
	text: string,
	// Maximum space occupied in either direction
	limit: [2]Maybe(f32),
	// Wrapping option
	wrap: Text_Wrap,
	// Hidden?
	hidden: bool,
}

Text_Iterator :: struct {
	// Font
	font: ^Font,
	size: ^Font_Size,
	// Current line size
	line_limit: Maybe(f32),
	line_size: [2]f32,
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
make_text_iterator :: proc(info: Text_Info) -> (it: Text_Iterator, ok: bool) {
	if !painter.atlas.font_exists[info.font] || info.size <= 0 {
		return
	}
	it.font = &painter.atlas.fonts[info.font]
	it.size, ok = get_font_size(it.font, info.size)
	it.line_limit = info.limit.x
	return
}
update_text_iterator_offset :: proc(it: ^Text_Iterator, info: Text_Info, paint_info: Text_Paint_Info) {
	it.offset.x = 0
	#partial switch paint_info.align {
		case .Middle: it.offset.x -= measure_next_line(info, it^) / 2
		case .Right: it.offset.x -= measure_next_line(info, it^)
	}
}
iterate_text_codepoint :: proc(it: ^Text_Iterator, info: Text_Info) -> bool {
	if it.next_index >= len(info.text) {
		return false
	}
	// Update index
	it.index = it.next_index
	// Decode next codepoint
	bytes: int
	it.codepoint, bytes = utf8.decode_rune(info.text[it.index:])
	// Update next index
	it.next_index += bytes
	// Get current glyph data
	if it.codepoint != '\n' {
		if glyph, ok := get_font_glyph(it.font, it.size, '•' if info.hidden else it.codepoint); ok {
			it.glyph = glyph
		}
	} else {
		it.glyph = nil
	}
	return true
}
iterate_text :: proc(it: ^Text_Iterator, info: Text_Info) -> bool {
	// Update horizontal offset with last glyph
	if it.glyph != nil {
		it.offset.x += it.glyph.advance
	}
	if it.new_line {
		it.line_size.x = 0 if it.glyph == nil else it.glyph.advance
	}
	/*
		Pre-paint
			Decode the next codepoint -> Update glyph data -> New line if needed
	*/
	if !iterate_text_codepoint(it, info) {
		// We might need to use the end index
		it.index = it.next_index
		it.glyph = nil
		it.codepoint = 0
		it.offset.y += it.size.ascent - it.size.descent
		return false
	}
	// Space needed to fit this glyph/word
	space: f32 = it.glyph.advance if it.glyph != nil else 0
	// Get the space for the next word if needed
	if ( info.wrap == .Word ) && ( it.next_index >= it.next_word ) && ( it.codepoint != ' ' ) {
		for i := it.next_word;; {
			c, b := utf8.decode_rune(info.text[i:])
			if c != '\n' {
				if g, ok := get_font_glyph(it.font, it.size, it.codepoint); ok {
					space += g.advance
				}
			}
			if c == ' ' || i > len(info.text) - 1 {
				it.next_word = i + b
				break
			}
			i += b
		}
	}
	// Reset new line state
	it.new_line = false
	new_line := false
	// Detect new line codepoint
	if ( it.codepoint == '\n' ) {
		new_line = true
	// Or detect overflow
	} else {
		if ( it.line_limit != nil && it.line_size.x + space >= it.line_limit.? ) {
			if info.wrap == .None {
				it.index = it.next_index
		it.glyph = nil
		it.codepoint = 0
		it.offset.y += it.size.ascent - it.size.descent
				return false
			} else {
				new_line = true
			}
		}
	}
	if !new_line && it.glyph != nil {
		it.line_size.x += it.glyph.advance
	}
	// Update vertical offset
	if it.index > 0 && new_line {
		it.new_line = true
		it.offset.y += it.size.ascent - it.size.descent + it.size.line_gap
	}
	return true
}

measure_next_line :: proc(info: Text_Info, it: Text_Iterator) -> f32 {
	it := it
	size: f32 
	for iterate_text(&it, info) {
		if it.new_line {
			break
		} else if it.glyph != nil {
			size += it.glyph.advance
		}
	}
	return size
}
measure_next_word :: proc(info: Text_Info, it: Text_Iterator) -> (size: f32, end: int) {
	it := it
	for iterate_text_codepoint(&it, info) {
		if it.glyph != nil {
			size += it.glyph.advance
		}
		if it.codepoint == ' ' {
			break
		}
	}
	end = it.index
	return
}
measure_text :: proc(info: Text_Info) -> [2]f32 {
	size: [2]f32
	if it, ok := make_text_iterator(info); ok {
		for iterate_text(&it, info) {
			size.x = max(size.x, it.line_size.x)
			if it.new_line {
				size.y += it.size.ascent - it.size.descent + it.size.line_gap
			}
		}
		size.y += it.size.ascent - it.size.descent
	}
	return size
}

/*
	Section [TEXT RESOURCES]
*/

// Load a font to the atlas
load_font :: proc(atlas: ^Atlas, file: string) -> (handle: Font_Handle, success: bool) {
	font: Font
	if file_data, ok := os.read_entire_file(file); ok {
		if ttf.InitFont(&font.data, transmute([^]u8)(transmute(runtime.Raw_Slice)file_data).data, 0) {
			for i in 0..<MAX_FONTS {
				if !atlas.font_exists[i] {
					atlas.font_exists[i] = true
					atlas.fonts[i] = font
					handle = Font_Handle(i)
					success = true
					break
				}
			}
		}
	} else {
		fmt.printf("Failed to load font from %s\n", file)
	}
	return
}
// Get the data for a given pixel size of the font
get_font_size :: proc(font: ^Font, size: f32) -> (data: ^Font_Size, ok: bool) {
	size := math.round(size)
	data, ok = &font.sizes[size]
	if !ok {
		data = map_insert(&font.sizes, size, Font_Size{})
		// Compute glyph scale
		data.scale = ttf.ScaleForPixelHeight(&font.data, f32(size))
		// Compute vertical metrics
		ascent, descent, line_gap: i32
		ttf.GetFontVMetrics(&font.data, &ascent, &descent, &line_gap)
		data.ascent = f32(f32(ascent) * data.scale)
		data.descent = f32(f32(descent) * data.scale)
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
		src: Box
		if image_data != nil {
			image = {
				data = transmute([]u8)runtime.Raw_Slice({data = image_data, len = int(image_width * image_height)}),
				channels = 1,
				width = int(image_width),
				height = int(image_height),
			}
			src = atlas_add(&painter.atlas, image) or_else Box{}
		}
		// Set glyph data
		glyph_data = map_insert(&size.glyphs, codepoint, Glyph_Data({
			image = image,
			src = src,
			offset = {f32(glyph_offset_x), f32(glyph_offset_y) + size.ascent},
			advance = f32((f32(advance) + f32(left_side_bearing)) * size.scale),
		}))
		success = true
	} else {
		success = true
	}
	data = glyph_data
	return
}

/*
	Section [TEXT PAINTING]
*/
Text_Paint_Info :: struct {
	align: Text_Align,
	baseline: Text_Baseline,
	clip: Maybe(Box),
}
paint_text :: proc(origin: [2]f32, info: Text_Info, paint_info: Text_Paint_Info, color: Color) -> [2]f32 {
	size: [2]f32 
	origin := origin
	if paint_info.baseline != .Top {
		size = measure_text(info)
		#partial switch paint_info.baseline {
			case .Middle: origin.y -= size.y / 2 
			case .Bottom: origin.y -= size.y
		}
	}
	if it, ok := make_text_iterator(info); ok {
		update_text_iterator_offset(&it, info, paint_info)
		for iterate_text(&it, info) {
			// Reset offset if new line
			if it.new_line {
				update_text_iterator_offset(&it, info, paint_info)
			}
			// Paint the glyph
			if it.codepoint != '\n' && it.codepoint != ' ' && it.glyph != nil {
				dst: Box = {low = linalg.floor(origin + it.offset + it.glyph.offset)}
				dst.high = dst.low + (it.glyph.src.high - it.glyph.src.low)
				if clip, ok := paint_info.clip.?; ok {
					paint_clipped_textured_box(painter.atlas.texture, it.glyph.src, dst, clip, color)
				} else {
					paint_textured_box(painter.atlas.texture, it.glyph.src, dst, color)
				}
			}
			// Update size
			if it.new_line {
				size.x = max(size.x, it.line_size.x)
				size.y += it.line_size.y
			}
		}
		size.x = max(size.x, it.line_size.x)
		size.y += it.line_size.y
	}
	return size 
}

paint_aligned_icon :: proc(font: Font_Handle, size: f32, icon: Icon, origin: [2]f32, color: Color, align: [2]Alignment) -> [2]f32 {
	font := &painter.atlas.fonts[font]
	font_size, _ := get_font_size(font, size)
	glyph, _ := get_font_glyph(font, font_size, rune(icon))
	icon_size := glyph.src.high - glyph.src.low

	box: Box
	switch align.x {
		case .Far: 
		box.low.x = origin.x - icon_size.x
		box.high.x = origin.x 
		case .Middle: 
		box.low.x = origin.x - icon_size.x / 2 
		box.high.x = origin.x + icon_size.x / 2
		case .Near: 
		box.low.x = origin.x 
		box.high.x = origin.x + icon_size.x 
	}
	switch align.y {
		case .Far: 
		box.low.y = origin.y - icon_size.y
		box.high.y = origin.y 
		case .Middle: 
		box.low.y = origin.y - icon_size.y / 2 
		box.high.y = origin.y + icon_size.y / 2
		case .Near: 
		box.low.y = origin.y 
		box.high.y = origin.y + icon_size.y 
	}
	paint_textured_box(painter.atlas.texture, glyph.src, box, color)
	return icon_size
}

Text_Interact_Info :: struct {
	read_only,
	focus_selects_all,
	invisible: bool,
}

Text_Interact_Result :: struct {
	hovered: bool,
	bounds: Box,
}

paint_interact_text :: proc(origin: [2]f32, widget: ^Widget, agent: ^Typing_Agent, text_info: Text_Info, text_paint_info: Text_Paint_Info, interact_info: Text_Interact_Info, color: Color) -> (res: Text_Interact_Result) {
	assert(widget != nil)
	assert(agent != nil)

	size := measure_text(text_info)
	origin := origin

	// Apply baseline if needed
	#partial switch text_paint_info.baseline {
		case .Middle: origin.y -= size.y / 2 
		case .Bottom: origin.y -= size.y
	}
	hover_index: int
	// Paint the text
	if it, ok := make_text_iterator(text_info); ok {
		at_end := false
		// Determine hovered line
		line_height := it.size.ascent - it.size.descent + it.size.line_gap
		line_count := int(math.floor(size.y / line_height))
		hovered_line := clamp(int((input.mouse_point.y - origin.y) / line_height), 0, line_count)

		min_dist: f32 = math.F32_MAX
		line: int
		// Get line offset
		update_text_iterator_offset(&it, text_info, text_paint_info)
		res.bounds.low = origin + it.offset
		last_line := it.offset
		// Start iteration
		for {
			if !iterate_text(&it, text_info) {
				at_end = true
			}
			// Update hovered index
			if it.glyph != nil && hovered_line == line {
				dist1 := math.abs((origin.x + it.offset.x) - input.mouse_point.x)
				if dist1 < min_dist {
					min_dist = dist1
					hover_index = it.index
				}
				if it.new_line || it.next_index >= len(text_info.text) {
					dist2 := math.abs((origin.x + it.offset.x + it.glyph.advance) - input.mouse_point.x)
					if dist2 < min_dist {
						min_dist = dist2
						hover_index = it.next_index
					}
				}
			}
			// Get hovered state
			if it.new_line || at_end {
				line += 1
				// Check for hover
				line_box: Box = {low = origin + last_line}
				line_box.high = {line_box.low.x + it.line_size.x, origin.y + it.offset.y}
				//paint_box_stroke(line_box, 1, {255, 0, 255, 255})
				if point_in_box(input.mouse_point, line_box) {
					res.hovered = true
				}
				update_text_iterator_offset(&it, text_info, text_paint_info)
				last_line = it.offset
			}
			// Get the glyph point
			point := origin + {it.offset.x, it.offset.y}
			// Paint cursor/selection
			if .Focused in widget.state {
				if agent.length == 0 && !interact_info.read_only {
					if agent.index == it.index {
						// Bar cursor
						box: Box = {{point.x - 1, point.y}, {point.x + 1, point.y + it.size.ascent - it.size.descent}}
						if clip, ok := text_paint_info.clip.?; ok {
							box = clamp_box(box, clip)
						}
						paint_box_fill(box, get_color(.Text_Highlight))
					}
				} else if it.glyph != nil && it.index >= agent.index && it.index < agent.index + agent.length {
					// Selection
					box: Box = {point, {point.x + it.glyph.advance, point.y + it.size.ascent - it.size.descent}}
					if line < line_count {
						box.high.y += it.size.line_gap
					}
					if clip, ok := text_paint_info.clip.?; ok {
						box = clamp_box(box, clip)
					}
					paint_box_fill(box, get_color(.Text_Highlight, 0.5))
				}
			}
			// Paint the glyph
			if it.glyph != nil {
				// Paint the glyph
				dst: Box = {low = point + it.glyph.offset}
				dst.high = dst.low + (it.glyph.src.high - it.glyph.src.low)
				res.bounds.high = linalg.max(res.bounds.high, dst.high)
				if clip, ok := text_paint_info.clip.?; ok {
					paint_clipped_textured_box(painter.atlas.texture, it.glyph.src, dst, clip, color)
				} else {
					paint_textured_box(painter.atlas.texture, it.glyph.src, dst, color)
				}
			}

			if at_end {
				break
			}
		}
	}
	// Update selection
	if mouse_pressed(.Left) {
		agent.index = hover_index
		agent.anchor = hover_index
	}
	// Dragging
	if .Pressed in widget.state && widget.click_count == 0 {
		// Selection by dragging
		if hover_index < agent.anchor {
			agent.index = hover_index
			agent.length = agent.anchor - hover_index
		} else {
			agent.index = agent.anchor
			agent.length = hover_index - agent.anchor
		}
	}
	return
}

Interactable_Text_Info :: struct {
	using text_info: Text_Info,
	paint_info: Text_Paint_Info,
}
do_interactable_text :: proc(info: Interactable_Text_Info, loc := #caller_location) {
	if self, ok := do_widget(hash(loc), {.Draggable}); ok {
		self.box = layout_next(current_layout())
		update_widget(self)

		origin: [2]f32
		switch placement.align.x {
			case .Far: origin.x = self.box.high.x
			case .Middle: origin.x = (self.box.low.x + self.box.high.x) * 0.5
			case .Near: origin.x = self.box.low.x
		}
		switch placement.align.y {
			case .Far: origin.y = self.box.high.y
			case .Middle: origin.y = (self.box.low.y + self.box.high.y) * 0.5
			case .Near: origin.y = self.box.low.y
		}

		array := typing_agent_get_buffer(&core.typing_agent, self.id)
		res := paint_interact_text(origin, self, &core.typing_agent, info.text_info, info.paint_info, {read_only = true}, get_color(.Text))
		update_widget_hover(self, res.hovered)
		paint_box_stroke(res.bounds, 1, {0, 255, 0, 255})

		self.layer.content_box = update_bounding_box(self.layer.content_box, res.bounds)
		if .Hovered in self.state {
			core.cursor = .Beam
		}
		if .Focused in self.state {
			typing_agent_edit(&core.typing_agent, {
				array = array,
			})
		}
	}
}

// Text that can be interacted with
//TODO: Re-implement
/*
do_interactable_text :: proc(widget: ^Widget, info: Selectable_Text_Info) -> (result: Selectable_Text_Result) {
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
						clamp_box = info.box,
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
						box = clamp_box({
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
					box = clamp_box({
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
*/
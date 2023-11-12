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

FMT_BUFFER_COUNT 		:: 16
FMT_BUFFER_SIZE 		:: 256
// Text formatting for short term usage
// each string is valid until it's home buffer is reused
@private fmt_buffers: [FMT_BUFFER_COUNT][FMT_BUFFER_SIZE]u8
@private fmt_buffer_index: u8

get_tmp_buffer :: proc() -> []u8 {
	defer	fmt_buffer_index = (fmt_buffer_index + 1) % FMT_BUFFER_COUNT
	return fmt_buffers[fmt_buffer_index][:]
}
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
get_font_glyph :: proc(font: ^Font, size: ^Font_Size, codepoint: rune) -> (data: ^Glyph_Data, ok: bool) {
	// Try fetching from map
	data, ok = &size.glyphs[codepoint]
	// If the glyph doesn't exist, we create and render it
	if !ok {
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
		data = map_insert(&size.glyphs, codepoint, Glyph_Data({
			image = image,
			src = src,
			offset = {f32(glyph_offset_x), f32(glyph_offset_y) + size.ascent},
			advance = f32((f32(advance) + f32(left_side_bearing)) * size.scale),
		}))
		ok = true
	}
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
				dst: Box = {low = origin + it.offset + it.glyph.offset}
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

paint_aligned_rune :: proc(font: Font_Handle, size: f32, icon: rune, origin: [2]f32, color: Color, align: [2]Alignment) -> [2]f32 {
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
	bounds,
	selection_bounds: Box,
}

paint_interact_text :: proc(origin: [2]f32, widget: ^Widget, agent: ^Typing_Agent, text_info: Text_Info, text_paint_info: Text_Paint_Info, interact_info: Text_Interact_Info, color: Color) -> (res: Text_Interact_Result) {
	assert(widget != nil)
	assert(agent != nil)

	size := measure_text(text_info)
	origin := origin
	res.selection_bounds.low = core.size

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
		res.bounds.high = res.bounds.low
		last_line := it.offset
		// Start iteration
		for {
			if !iterate_text(&it, text_info) {
				at_end = true
			}
			// Get hovered state
			if it.new_line || at_end {
				if it.glyph != nil && hovered_line == line {
					// Left side of glyph
					dist1 := math.abs((origin.x + it.offset.x) - input.mouse_point.x)
					if dist1 < min_dist {
						min_dist = dist1
						hover_index = it.index
					}
				}
				line += 1
				// Check for hover
				line_box: Box = {low = origin + last_line}
				line_box.high = {line_box.low.x + it.line_size.x, origin.y + it.offset.y}
				//paint_box_stroke(line_box, 1, {255, 0, 255, 255})
				if point_in_box(input.mouse_point, line_box) {
					res.hovered = true
				}
				if !at_end {
					update_text_iterator_offset(&it, text_info, text_paint_info)
					last_line = it.offset
				}
			}
			// Update hovered index
			if it.glyph != nil && hovered_line == line {
				// Left side of glyph
				dist1 := math.abs((origin.x + it.offset.x) - input.mouse_point.x)
				if dist1 < min_dist {
					min_dist = dist1
					hover_index = it.index
				}
				if it.new_line || it.next_index >= len(text_info.text) {
					// Right side of glyph
					dist2 := math.abs((origin.x + it.offset.x + it.glyph.advance) - input.mouse_point.x)
					if dist2 < min_dist {
						min_dist = dist2
						hover_index = it.next_index
					}
				}
			}
			// Get the glyph point
			point := origin + {it.offset.x, last_line.y}
			// Paint cursor/selection
			if .Focused in widget.state {
				if agent.length == 0 && !interact_info.read_only {
					if agent.index == it.index {
						// Bar cursor
						box: Box = {{point.x - 1, point.y}, {point.x + 1, point.y + it.size.ascent - it.size.descent}}
						res.selection_bounds.low = linalg.min(res.selection_bounds.low, box.low)
						res.selection_bounds.high = linalg.max(res.selection_bounds.high, box.high)
						if clip, ok := text_paint_info.clip.?; ok {
							box = clamp_box(box, clip)
						}
						paint_box_fill(box, style.color.accent[1])
					}
				} else if it.glyph != nil && it.index >= agent.index && it.index < agent.index + agent.length {
					// Selection
					box: Box = {point, {point.x + it.glyph.advance, point.y + it.size.ascent - it.size.descent}}
					res.selection_bounds.low = linalg.min(res.selection_bounds.low, box.low)
					res.selection_bounds.high = linalg.max(res.selection_bounds.high, box.high)
					if line < line_count {
						box.high.y += it.size.line_gap
					}
					if clip, ok := text_paint_info.clip.?; ok {
						box = clamp_box(box, clip)
					}
					paint_box_fill(box, fade(style.color.accent[1], 0.5))
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
	// Copy
	if .Focused in widget.state {
		if (key_pressed(.C) && (key_down(.Left_Control) || key_down(.Right_Control))) && agent.length > 0 {
			set_clipboard_string(text_info.text[agent.index:][:agent.length])
		}
	}
	// Update selection
	if .Got_Press in widget.state {
		if widget.click_count == 1 {
			// Select the hovered word
			// Move index to the beginning of the hovered word
			for i := min(agent.index, len(text_info.text) - 1); ; i -= 1 {
				if i <= 0 {
					agent.index = 0
					break
				} else if is_seperator(text_info.text[i]) {
					agent.index = i + 1
					break
				}
			}
			// Find length of the word
			for j := agent.index + 1; ; j += 1 {
				if j >= len(text_info.text) - 1 {
					agent.length = len(text_info.text) - agent.index
					break
				} else if is_seperator(text_info.text[j]) {
					agent.length = j - agent.index
					break
				}
			}
		} else if widget.click_count == 2 {
			// Select everything
			agent.index = 0
			agent.anchor = 0
			agent.length = len(text_info.text)
		} else {
			// Normal select
			agent.index = hover_index
			agent.anchor = hover_index
			agent.length = 0
		}
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

Do_Text_Info :: struct {
	text: string,
	align: Text_Align,
	baseline: Text_Baseline,
	color: Maybe(Color),
}
do_text :: proc(info: Do_Text_Info) {
	box := use_next_box() or_else layout_next(current_layout())
	box = shrink_box(box, style.layout.widget_padding)
	origin: [2]f32
	switch info.align {
		case .Left: origin.x = box.low.x
		case .Middle: origin.x = (box.low.x + box.high.x) / 2
		case .Right: origin.x = box.high.x
	}
	switch info.align {
		case .Left: origin.y = box.low.y
		case .Middle: origin.y = (box.low.y + box.high.y) / 2
		case .Right: origin.y = box.high.y
	}
	paint_text(origin, {text = info.text, font = style.font.label, size = style.text_size.label}, {align = info.align, baseline = info.baseline}, info.color.? or_else style.color.base_text[0])
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

		res := paint_interact_text(origin, self, &core.typing_agent, info.text_info, info.paint_info, {read_only = true}, style.color.base_text[1])
		update_widget_hover(self, res.hovered)

		self.layer.content_box = update_bounding_box(self.layer.content_box, res.bounds)
		if .Hovered in self.state {
			core.cursor = .Beam
		}
	}
}
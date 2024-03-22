/*
	TODO: Implement descrete text formatting and painting options
*/

package maui

import "core:runtime"
import "core:os"

import "core:c/libc"
import "core:math"
import "core:math/bits"
import "core:math/linalg"

import "core:fmt"

import "core:strings"
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

get_tmp_builder :: proc() -> strings.Builder {
	buf := get_tmp_buffer()
	return strings.builder_from_bytes(buf)
}
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
	//
	align: Text_Align,
	baseline: Text_Baseline,
	clip: Maybe(Box),
}

Text_Iterator :: struct {
	// Font
	font: ^Font,
	size: ^Font_Size,
	line_limit: Maybe(f32),
	// Current line size
	line_size: [2]f32,
	// Set if `codepoint` is the first rune on a new line
	new_line: bool,
	// Glyph offset
	offset: [2]f32,
	// Last decoded rune 
	last_codepoint,
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
make_text_iterator :: proc(painter: ^Painter, info: Text_Info) -> (it: Text_Iterator, ok: bool) {
	if info.size <= 0 {
		return
	}
	it.font = &painter.fonts[info.font].?
	it.size, ok = get_font_size(painter, it.font, info.size)
	it.line_limit = info.limit.x
	it.line_size.y = it.size.ascent - it.size.descent + it.size.line_gap
	return
}
update_text_iterator_offset :: proc(painter: ^Painter, it: ^Text_Iterator, info: Text_Info) {
	it.offset.x = 0
	#partial switch info.align {
		case .Middle: it.offset.x -= math.floor(measure_next_line(painter, info, it^) / 2)
		case .Right: it.offset.x -= measure_next_line(painter, info, it^)
	}
}
iterate_text_codepoint :: proc(painter: ^Painter, it: ^Text_Iterator, info: Text_Info) -> bool {
	it.last_codepoint = it.codepoint
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
		if glyph, ok := get_font_glyph(painter, it.font, it.size, '•' if info.hidden else it.codepoint); ok {
			it.glyph = glyph
		}
	} else {
		it.glyph = nil
	}
	return true
}
iterate_text :: proc(painter: ^Painter, it: ^Text_Iterator, info: Text_Info) -> (ok: bool) {
	// Update horizontal offset with last glyph
	if it.glyph != nil {
		it.offset.x += it.glyph.advance
	}
	/*
		Pre-paint
			Decode the next codepoint -> Update glyph data -> New line if needed
	*/
	ok = iterate_text_codepoint(painter, it, info)
	// Space needed to fit this glyph/word
	space: f32 = it.glyph.advance if it.glyph != nil else 0
	if !ok {
		// We might need to use the end index
		it.index = it.next_index
		it.glyph = nil
		it.codepoint = 0
	} else {
		// Get the space for the next word if needed
		if (info.wrap == .Word) && (it.next_index >= it.next_word) && (it.codepoint != ' ') {
			for i := it.next_word;true;/**/ {
				c, b := utf8.decode_rune(info.text[i:])
				if c != '\n' {
					if g, ok := get_font_glyph(painter, it.font, it.size, it.codepoint); ok {
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
	}
	// Reset new line state
	it.new_line = false
	// If the last rune was '\n' then this is a new line
	if (it.last_codepoint == '\n') {
		it.new_line = true
	} else {
		// Or if this rune would exceede the limit
		if ( it.line_limit != nil && it.line_size.x + space >= it.line_limit.? ) {
			if info.wrap == .None {
				it.index = it.next_index
				it.offset.y += it.size.ascent - it.size.descent
				ok = false
			} else {
				it.new_line = true
			}
		}
	}	
	// Update vertical offset if there's a new line or if reached end
	if it.new_line {
		it.line_size.x = 0
		it.offset.y += it.size.ascent - it.size.descent + it.size.line_gap
	} else if it.glyph != nil {
		it.line_size.x += it.glyph.advance
	}
	return
}

measure_next_line :: proc(painter: ^Painter, info: Text_Info, it: Text_Iterator) -> f32 {
	it := it
	for iterate_text(painter, &it, info) {
		if it.new_line {
			break
		}
	}
	return it.line_size.x
}
measure_next_word :: proc(painter: ^Painter, info: Text_Info, it: Text_Iterator) -> (size: f32, end: int) {
	it := it
	for iterate_text_codepoint(painter, &it, info) {
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
measure_text :: proc(painter: ^Painter, info: Text_Info) -> [2]f32 {
	size: [2]f32
	if it, ok := make_text_iterator(painter, info); ok {
		for iterate_text(painter, &it, info) {
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
	Load a font from a given file path
*/
load_font :: proc(painter: ^Painter, file_path: string) -> (handle: Font_Handle, success: bool) {
	font: Font
	if file_data, ok := os.read_entire_file(file_path); ok {
		if ttf.InitFont(&font.data, raw_data(file_data), 0) {
			for i in 0..<MAX_FONTS {
				if painter.fonts[i] == nil {
					painter.fonts[i] = font
					handle = Font_Handle(i)
					success = true
					break
				}
			}
		} else {
			fmt.printf("Failed to initialize font '%s'\n", file_path)
		}
	} else {
		fmt.printf("Failed to load font '%s'\n", file_path)
	}
	return
}
/*
	Destroy a font and free it's handle
*/
unload_font :: proc(painter: ^Painter, handle: Font_Handle) {
	if font, ok := &painter.fonts[handle].?; ok {
		destroy_font(font)
		painter.fonts[handle] = nil
	}
}
// Get the data for a given pixel size of the font
get_font_size :: proc(painter: ^Painter, font: ^Font, size: f32) -> (data: ^Font_Size, ok: bool) {
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
get_font_glyph :: proc(painter: ^Painter, font: ^Font, size: ^Font_Size, codepoint: rune) -> (data: ^Glyph_Data, ok: bool) {
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
		image_width, image_height, glyph_offset_x, glyph_offset_y: libc.int
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
			src = add_atlas_image(painter, image) or_else Box{}
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

paint_text_box :: proc(painter: ^Painter, box: Box, info: Text_Info, color: Color) -> [2]f32 {
	origin: [2]f32
	switch info.align {
		case .Left:
		origin.x = box.low.x
		case .Middle:
		origin.x = (box.low.x + box.high.x) / 2
		case .Right:
		origin.x = box.high.x
	}
	switch info.baseline {
		case .Top:
		origin.y = box.low.y
		case .Middle:
		origin.y = (box.low.y + box.high.y) / 2
		case .Bottom:
		origin.y = box.high.y
	}
	return paint_text(painter, origin, info, color)
}
paint_text :: proc(painter: ^Painter, origin: [2]f32, info: Text_Info, color: Color) -> [2]f32 {
	size: [2]f32 
	origin := origin
	if info.baseline != .Top {
		size = measure_text(painter, info)
		#partial switch info.baseline {
			case .Middle: origin.y -= math.floor(size.y / 2) 
			case .Bottom: origin.y -= size.y
		}
	}
	origin = linalg.floor(origin)
	if it, ok := make_text_iterator(painter, info); ok {
		update_text_iterator_offset(painter, &it, info)
		for iterate_text(painter, &it, info) {
			// Reset offset if new line
			if it.new_line {
				update_text_iterator_offset(painter, &it, info)
			}
			// Paint the glyph
			if it.codepoint != '\n' && it.codepoint != ' ' && it.glyph != nil {
				dst: Box = {low = origin + it.offset + it.glyph.offset}
				dst.high = dst.low + (it.glyph.src.high - it.glyph.src.low)
				if clip, ok := info.clip.?; ok {
					paint_clipped_textured_box(painter, painter.texture, it.glyph.src, dst, clip, color)
				} else {
					paint_textured_box(painter, painter.texture, it.glyph.src, dst, color)
				}
			}
			// Update size
			if it.new_line {
				size.x = max(size.x, it.line_size.x)
				size.y += it.line_size.y
			}
		}
		size.y += it.line_size.y
	}
	return size 
}

paint_aligned_rune :: proc(painter: ^Painter, font: Font_Handle, size: f32, icon: rune, origin: [2]f32, color: Color, align: Text_Align, baseline: Text_Baseline) -> [2]f32 {
	font := &painter.fonts[font].?
	font_size, _ := get_font_size(painter, font, size)
	glyph, _ := get_font_glyph(painter, font, font_size, rune(icon))
	icon_size := glyph.src.high - glyph.src.low

	box: Box
	switch align {
		case .Right: 
		box.low.x = origin.x - icon_size.x
		box.high.x = origin.x 
		case .Middle: 
		box.low.x = origin.x - math.floor(icon_size.x / 2) 
		box.high.x = origin.x + math.floor(icon_size.x / 2)
		case .Left: 
		box.low.x = origin.x 
		box.high.x = origin.x + icon_size.x 
	}
	switch baseline {
		case .Bottom: 
		box.low.y = origin.y - icon_size.y
		box.high.y = origin.y 
		case .Middle: 
		box.low.y = origin.y - math.floor(icon_size.y / 2) 
		box.high.y = origin.y + math.floor(icon_size.y / 2)
		case .Top: 
		box.low.y = origin.y 
		box.high.y = origin.y + icon_size.y 
	}
	paint_textured_box(painter, painter.texture, glyph.src, box, color)
	return icon_size
}

paint_clipped_aligned_rune :: proc(painter: ^Painter, font: Font_Handle, size: f32, icon: rune, origin: [2]f32, color: Color, align: [2]Alignment, clip: Box) -> [2]f32 {
	font := &painter.fonts[font].?
	font_size, _ := get_font_size(painter, font, size)
	glyph, _ := get_font_glyph(painter, font, font_size, rune(icon))
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
	paint_clipped_textured_box(painter, painter.texture, glyph.src, box, clip, color)
	return icon_size
}

Tactile_Text_Info :: struct {
	using base: Text_Info,
	focus_selects_all,
	read_only: bool,
}
Tactile_Text_Result :: struct {
	// If a selection or a change was made
	changed: bool,
	// If the text is hovered
	hovered: bool,
	// Text and selection bounds
	bounds,
	selection_bounds: Box,
	// New selection
	selection: Text_Selection,
}
/*
	Paint interactable text
*/
paint_tactile_text :: proc(ui: ^UI, widget: ^Widget, origin: [2]f32, info: Tactile_Text_Info, color: Color) -> Tactile_Text_Result {
	// Initial measurement
	size := measure_text(ui.painter, info)
	origin := origin
	// Prepare result
	using result: Tactile_Text_Result = {
		selection_bounds = {math.F32_MAX, {}},
		selection = ui.scribe.selection,
	}
	// Layer to paint on
	layer := current_layer(ui)
	// Apply baseline if needed
	#partial switch info.baseline {
		case .Middle: origin.y -= size.y / 2 
		case .Bottom: origin.y -= size.y
	}
	// Hovered index
	hover_index: int
	// Paint the text
	if it, ok := make_text_iterator(ui.painter, info); ok {
		// If we've reached the end
		at_end := false
		// Determine hovered line
		line_height := it.size.ascent - it.size.descent + it.size.line_gap
		line_count := int(math.floor(size.y / line_height))
		hovered_line := clamp(int((ui.io.mouse_point.y - origin.y) / line_height), 0, line_count - 1)
		// Current line and column
		line, column: int
		// Keep track of smallest distance to mouse
		min_dist: f32 = math.F32_MAX
		// Get line offset
		update_text_iterator_offset(ui.painter, &it, info)
		// Top left of this line
		line_origin := origin + it.offset
		// Horizontal bounds of the selection on the current line
		line_box_bounds: [2]f32 = {math.F32_MAX, 0}
		// Set bounds
		bounds.low = line_origin
		bounds.high = bounds.low
		// Start iteration
		for {
			// Iterate the iterator
			if !iterate_text(ui.painter, &it, info) {
				at_end = true
			}
			// Get hovered state
			if it.new_line {
				// Allows for highlighting the last glyph in a line
				if hovered_line == line {
					dist1 := math.abs((origin.x + it.offset.x) - ui.io.mouse_point.x)
					if dist1 < min_dist {
						min_dist = dist1
						hover_index = it.index
					}
				}
				// Check if the last line was hovered
				line_box: Box = {line_origin, line_origin + it.line_size}
				if point_in_box(ui.io.mouse_point, line_box) {
					hovered = true
				}
				update_text_iterator_offset(ui.painter, &it, info)
				line += 1
				column = 0
				line_origin = origin + it.offset
			}
			// Update hovered index
			if hovered_line == line {
				// Left side of glyph
				dist1 := math.abs((origin.x + it.offset.x) - ui.io.mouse_point.x)
				if dist1 < min_dist {
					min_dist = dist1
					hover_index = it.index
				}
				if it.glyph != nil && (it.new_line || it.next_index >= len(info.text)) {
					// Right side of glyph
					dist2 := math.abs((origin.x + it.offset.x + it.glyph.advance) - ui.io.mouse_point.x)
					if dist2 < min_dist {
						min_dist = dist2
						hover_index = it.next_index
					}
				}
			}
			// Get the glyph point
			point: [2]f32 = origin + it.offset
			glyph_color := color
			// Get selection info
			if .Focused in (widget.state) {
				if selection.offset == it.index {
					selection.line = line
					selection.column = column
				}
				if it.index >= selection.offset && it.index <= selection.offset + selection.length {
					line_box_bounds = {
						min(line_box_bounds[0], point.x),
						max(line_box_bounds[1], point.x),
					}
				}
				if selection.length > 0 && it.index >= selection.offset && it.index < selection.offset + selection.length {
					glyph_color = ui.style.color.accent_text
				}
			}
			// Paint the glyph
			if it.glyph != nil {
				// Paint the glyph
				dst: Box = {low = point + it.glyph.offset}
				dst.high = dst.low + (it.glyph.src.high - it.glyph.src.low)
				bounds.high = linalg.max(bounds.high, dst.high)
				if clip, ok := info.clip.?; ok {
					paint_clipped_textured_box(ui.painter, ui.painter.texture, it.glyph.src, dst, clip, glyph_color)
				} else {
					paint_textured_box(ui.painter, ui.painter.texture, it.glyph.src, dst, glyph_color)
				}
			}
			// Paint this line's selection
			if (.Focused in widget.state) && (it.index >= len(info.text) || info.text[it.index] == '\n') {
				ui.painter.target = layer.targets[.Background]
				// Draw it if the selection is valid
				if line_box_bounds[1] >= line_box_bounds[0] {
					box: Box = {
						{line_box_bounds[0] - 1, line_origin.y},
						{line_box_bounds[1] + 1, line_origin.y + it.line_size.y},
					}
					selection_bounds = {
						linalg.min(selection_bounds.low, box.low),
						linalg.max(selection_bounds.high, box.high),
					}
					if clip, ok := info.clip.?; ok {
						box = clamp_box(box, clip)
					}
					paint_box_fill(ui.painter, box, ui.style.color.accent)
					line_box_bounds = {math.F32_MAX, 0}
				}
				// Continue painting to the foreground
				ui.painter.target = layer.targets[.Foreground]
			}
			// Break if reached end
			if at_end {
				break
			}
			// Increment column
			column += 1
		}
	}
	
	// These require `hover_index` to be determined
	if .Focused in widget.state {
		if (key_pressed(ui.io, .C) && (key_down(ui.io, .Left_Control) || key_down(ui.io, .Right_Control))) && selection.length > 0 {
			set_clipboard_string(ui.io, info.text[selection.offset:][:selection.length])
		}
	}
	// Update selection
	if .Pressed in (widget.state - widget.last_state) {
		if widget.click_count == 2 {
			// Select everything
			selection.offset = strings.last_index_byte(info.text[:hover_index], '\n') + 1
			ui.scribe.anchor = selection.offset
			selection.length = strings.index_byte(info.text[ui.scribe.anchor:], '\n')
			if selection.length == -1 {
				selection.length = len(info.text) - selection.offset
			}
		} else {
			// Normal select
			selection.offset = hover_index
			ui.scribe.anchor = hover_index
			selection.length = 0
		}
	}
	// Dragging
	if (.Pressed in widget.state) && (widget.click_count < 2) {
		// Selection by dragging
		if widget.click_count == 1 {
			next, last: int
			if hover_index < ui.scribe.anchor {
				last = hover_index if info.text[hover_index] == ' ' else max(0, strings.last_index_any(info.text[:hover_index], " \n") + 1)
				next = strings.index_any(info.text[ui.scribe.anchor:], " \n")
				if next == -1 {
					next = len(info.text) - ui.scribe.anchor
				}
				next += ui.scribe.anchor
			} else {
				last = max(0, strings.last_index_any(info.text[:ui.scribe.anchor], " \n") + 1)
				next = 0 if (hover_index > 0 && info.text[hover_index - 1] == ' ') else strings.index_any(info.text[hover_index:], " \n")
				if next == -1 {
					next = len(info.text) - hover_index
				}
				next += hover_index
			}
			selection.offset = last
			selection.length = next - last
		} else {
			if hover_index < ui.scribe.anchor {
				selection.offset = hover_index
				selection.length = ui.scribe.anchor - hover_index
			} else {
				selection.offset = ui.scribe.anchor
				selection.length = hover_index - ui.scribe.anchor
			}
		}
	}
	return result
}

Text_Box_Info :: struct {
	using generic: Generic_Widget_Info,
	text_info: union {
		Text_Info,
		Tactile_Text_Info,
	},
	color: Maybe(Color),
}
Text_Box_Result :: struct {
	using generic: Generic_Widget_Result,
	selection: [2]int,
}
text_box :: proc(ui: ^UI, info: Text_Box_Info, loc := #caller_location) -> Text_Box_Result {
	self, generic_result := get_widget(ui, info, loc)
	result: Text_Box_Result = {
		generic = generic_result,
	}
	self.box = layout_next(current_layout(ui))
	text_info := info.text_info.(Text_Info) or_else info.text_info.(Tactile_Text_Info).base
	origin: [2]f32
	switch text_info.align {
		case .Left: origin.x = self.box.low.x
		case .Middle: origin.x = (self.box.low.x + self.box.high.x) / 2
		case .Right: origin.x = self.box.high.x
	}
	switch text_info.baseline {
		case .Top: origin.y = self.box.low.y
		case .Middle: origin.y = (self.box.low.y + self.box.high.y) / 2
		case .Bottom: origin.y = self.box.high.y
	}
	color := info.color.? or_else ui.style.color.text[0]
	switch text_info in info.text_info {
		case Tactile_Text_Info: paint_tactile_text(ui, self, origin, text_info, color)
		case Text_Info: paint_text(ui.painter, origin, text_info, color)
	}
	return result
}
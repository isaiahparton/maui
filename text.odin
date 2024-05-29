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

import "vendor:nanovg"
import "vendor:fontstash"

TEXT_BREAK :: "..."

Font_Handle :: int

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

Text_Interact_Info :: struct {
	text: string,
	focus_selects_all,
	read_only: bool,
}
Text_Interact_Result :: struct {
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
text_interactive :: proc(ui: ^UI, widget: ^Widget, origin: [2]f32, info: Text_Interact_Info) -> Text_Interact_Result {
	using nanovg
	result: Text_Interact_Result
	selection: Text_Selection
	hover_index: int

	state := __getState(ui.ctx)
	scale := __getFontScale(state) * ui.ctx.devicePxRatio
	invscale := f32(1.0) / scale
	is_flipped := __isTransformFlipped(state.xform[:])

	if state.fontId == -1 {
		return {}
	}

	fs := &ui.ctx.fs
	fontstash.SetSize(fs, state.fontSize * scale)
	fontstash.SetSpacing(fs, state.letterSpacing * scale)
	fontstash.SetBlur(fs, state.fontBlur * scale)
	fontstash.SetAlignHorizontal(fs, state.alignHorizontal)
	fontstash.SetAlignVertical(fs, state.alignVertical)
	fontstash.SetFont(fs, state.fontId)

	cverts := max(2, len(info.text)) * 6 // conservative estimate.
	verts := __allocTempVerts(ui.ctx, cverts)
	nverts: int

	iter := fontstash.TextIterInit(fs, origin.x * scale, origin.y * scale, info.text)
	prev_iter := iter
	q: fontstash.Quad
	// Text iteration using fontstash
	for fontstash.TextIterNext(&ui.ctx.fs, &iter, &q) {
		c: [4 * 2]f32
		
		if iter.previousGlyphIndex == -1 { // can not retrieve glyph?
			if nverts != 0 {
				__renderText(ui.ctx, verts[:])
				nverts = 0
			}

			if !__allocTextAtlas(ui.ctx) {
				break // no memory :(
			}

			iter = prev_iter
			fontstash.TextIterNext(fs, &iter, &q) // try again
			
			if iter.previousGlyphIndex == -1 {
				// still can not find glyph?
				break
			} 
		}
		
		prev_iter = iter
		if is_flipped {
			q.y0, q.y1 = q.y1, q.y0
			q.t0, q.t1 = q.t1, q.t0
		}

		// Transform corners.
		TransformPoint(&c[0], &c[1], state.xform, q.x0 * invscale, q.y0 * invscale)
		TransformPoint(&c[2], &c[3], state.xform, q.x1 * invscale, q.y0 * invscale)
		TransformPoint(&c[4], &c[5], state.xform, q.x1 * invscale, q.y1 * invscale)
		TransformPoint(&c[6], &c[7], state.xform, q.x0 * invscale, q.y1 * invscale)

		// Create triangles
		if nverts + 6 <= cverts {
			verts[nverts+0] = {c[0], c[1], q.s0, q.t0}
			verts[nverts+1] = {c[4], c[5], q.s1, q.t1}
			verts[nverts+2] = {c[2], c[3], q.s1, q.t0}
			verts[nverts+3] = {c[0], c[1], q.s0, q.t0}
			verts[nverts+4] = {c[6], c[7], q.s0, q.t1}
			verts[nverts+5] = {c[4], c[5], q.s1, q.t1}
			nverts += 6
		}

		// Get selection info
		/*if .Focused in (widget.state) {
			if selection.offset == it.index {
				selection.line = line
				selection.column = column
			}
			if it.index >= selection.offset && it.index <= selection.offset + selection.length {
				line_box_bounds = {
					min(line_box_bounds[0], iter),
					max(line_box_bounds[1], point.x),
				}
			}
			if selection.length > 0 && it.index >= selection.offset && it.index < selection.offset + selection.length {
				glyph_color = ui.style.color.accent_text
			}
		}*/

		// Paint this line's selection
		/*if (.Focused in widget.state) && (it.index >= len(info.text) || info.text[it.index] == '\n') {
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

				nanovg.BeginPath(ui.ctx)
				DrawBox(ctx, box)
				nanovg.FillColor(ui.ctx, ui.style.color.accent)
				nanovg.Fill(ui.ctx)

				line_box_bounds = {math.F32_MAX, 0}
			}
		}*/
	}
	ui.ctx.textureDirty = true
	__renderText(ui.ctx, verts[:nverts])
	// These require `hover_index` to be determined
	/*if .Focused in widget.state {
		if (key_pressed(ui.io, .C) && (key_down(ui.io, .Left_Control) || key_down(ui.io, .Right_Control))) && selection.length > 0 {
			set_clipboard_string(ui.io, info.text[selection.offset:][:selection.length])
		}
	}*/
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
		Text_Interact_Result,
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
	self.box = next_box(ui)
	/*text_info := info.text_info.(Text_Info) or_else info.text_info.(Text_Interact_Result).base
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
		case Text_Interact_Result: paint_tactile_text(ui, self, origin, text_info, color)
		case Text_Info: paint_text(ui.painter, origin, text_info, color)
	}*/
	return result
}
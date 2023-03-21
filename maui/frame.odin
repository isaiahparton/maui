package maui

FrameOption :: enum {
	noScrollX,
	noScrollY,
	noClip,
}
FrameOptions :: bit_set[FrameOption]
FrameData :: struct {
	body: Rect,
	scroll, space: Vec2,
	options: FrameOptions,
}

GetCurrentFrame :: proc() -> ^FrameData {
	return &ctx.frames[ctx.frameIndex]
}

PushFrame :: proc(rect: Rect, options: FrameOptions, loc := #caller_location) -> bool {
	id := HashId(loc)
	index, ok := ctx.frameMap[id]
	if !ok {
		for i in 0..<MAX_FRAMES {
			if !ctx.frameExists[i] {
				ctx.frames[i] = {}
				index = i32(i)
				break
			}
			if i == MAX_FRAMES - 1 {
				return false
			}
		}
	}

	ctx.frameIndex = index
	frame := &ctx.frames[index]
	frame.options += options
	frame.body = rect

	PushLayout(rect)

	return true
}
PopFrame :: proc() {
	PopLayout()
}

@(deferred_out=_Frame)
Frame :: proc(options: FrameOptions, loc := #caller_location) -> (ok: bool) {
	return PushFrame(GetNextRect(), options, loc)
}
@private _Frame :: proc(ok: bool) {
	if ok {
		PopFrame()
	}
}
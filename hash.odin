package maui

import "core:runtime"

Id :: u32

FNV1A64_OFFSET_BASIS :: 0xcbf29ce484222325
FNV1A64_PRIME :: 0x00000100000001B3
fnv64a :: proc(data: []byte, seed: u64) -> u64 {
	h: u64 = seed;
	for b in data {
		h = (h ~ u64(b)) * FNV1A64_PRIME;
	}
	return h;
}
FNV1A32_OFFSET_BASIS :: 0x811c9dc5
FNV1A32_PRIME :: 0x01000193
fnv32a :: proc(data: []byte, seed: u32) -> u32 {
	h: u32 = seed;
	for b in data {
		h = (h ~ u32(b)) * FNV1A32_PRIME;
	}
	return h;
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
	hash := ctx.idStack[ctx.idCount - 1] if ctx.idCount > 0 else FNV1A32_OFFSET_BASIS
	return hash ~ (Id(num) * FNV1A32_PRIME)
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
	return fnv32a(bytes, ctx.idStack[ctx.idCount - 1] if ctx.idCount > 0 else FNV1A32_OFFSET_BASIS)
}
HashIdFromLoc :: proc(loc: runtime.Source_Code_Location) -> Id {
	hash := HashIdFromBytes(transmute([]byte)loc.file_path)
	hash = hash ~ (Id(loc.line) * FNV1A32_PRIME)
	hash = hash ~ (Id(loc.column) * FNV1A32_PRIME)
	return hash
}

@private
_PushId :: proc(id: Id) {
	assert(ctx.idCount < ID_STACK_SIZE, "PushId() id stack is full!")
	ctx.idStack[ctx.idCount] = id
	ctx.idCount += 1
}
PushIdFromInt :: proc(num: int) {
	_PushId(HashIdFromInt(num))
}
PushIdFromString :: proc(str: string) {
	_PushId(HashIdFromString(str))
}
PushIdFromOtherId :: proc(id: Id) {
	_PushId(HashIdFromInt(int(id)))
}
PushId :: proc {
	PushIdFromInt,
	PushIdFromString,
	PushIdFromOtherId,
}

PopId :: proc() {
	assert(ctx.idCount > 0, "PopId() id stack already empty!")
	ctx.idCount -= 1
}
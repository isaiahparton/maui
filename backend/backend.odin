package backend

Render_API :: enum {
	OpenGL,
	Vulkan,
}

Platform_API :: enum {
	GLFW,
	SDL,
	Win32,
}

Platform_Renderer_Interface :: struct {
	render_api: Render_API,
	platform_api: Platform_API,
	screen_size: [2]i32,
}
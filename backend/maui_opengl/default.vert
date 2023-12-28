#version 330 core
in vec2 Position;
in vec2 UV;
in vec4 Color;
uniform mat4 ProjMtx;
out vec2 Frag_UV;
out vec4 Frag_Color;
out vec2 Bg_UV;
void main()
{	
	gl_Position = ProjMtx * vec4(Position.xy, 0.0, 1.0);
	Bg_UV = gl_Position.xy;
	Frag_UV = UV;
	Frag_Color = Color;
}
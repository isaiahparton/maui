#version 330 core
in vec2 Position;
in vec2 UV;
in vec4 Color;
uniform mat4 ProjMtx;
uniform float Depth;
out vec2 Frag_UV;
out vec4 Frag_Color;
void main()
{	
	gl_Position = ProjMtx * vec4(Position.xy, Depth, 1.0);
	Frag_UV = UV;
	Frag_Color = Color;
}
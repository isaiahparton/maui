#version 330 core
in vec2 Frag_UV;
in vec4 Frag_Color;
out vec4 Out_Color;
uniform sampler2D Texture;
void main()
{
	vec4 Tex_Color = texture(Texture, Frag_UV);
	Out_Color = Frag_Color * Tex_Color;
}
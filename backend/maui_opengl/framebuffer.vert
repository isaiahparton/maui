#version 330 core

layout (location = 0) in vec2 inPos;
layout (location = 1) in vec2 inTexCoords;

uniform float srcScale;
uniform float dstScale;

out vec2 TexCoords;

void main()
{
    vec2 pos = -1.0 + (inPos + 1.0) * dstScale;
    gl_Position = vec4(pos.x, pos.y, 0.0, 1.0); 
    TexCoords = inTexCoords * srcScale;
}  
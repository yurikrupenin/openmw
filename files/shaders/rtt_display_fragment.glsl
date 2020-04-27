#version 330

uniform sampler2DRect textureID0;

in vec2 texCoords;
out vec4 target;

void main(void)
{
    target = vec4(texture( textureID0, texCoords.st ).rgb, 1);
}
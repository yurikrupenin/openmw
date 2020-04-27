#version 330

layout(location = 0) in vec4 osg_Vertex;
layout(location = 1) in vec3 osg_Normal;
layout(location = 2) in vec4 osg_Color;
layout(location = 3) in vec4 osg_MultiTexCoord0;

uniform mat4 osg_ModelViewProjectionMatrix;

out vec2 texCoords;

void main(void)
{
    texCoords = osg_MultiTexCoord0.st;
    gl_Position = osg_ModelViewProjectionMatrix * osg_Vertex;
}
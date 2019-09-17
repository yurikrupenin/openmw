
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 3) in vec4 aTexCoords;

out vec2 TexCoords;
out vec3 WorldPos;
out vec3 Normal;

uniform mat4 osg_ModelViewProjectionMatrix;
uniform mat4 osg_ModelViewMatrix;
uniform mat4 osg_ViewMatrixInverse;
uniform mat3 osg_NormalMatrix;
uniform mat4 osg_ViewMatrix;



void main()
{
    TexCoords = aTexCoords.xy;
    mat4 model = osg_ViewMatrixInverse * osg_ModelViewMatrix;
	WorldPos = vec3(model * vec4(aPos, 1.0)); 
	Normal = mat3(transpose(inverse(model))) * aNormal;
	gl_Position = osg_ModelViewProjectionMatrix * vec4(aPos, 1.0);
}
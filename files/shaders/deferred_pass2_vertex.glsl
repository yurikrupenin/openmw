#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 3) in vec4 aTexCoords;
layout (location = 4) in vec4 aTangentSpace;

in vec3 osg_Normal;
in vec4 osg_Vertex;

uniform mat4 osg_ModelViewProjectionMatrix;
uniform mat3 osg_NormalMatrix;
uniform mat4 osg_ViewMatrixInverse;
uniform mat4 osg_ModelViewMatrix;


out vec2 texCoords;
out vec4 pos_worldspace;
out vec3 n_worldspace;
out vec3 t_worldspace;
out vec3 b_worldspace;

void main()
{
    gl_Position = osg_ModelViewProjectionMatrix * vec4(aPos, 1.0);

    // Pass the texture coordinate further to the fragment shader.
    texCoords = aTexCoords.xy;

    mat4 modelMatrix = osg_ViewMatrixInverse * osg_ModelViewMatrix;
    mat3 modelMatrix3x3 = mat3(modelMatrix);


    // Convert everything to World space.
    // Position.
    pos_worldspace = modelMatrix * vec4(aPos, 1.0);

    // Normal.
    n_worldspace   = modelMatrix3x3 * osg_Normal;

    // Tangent.
    t_worldspace   = modelMatrix3x3 * aTangentSpace.xyz;
    
    // Bitangent / binormal.
    b_worldspace   = cross(n_worldspace, t_worldspace);
}

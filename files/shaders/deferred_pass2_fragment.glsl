#version 330 core

const float normalScale  = 1.0;

out vec4 FragColor[4];
in vec2 texCoords;
in vec4 pos_worldspace;
in vec3 n_worldspace;
in vec3 t_worldspace;
in vec3 b_worldspace;
    

uniform sampler2D diffuseMap;
uniform sampler2D normalMap;
uniform sampler2D specularMap;
uniform sampler2D roughnessMap;

vec3 getNormalFromMap()
{
    vec3 tangentNormal = texture(normalMap, texCoords).xyz * 2.0 - 1.0;

    vec3 Q1 = dFdx(pos_worldspace.xyz);
    vec3 Q2 = dFdy(pos_worldspace.xyz);
    vec2 st1 = dFdx(texCoords);
    vec2 st2 = dFdy(texCoords);

    vec3 N = normalize(n_worldspace);
    vec3 T = normalize(Q1 * st2.t - Q2 * st1.t);
    vec3 B = -normalize(cross(N, T));
    mat3 TBN = mat3(T, B, N);

    return normalize(TBN * tangentNormal * vec3(normalScale, normalScale, 1.0));
}
void main()
{

	FragColor[0] = texture(diffuseMap, texCoords).rgba;

    vec3 nn = vec3(1.0);

    // Convert [0; 1] range to [-1; 1].
    //nn = 2.0 * texture2D(normalMap, texCoords.xy).xyz - vec3(1.0);
    // Convert Tangent space to World space with TBN matrix.
    //FragColor[1] = vec4(nn.x * t_worldspace + nn.y * b_worldspace + nn.z * n_worldspace, 1.0);

    FragColor[1] = vec4(getNormalFromMap(), 1.0);

    FragColor[2] = texture(roughnessMap, texCoords).rgba;

    FragColor[3] = vec4(pos_worldspace.xyz, pos_worldspace.z);
}
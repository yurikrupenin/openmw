#version 330 core
out vec4 FragColor;
in vec2 TexCoords;
in vec3 WorldPos;
in vec3 Normal;

// material parameters
uniform sampler2D diffuseMap;
uniform sampler2D normalMap;
uniform sampler2D specularMap;
uniform sampler2D roughnessMap;

uniform float ao;



struct PointLight {
    vec3 position;
    vec3 color;
};
#define NR_POINT_LIGHTS 64
uniform PointLight pointLights[NR_POINT_LIGHTS];

uniform vec3 camPos;

const float PI = 3.14159265359;
const float normalScale = 3.0;
const float ambientLight = 0.02;
const float roughnessMultiplier = 0.65;
const float attentuationRate = 0.8;
// ----------------------------------------------------------------------------

vec3 getNormalFromMap()
{
    vec3 tangentNormal = texture(normalMap, TexCoords).xyz * 2.0 - 1.0;

    vec3 Q1  = dFdx(WorldPos);
    vec3 Q2  = dFdy(WorldPos);
    vec2 st1 = dFdx(TexCoords);
    vec2 st2 = dFdy(TexCoords);

    vec3 N   = normalize(Normal);
    vec3 T  = normalize(Q1*st2.t - Q2*st1.t);
    vec3 B  = -normalize(cross(N, T));
    mat3 TBN = mat3(T, B, N);

    return normalize(TBN * tangentNormal * vec3(normalScale, normalScale, 1.0));
}


vec3
calcDiffuse(vec3 diffuseColor)
{
  return diffuseColor / PI;
}


float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness*roughness;
    float a2 = a*a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / max(denom, 0.001); // prevent divide by zero for roughness=0.0 and NdotH=1.0
}
// ----------------------------------------------------------------------------
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}
// ----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}
// ----------------------------------------------------------------------------
void main()
{	
    vec3 N = getNormalFromMap();
    vec3 V = normalize(camPos - WorldPos);

    float roughness = texture(roughnessMap, TexCoords).r * roughnessMultiplier;

    vec3 specular = pow(texture(specularMap, TexCoords).rgb, vec3(2.2)) * 2;
    clamp(specular, 0.0, 1.0);

    roughness = max(0.0, roughness);

    vec4 diffuse = texture(diffuseMap, TexCoords).rgba;

    vec3 albedo = pow(diffuse.rgb, vec3(2.2));

    vec3 Cdiff = albedo.rgb * (1.0 - specular);

    vec3 F0 = specular;

    // reflectance equation
    vec3 Lo = vec3(0.0);
    for(int i = 0; i < NR_POINT_LIGHTS; ++i) 
    {
        // HACK: skip insignificant lights [1]
        if (pointLights[i].color.r < 0.1 && pointLights[i].color.g < 0.1 && pointLights[i].color.b < 0.1)
            continue;

        // calculate per-light radiance
        vec3 L = normalize(pointLights[i].position - WorldPos);
        vec3 H = normalize(V + L);
        float distance = length(pointLights[i].position - WorldPos);
        float attenuation = attentuationRate / (distance * distance);
        vec3 radiance = (pointLights[i].color) * attenuation;

        // HACK: skip insignificant lights [2]
        if (radiance.r < 0.01 && radiance.g < 0.01 && radiance.b < 0.01)
            continue;

        // Cook-Torrance BRDF
        float NDF = DistributionGGX(N, H, roughness);   
        float G   = GeometrySmith(N, V, L, roughness);      
        vec3 F    = fresnelSchlick(clamp(dot(H, V), 0.0, 1.0), F0);
           
        vec3 nominator    = NDF * G * F;
        float denominator = 4 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0);
        vec3 Fspec = nominator / max(denominator, 0.001); // prevent divide by zero for NdotV=0.0 or NdotL=0.0
        vec3 Fdiff = (1.0 - F) * calcDiffuse(Cdiff);

        // scale light by NdotL
        float NdotL = max(dot(N, L), 0.0);        

        // add to outgoing radiance Lo
        Lo += radiance * NdotL * (Fdiff + Fspec);
    }   
    
    // ambient lighting calculation
    // HACK: grab it from cell's ambient lighting
    vec3 ambient = vec3(ambientLight) * albedo;

    vec3 color = ambient + Lo;

    // HDR tonemapping
    color = color / (color + vec3(1.0));
    
    // gamma correct
    color = pow(color, vec3(1.0/2.2)); 

    FragColor = vec4(color, diffuse.a);

}
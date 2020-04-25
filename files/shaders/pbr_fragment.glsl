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



struct PointLight {
    vec3 position;
    vec3 color;
};
#define NR_POINT_LIGHTS 32
uniform PointLight pointLights[NR_POINT_LIGHTS];

uniform vec3 camPos;

const float PI = 3.14159265359;
const float normalScale = 1.0;
const float ambientLight = 0.02;
const float roughnessMultiplier = 1.0;
const float attenuationRate = 1.0;
float glossMultiplier = 1.0;



float maxvec(vec3 v)
{
    return max(max(v.x, v.y), v.z);
}

vec3 lerp(vec3 x, vec3 y, vec3 s)
{
  return x + s * (y - x);
}

vec3 lerp(vec3 x, vec3 y, float s)
{
  return x + s * (y - x);
}

float lerp(float x, float y, float s)
{
  return x + s * (y - x);
}


float adjustRoughness(float roughness, vec3 normal ) {
    float normalLen = length(normal*2.0-1.0);
    if ( normalLen < 1.0) {
        float normalLen2 = normalLen * normalLen;
        float kappa = ( 3.0 * normalLen -  normalLen2 * normalLen )/( 1.0 - normalLen2 );
        return min(1.0, sqrt( roughness * roughness + 0.5/kappa ));
    }
    return roughness;
}


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


vec3 calcDiffuse(vec3 diffuseColor)
{
  return diffuseColor / PI;
}


float microfacetDist(float NdH, float roughness)
{
    float a, aa, f;
    a = roughness * roughness;
    aa = a * a;

    f = NdH * NdH * (aa - 1.0) + 1.0;

    return aa / max((PI * f * f), 0.0001); // prevent divide by zero
}


float geomOcclusion(float NdL, float NdV, float roughness)
{
  float k, Gv, Gl;

  k  = pow(roughness + 1.0, 2.0) / 8.0;
  Gv = NdV / lerp(k, 1.0, NdV);
  Gl = NdL / lerp(k, 1.0, NdL);

  return Gv * Gl;
}


vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}


void main()
{	
    vec3 N = getNormalFromMap();
    vec3 V = normalize(camPos - WorldPos);

    float roughness = texture(roughnessMap, TexCoords).r * roughnessMultiplier;

    roughness = adjustRoughness(roughness, texture(normalMap, TexCoords).xyz);

    vec3 specular = pow(texture(specularMap, TexCoords).rgb, vec3(2.2)) * glossMultiplier;

    vec4 diffuse = texture(diffuseMap, TexCoords).rgba;

    vec3 albedo = pow(diffuse.rgb, vec3(2.2));

    vec3 Cdiff = albedo * (1.0 - clamp(specular, vec3(0.0), vec3(1.0)));

    // reflectance equation
    vec3 Lo = vec3(0.0);

    for(int i = 0; i < NR_POINT_LIGHTS; ++i) 
    {
        // calculate per-light radiance
        vec3 L = normalize(pointLights[i].position - WorldPos);
        vec3 H = normalize(V + L);

        float NdV   =  clamp(dot(N, V), 0.001, 1.0);
        float NdL   =  clamp(dot(N, L), 0.001, 1.0);
        float NdH   =  clamp(dot(N, H), 0.0,   1.0);
        float LdH   =  clamp(dot(L, H), 0.0,   1.0);
        float VdH   =  clamp(dot(V, H), 0.0,   1.0);

        float distance = length(pointLights[i].position - WorldPos);
        float attenuation = attenuationRate / (distance * distance);
        vec3 radiance = (pointLights[i].color) * attenuation;

  
        float D = microfacetDist(NdH, roughness);    
        float G = geomOcclusion(NdL, NdV, roughness);

        vec3 F    = fresnelSchlick(VdH, specular);
           
        vec3 nominator    = F * G * D;
        float denominator = 4.0 * NdL * NdV;
        vec3 Fspec = nominator / denominator;
        vec3 Fdiff = (1.0 - F) * calcDiffuse(Cdiff);

        // add to outgoing radiance Lo
        Lo += radiance * NdL * (Fdiff + Fspec);
    }   
    
    // ambient lighting calculation
    // HACK: grab it from cell's ambient lighting
    vec3 ambient = vec3(ambientLight) * albedo;

    vec3 color = ambient + Lo;

    // HDR tonemapping
    color = color / (color + vec3(1.0));
    
    // gamma correct
    color = pow(color, vec3(1.0/2.2)); 

    clamp(color, 0.0, 1.0);

    FragColor = vec4(color, diffuse.a);

}
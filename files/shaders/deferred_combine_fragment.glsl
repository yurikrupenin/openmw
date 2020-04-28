#version 330


struct PointLight {
    vec4 position;
    vec4 color;
};

uniform uint lightNumber;
uniform PointLight pointLights[32];

uniform vec3 cameraPos;

const float gamma = 2.2;
const float PI = 3.14159265359;
const float normalScale = 10.0;
const float ambientLight = 0.12;
const float roughnessMultiplier = 0.7;
const float attenuationRate = 1;
float glossMultiplier = 1.0;

uniform sampler2DRect diffuseMap;
uniform sampler2DRect normalMap;
uniform sampler2DRect roughnessMap;
uniform sampler2DRect specularMap;
uniform sampler2DRect posMap;
uniform sampler2DRect texCoordMap;

in vec2 texCoords;
out vec4 fragColor;

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

float adjustRoughness(float roughness, vec3 normal)
{
    float normalLen = length(normal*2.0-1.0);
    if ( normalLen < 1.0) {
        float normalLen2 = normalLen * normalLen;
        float kappa = ( 3.0 * normalLen -  normalLen2 * normalLen )/( 1.0 - normalLen2 );
        return min(1.0, sqrt( roughness * roughness + 0.5/kappa ));
    }
    return roughness;
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



void main(void)
 {
    vec3 worldPos = texture2DRect(posMap, texCoords).xyz;

    vec3 N = texture2DRect(normalMap, texCoords).xyz;
    vec3 V = normalize(cameraPos - texture2DRect(posMap, texCoords).xyz);
    float roughness = texture2DRect(roughnessMap, texCoords).r * roughnessMultiplier;

    roughness = adjustRoughness(roughness, texture2DRect(normalMap, texCoords).xyz);

    vec3 specular = pow(texture2DRect(specularMap, texCoords).rgb, vec3(gamma)) * glossMultiplier;

    vec4 diffuse = texture2DRect(diffuseMap, texCoords).rgba;
    vec3 albedo = pow(diffuse.rgb, vec3(gamma));

    vec3 Cdiff = albedo * (1.0 - clamp(specular, vec3(0.0), vec3(1.0)));

    // reflectance equation
    vec3 Lo = vec3(0.0);

    //TODO: Per-light computation

    for(uint i = 0u; i < lightNumber; ++i) 
    {
        // calculate per-light radiance
        vec3 L = normalize(pointLights[i].position.xyz - worldPos);
        vec3 H = normalize(V + L);

        float NdV   =  clamp(dot(N, V), 0.001, 1.0);
        float NdL   =  clamp(dot(N, L), 0.001, 1.0);
        float NdH   =  clamp(dot(N, H), 0.0,   1.0);
        float LdH   =  clamp(dot(L, H), 0.0,   1.0);
        float VdH   =  clamp(dot(V, H), 0.0,   1.0);

        float distance = length(pointLights[i].position.xyz - worldPos);
        float attenuation = attenuationRate / (distance * distance);

        vec3 radiance = pointLights[i].color.rgb * attenuation * 30000.0f;

        float D = microfacetDist(NdH, roughness);    
        float G = geomOcclusion(NdL, NdV, roughness);

        vec3 F = fresnelSchlick(VdH, specular);
           
        vec3 nominator    = F * G * D;
        float denominator = 4.0 * NdL * NdV;
        vec3 Fspec = nominator / denominator;
        vec3 Fdiff = (1.0 - F) * calcDiffuse(Cdiff);

        // add to outgoing radiance Lo
        Lo += radiance * NdL * (Fdiff + Fspec);

    }

    // Ambient lighting colculation
    // HACK: grab it from cell's ambient lighting
    vec3 ambient = vec3(ambientLight) * albedo;
                                
    vec3 color = ambient + Lo;
    //HDR tonemapping
    color = color / (color + vec3(1.0));

    // gamma correct
    color = pow(color, vec3(1.0/gamma));
            
    clamp(color, 0.0, 1.0);

    fragColor = vec4(color, diffuse.a);
                         
}

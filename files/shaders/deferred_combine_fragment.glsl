#version 330

const float gamma = 2.2;
const float roughnessMultiplier = 1.0;
const float glossMultiplier = 1.0;
const float ambientLight = 4.13;

uniform sampler2DRect diffuseMap;
uniform sampler2DRect normalMap;
uniform sampler2DRect specularMap;
uniform sampler2DRect roughnessMap;

in vec2 texCoords;
out vec4 fragColor;

                               

void main(void)
 {
    float roughness = texture2DRect(roughnessMap, texCoords).r * roughnessMultiplier;

    //TODO: Adjust roughness!

    vec3 specular = pow(texture2DRect(specularMap, texCoords).rgb, vec3(gamma)) * glossMultiplier;

    vec4 diffuse = texture2DRect(diffuseMap, texCoords).rgba;
    vec3 albedo = pow(diffuse.rgb, vec3(gamma));

    vec3 Lo = vec3(0.0);

    //TODO: Per-light computation

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

//
//  ABZA Shader: glowing ores
//

#include "/abza/OreHosts.glsl"

// Emission for one ore texel: texels that differ from the host stone's colour glow, the stone around them doesn't
float abzaOreGlow(vec3 albedo, int material) {
    vec3 host = abzaOreHostColor(material);
    float luma = dot(albedo, vec3(1.0 / 3.0));
    float hostLuma = dot(host, vec3(1.0 / 3.0));
    float chromaDifference = length((albedo - luma) - (host - hostLuma));
    float lumaDifference = max(abs(luma - hostLuma) - 0.12, 0.0);
    return smoothstep(0.15, 0.4, chromaDifference * 2.5 + lumaDifference * 1.5) * GLOWING_ORE_STRENGTH;
}

//
//  ABZA Shader: glowing ores
//

#include "/abza/OreHosts.glsl"

// Glow mask for one ore texel from its texture colour: texels that differ from the host stone's colour glow, the stone around them doesn't
float abzaOreMask(vec3 textureColor, int material) {
    vec3 host = abzaOreHostColor(material);
    float luma = dot(textureColor, vec3(1.0 / 3.0));
    float hostLuma = dot(host, vec3(1.0 / 3.0));
    float chromaDifference = length((textureColor - luma) - (host - hostLuma));
    float lumaDifference = max(abs(luma - hostLuma) - 0.12, 0.0);
    return smoothstep(0.15, 0.4, chromaDifference * 2.5 + lumaDifference * 1.5);
}

// Ore glow on a terrain texel whose albedo is texture colour times vertex colour: the mask is tested on the texture colour, and glowing texels drop the vertex colour's corner shading
void abzaOreGlow(inout GbufferData data, vec3 vertexColor, int material) {
    vec3 textureColor = data.albedo.rgb / max(vertexColor, vec3(1e-3));
    float mask = abzaOreMask(textureColor, material);
    data.albedo.rgb = mix(data.albedo.rgb, textureColor, mask);
    data.emissive = max(data.emissive, mask * GLOWING_ORE_STRENGTH);
}

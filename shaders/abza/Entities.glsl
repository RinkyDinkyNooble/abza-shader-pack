//
//  ABZA Shader: entity emission and texture coordinates for history
//

// 1 for ETF's emissive texture overlays (resource packs' _e.png textures), which ETF draws with block light 242;
// vanilla light reaches 240 at most. blockLight is the block-light coordinate divided by 240 (Textured.vert).
float abzaETFEmissive(float blockLight) {
    return float(blockLight > 241.0 / 240.0);
}

// True for shadow-style decals that mods draw over blocks with the entity shadow render type (Zombie Awareness blood):
// translucent vertex colour at full light 240/240. Textured.frag discards them.
bool abzaEntityDecal(float vertexAlpha, vec2 lightmap) {
    return vertexAlpha < 0.999 && all(greaterThan(lightmap, vec2(239.5 / 240.0))) && all(lessThan(lightmap, vec2(240.5 / 240.0)));
}

// colortex11 value of an entity fragment: its texture coordinate wrapped 16 times across the texture (xy) and that value's change per pixel (zw, above 0)
vec4 abzaEntityCoord(vec2 coord) {
    return vec4(fract(coord * 16.0), fwidth(coord) * 16.0 + 1.0 / 65535.0);
}

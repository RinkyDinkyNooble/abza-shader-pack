//
//  ABZA Shader: where rain reaches, from Shaders Companion's rain cover (the mod's API.md, "Rain cover", protocol 1):
//  Minecraft's rain heightmap around the camera, so surfaces under glass and other see-through roofs stay dry. Without
//  the mod, the sky-light estimate alone decides. The same heightmap repairs sky light under open sky.
//

#ifndef ABZA_RAIN_COVER_GLSL
#define ABZA_RAIN_COVER_GLSL

uniform sampler2D scRainCover;

// True when the mod writes the rain cover (without it, Oculus binds the 16 x 16 missing texture)
bool abzaRainCoverReady() {
    return textureSize(scRainCover, 0) == ivec2(512, 513)
        && texelFetch(scRainCover, ivec2(0, 512), 0).r == 4242.0 && texelFetch(scRainCover, ivec2(1, 512), 0).r == 1.0;
}

// 1 where rain reaches a block column's surfaces at height y, 0 below its roof; unknown when the column isn't loaded
float abzaRainColumnOpen(ivec2 column, float y, float unknown) {
    float texel = texelFetch(scRainCover, column & 511, 0).r;
    int v = int(texel);
    int tag = ((column.x >> 9) & 15) | (((column.y >> 9) & 15) << 4);
    if (texel < 0.0 || (v >> 12) != tag) {
        return unknown;
    }
    return step(float((v & 4095) - 2048) - 0.5, y);
}

// Share of the four nearest columns open above a point pushed off the surface along its world-space normal (bilinear),
// so side faces read the column in front of them
float abzaRainColumnsOpen(vec3 worldPos, vec3 worldNormal, float unknown) {
    vec3 p = worldPos + worldNormal * 0.05;
    vec2 cell = p.xz - 0.5;
    ivec2 base = ivec2(floor(cell));
    vec2 f = cell - vec2(base);
    return mix(
        mix(abzaRainColumnOpen(base, p.y, unknown), abzaRainColumnOpen(base + ivec2(1, 0), p.y, unknown), f.x),
        mix(abzaRainColumnOpen(base + ivec2(0, 1), p.y, unknown), abzaRainColumnOpen(base + ivec2(1, 1), p.y, unknown), f.x),
        f.y);
}

// How much rain reaches a surface: the sky-light estimate (outdoor, 0 to 1), times the share of the rain heightmap's
// columns around the point that are open above it. Unknown columns count as open.
float abzaRainOutdoor(float outdoor, vec3 worldPos, vec3 worldNormal) {
    #ifdef COMPANION_RAIN_COVER
        if (outdoor > 0.0 && abzaRainCoverReady()) {
            outdoor *= abzaRainColumnsOpen(worldPos, worldNormal, 1.0);
        }
    #endif
    return outdoor;
}

// Sky light (0 to 1) raised to full where the columns above the surface are open: Minecraft's sky light is 15 at every
// block above the rain heightmap. Unknown columns count as closed; unchanged in worlds without sky light.
#if ABZA_SKYLIGHT == 1
    uniform bool hasSkylight;
#endif

float abzaOpenSkyLight(float skyLight, vec3 worldPos, vec3 worldNormal) {
    #if ABZA_SKYLIGHT == 1
        if (skyLight < 1.0 && hasSkylight && abzaRainCoverReady()) {
            skyLight = max(skyLight, abzaRainColumnsOpen(worldPos, worldNormal, 0.0));
        }
    #endif
    return skyLight;
}

#endif

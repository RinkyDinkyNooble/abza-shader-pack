//
//  ABZA Shader: where rain reaches, from Shaders Companion's rain cover (the mod's API.md, "Rain cover", protocol 1):
//  Minecraft's rain heightmap around the camera, so surfaces under glass and other see-through roofs stay dry. Without
//  the mod, the sky-light estimate alone decides.
//

#ifndef ABZA_RAIN_COVER_GLSL
#define ABZA_RAIN_COVER_GLSL

#ifdef COMPANION_RAIN_COVER
    uniform sampler2D scRainCover;

    // 1 where rain reaches a block column's surfaces at height y, 0 below its roof; 1 when the column is unknown
    float abzaRainColumnOpen(ivec2 column, float y) {
        float texel = texelFetch(scRainCover, column & 511, 0).r;
        int v = int(texel);
        int tag = ((column.x >> 9) & 15) | (((column.y >> 9) & 15) << 4);
        if (texel < 0.0 || (v >> 12) != tag) {
            return 1.0;
        }
        return step(float((v & 4095) - 2048) - 0.5, y);
    }
#endif

// How much rain reaches a surface: the sky-light estimate (outdoor, 0 to 1), times the share of the rain heightmap's
// columns around the point that are open above it (bilinear over the four nearest columns). The point is pushed off the
// surface along its world-space normal, so side faces read the column in front of them.
float abzaRainOutdoor(float outdoor, vec3 worldPos, vec3 worldNormal) {
    #ifdef COMPANION_RAIN_COVER
        if (outdoor > 0.0 && textureSize(scRainCover, 0) == ivec2(512, 513)
            && texelFetch(scRainCover, ivec2(0, 512), 0).r == 4242.0 && texelFetch(scRainCover, ivec2(1, 512), 0).r == 1.0) {
            vec3 p = worldPos + worldNormal * 0.05;
            vec2 cell = p.xz - 0.5;
            ivec2 base = ivec2(floor(cell));
            vec2 f = cell - vec2(base);
            float open = mix(
                mix(abzaRainColumnOpen(base, p.y), abzaRainColumnOpen(base + ivec2(1, 0), p.y), f.x),
                mix(abzaRainColumnOpen(base + ivec2(0, 1), p.y), abzaRainColumnOpen(base + ivec2(1, 1), p.y), f.x),
                f.y);
            outdoor *= open;
        }
    #endif
    return outdoor;
}

#endif

//
//  ABZA Shader: Shaders Companion's far terrain (the mod's API.md, "Far terrain", far protocol 1): its depth and info
//  textures and the far case of the LOD helpers (libs/GbufferData.glsl). The far layers hold this frame's far terrain
//  only when the info texture says so; otherwise every helper answers as if there were no LOD (projections the
//  gbuffers', depths 1, the range the chunk terrain's).
//

#ifndef ABZA_FAR_TERRAIN_GLSL
#define ABZA_FAR_TERRAIN_GLSL

#define ABZA_FAR_PROTOCOL 1

// far_depth: r the opaque surface's depth, g the translucent surface's in front of it, 1 where there is none
uniform sampler2D scFarDepth;
// far_info (far_info_still without TAA), 12 x 1 (4 x 1 before Shaders Companion 3.0.0-dev4): (4242, protocol, drawn,
// frame), (near, far, range, chunk radius), (projection [0].x, [1].y, jitter), (width, height), then the far shadow
// map's (abza/FarShadow.glsl)
uniform sampler2D scFarInfo;

// Whether this frame's far layers hold far terrain at the screen's size (without the mod the info texture is the
// missing texture)
bool abzaFarDrawn() {
    vec4 header = texelFetch(scFarInfo, ivec2(0, 0), 0);
    vec2 size = texelFetch(scFarInfo, ivec2(3, 0), 0).xy;
    return header.x == 4242.0 && header.y == float(ABZA_FAR_PROTOCOL) && header.z == 1.0 && size == screenSize;
}

// The far layers' depth mapping: its near and far plane in blocks
vec2 abzaFarPlanes() {
    return texelFetch(scFarInfo, ivec2(1, 0), 0).xy;
}

// How far the far terrain reaches (blocks from the camera), the chunk terrain's far plane when not drawn
float abzaFarRange() {
    return abzaFarDrawn() ? max(texelFetch(scFarInfo, ivec2(1, 0), 0).z, far) : far;
}

// A projection with the far layers' depth mapping in place of its own
mat4 abzaFarDepthMapping(mat4 projection) {
    vec2 planes = abzaFarPlanes();
    projection[2].z = -(planes.y + planes.x) / (planes.y - planes.x);
    projection[3].z = -2.0 * planes.y * planes.x / (planes.y - planes.x);
    return projection;
}

mat4 abzaFarProjection() {
    return abzaFarDrawn() ? abzaFarDepthMapping(gbufferProjection) : gbufferProjection;
}

mat4 abzaFarProjectionInverse() {
    mat4 inverse = gbufferProjectionInverse;
    if (abzaFarDrawn()) {
        vec2 planes = abzaFarPlanes();
        inverse[2].w = -(planes.y - planes.x) / (2.0 * planes.y * planes.x);
        inverse[3].w = (planes.y + planes.x) / (2.0 * planes.y * planes.x);
    }
    return inverse;
}

// Last frame's projection with this frame's depth mapping (the far layers' planes change only with the render distance)
mat4 abzaFarPreviousProjection() {
    return abzaFarDrawn() ? abzaFarDepthMapping(gbufferPreviousProjection) : gbufferPreviousProjection;
}

// The opaque (x) and translucent (y) far depth at a screen coordinate, 1 where nothing far was drawn
vec2 abzaFarDepths(vec2 coord) {
    return abzaFarDrawn() ? textureLod(scFarDepth, coord, 0.0).rg : vec2(1.0);
}

float abzaFarDepthSolid(vec2 coord) {
    return abzaFarDepths(coord).x;
}

// The nearest far surface, water and glass included
float abzaFarDepthNearest(vec2 coord) {
    vec2 depths = abzaFarDepths(coord);
    return min(depths.x, depths.y);
}

// The nearest far surface at the four texels around a coordinate, in textureGather's order (fetched one by one: programs
// from GLSL 3.3 include this too)
vec4 abzaFarGatherNearest(vec2 coord) {
    if (!abzaFarDrawn()) {
        return vec4(1.0);
    }
    ivec2 base = ivec2(floor(coord * screenSize - 0.5));
    ivec2 last = ivec2(screenSize) - 1;
    vec2 d0 = texelFetch(scFarDepth, clamp(base + ivec2(0, 1), ivec2(0), last), 0).rg;
    vec2 d1 = texelFetch(scFarDepth, clamp(base + ivec2(1, 1), ivec2(0), last), 0).rg;
    vec2 d2 = texelFetch(scFarDepth, clamp(base + ivec2(1, 0), ivec2(0), last), 0).rg;
    vec2 d3 = texelFetch(scFarDepth, clamp(base, ivec2(0), last), 0).rg;
    return vec4(min(d0.x, d0.y), min(d1.x, d1.y), min(d2.x, d2.y), min(d3.x, d3.y));
}

#endif

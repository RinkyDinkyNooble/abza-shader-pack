//
//  ABZA Shader: crease shading, short-range ambient occlusion from the visibility bitmask trace
//

// colortex10: crease occlusion from 0 to 1 (r), blended over frames like the visibility bitmask (Deferred0 reprojects it, Deferred12 updates it)
// colortex11: entity coordinates of this frame (abzaEntityCoord in Textured.frag), 0 off entities
// colortex12: colortex11's xy of the last frame (Deferred0)

/*
const int colortex10Format = R16F;
const int colortex11Format = RGBA16;
const int colortex12Format = RG16;
*/
const bool colortex10Clear = false;
const vec4 colortex11ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const bool colortex12Clear = false;

uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;

// The visibility bitmask trace runs for ambient occlusion (VBAO and crease shading) or global illumination
#if defined AMBIENT_OCCLUSION || defined VBGI
    #define ABZA_VB_TRACE
#endif

// Crease occlusion summed over the trace samples, in 1/32 slice units (Deferred12, abzaCreaseSample)
float abzaCreaseSum = 0.0;

// Crease occlusion at the reprojected position, weighted by blended frames, then divided by their sum (Deferred0)
float abzaCreaseHistory = 0.0;

// Scale of the position test on previous-frame texels, in Deferred0; a smaller value accepts a larger distance
float abzaPrevPositionScale = 5000.0;

// This pixel's colortex11 value, 0 on the hand, and how many pixels of texture a previous-frame texel may differ by, in Deferred0
vec4 abzaEntityCoordData = vec4(0.0);
float abzaEntityCoordReach = 2.0;

// 1 where a previous-frame texel shows the same point of the entity's texture as this pixel, and off entities
float abzaSameEntityPoint(ivec2 sampleTexel) {
    if (abzaEntityCoordData.z == 0.0) {
        return 1.0;
    }
    vec2 coordDiff = abs(texelFetch(colortex12, sampleTexel, 0).xy - abzaEntityCoordData.xy);
    coordDiff = min(coordDiff, 1.0 - coordDiff);
    return float(all(lessThanEqual(coordDiff, abzaEntityCoordData.zw * abzaEntityCoordReach + 3e-5)));
}

// Share of ambient occlusion and crease shading shown on a pixel: none on the first frame of history, all from the fifth
float abzaHistoryShare(float blendedFrames) {
    return clamp(0.25 * blendedFrames - 0.25, 0.0, 1.0);
}

// Crease occlusion of a previous-frame texel
float abzaPrevCrease(vec2 sampleTexel) {
    #ifdef AMBIENT_OCCLUSION
        return clamp(texelFetch(colortex10, ivec2(sampleTexel), 0).r, 0.0, 1.0);
    #else
        return 0.0;
    #endif
}

// This frame's crease occlusion blended with the reprojected history; none with ambient occlusion off
float abzaCrease(ivec2 texel, float isOriginNotHand, float blendWeight, float traceCount) {
    #ifdef AMBIENT_OCCLUSION
        float current = abzaCreaseSum * isOriginNotHand / (32.0 * traceCount);
        return mix(clamp(texelFetch(colortex10, texel, 0).r, 0.0, 1.0), current, blendWeight);
    #else
        return 0.0;
    #endif
}

// Share of light kept in a crease; share scales the strength
float abzaCreaseLight(float crease, float share) {
    return pow(max(1.0 - crease, 1e-3), CREASE_SHADING_STRENGTH * share);
}

// Deferred11's lit colour (emission plus direct light) with the direct light shaded by CREASE_SHADING_DIRECT of the crease shading
vec3 abzaCreaseDirect(vec3 litColor, vec3 albedo, float emissive, float crease) {
    vec3 emission = emissive * (PBR_BRIGHTNESS * PI) * albedo;
    return emission + max(litColor - emission, 0.0) * abzaCreaseLight(crease, CREASE_SHADING_DIRECT);
}

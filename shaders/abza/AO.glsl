//
//  ABZA Shader: crease shading, short-range ambient occlusion from the visibility bitmask trace
//

// colortex10: crease occlusion from 0 to 1 (r), blended over frames like the visibility bitmask (Deferred0 reprojects it, Deferred12 updates it)

/*
const int colortex10Format = R16F;
*/
const bool colortex10Clear = false;

uniform sampler2D colortex10;

// The visibility bitmask trace runs for ambient occlusion (VBAO and crease shading) or global illumination
#if defined AMBIENT_OCCLUSION || defined VBGI
    #define ABZA_VB_TRACE
#endif

// Crease occlusion summed over the trace samples, in 1/32 slice units (Deferred12, abzaCreaseSample)
float abzaCreaseSum = 0.0;

// Crease occlusion at the reprojected position, weighted by blended frames, then divided by their sum (Deferred0)
float abzaCreaseHistory = 0.0;

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

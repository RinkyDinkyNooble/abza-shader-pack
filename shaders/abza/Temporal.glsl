//
//  ABZA Shader: temporal anti-aliasing history
//

// colortex13: frames of history behind each pixel (abzaTaaHistoryWeight, written by Composite7)

/*
const int colortex13Format = R16F;
*/
const bool colortex13Clear = false;

uniform sampler2D colortex13;

// Largest depth buffer value of the held item and hand
#define ABZA_HAND_DEPTH_MAX (0.5 + 0.5 * MC_HAND_DEPTH + 1e-4)

// 0.0 where the history comes from held-item pixels of the previous frame but no held item is near the pixel now, 1.0 elsewhere
float abzaHandHistoryFactor(float closestDepth, float prevNearestDepth) {
    return 1.0 - float(closestDepth > ABZA_HAND_DEPTH_MAX && prevNearestDepth < ABZA_HAND_DEPTH_MAX);
}

// Depth at a texel as getClosestDepth reads it: the LOD depth added where no chunk is drawn
float abzaResolveDepth(ivec2 texel) {
    texel = clamp(texel, ivec2(0), ivec2(screenSize) - 1);
    float depth = texelFetch(depthtex0, texel, 0).r;
    #ifdef LOD
        depth += step(1.0, depth) * getLodDepthWater((vec2(texel) + 0.5) * texelSize);
    #endif
    return depth;
}

// 0.0 where a nearer surface lay within a pixel of the history's position (prevNearestDepth against prevDepth, this
// surface's depth in the previous frame) but none lies within two pixels of this one now: an edge that has moved off
// the pixel, whose colour the history still holds there. 1.0 elsewhere. The two-pixel reach keeps edges that only
// shift with the jitter.
float abzaUncoveredFactor(float closestDepth, float prevDepth, float prevNearestDepth) {
    if (prevNearestDepth + 1e-3 >= prevDepth) {
        return 1.0;
    }
    ivec2 texel = ivec2(gl_FragCoord.st);
    float nearest = closestDepth;
    for (int i = 0; i < 9; i++) {
        ivec2 offset = ivec2(i % 3, i / 3) * 2 - 2;
        if (i != 4) {
            nearest = min(nearest, abzaResolveDepth(texel + offset));
        }
    }
    return float(nearest + 1e-3 < abzaResolveDepth(texel));
}

// How far the surface at closest (getClosestDepth's depth) is from the camera, from 0.0 there to 1.0 far away (0.5 at
// 40 blocks) and for the sky
float abzaTaaDistanceFactor(vec3 closest) {
    vec3 viewPos;
    #ifdef LOD
        if (closest.z >= 2.0) {
            return 1.0;
        }
        if (closest.z > 1.0) {
            viewPos = projectionToViewPosLod(vec3(closest.st, closest.z - 1.0) * 2.0 - 1.0);
            return 1.0 - exp2(-0.025 * length(viewPos));
        }
    #endif
    if (closest.z >= 1.0) {
        return 1.0;
    }
    viewPos = projectionToViewPos(vec3(closest.st, closest.z) * 2.0 - 1.0);
    return 1.0 - exp2(-0.025 * length(viewPos));
}

// TAA's history weight, and in frames the history's length behind the pixel for colortex13. While the history is young
// every earlier frame counts the same. TAA_STYLE 0: then the weight given (accepted) applies. TAA_STYLE 1: then the
// weight stops 0.05 under TAA_HISTORY_WEIGHT far away and 0.3 under it close to the camera, where things cross the
// screen faster, and history sampled between pixel centres (in motion) counts up to a quarter less, which keeps moving
// surfaces sharp. accepted: 0.0 where the history is rejected.
float abzaTaaHistoryWeight(vec2 prevCoord, float accepted, float distanceFactor, out float frames) {
    frames = 0.0;
    if (accepted <= 0.0) {
        return 0.0;
    }
    vec2 prevTexel = prevCoord * screenSize;
    frames = min(texelFetch(colortex13, ivec2(prevTexel), 0).r + 1.0, 99.0);
    #if TAA_STYLE == 0
        return min(accepted, frames / (frames + 1.0));
    #else
        float weight = min(frames / (frames + 1.0), mix(TAA_HISTORY_WEIGHT - 0.3, TAA_HISTORY_WEIGHT - 0.05, distanceFactor));
        vec2 centred = 1.0 - abs(2.0 * fract(prevTexel) - 1.0);
        float offCentre = 0.75 + 0.25 * sqrt(centred.x * centred.y);
        frames *= offCentre;
        return weight * offCentre;
    #endif
}

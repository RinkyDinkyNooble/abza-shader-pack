//
//  ABZA Shader: temporal anti-aliasing history
//

// colortex13: frames of history behind each pixel, divided by 255 (abzaHistoryFrames, written by Composite7)

/*
const int colortex13Format = R8;
*/
const bool colortex13Clear = false;

uniform sampler2D colortex13;

// Largest depth buffer value of the held item and hand
#define ABZA_HAND_DEPTH_MAX (0.5 + 0.5 * MC_HAND_DEPTH + 1e-4)

// 0.0 where the history comes from held-item pixels of the previous frame but no held item is near the pixel now, 1.0 elsewhere
float abzaHandHistoryFactor(float closestDepth, float prevNearestDepth) {
    return 1.0 - float(closestDepth > ABZA_HAND_DEPTH_MAX && prevNearestDepth < ABZA_HAND_DEPTH_MAX);
}

// Frames of history behind a pixel: 0 where its history is rejected, otherwise one more than at prevCoord, up to 99
float abzaHistoryFrames(vec2 prevCoord, float blendWeight) {
    if (blendWeight <= 0.0) {
        return 0.0;
    }
    return min(texelFetch(colortex13, ivec2(prevCoord * screenSize), 0).r * 255.0 + 1.0, 99.0);
}

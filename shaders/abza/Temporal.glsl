//
//  ABZA Shader: temporal anti-aliasing history
//

// Largest depth buffer value of the held item and hand
#define ABZA_HAND_DEPTH_MAX (0.5 + 0.5 * MC_HAND_DEPTH + 1e-4)

// 0.0 where the history comes from held-item pixels of the previous frame but no held item is near the pixel now, 1.0 elsewhere
float abzaHandHistoryFactor(float closestDepth, float prevNearestDepth) {
    return 1.0 - float(closestDepth > ABZA_HAND_DEPTH_MAX && prevNearestDepth < ABZA_HAND_DEPTH_MAX);
}

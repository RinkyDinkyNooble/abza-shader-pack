//
//  ABZA Shader: reflections the sky light doesn't reach
//

#ifndef ABZA_REFLECTIONS_GLSL
#define ABZA_REFLECTIONS_GLSL

// Light on the surfaces around a reflecting point that the reflection can't see: the block light and the minimum light
// at that point (as Composite5 lights translucent surfaces) on surfaces of albedo INDOOR_REFLECTION. worldPos is the
// point relative to the camera (a light source in the player's hand raises the block light near them).
vec3 abzaIndoorFill(float blockLevel, vec3 worldPos) {
    #ifdef IS_IRIS
        float eyeRelatedDistance = length(worldPos + relativeEyePosition);
        blockLevel = max(blockLevel, heldBlockLightValue / 15.0 * clamp(1.0 - eyeRelatedDistance / 15.0, 0.0, 1.0));
    #endif
    const float fadeFactor = VANILLA_BLOCK_LIGHT_FADE;
    vec3 blockLight = pow2(1.0 / (fadeFactor - fadeFactor * fadeFactor / (1.0 + fadeFactor) * blockLevel) - 1.0 / fadeFactor) * commonLightColor;
    return (blockLight + 3e-4) * INDOOR_REFLECTION;
}

vec3 abzaIndoorReflection(GbufferData gbufferData, vec3 viewPos) {
    return abzaIndoorFill(gbufferData.lightmap.x, viewToWorldPos(viewPos));
}

#endif

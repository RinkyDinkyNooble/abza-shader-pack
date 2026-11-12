//
//  ABZA Shader: reflections the sky light doesn't reach
//

// Light on the surfaces around a reflecting point that the reflection can't see: the block light and the minimum light
// at that point (as Composite5 lights translucent surfaces) on surfaces of albedo INDOOR_REFLECTION
vec3 abzaIndoorReflection(GbufferData gbufferData, vec3 viewPos) {
    float blockLevel = gbufferData.lightmap.x;
    #ifdef IS_IRIS
        float eyeRelatedDistance = length(viewToWorldPos(viewPos) + relativeEyePosition);
        blockLevel = max(blockLevel, heldBlockLightValue / 15.0 * clamp(1.0 - eyeRelatedDistance / 15.0, 0.0, 1.0));
    #endif
    const float fadeFactor = VANILLA_BLOCK_LIGHT_FADE;
    vec3 blockLight = pow2(1.0 / (fadeFactor - fadeFactor * fadeFactor / (1.0 + fadeFactor) * blockLevel) - 1.0 / fadeFactor) * commonLightColor;
    return (blockLight + 3e-4) * INDOOR_REFLECTION;
}

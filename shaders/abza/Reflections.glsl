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

#ifdef ABZA_FAR_TERRAIN
    // Composite14's option, read here too
    #define RAIN_BLOOM_FOG_DENSITY 1.0 // [0.0 0.01 0.02 0.03 0.04 0.06 0.08 0.1 0.12 0.14 0.16 0.18 0.2 0.22 0.24 0.26 0.28 0.3 0.35 0.4 0.45 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0 4.2 4.4 4.6 4.8 5.0 5.5 6.0 6.5 7.0 7.5 8.0 9.5 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 22.0 24.0 26.0 28.0 30.0 32.0 34.0 36.0 38.0 40.0 42.0 44.0 46.0 48.0 50.0 55.0 60.0 65.0 70.0 75.0 80.0 85.0 90.0 95.0 100.0]

    // Whether the fog hides a far surface (view position viewPos) so fully in this weather that its reflection can't
    // show: the air and rain fog of Composite5 (solidAtmosphereScattering seen from the eye) lets through under 2% of its
    // light, and that together with Composite14's rain bloom fog under 0.1%. Never outside the overworld's fog.
    bool abzaFarFogHides(vec3 viewPos) {
        #if defined ATMOSPHERE_SCATTERING_FOG && defined SHADOW_AND_SKY && !defined NETHER && !defined THE_END
            if (weatherStrength < 0.05 || isEyeInWater != 0) {
                return false;
            }
            float viewDistance = length(viewPos);
            float playerHeight = max(cameraPosition.y + WORLD_BASIC_HEIGHT + earthRadius, 300.0 + earthRadius);
            vec2 originDensity = exp2(earthScaledHeight - playerHeight / scaledHeight * 1.44269502);
            float eyeSkyLight = clamp(eyeBrightnessSmooth.y / 240.0, 0.0, 1.0);
            float atmosphereDepth = viewDistance * (1.0 + RF_GROUND_EXTRA_DENSITY * 3.0 * weatherStrength);
            vec2 opticalDepth = originDensity * atmosphereDepth * 5.0 * (1.0 + RF_DENSITY * 5.0 * weatherStrength * weatherStrength * eyeSkyLight);
            vec3 absorption = exp2(-opticalDepth.x * rayleighBeta - opticalDepth.y * rainyMieBeta);
            float air = max(absorption.r, max(absorption.g, absorption.b)) * airAbsorption(viewDistance);
            float bloomFog = exp2(-weatherStrength * weatherStrength * eyeSkyLight * RAIN_BLOOM_FOG_DENSITY * 0.03 * -viewPos.z * exp2(-cameraPosition.y / 2000.0 - WORLD_BASIC_HEIGHT / 2000.0));
            return air < 0.02 && air * bloomFog < 1e-3;
        #else
            return false;
        #endif
    }
#endif

#endif

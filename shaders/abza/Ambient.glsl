//
//  ABZA Shader: sky light, block light and the minimum light on a surface off screen, as Deferred12 lights terrain
//

#ifndef ABZA_AMBIENT_GLSL
#define ABZA_AMBIENT_GLSL
    #ifdef BASIC_LIGHT
        #define ABZA_BASIC_LIGHT BASIC_LIGHT
    #elif defined SHADOW_AND_SKY
        #define ABZA_BASIC_LIGHT 3e-4
    #else
        #define ABZA_BASIC_LIGHT 0.01
    #endif

    // Deferred12's light for a rough surface without its ambient occlusion and bounce light: the minimum light, night
    // vision (nightLight), block light (raised by a light source in the player's hand), and sky light weighted by
    // the normal's direction (plants count as facing up), times Deferred12's diffuse weight for a rough surface.
    // worldPos is relative to the camera.
    vec3 abzaAmbientLight(float blockLevel, float skyLevel, vec3 worldPos, vec3 normal, bool plant, vec3 nightLight) {
        vec3 skyNormal = plant ? vec3(0.0, 1.0, 0.0) : normal;
        float skyLightStrength = pow2(1.0 / (0.75 - 0.75 * 0.75 / (1.0 + 0.75) * skyLevel) - 1.0 / 0.75) *
            (skyNormal.y * 0.3 + 0.6 + mix(dot(skyNormal, sunDirection), dot(skyNormal, shadowDirection), clamp(-sunDirection.y * 10.0, 0.0, 1.0)) * 0.2);
        #ifdef IS_IRIS
            blockLevel = max(blockLevel, heldBlockLightValue / 15.0 * clamp(1.0 - length(worldPos + relativeEyePosition) / 15.0, 0.0, 1.0));
        #endif
        vec3 light = ABZA_BASIC_LIGHT + nightLight;
        const float fadeFactor = VANILLA_BLOCK_LIGHT_FADE;
        light += pow2(1.0 / (fadeFactor - fadeFactor * fadeFactor / (1.0 + fadeFactor) * blockLevel) - 1.0 / fadeFactor) * commonLightColor;
        #if defined SHADOW_AND_SKY && ABZA_SKYLIGHT == 1
            light +=
                skyLightStrength *
                (skyColorUp * 0.8 + sunColor * 2.0 * ABZA_AMBIENT * SHADE_FILL * SUNLIGHT_BRIGHTNESS * (1.0 - (0.75 + 0.25 * float(CLOUD_TYPE != 2)) * weatherStrength)) *
                (1.0 - 0.75 * (1.0 - exp2(-RF_DENSITY * 4.0)) * weatherStrength);
        #endif
        return light * (1.0 + 1.0 / PI);
    }
#endif

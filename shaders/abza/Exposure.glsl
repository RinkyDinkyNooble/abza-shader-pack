//
//  ABZA Shader: steady exposure, and exposure off
//

#if (EXPOSURE_MODE == 1 || EXPOSURE_MODE == 2) && defined ABZA_WORLD
    #define ABZA_STEADY_EXPOSURE

    in vec3 skyColorUp;
    in vec3 abzaSkyColorNoon;

    // The scene's grey ground: linear albedo, and the diffuse weight of a rough surface in Sundial's deferred lighting
    const float ABZA_SCENE_ALBEDO = 0.2;
    const float ABZA_SCENE_DIFFUSE = 1.0 + 1.0 / PI;
    // The scene's minimum light without night vision
    const vec3 ABZA_SCENE_BASIC = vec3(ABZA_SCENE_ALBEDO * ABZA_SCENE_DIFFUSE * 3e-4);
    // SHADE_FILL's default (abza/Abza.glsl), the value the scene's sky light is calibrated at
    const float ABZA_SCENE_SHADE_FILL = 0.7;

    // A linear colour in the units of the metered brightness (3 times the mean linear colour on screen), above zero
    float abzaSceneBrightness(vec3 color) {
        return max(3.0 * dot(color, vec3(1.0 / 3.0)), 1e-6);
    }

    // Linear colour of a fixed outdoor scene: grey ground (60 % flat and 40 % walls; 70 % in direct light) and 35 % open sky,
    // lit like Deferred12 lights terrain by direct light `sun` at height lightHeight (0 to 1), the sky colour `sky` and the
    // weather. Its sky light follows Shade fill relative to the default and has Deferred12's weather term for the cloud type.
    vec3 abzaOutdoorScene(vec3 sun, vec3 sky, float lightHeight, float weather) {
        const float skyShare = 0.35;

        float facing = 0.6 * lightHeight + 0.4 / PI * sqrt(1.0 - lightHeight * lightHeight);
        vec3 direct = sun * (0.7 * facing * 9.5 * SUNLIGHT_BRIGHTNESS * (1.0 - sqrt(weather)));
        vec3 ambient =
            (sky * 0.8 + sun * 2.0 * ABZA_AMBIENT * (SHADE_FILL / ABZA_SCENE_SHADE_FILL) * SUNLIGHT_BRIGHTNESS * (1.0 - (0.75 + 0.25 * float(CLOUD_TYPE != 2)) * weather)) *
            (1.0 - 0.75 * (1.0 - exp2(-RF_DENSITY * 4.0)) * weather) * ABZA_SCENE_DIFFUSE;
        return (1.0 - skyShare) * ABZA_SCENE_ALBEDO * (direct + ambient) + skyShare * 1.5 * sky;
    }

    #include "/abza/NightLight.glsl"

    // Brightness of the outdoor scene in clear weather with the world's daylight straight overhead
    float abzaNoonBrightness() {
        #if ABZA_AIR == 1
            const vec3 noonLight = vec3(0.904, 0.830, 0.743);
        #else
            const vec3 noonLight = vec3(1.0);
        #endif
        return abzaSceneBrightness(abzaOutdoorScene(noonLight * ABZA_DAY_LIGHT, abzaSkyColorNoon, 1.0, 0.0));
    }

    // Scene brightness in the units of the metered brightness, without reading the screen.
    // Steady: the outdoor scene now; locally it is scaled by the sky light at the player, plus a share of the block light there.
    //   STEADY_LOCAL_ADAPTATION blends the two in log space: 0 uses the outdoor scene only, 1 the local one.
    //   Below an eighth of the noon brightness (about the light at sunset; worlds with a fixed time: of their outdoor scene),
    //   the result falls in log space at STEADY_NIGHT_LIFT times the rate, so darker scenes get that share of the exposure lift.
    // Off: the noon brightness, so it never changes.
    //   Worlds with a fixed time use their outdoor scene in clear weather without night vision, which doesn't change either.
    float abzaSteadyBrightness() {
        #if EXPOSURE_MODE == 2 && ABZA_FIXED_TIME == 0
            return abzaNoonBrightness();
        #elif EXPOSURE_MODE == 2
            return abzaSceneBrightness(abzaOutdoorScene(sunColor, skyColorUp, clamp(shadowDirection.y, 0.0, 1.0), 0.0) + ABZA_SCENE_BASIC);
        #else
            vec3 outdoor = abzaOutdoorScene(sunColor, skyColorUp, clamp(shadowDirection.y, 0.0, 1.0), weatherStrength);

            vec2 eyeLight = vec2(eyeBrightnessSmooth) / 240.0;
            float skyLight = pow2(1.0 / (0.75 - 0.75 * 0.75 / (1.0 + 0.75) * eyeLight.y) - 1.0 / 0.75);
            const float fadeFactor = VANILLA_BLOCK_LIGHT_FADE;
            float blockLevel = clamp(max(eyeLight.x, heldBlockLightValue / 15.0 * 0.7), 0.0, 1.0);
            vec3 blockLight = pow2(1.0 / (fadeFactor - fadeFactor * fadeFactor / (1.0 + fadeFactor) * blockLevel) - 1.0 / fadeFactor) * commonLightColor * 0.3;
            vec3 basic = ABZA_SCENE_BASIC + ABZA_SCENE_ALBEDO * ABZA_SCENE_DIFFUSE * abzaNightLight();
            vec3 indoor = ABZA_SCENE_ALBEDO * ABZA_SCENE_DIFFUSE * blockLight;

            float outdoorScene = abzaSceneBrightness(outdoor + basic);
            float localScene = abzaSceneBrightness(outdoor * skyLight + indoor + basic);
            float brightness = exp2(mix(log2(outdoorScene), log2(localScene), STEADY_LOCAL_ADAPTATION));
            #if ABZA_FIXED_TIME == 0
                float reference = 0.125 * abzaNoonBrightness();
            #else
                float reference = 0.125 * outdoorScene;
            #endif
            float ratio = brightness / reference;
            return reference * (ratio < 1.0 ? pow(ratio, STEADY_NIGHT_LIFT) : ratio);
        #endif
    }
#endif

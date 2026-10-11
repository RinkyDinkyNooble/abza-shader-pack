//
//  ABZA Shader: steady exposure, and exposure off
//

#if (EXPOSURE_MODE == 1 || EXPOSURE_MODE == 2) && defined ABZA_WORLD
    #define ABZA_STEADY_EXPOSURE

    in vec3 skyColorUp;
    #if EXPOSURE_MODE == 2
        in vec3 abzaSkyColorNoon;
    #endif

    // Linear colour of a fixed outdoor scene: grey ground (linear albedo 0.2; 60 % flat and 40 % walls; 70 % in direct light) and 35 % open sky,
    // lit like Sundial's deferred lighting by direct light `sun` at height lightHeight (0 to 1), the sky colour `sky` and the weather.
    vec3 abzaOutdoorScene(vec3 sun, vec3 sky, float lightHeight, float weather) {
        const float albedo = 0.2;
        const float skyShare = 0.35;
        const float diffuse = 1.0 + 1.0 / PI;

        float facing = 0.6 * lightHeight + 0.4 / PI * sqrt(1.0 - lightHeight * lightHeight);
        vec3 direct = sun * (0.7 * facing * 9.5 * SUNLIGHT_BRIGHTNESS * (1.0 - sqrt(weather)));
        vec3 ambient =
            (sky * 0.8 + sun * 2.0 * ABZA_AMBIENT * SUNLIGHT_BRIGHTNESS * (1.0 - 0.75 * weather)) *
            (1.0 - 0.75 * (1.0 - exp2(-RF_DENSITY * 4.0)) * weather) * diffuse;
        return (1.0 - skyShare) * albedo * (direct + ambient) + skyShare * 1.5 * sky;
    }

    // Scene brightness in the units of the metered brightness (3 times the mean linear colour on screen), without reading the screen.
    // Steady: the outdoor scene now; locally it is scaled by the sky light at the player, plus a share of the block light there.
    //   STEADY_LOCAL_ADAPTATION blends the two in log space: 0 uses the outdoor scene only, 1 the local one.
    // Off: the outdoor scene in clear weather with the world's daylight straight overhead, so it never changes.
    //   Worlds with a fixed time use their outdoor scene now, which doesn't change either.
    float abzaSteadyBrightness() {
        #if EXPOSURE_MODE == 2 && ABZA_FIXED_TIME == 0
            #if ABZA_AIR == 1
                const vec3 noonLight = vec3(0.904, 0.830, 0.743);
            #else
                const vec3 noonLight = vec3(1.0);
            #endif
            vec3 noonScene = abzaOutdoorScene(noonLight * ABZA_DAY_LIGHT, abzaSkyColorNoon, 1.0, 0.0);
            return max(3.0 * dot(noonScene, vec3(1.0 / 3.0)), 1e-6);
        #else
            const float albedo = 0.2;
            const float diffuse = 1.0 + 1.0 / PI;
            vec3 outdoor = abzaOutdoorScene(sunColor, skyColorUp, clamp(shadowDirection.y, 0.0, 1.0), weatherStrength);

            vec2 eyeLight = vec2(eyeBrightnessSmooth) / 240.0;
            float skyLight = pow2(1.0 / (0.75 - 0.75 * 0.75 / (1.0 + 0.75) * eyeLight.y) - 1.0 / 0.75);
            const float fadeFactor = VANILLA_BLOCK_LIGHT_FADE;
            float blockLevel = clamp(max(eyeLight.x, heldBlockLightValue / 15.0 * 0.7), 0.0, 1.0);
            vec3 blockLight = pow2(1.0 / (fadeFactor - fadeFactor * fadeFactor / (1.0 + fadeFactor) * blockLevel) - 1.0 / fadeFactor) * commonLightColor * 0.3;
            vec3 basic = albedo * diffuse * vec3(3e-4 + nightVision * NIGHT_VISION_BRIGHTNESS);
            vec3 indoor = albedo * diffuse * blockLight;

            float outdoorScene = max(3.0 * dot(outdoor + basic, vec3(1.0 / 3.0)), 1e-6);
            #if EXPOSURE_MODE == 2
                return outdoorScene;
            #else
                float localScene = max(3.0 * dot(outdoor * skyLight + indoor + basic, vec3(1.0 / 3.0)), 1e-6);
                return exp2(mix(log2(outdoorScene), log2(localScene), STEADY_LOCAL_ADAPTATION));
            #endif
        #endif
    }
#endif

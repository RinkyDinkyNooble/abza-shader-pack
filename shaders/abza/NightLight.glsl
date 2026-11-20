//
//  ABZA Shader: night vision's light, as Deferred12 adds it to terrain
//

#ifndef ABZA_NIGHT_LIGHT_GLSL
#define ABZA_NIGHT_LIGHT_GLSL
    #ifdef MOD_NIGHT_VISION_COMPAT
        uniform sampler2D abzaLightmap;
    #endif

    // With MOD_NIGHT_VISION_COMPAT the game's light map without sky or block light, so mods' own night vision counts;
    // else vanilla's effect
    vec3 abzaNightLight() {
        #ifdef MOD_NIGHT_VISION_COMPAT
            return pow(texelFetch(abzaLightmap, ivec2(0), 0).rgb, vec3(2.2)) * NIGHT_VISION_BRIGHTNESS;
        #else
            return vec3(nightVision * NIGHT_VISION_BRIGHTNESS);
        #endif
    }
#endif

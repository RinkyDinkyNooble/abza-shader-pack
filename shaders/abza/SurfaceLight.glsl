//
//  ABZA Shader: lighting for surfaces that reflections find off screen
//

#ifndef ABZA_SURFACE_LIGHT
#define ABZA_SURFACE_LIGHT
    // ABZA_SHADOW_INCLUDED: a program that has included libs/Shadow.glsl already
    #if defined SHADOW_AND_SKY && !defined ABZA_SHADOW_INCLUDED
        #include "/libs/Shadow.glsl"
    #endif
    #ifdef GLOWING_ORES
        #include "/abza/Ores.glsl"
    #endif
    #include "/abza/Ambient.glsl"

    // Light reaching a surface a reflection finds off screen (a voxel face, the player, a companion cube texel), as
    // Deferred11, Deferred12 and Composite5 light terrain: block light, the minimum light, and sky light and sunlight
    // through the shadow map where the world has them. translucent is 1 on thin surfaces sunlight passes through
    // (plants), which are lit on both sides as Sundial's subsurface scattering lights them on screen.
    vec3 abzaSurfaceLight(float blockLevel, float skyLevel, vec3 worldPos, vec3 normal, float translucent) {
        vec3 light = abzaAmbientLight(blockLevel, skyLevel, worldPos, normal, translucent > 0.5, vec3(nightVision * NIGHT_VISION_BRIGHTNESS));
        #ifdef SHADOW_AND_SKY
            #if ABZA_DIRECT_LIGHT == 1
                float NdotL = dot(normal, shadowDirection);
                float direct = mix(NdotL, 0.5 + 0.5 * abs(NdotL), translucent);
                if (direct > 0.0 && skyLevel > 0.0) {
                    // Normal offset as Sundial's terrain shadows (libs/Shadow.glsl), towards the sun's side
                    vec3 offsetNormal = NdotL < 0.0 ? -normal : normal;
                    float normalOffset = (length(worldPos) * 2e-3 + 2e-2) * (1.0 + sqrt(1.0 - abs(NdotL))) * 4096.0 / realShadowMapResolution;
                    vec3 shadowCoord = worldPosToShadowCoord(worldPos + offsetNormal * max(normalOffset, 0.05));
                    float visibility = skyLevel;
                    if (all(lessThan(abs(shadowCoord - vec3(vec2(0.75), 0.5)), vec3(vec2(0.25), 0.5)))) {
                        visibility = textureLod(shadowtex0, shadowCoord - vec3(0.0, 0.0, 4e-5), 0.0);
                    }
                    light += sunColor * basicSunlight * direct * visibility;
                }
            #endif
        #endif
        return light;
    }

    vec3 abzaSurfaceLight(float blockLevel, float skyLevel, vec3 worldPos, vec3 normal) {
        return abzaSurfaceLight(blockLevel, skyLevel, worldPos, normal, 0.0);
    }
#endif

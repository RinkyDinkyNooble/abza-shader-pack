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
    #include "/abza/NightLight.glsl"

    // Sunlight reaching a surface off screen with this NdotL, through the shadow map (or by its sky light outside the
    // map): the sun's colour times its visibility, without the surface's own direct weight. 0 where the world has no
    // sun or the surface has no sky light.
    vec3 abzaSurfaceSunlight(float skyLevel, vec3 worldPos, vec3 normal, float NdotL) {
        #if defined SHADOW_AND_SKY && ABZA_DIRECT_LIGHT == 1
            if (skyLevel > 0.0) {
                // Normal offset as Sundial's terrain shadows (libs/Shadow.glsl), towards the sun's side
                vec3 offsetNormal = NdotL < 0.0 ? -normal : normal;
                float normalOffset = (length(worldPos) * 2e-3 + 2e-2) * (1.0 + sqrt(max(1.0 - abs(NdotL), 0.0))) * 4096.0 / realShadowMapResolution;
                vec3 shadowCoord = worldPosToShadowCoord(worldPos + offsetNormal * max(normalOffset, 0.05));
                float visibility = skyLevel;
                if (all(lessThan(abs(shadowCoord - vec3(vec2(0.75), 0.5)), vec3(vec2(0.25), 0.5)))) {
                    visibility = textureLod(shadowtex0, shadowCoord - vec3(0.0, 0.0, 4e-5), 0.0);
                }
                return sunColor * basicSunlight * visibility;
            }
        #endif
        return vec3(0.0);
    }

    // Light reaching a surface a reflection finds off screen (a voxel face, the player, a companion cube texel), as
    // Deferred11, Deferred12 and Composite5 light terrain: block light, the minimum light, night vision, and sky light
    // and sunlight through the shadow map where the world has them. translucent is 1 on thin surfaces sunlight passes
    // through (plants), which are lit on both sides as Sundial's subsurface scattering lights them on screen.
    // ambientShade and directShade: what steady ambient occlusion leaves of the ambient and the direct light (abzaLatticeShade)
    vec3 abzaSurfaceLight(float blockLevel, float skyLevel, vec3 worldPos, vec3 normal, float translucent, float ambientShade, float directShade) {
        vec3 light = abzaAmbientLight(blockLevel, skyLevel, worldPos, normal, translucent > 0.5, abzaNightLight()) * ambientShade;
        #if defined SHADOW_AND_SKY && ABZA_DIRECT_LIGHT == 1
            float NdotL = dot(normal, shadowDirection);
            float direct = mix(NdotL, 0.5 + 0.5 * abs(NdotL), translucent);
            if (direct > 0.0) {
                light += abzaSurfaceSunlight(skyLevel, worldPos, normal, NdotL) * direct * directShade;
            }
        #endif
        return light;
    }

    vec3 abzaSurfaceLight(float blockLevel, float skyLevel, vec3 worldPos, vec3 normal, float translucent) {
        return abzaSurfaceLight(blockLevel, skyLevel, worldPos, normal, translucent, 1.0, 1.0);
    }

    vec3 abzaSurfaceLight(float blockLevel, float skyLevel, vec3 worldPos, vec3 normal) {
        return abzaSurfaceLight(blockLevel, skyLevel, worldPos, normal, 0.0);
    }
#endif

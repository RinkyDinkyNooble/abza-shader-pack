//
//  ABZA Shader: water and glass drawn where the screen's own passes don't reach them (water behind other translucents,
//  and water and glass in Shaders Companion's views): the waves' normal and the sky a surface reflects
//

#ifndef ABZA_WATER_SURFACE_GLSL
#define ABZA_WATER_SURFACE_GLSL
    #include "/libs/Water.glsl"
    #include "/abza/WaterWaves.glsl"

    // The water's normal (world space) at a surface point relative to the camera, seen along worldDir by a pixel that
    // covers footprint blocks of water: the waves with the default water type, straight up with the flat one
    vec3 abzaWaterSurfaceNormal(vec3 surfacePos, vec3 worldDir, float footprint) {
        #if WATER_TYPE == 0
            // The waves in the surface's tangent space (x and z across it, y up)
            return abzaWaterSurfaceWave((surfacePos + cameraPosition) / 32.0, worldDir.xzy, footprint).xzy;
        #else
            return vec3(0.0, 1.0, 0.0);
        #endif
    }

    // The sky's colour from a point relative to the camera in direction worldDir (black where there is no sky)
    vec3 abzaSkyColor(vec3 surfacePos, vec3 worldDir, vec3 skyColor) {
        #if defined SHADOW_AND_SKY && ABZA_AIR == 1
            vec3 atmosphere;
            return singleAtmosphereScattering(
                vec3(0.0), surfacePos, worldDir, sunDirection, planetIntersectionData(surfacePos, worldDir), skyColor, 30.0, atmosphere
            );
        #else
            return vec3(0.0);
        #endif
    }

    // A smooth surface (water f0 0.02, glass 0.04) with this normal at surfacePos, seen along worldDir: the sky it
    // reflects mixed over color (what the surface shows of itself and of what lies behind it) by its Fresnel weight,
    // darkened under cover by its sky light
    vec3 abzaSkyReflection(vec3 color, vec3 surfacePos, vec3 worldDir, vec3 normal, float f0, float skyLight, vec3 skyColor) {
        #if defined SHADOW_AND_SKY && ABZA_AIR == 1
            vec3 rayDir = reflect(worldDir, normal);
            rayDir.y = max(rayDir.y, 0.01);
            rayDir = normalize(rayDir);
            float reflectance = fresnel(clamp(dot(-worldDir, normal), 0.0, 1.0), vec3(f0)).x * skyLight * skyLight;
            color = mix(color, abzaSkyColor(surfacePos, rayDir, skyColor), reflectance);
        #endif
        return color;
    }
#endif

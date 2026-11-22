//
//  ABZA Shader: surfaces with a material class (abza/MaterialClass.glsl) found off screen, in Shaders Companion's cube
//  and mirror views and its lattice, lit with the screen's own material model: Deferred11's diffuse weight and sun
//  highlight, Deferred12's ambient weight, and the reflection Composite0 would trace for them. Off screen there is no
//  second bounce, so that reflection is what Composite0 takes where its rays find nothing (the sky under open sky,
//  the indoor fill under cover), and the ground for rays that point down. Without a class the same functions give a
//  rough surface's lighting (F0 0.04, no reflection), as before.
//

#ifndef ABZA_VIEW_MATERIAL_GLSL
#define ABZA_VIEW_MATERIAL_GLSL
    #include "/abza/MaterialClass.glsl"
    #include "/abza/Reflections.glsl"

    // Albedo taken for the ground a classed surface reflects when its reflection points down (no colours are known
    // there; the lattice's hits take the same)
    #define ABZA_VIEW_GROUND_ALBEDO 0.3

    struct AbzaViewMaterial {
        float smoothness;
        // 0 or 1 (Sundial's named metals and metal by albedo are 1)
        float metalness;
        vec3 f0;
        vec3 f82;
    };

    // The material of class materialClass on a surface of this albedo (linear), as Deferred11 reads a specular map;
    // false for class 0 or without the mod's table
    bool abzaViewMaterial(int materialClass, vec3 albedo, out AbzaViewMaterial material) {
        material = AbzaViewMaterial(0.0, 0.0, vec3(0.04), vec3(1.0));
        vec3 values;
        if (!abzaMaterialValues(materialClass, values)) {
            return false;
        }
        material.smoothness = values.r;
        float metalness = values.g;
        #ifdef LABPBR_F0
            material.f0 = mix(material.f0, vec3(metalness), step(0.001, metalness));
            material.f82 = hardcodedMetal(metalness);
            metalness = step(229.5 / 255.0, metalness);
        #endif
        material.metalness = metalness;
        material.f0 = mix(material.f0, albedo, metalness);
        return true;
    }

    // The share of a surface's reflection Sundial leaves to its ambient light instead of tracing it (Deferred12's
    // diffuse weight; Composite0 traces the rest): 1 on a rough surface
    float abzaViewRoughShare(AbzaViewMaterial material) {
        float roughShare = pow(1.0 - material.smoothness, 5.0);
        #ifndef FULL_REFLECTION
            roughShare = 1.0 - (1.0 - roughShare) * sqrt(clamp(material.smoothness - (1.0 - material.smoothness) * (1.0 - 0.6666 * material.metalness), 0.0, 1.0));
        #endif
        return roughShare;
    }

    // Deferred11's weight for diffuse direct light (1 on a rough surface, 0 on metal)
    vec3 abzaViewDiffuse(AbzaViewMaterial material, float NdotV) {
        return (1.0 - material.metalness) * diffuseAbsorptionWeight(NdotV, material.smoothness, material.f0, material.f82);
    }

    // Deferred12's weight for ambient light, against a rough surface's (abzaAmbientLight is a rough surface's light)
    vec3 abzaViewAmbientWeight(AbzaViewMaterial material, float NdotV) {
        return (abzaViewDiffuse(material, NdotV) + abzaViewRoughShare(material) / PI) / (1.0 + 1.0 / PI);
    }

    // Deferred11's sun highlight, world space (rayDir from the viewer to the surface)
    vec3 abzaViewSunSpecular(AbzaViewMaterial material, vec3 rayDir, vec3 normal, float NdotL, float NdotV) {
        #if defined SHADOW_AND_SKY || defined END_FLASH
            return sunlightSpecular(rayDir, shadowDirection, normal, material.smoothness * 0.995, NdotL, NdotV, material.f0, material.f82) *
                airAbsorption(11.4 * material.smoothness) * clamp(19.0 - material.smoothness * 20.0, 0.0, 1.0);
        #else
            return vec3(0.0);
        #endif
    }

    // The light on the ground under a surface: its ambient light facing up and the sun by the surface's own sky light
    vec3 abzaViewGroundLight(float blockLevel, float skyLevel, vec3 worldPos, vec3 nightLight) {
        vec3 light = abzaAmbientLight(blockLevel, skyLevel, worldPos, vec3(0.0, 1.0, 0.0), false, nightLight);
        #if defined SHADOW_AND_SKY && ABZA_DIRECT_LIGHT == 1
            light += sunColor * basicSunlight * clamp(shadowDirection.y, 0.0, 1.0) * skyLevel * skyLevel;
        #endif
        return light;
    }

    // The reflection Composite0 would add for this surface (worldPos relative to the camera, seen along rayDir): its
    // traced share of the surface, by the Fresnel weight, of the sky (times the sky light, with the indoor fill for the
    // rest, as Composite0 does where its rays find nothing) or, for a reflection pointing down, of the ground under it
    // (abzaViewGroundLight). None on a surface Sundial doesn't trace reflections for.
    vec3 abzaViewReflection(AbzaViewMaterial material, vec3 rayDir, vec3 normal, vec3 worldPos, float blockLevel, float skyLevel, vec3 nightLight) {
        float strength = 1.0 - abzaViewRoughShare(material);
        if (strength < 1e-5) {
            return vec3(0.0);
        }
        vec3 groundLight = abzaViewGroundLight(blockLevel, skyLevel, worldPos, nightLight);
        vec3 reflected = reflect(rayDir, normal);
        float NdotV = clamp(dot(-rayDir, normal), 0.0, 1.0);
        // The sky straight up: the atmosphere's colour in the reflected direction cost 2 ms of GPU in the mirror view's
        // lighting pass (a mirror view full of metal and polished stone, 1080p) for a reflection seen in a reflection
        vec3 open = skyColorUp;
        #ifdef LIGHT_LEAKING_FIX
            open = open * skyLevel + abzaIndoorFill(blockLevel, worldPos) * (1.0 - skyLevel);
        #endif
        vec3 environment = mix(groundLight * ABZA_VIEW_GROUND_ALBEDO, open, smoothstep(-0.2, 0.05, reflected.y));
        return environment * F_AdobeF82(material.f0, material.f82, NdotV) * strength;
    }

    // A classed surface found off screen, with the simple lighting of the cube's reflections (abzaSurfaceLight: one
    // shadow sample, no occlusion): albedo linear, normal facing the viewer, rayDir from the viewer to worldPos
    // ambientShade and directShade as abzaSurfaceLight takes them (steady ambient occlusion)
    vec3 abzaViewClassedLight(AbzaViewMaterial material, vec3 albedo, vec3 normal, vec3 rayDir, vec3 worldPos, float blockLevel, float skyLevel, float ambientShade, float directShade) {
        float NdotV = clamp(dot(-rayDir, normal), 0.0, 1.0);
        vec3 nightLight = abzaNightLight();
        vec3 color = albedo * abzaAmbientLight(blockLevel, skyLevel, worldPos, normal, false, nightLight) * abzaViewAmbientWeight(material, NdotV) * ambientShade;
        #if defined SHADOW_AND_SKY && ABZA_DIRECT_LIGHT == 1
            float NdotL = dot(normal, shadowDirection);
            if (NdotL > 0.0) {
                color += abzaSurfaceSunlight(skyLevel, worldPos, normal, NdotL) * NdotL * directShade *
                    (albedo * abzaViewDiffuse(material, NdotV) + abzaViewSunSpecular(material, rayDir, normal, NdotL, NdotV));
            }
        #endif
        return color + abzaViewReflection(material, rayDir, normal, worldPos, blockLevel, skyLevel, nightLight);
    }

    vec3 abzaViewClassedLight(AbzaViewMaterial material, vec3 albedo, vec3 normal, vec3 rayDir, vec3 worldPos, float blockLevel, float skyLevel) {
        return abzaViewClassedLight(material, albedo, normal, rayDir, worldPos, blockLevel, skyLevel, 1.0, 1.0);
    }

    // The class of a texel of the mod's views by its id field (cube_data.b): a block's from its id, none for entities
    // and Distant Horizons' LODs
    int abzaViewTexelClass(uint id) {
        return id < 0x8000u ? abzaMaterialClassOf(int(id) - 1) : 0;
    }
#endif

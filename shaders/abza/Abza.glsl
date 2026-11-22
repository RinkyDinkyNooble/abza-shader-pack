//
//  ABZA Shader: settings and per-world configuration
//

#define ABZA_SHADER v2_0_0 // [v2_0_0]

// Shadow filtering
    #define SHADOW_EDGE_SOFTNESS 0.5 // [0.25 0.5 0.75 1.0 1.5 2.0]
    // #define SUBSURFACE_SCATTERING_FADE

// Shadow casters
    // #define SHADOW_ENTITIES
    #define SHADOW_PLAYER
    // #define SHADOW_BLOCK_ENTITIES

    // Tested here so Iris lists them as options; shaders.properties uses them
    #ifdef SHADOW_ENTITIES
    #endif
    #ifdef SHADOW_PLAYER
    #endif
    #ifdef SHADOW_BLOCK_ENTITIES
    #endif

// Glowing ores
    #define GLOWING_ORES
    #define GLOWING_ORE_STRENGTH 0.6 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

// Sky
    // #define ABZA_MODPACK
    #define STAR_TEXTURE_BRIGHTNESS 25.0 // [2.0 5.0 10.0 15.0 20.0 25.0 30.0 40.0 50.0 75.0 100.0 150.0 200.0 300.0]
    #define STARS_BY_DAY 8.0 // [1.0 2.0 4.0 8.0 16.0 32.0]
    // #define SMOOTH_HORIZON

// Water
    // #define WATER_WAVE_FILTER
    // #define TRANSLUCENT_LIGHT_DITHER

// Glass
    #define THIN_GLASS_REFRACTION
    // #define DEPTH_RELATIVE_REFRACTION

// Rain
    #define COMPANION_RAIN_COVER

// Closed doors keep light out: read by the Shaders Companion mod, which works out the light around closed doors
    // #define COMPANION_DOOR_LIGHT
    #ifdef COMPANION_DOOR_LIGHT
    #endif

// Reflections
    // #define COMPANION_REFLECTIONS
    // #define COMPANION_MIRROR
    // #define COMPANION_MIRROR_LIGHTING
    // #define COMPANION_REFLECTED_WATER
    // #define COMPANION_MATERIALS
    // #define COMPANION_HELD_ITEMS
    // #define COMPANION_ENTITY_MATERIALS
    // #define COMPANION_REFLECTIONS_ONLY
    #define HELD_ITEM_LOOK 0 // [0 1]
    #define COMPANION_MIRROR_DETAIL 48 // [0 16 32 48 64 96 128 192 256 512]
    #define COMPANION_MIRROR_PLANES 1 // [1 2 3 4]
    // #define WORLD_REFLECTIONS
    #define WORLD_REFLECTION_DISTANCE 48 // [16 24 32 48 64]
    #define INDOOR_REFLECTION 0.3 // [0.0 0.05 0.1 0.15 0.2 0.3 0.4 0.5 0.6 0.8 1.0]

// Ambient occlusion (VBAO and crease shading)
    #define AMBIENT_OCCLUSION
    // #define LATTICE_AMBIENT_OCCLUSION

// Crease shading
    #define CREASE_SHADING_STRENGTH 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 2.5 3.0]
    #define CREASE_SHADING_RADIUS 1.5 // [0.5 0.75 1.0 1.25 1.5 2.0 2.5 3.0 4.0]
    #define CREASE_SHADING_DIRECT 0.5 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

// Sunshine sheen
    #define SUN_SHEEN 2.0 // [0.0 0.25 0.5 0.75 1.0 1.5 2.0 3.0 4.0]
    #define SUN_SHEEN_FOCUS 0.45 // [0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.6]
    #define PLANT_GLOW 2.0 // [0.0 0.5 1.0 1.5 2.0 3.0 4.0 6.0]
    #define SHADE_FILL 0.7 // [0.0 0.2 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.25 1.5]

// Planet fog
    #define PLANET_FOG
    #define PLANET_FOG_DENSITY 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0 4.0]
    #define PLANET_FOG_BRIGHTNESS 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0 4.0]
    #define PLANET_FOG_HEIGHT 1.0 // [0.5 0.75 1.0 1.5 2.0 3.0 4.0]

// Exposure
    #define EXPOSURE_MODE 1 // [0 1 2]
    #define STEADY_LOCAL_ADAPTATION 0.5 // [0.0 0.05 0.1 0.15 0.2 0.3 0.4 0.5 0.75 1.0]
    #define STEADY_NIGHT_LIFT 0.55 // [0.25 0.4 0.55 0.7 0.85 1.0]
    #define EXPOSURE_DARK_LIMIT 1.0 // [0.0 0.25 0.5 1.0 2.0 4.0 8.0]

// TAA style: 0 Sundial's (history weight cut by speed, clip to twice the standard deviation), 1 sharp (history weight by
// distance and off-centre sampling, tight clip; abza/Temporal.glsl, abza/TaaClip.glsl)
    #define TAA_STYLE 0 // [0 1]

#include "/abza/World.glsl"

#define ABZA_EXPOSURE_FLOOR (ABZA_DARK_FLOOR * EXPOSURE_DARK_LIMIT)

// Refraction through glass and other translucent blocks: true bends only by the surface's normal map (a thin pane, as
// water), false also by the face itself (a solid block)
#ifdef THIN_GLASS_REFRACTION
    #define ABZA_THIN_GLASS true
#else
    #define ABZA_THIN_GLASS false
#endif

// Airless worlds: no distance haze from air and no light shafts
#if ABZA_AIR == 0
    #undef ATMOSPHERE_SCATTERING_FOG
    #undef VOLUMETRIC_LIGHT
    #undef VOLUMETRIC_FOG
#endif

// Worlds without direct light: no shadow filtering
#if ABZA_DIRECT_LIGHT == 0
    #undef PCSS
    #undef SCREEN_SPACE_SHADOW
#endif

#ifdef PLANET_FOG
    #if ABZA_FOG == 1
        #define ABZA_PLANET_FOG 1
    #endif
#endif

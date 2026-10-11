//
//  ABZA Shader: worlds without clouds
//

#include "/abza/World.glsl"

// Lowest height of the sun or moon (world-space Y of its direction) that still lights any part of the realistic cloud layer.
// Below it the planet blocks the light at every cloud sample (atmosphereAbsorptionGround is 0), with a margin for clouds up to 50 km away.
#define ABZA_CLOUD_LIGHT_HORIZON (-sqrt(2.0 * (CLOUD_REALISTIC_HEIGHT + CLOUD_REALISTIC_THICKNESS) / earthRadius) - 0.01)

#if ABZA_CLOUDS == 0
    #undef CLOUD_TYPE
    #define CLOUD_TYPE 0
    #undef PLANE_CLOUD
#endif

// Realistic clouds computed at half resolution (deferred13) and blended in at full resolution (composite4), in ABZA's world folders
#define CLOUD_HALF_RES

#ifdef CLOUD_HALF_RES
    #if CLOUD_TYPE == 2 && defined ABZA_WORLD
        #define ABZA_HALF_RES_CLOUDS
    #endif
#endif

// Reflections that reach the sky take the half-resolution clouds where the reflected direction is on screen (composite0)
#define REFLECTION_SKY_REUSE

#ifdef REFLECTION_SKY_REUSE
    #ifdef ABZA_HALF_RES_CLOUDS
        #define ABZA_REFLECTED_HALF_RES_CLOUDS
    #endif
#endif

//
//  Umbra (abza:umbra)
//

// No star moves with the time of day in this sky.

// Fixed time: midnight
#define ABZA_FIXED_TIME 1

// No air and no clouds
#define ABZA_AIR 0
#define ABZA_CLOUDS 0

// No sky light, and no direct light by day or night
#define ABZA_DIRECT_LIGHT 0
#define ABZA_SKYLIGHT 0
#define ABZA_DAY_LIGHT vec3(0.0)
#define ABZA_NIGHT_LIGHT vec3(0.0)

// Lowest scene brightness exposure adapts to
#define ABZA_DARK_FLOOR 0.02

// Planet fog
#define ABZA_FOG 1
#define ABZA_FOG_DENSITY_DRY 0.012
#define ABZA_FOG_DENSITY_WET 0.012
#define ABZA_FOG_BASE 50.0
#define ABZA_FOG_FALLOFF 16.0
#define ABZA_FOG_GLOW 0.0006
#define ABZA_FOG_RAIN 0.0

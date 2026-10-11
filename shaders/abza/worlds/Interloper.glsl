//
//  Interloper (abza:interloper)
//

// Half-size of the star Ad Astra draws ("scale" in the world's planet renderer file)
#define ABZA_STAR_SCALE 8.0

// No air and no clouds
#define ABZA_AIR 0
#define ABZA_CLOUDS 0

// Direct light by day and by night, and the sunlight part of the sky-light fill
#define ABZA_DAY_LIGHT vec3(0.95)
#define ABZA_AMBIENT 0.5

// Lowest scene brightness exposure adapts to
#define ABZA_DARK_FLOOR 0.006

// Planet fog
#define ABZA_FOG 1
#define ABZA_FOG_DENSITY_DRY 0.006
#define ABZA_FOG_DENSITY_WET 0.0135
#define ABZA_FOG_BASE 62.0
#define ABZA_FOG_FALLOFF 14.0
#define ABZA_FOG_GLOW 0.0
#define ABZA_FOG_RAIN 1.0

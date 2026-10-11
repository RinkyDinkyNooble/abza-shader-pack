//
//  Cinder (abza:cinder)
//

// No star moves with the time of day in this sky.

// Fixed time: always night
#define ABZA_FIXED_TIME 1

// No air and no clouds
#define ABZA_AIR 0
#define ABZA_CLOUDS 0

// Direct light by day and by night, and the sunlight part of the sky-light fill
#define ABZA_DAY_LIGHT vec3(1.05, 0.82, 0.63)
#define ABZA_NIGHT_LIGHT vec3(1.2, 2.0, 2.2)
#define ABZA_AMBIENT 0.5

// Lowest scene brightness exposure adapts to
#define ABZA_DARK_FLOOR 0.01

// Planet fog
#define ABZA_FOG 1
#define ABZA_FOG_DENSITY_DRY 0.009
#define ABZA_FOG_DENSITY_WET 0.009
#define ABZA_FOG_BASE 70.0
#define ABZA_FOG_FALLOFF 20.0
#define ABZA_FOG_GLOW 0.003
#define ABZA_FOG_RAIN 0.0

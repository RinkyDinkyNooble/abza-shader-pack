//
//  Earth Orbit (ad_astra:earth_orbit)
//

// Half-size of the star Ad Astra draws ("scale" in the world's planet renderer file)
#define ABZA_STAR_SCALE 10.0

// No air and no clouds
#define ABZA_AIR 0
#define ABZA_CLOUDS 0

// Direct light by day and by night, and the sunlight part of the sky-light fill
#define ABZA_DAY_LIGHT vec3(1.05)
#define ABZA_AMBIENT 0.35

// Lowest scene brightness exposure adapts to
#define ABZA_DARK_FLOOR 0.006

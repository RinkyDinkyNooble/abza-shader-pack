//
//  Moon (ad_astra:moon)
//

// Half-size of the star Ad Astra draws ("scale" in the world's planet renderer file)
#define ABZA_STAR_SCALE 9.0

// No air and no clouds
#define ABZA_AIR 0
#define ABZA_CLOUDS 0

// Direct light by day and by night, and the sunlight part of the sky-light fill
#define ABZA_DAY_LIGHT vec3(1.05)
#define ABZA_NIGHT_LIGHT vec3(0.8, 0.9, 1.1)
#define ABZA_AMBIENT 0.4

// Exposure multiplier by day and by night
#define ABZA_DAY_EXPOSURE 0.5
#define ABZA_NIGHT_EXPOSURE 0.75

// Lowest scene brightness exposure adapts to
#define ABZA_DARK_FLOOR 0.01

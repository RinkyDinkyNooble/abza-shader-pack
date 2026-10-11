//
//  Umbra Orbit (abza:umbra_orbit)
//

// Half-size of the star Ad Astra draws ("scale" in the world's planet renderer file)
#define ABZA_STAR_SCALE 6.0

// Texture Ad Astra draws the star with: 0 sun.png, 1 red_sun.png
#define ABZA_STAR_TEXTURE 1

// No air and no clouds
#define ABZA_AIR 0
#define ABZA_CLOUDS 0

// Direct light by day and by night, and the sunlight part of the sky-light fill
#define ABZA_DAY_LIGHT vec3(1.05, 0.82, 0.63)
#define ABZA_AMBIENT 0.35

// Lowest scene brightness exposure adapts to
#define ABZA_DARK_FLOOR 0.006

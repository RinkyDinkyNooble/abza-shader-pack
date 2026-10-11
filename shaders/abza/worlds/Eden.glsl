//
//  Eden (abza:eden)
//

// Half-size of the star Ad Astra draws ("scale" in the world's planet renderer file)
#define ABZA_STAR_SCALE 10.0

// Texture Ad Astra draws the star with: 0 sun.png, 1 red_sun.png
#define ABZA_STAR_TEXTURE 1

// Direct light from the red sun
#define ABZA_DAY_LIGHT vec3(1.0, 0.8, 0.66)

// Clouds: more than Earth's
#define ABZA_CLOUD_AMOUNT 0.1

// Volumetric fog: denser than Earth's, in the biome's fog colour
#define ABZA_MIST_DRY 2.0
#define ABZA_MIST_WET 2.0
#define ABZA_MIST_TINT 1

// Planet fog
#define ABZA_FOG 1
#define ABZA_FOG_DENSITY_DRY 0.00375
#define ABZA_FOG_DENSITY_WET 0.00375
#define ABZA_FOG_BASE 63.0
#define ABZA_FOG_FALLOFF 14.0
#define ABZA_FOG_GLOW 0.0
#define ABZA_FOG_RAIN 1.5

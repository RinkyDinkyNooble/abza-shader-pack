//
//  ABZA Shader: per-world settings
//

#ifndef ABZA_WORLD_SETTINGS
#define ABZA_WORLD_SETTINGS 1

#if defined ABZA_WORLD_EARTH
    #include "/abza/worlds/Earth.glsl"
#elif defined ABZA_WORLD_EARTH_ORBIT
    #include "/abza/worlds/EarthOrbit.glsl"
#elif defined ABZA_WORLD_MOON
    #include "/abza/worlds/Moon.glsl"
#elif defined ABZA_WORLD_MOON_ORBIT
    #include "/abza/worlds/MoonOrbit.glsl"
#elif defined ABZA_WORLD_INTERLOPER
    #include "/abza/worlds/Interloper.glsl"
#elif defined ABZA_WORLD_INTERLOPER_ORBIT
    #include "/abza/worlds/InterloperOrbit.glsl"
#elif defined ABZA_WORLD_CINDER
    #include "/abza/worlds/Cinder.glsl"
#elif defined ABZA_WORLD_CINDER_ORBIT
    #include "/abza/worlds/CinderOrbit.glsl"
#elif defined ABZA_WORLD_EDEN
    #include "/abza/worlds/Eden.glsl"
#elif defined ABZA_WORLD_EDEN_ORBIT
    #include "/abza/worlds/EdenOrbit.glsl"
#elif defined ABZA_WORLD_UMBRA
    #include "/abza/worlds/Umbra.glsl"
#elif defined ABZA_WORLD_UMBRA_ORBIT
    #include "/abza/worlds/UmbraOrbit.glsl"
#endif

// Values a world file doesn't set

// Texture Ad Astra draws the star with: 0 sun.png, 1 red_sun.png
#ifndef ABZA_STAR_TEXTURE
    #define ABZA_STAR_TEXTURE 0
#endif

// 1 where the time of day never changes
#ifndef ABZA_FIXED_TIME
    #define ABZA_FIXED_TIME 0
#endif

// Air: 1 keeps the atmosphere (sky scattering, distance haze, light shafts); 0 leaves a black sky
#ifndef ABZA_AIR
    #define ABZA_AIR 1
#endif

// Sky light: 0 where the dimension has none
#ifndef ABZA_DIRECT_LIGHT
    #define ABZA_DIRECT_LIGHT 1
#endif
#ifndef ABZA_SKYLIGHT
    #define ABZA_SKYLIGHT 1
#endif

// Clouds: 1 draws the shader's clouds
#ifndef ABZA_CLOUDS
    #define ABZA_CLOUDS 1
#endif

// Change to the realistic cloud amount: a fixed part, and a part per unit of biome rainfall away from 0.5
#ifndef ABZA_CLOUD_AMOUNT
    #define ABZA_CLOUD_AMOUNT 0.0
#endif
#ifndef ABZA_CLOUD_HUMIDITY
    #define ABZA_CLOUD_HUMIDITY 0.0
#endif

// Colour and strength of direct light: by day, and by night relative to the night brightness option
#ifndef ABZA_DAY_LIGHT
    #define ABZA_DAY_LIGHT vec3(1.0)
#endif
#ifndef ABZA_NIGHT_LIGHT
    #define ABZA_NIGHT_LIGHT vec3(1.0)
#endif

// Strength of the sunlight part of the sky-light fill
#ifndef ABZA_AMBIENT
    #define ABZA_AMBIENT 1.0
#endif

// Exposure multiplier by day and by night
#ifndef ABZA_DAY_EXPOSURE
    #define ABZA_DAY_EXPOSURE 1.0
#endif
#ifndef ABZA_NIGHT_EXPOSURE
    #define ABZA_NIGHT_EXPOSURE 1.0
#endif

// Lowest scene brightness exposure adapts to (0 is no limit)
#ifndef ABZA_DARK_FLOOR
    #define ABZA_DARK_FLOOR 0.0
#endif

// Volumetric fog density multiplier in dry and wet biomes; 1 tints it with the biome's fog colour
#ifndef ABZA_MIST_DRY
    #define ABZA_MIST_DRY 1.0
#endif
#ifndef ABZA_MIST_WET
    #define ABZA_MIST_WET 1.0
#endif
#ifndef ABZA_MIST_TINT
    #define ABZA_MIST_TINT 0
#endif

// Planet fog: a height haze in the biome's fog colour
//   ABZA_FOG_DENSITY_DRY, ABZA_FOG_DENSITY_WET: density per block at the base height, in dry and wet biomes
//   ABZA_FOG_BASE: height (Y) the density starts falling off from
//   ABZA_FOG_FALLOFF: blocks above the base for the density to drop to 37%
//   ABZA_FOG_GLOW: light the fog gives off itself
//   ABZA_FOG_RAIN: extra density in rain, as a share of the normal density
#ifndef ABZA_FOG
    #define ABZA_FOG 0
#endif
#ifndef ABZA_FOG_DENSITY_DRY
    #define ABZA_FOG_DENSITY_DRY 0.0
#endif
#ifndef ABZA_FOG_DENSITY_WET
    #define ABZA_FOG_DENSITY_WET 0.0
#endif
#ifndef ABZA_FOG_BASE
    #define ABZA_FOG_BASE 63.0
#endif
#ifndef ABZA_FOG_FALLOFF
    #define ABZA_FOG_FALLOFF 32.0
#endif
#ifndef ABZA_FOG_GLOW
    #define ABZA_FOG_GLOW 0.0
#endif
#ifndef ABZA_FOG_RAIN
    #define ABZA_FOG_RAIN 0.0
#endif

#endif

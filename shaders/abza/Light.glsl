//
//  ABZA Shader: per-world light
//

// Time-of-day and rain darkening the game applies to the fog colour, and the biome's rainfall eased over a few seconds (shaders.properties)
uniform vec3 abzaFogDivisor;
uniform float abzaHumidity;

// Change to the realistic cloud amount in the current biome
#define ABZA_CLOUD_EXTRA (ABZA_CLOUD_AMOUNT + ABZA_CLOUD_HUMIDITY * (abzaHumidity - 0.5))

// Direct light from the sun by day and the moon by night.
// With air, the atmosphere colours it (Sundial's sunlightColor); without, it stays white and only the horizon cuts it off.
vec3 abzaSunColor() {
    float day = clamp(sunDirection.y * 1e+5, 0.0, 1.0);
    #if ABZA_AIR == 1
        vec3 light = sunlightColor;
    #else
        vec3 light = vec3(clamp(shadowDirection.y * 30.0, 0.0, 1.0));
    #endif
    return light * mix(ABZA_NIGHT_LIGHT * nightBrightness, ABZA_DAY_LIGHT, day);
}

// Exposure multiplier for the time of day; with exposure off, the day value (worlds with a fixed time keep theirs)
float abzaExposureScale() {
    #if EXPOSURE_MODE == 2 && ABZA_FIXED_TIME == 0 && defined ABZA_WORLD
        return ABZA_DAY_EXPOSURE;
    #else
        return mix(ABZA_NIGHT_EXPOSURE, ABZA_DAY_EXPOSURE, smoothstep(-0.1, 0.1, sunDirection.y));
    #endif
}

// Linear fog colour of the current biome, scaled so its brightest channel is 1
vec3 abzaFogAlbedo() {
    vec3 color = max(fogColor / max(abzaFogDivisor, vec3(0.02)), vec3(1e-6));
    color /= max(color.r, max(color.g, color.b));
    return pow(color, vec3(2.2));
}

// Colour of the volumetric fog
vec3 abzaMistTint() {
    #if ABZA_MIST_TINT == 1
        return abzaFogAlbedo();
    #else
        return vec3(1.0);
    #endif
}

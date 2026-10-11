//
//  ABZA Shader: planet fog
//

// The fog's density is constant up to the base height and falls off exponentially above it.
// Integral of that density profile from the base height to height y (negative below the base).
#define ABZA_FOG_FALLOFF_SCALED (ABZA_FOG_FALLOFF * PLANET_FOG_HEIGHT)

float abzaFogHeightIntegral(float y) {
    float above = y - ABZA_FOG_BASE;
    return above < 0.0 ? above : ABZA_FOG_FALLOFF_SCALED * (1.0 - exp(-above / ABZA_FOG_FALLOFF_SCALED));
}

// Length of a ray weighted by the density profile: start height, vertical direction, length in blocks
float abzaFogRayLength(float startY, float dirY, float rayLength) {
    float rise = dirY * rayLength;
    if (abs(rise) < 0.01) {
        return rayLength * exp(-max(startY + 0.5 * rise - ABZA_FOG_BASE, 0.0) / ABZA_FOG_FALLOFF_SCALED);
    }
    return (abzaFogHeightIntegral(startY + rise) - abzaFogHeightIntegral(startY)) / dirY;
}

// Distance to the farthest terrain drawn, where rays toward the sky end
float abzaFogFarthest() {
    #ifdef LOD
        return max(lodRenderDistance(), far);
    #else
        return far;
    #endif
}

// Applies the fog along a ray segment.
// startPos: segment start relative to the camera; rayLength: blocks; skyLight: sky light where the light is measured (0 to 1).
// In caves the fog is thinner and only its own glow lights it.
vec3 abzaPlanetFog(vec3 color, vec3 startPos, vec3 worldDir, float rayLength, float skyLight, vec3 skyColor) {
    #if ABZA_SKYLIGHT == 0
        skyLight = 1.0;
    #endif
    float density = mix(ABZA_FOG_DENSITY_DRY, ABZA_FOG_DENSITY_WET, abzaHumidity) * PLANET_FOG_DENSITY;
    density *= (1.0 + ABZA_FOG_RAIN * weatherStrength) * (0.25 + 0.75 * skyLight);
    rayLength = min(rayLength, abzaFogFarthest());
    float transmittance = exp(-density * abzaFogRayLength(startPos.y + cameraPosition.y, worldDir.y, rayLength));

    float LdotV = dot(worldDir, shadowDirection);
    vec3 fogLight = sunColor * (60.0 * SUNLIGHT_BRIGHTNESS * (1.0 - 0.5 * sqrt(weatherStrength)) * miePhase(LdotV, 0.4, 0.16));
    fogLight += skyColor * 0.8 + sunColor * (2.0 * ABZA_AMBIENT * SUNLIGHT_BRIGHTNESS);
    fogLight = fogLight * (skyLight * skyLight) + ABZA_FOG_GLOW;
    vec3 fogRadiance = abzaFogAlbedo() * fogLight * PLANET_FOG_BRIGHTNESS;

    return mix(fogRadiance, color, transmittance);
}

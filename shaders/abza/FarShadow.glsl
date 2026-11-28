//
//  ABZA Shader: Shaders Companion's far shadow map (the mod's API.md, "Far terrain", "The far shadow map"): the far
//  terrain drawn from the light into two cascades, read past the shadow map's reach by far and near texels alike, blended
//  in across the shadow map's edge, and by the light shafts' samples. Needs libs/Shadow.glsl and abza/FarTerrain.glsl.
//

#ifndef ABZA_FAR_SHADOW_GLSL
#define ABZA_FAR_SHADOW_GLSL

#if defined ABZA_FAR_SHADOWS && (defined SHADOW_AND_SKY || defined END_FLASH)
    #define ABZA_FAR_SHADOW_MAP
#endif

#ifdef ABZA_FAR_SHADOW_MAP
    // far_shadow: depth from the light, cascade 0 in the left half, cascade 1 in the right half, compared (less or equal)
    uniform sampler2DShadow scFarShadow;

    // far_info texels 4 to 11: (1 when ready, cascade size, depth per block of cascade 0, of cascade 1), three rows per
    // cascade from player space to its (u, v, depth), (texel size in blocks of cascade 0, of cascade 1)
    bool abzaFarShadowReady() {
        return abzaFarDrawn() && textureSize(scFarInfo, 0).x >= 12 && texelFetch(scFarInfo, ivec2(4, 0), 0).x == 1.0;
    }

    vec3 abzaFarShadowCoord(int cascade, vec3 worldPos) {
        int at = 5 + cascade * 3;
        vec4 u = texelFetch(scFarInfo, ivec2(at, 0), 0);
        vec4 v = texelFetch(scFarInfo, ivec2(at + 1, 0), 0);
        vec4 d = texelFetch(scFarInfo, ivec2(at + 2, 0), 0);
        return vec3(dot(u.xyz, worldPos) + u.w, dot(v.xyz, worldPos) + v.w, dot(d.xyz, worldPos) + d.w);
    }

    // One comparison at a cascade coordinate (bilinear over 2 x 2 texels), kept inside the cascade's half
    float abzaFarShadowTap(int cascade, vec2 coord, float depth, float size) {
        coord = clamp(coord, vec2(0.5 / size), vec2(1.0 - 0.5 / size));
        return texture(scFarShadow, vec3((coord.x + float(cascade)) * 0.5, coord.y, depth));
    }

    // Four comparisons on a circle of 0.75 texels, turned by noise (0 to 1)
    float abzaFarShadowFilter(int cascade, vec3 coord, float depth, float size, float noise) {
        float angle = noise * 6.2831853;
        vec2 a = vec2(cos(angle), sin(angle)) * (0.75 / size);
        vec2 b = vec2(-a.y, a.x);
        return 0.25 * (
            abzaFarShadowTap(cascade, coord.xy + a, depth, size) + abzaFarShadowTap(cascade, coord.xy - a, depth, size) +
            abzaFarShadowTap(cascade, coord.xy + b, depth, size) + abzaFarShadowTap(cascade, coord.xy - b, depth, size)
        );
    }

    // A surface point's share of the light from the far shadow map: cascade 0 where the point lies in it, cascade 1
    // beyond, blended over cascade 0's last 15%; 1 outside both. The lookup moves 1.5 texels out along the surface's
    // geometry normal and half a texel toward the light.
    float abzaFarShadowLight(vec3 worldPos, vec3 worldGeoNormal, float noise) {
        vec4 head = texelFetch(scFarInfo, ivec2(4, 0), 0);
        vec2 texelBlocks = texelFetch(scFarInfo, ivec2(11, 0), 0).xy;
        vec3 coord = abzaFarShadowCoord(0, worldPos + worldGeoNormal * (1.5 * texelBlocks.x));
        float edge = max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 2.0;
        float far = smoothstep(0.85, 1.0, edge);
        float light = 0.0;
        if (far < 1.0) {
            light = abzaFarShadowFilter(0, coord, coord.z - (0.25 + 0.5 * texelBlocks.x) * head.z, head.y, noise) * (1.0 - far);
        }
        if (far > 0.0) {
            coord = abzaFarShadowCoord(1, worldPos + worldGeoNormal * (1.5 * texelBlocks.y));
            float farLight = 1.0;
            if (all(lessThan(abs(coord.xy - 0.5), vec2(0.5)))) {
                farLight = abzaFarShadowFilter(1, coord, coord.z - (0.25 + 0.5 * texelBlocks.y) * head.w, head.y, noise);
            }
            light += farLight * far;
        }
        return light;
    }

    // A point's share of the light from the far shadow map, for the light shafts' samples (in the air: no normal, one
    // comparison); casters within minDistance blocks toward the light are left out. 1 outside both cascades.
    float abzaFarShadowPoint(vec3 worldPos, float minDistance) {
        vec4 head = texelFetch(scFarInfo, ivec2(4, 0), 0);
        vec3 coord = abzaFarShadowCoord(0, worldPos);
        if (all(lessThan(abs(coord.xy - 0.5), vec2(0.5)))) {
            return abzaFarShadowTap(0, coord.xy, coord.z - minDistance * head.z, head.y);
        }
        coord = abzaFarShadowCoord(1, worldPos);
        if (all(lessThan(abs(coord.xy - 0.5), vec2(0.5)))) {
            return abzaFarShadowTap(1, coord.xy, coord.z - minDistance * head.w, head.y);
        }
        return 1.0;
    }
#endif

// The far terrain's shadow on a texel's sunlight, after the shadow map's lookup (which holds only the chunk terrain
// around the camera): Deferred11 for every opaque texel, Composite5 for water and glass. Where the shadow map doesn't
// reach (and across its last stretch, blended), the texel takes what the lookup gives outside the shadow map (sky light
// and the normal's factor, as libs/Shadow.glsl's branch) times the far shadow map's light. worldPos and worldGeoNormal as
// the lookup takes them; NdotL, smoothness, porosity and skyLight as the lookup took them; noise 0 to 1; shadowBefore and
// subsurfaceBefore the lookup's inputs, shadow and subsurfaceScattering its results.
void abzaFarShadow(
    vec3 worldPos, vec3 worldGeoNormal, float NdotL, float smoothness, float porosity, float skyLight, float noise,
    vec3 shadowBefore, vec3 subsurfaceBefore, inout vec3 shadow, inout vec3 subsurfaceScattering
) {
    #ifdef ABZA_FAR_SHADOW_MAP
        if (weatherStrength >= 0.999) {
            return;
        }
        // 0 within the shadow map, 1 past its edge (the square of the shadow distance in the light's plane)
        vec3 shadowCoord = worldPosToShadowCoordNoDistort(worldPos);
        float outside = smoothstep(0.8, 0.95, max(abs(shadowCoord.x), abs(shadowCoord.y)));
        if (outside <= 0.0 || !abzaFarShadowReady()) {
            return;
        }
        float light = abzaFarShadowLight(worldPos, worldGeoNormal, noise);
        #ifdef PCSS
            float normalFactor = clamp(pow(max(NdotL, 0.0), pow2(1.0 - smoothness * 0.3)), 0.0, 1.0);
        #else
            float normalFactor = clamp(pow(max(NdotL, 0.0), pow2(1.0 - min(0.3, smoothness))), 0.0, 1.0);
        #endif
        float scatterNdotL = abs(dot(worldGeoNormal, shadowDirection));
        scatterNdotL = scatterNdotL + (1.0 - scatterNdotL) * clamp(porosity * 255.0 / 191.0 - 64.0 / 191.0, 0.0, 1.0);
        vec3 openShadow = shadowBefore * (skyLight * normalFactor);
        vec3 openScattering = subsurfaceBefore * (clamp(SUBSERFACE_SCATTERING_STRENTGH * 1e+10, 0.0, 1.0) * skyLight * (1.0 - normalFactor) * scatterNdotL *
            step(64.5 / 255.0, porosity));
        shadow = mix(shadow, openShadow * light, outside);
        subsurfaceScattering = mix(subsurfaceScattering, openScattering * light, outside);
    #endif
}

#endif

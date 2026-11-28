//
//  ABZA Shader: Shaders Companion's mirror views lit by the pack's own lighting, for reflections to read: sunlight
//  with soft shadows, light through plants and the sun's highlight as Deferred11 lights terrain, and sky light and
//  block light as Deferred12 does, with ambient occlusion from the mirror view's own surfaces (Deferred12's own
//  occlusion and bounce light need the screen). Water and glass are drawn over what the mod's copy of the view shows
//  behind them. Surfaces farther along the reflection than COMPANION_MIRROR_DETAIL blocks get hard shadows, no
//  occlusion and calm water. The mod's far terrain in the views is lit as the chunk terrain is, with the far terrain's
//  shadows past the shadow map (abza/FarShadow.glsl). colortex14 holds one screen-sized tile per mirrored plane, side by side (its
//  size.buffer in shaders.properties), in the order of the mod's info rows.
//

#define ABZA_MIRROR_LIGHT_PASS
#include "/programs/deferred/Deferred11.frag"
#define ABZA_SHADOW_INCLUDED

/*
const int colortex14Format = RGBA16F;
*/

layout(location = 0) out vec4 texBuffer14;

#ifdef SHADOW_AND_SKY
    in vec3 skyColorUp;
#else
    const vec3 skyColorUp = vec3(0.0);
#endif

#include "/abza/Companion.glsl"
#include "/abza/RainCover.glsl"
// Steady ambient occlusion: the screen's occlusion and crease shading from the lattice, for surfaces in the views too
#include "/abza/LatticeAO.glsl"

#ifdef ABZA_MIRROR_LIGHTING
    uniform sampler2D scMirrorAlbedo;
    uniform sampler2D scMirrorData;
    uniform sampler2D scMirrorDistance;
    uniform sampler2D scMirrorInfo;
    #ifdef ABZA_MIRROR_BEHIND
        uniform sampler2D scMirrorBehindAlbedo;
        uniform sampler2D scMirrorBehindData;
        uniform sampler2D scMirrorBehindDistance;
    #endif

    #define ABZA_MIRROR_AO_SAMPLES 8
    // Water with nothing drawn under it counts as this deep (blocks)
    #define ABZA_MIRROR_DEEP_WATER 64.0
    #define ABZA_MIRROR_AO_RADIUS 3.0
    #define ABZA_MIRROR_AO_STRENGTH 1.5

    // A plane's mirror view, for finding its texels' surface points: fromClip takes clip coordinates to positions
    // relative to the view's origin, and eye is where the view's rays start, relative to the origin (view bobbing moves
    // it off the origin, which the texels' distances are measured from). Texels are counted within the view; tile is
    // the view's corner in the mod's textures.
    struct AbzaMirrorView {
        mat4 fromClip;
        vec3 origin;
        vec3 eye;
        vec2 size;
        ivec2 tile;
    };

    AbzaMirrorView abzaMirrorViewOf(mat4 toClip, vec3 origin, vec2 size, ivec2 tile) {
        AbzaMirrorView view;
        mat4 toLocalClip = toClip;
        toLocalClip[3] = toClip * vec4(origin, 1.0);
        view.fromClip = inverse(toLocalClip);
        vec4 eyePoint = view.fromClip * vec4(0.0, 0.0, 1.0, 0.0);
        view.eye = eyePoint.xyz / eyePoint.w;
        view.origin = origin;
        view.size = size;
        view.tile = tile;
        return view;
    }

    // A texel of the view (counted within it) in one of the mod's textures
    vec4 abzaMirrorFetch(sampler2D mirrorTexture, AbzaMirrorView view, ivec2 texel) {
        return texelFetch(mirrorTexture, view.tile + texel, 0);
    }

    // A mirror view texel's surface point relative to the camera: the point on the texel's ray from the eye that lies
    // at the texel's distance from the origin
    vec3 abzaMirrorTexelPos(ivec2 texel, AbzaMirrorView view, float surface) {
        vec4 nearPoint = view.fromClip * vec4((vec2(texel) + 0.5) / view.size * 2.0 - 1.0, -1.0, 1.0);
        vec3 rayDir = normalize(nearPoint.xyz / nearPoint.w - view.eye);
        float along = dot(view.eye, rayDir);
        float reach = sqrt(max(along * along - dot(view.eye, view.eye) + surface * surface, 0.0)) - along;
        return view.origin + view.eye + rayDir * reach;
    }

    // Ambient occlusion from the mirror view's own surfaces, in place of Deferred12's screen-space occlusion: the
    // surfaces within ABZA_MIRROR_AO_RADIUS blocks that rise above the point's surface, found in a ring of texels.
    // Texels outside the view or the part of it the mod drew say nothing and are left out of the average, down to half
    // the samples (fewer would let one or two noisy samples decide alone).
    float abzaMirrorOcclusion(ivec2 texel, AbzaMirrorView view, vec3 worldPos, vec3 normal, float surface) {
        // Texels per block at this distance
        vec3 nextPos = abzaMirrorTexelPos(texel + ivec2(1, 0), view, surface);
        float texelsPerBlock = 1.0 / max(distance(nextPos, worldPos), 1e-4);
        float texelRadius = clamp(ABZA_MIRROR_AO_RADIUS * texelsPerBlock, 2.0, 256.0);
        // By the pixel, not texcoord: colortex14 is a screen wide per plane, and the noise must keep one texel a pixel
        vec2 noise = blueNoiseTemporal(gl_FragCoord.xy / screenSize).xy;
        float occlusion = 0.0;
        float samples = 0.0;
        for (int i = 0; i < ABZA_MIRROR_AO_SAMPLES; i++) {
            float angle = (float(i) + noise.x) * (2.0 * PI / float(ABZA_MIRROR_AO_SAMPLES));
            float radius = texelRadius * (0.2 + 0.8 * fract(noise.y + float(i) * 0.618034));
            ivec2 sampleTexel = texel + ivec2(round(vec2(cos(angle), sin(angle)) * radius));
            if (any(lessThan(sampleTexel, ivec2(0))) || any(greaterThanEqual(sampleTexel, ivec2(view.size)))) {
                continue;
            }
            float sampleSurface = abzaMirrorFetch(scMirrorDistance, view, sampleTexel).r;
            if (sampleSurface < -0.5) {
                continue;
            }
            samples += 1.0;
            if (sampleSurface <= 0.0) {
                continue;
            }
            vec3 offset = abzaMirrorTexelPos(sampleTexel, view, sampleSurface) - worldPos;
            float offsetLength = length(offset);
            occlusion += clamp(dot(offset, normal) / max(offsetLength, 1e-4) - 0.15, 0.0, 1.0) *
                (1.0 - smoothstep(0.5 * ABZA_MIRROR_AO_RADIUS, ABZA_MIRROR_AO_RADIUS, offsetLength));
        }
        return clamp(occlusion * ABZA_MIRROR_AO_STRENGTH / max(samples, 0.5 * float(ABZA_MIRROR_AO_SAMPLES)), 0.0, 1.0);
    }

    // The lit colour of a surface the mirror view shows, from its albedo and data texels: worldPos is its point relative
    // to the camera, rayDir the direction the view's ray reached it in. detailed: soft shadows and occlusion from the
    // view's own surfaces around texel (the surface at distance surface from the view's origin), else a single shadow
    // sample and no occlusion. opaque: an opaque surface, lit with its material class's values when it has one
    // (abza/ViewMaterial.glsl); water and glass keep their own look.
    vec3 abzaMirrorLightSurface(
        vec3 albedo, vec4 rawData, vec3 worldPos, vec3 rayDir, ivec2 texel, AbzaMirrorView view, float surface, bool detailed, bool opaque
    ) {
        uvec3 data = uvec3(round(rawData.rgb * 65535.0));
        vec3 normal = abzaCompanionOctDecode(vec2(float(data.r >> 8u), float(data.r & 255u)) / 255.0);
        // Surfaces drawn on both sides (plants, panes) face the ray, as Terrain.frag turns them to the camera
        normal = dot(normal, rayDir) > 0.0 ? -normal : normal;
        // With steady ambient occlusion the lattice's occlusion and crease shading, as Deferred12 shades the same
        // surface on screen (the view's own occlusion only where the lattice doesn't reach), else the view's own
        float latticeOcclusion = 0.0;
        float crease = 0.0;
        float latticeShare = 0.0;
        #ifdef ABZA_LATTICE_AO
            latticeShare = abzaLatticeOcclusionAt(worldPos, normal, false, latticeOcclusion, crease);
            crease *= latticeShare;
        #endif
        // The lattice's occlusion counts by its share: past its window (share 0) it may be 2 (no probe answers)
        float occlusion = latticeOcclusion * latticeShare;
        if (detailed && latticeShare < 1.0) {
            occlusion = mix(abzaMirrorOcclusion(texel, view, worldPos, normal, surface), latticeOcclusion, latticeShare);
        }
        float blockLevel = float(data.g >> 8u) / 255.0;
        float skyLevel = abzaOpenSkyLight(float(data.g & 255u) / 255.0, worldPos + cameraPosition, normal);
        int material = 0;
        float emissive;
        if (data.b >= 0xC000u) {
            // Distant Horizons materials: lava (6) and light sources (15)
            uint lodMaterial = data.b & 0xFFu;
            emissive = float(lodMaterial == 6u || lodMaterial == 15u);
        }
        else if (data.b >= 0x8000u) {
            // Entities: glowing layers such as eyes
            emissive = rawData.a;
        }
        else {
            material = abzaCompanionMaterial(int(data.b) - 1, normal);
            emissive = abzaCompanionEmission(albedo, int(data.b) - 1, blockLevel);
        }
        float porosity = abzaCompanionPorosity(material);
        bool plant = abzaCompanionPlant(material);
        albedo = pow(albedo, vec3(2.2));
        float NdotV = clamp(dot(-rayDir, normal), 0.0, 1.0);
        // The screen's material model: a rough surface (F0 0.04), or an opaque block's material class
        AbzaViewMaterial viewMaterial;
        abzaViewMaterial(opaque ? abzaViewTexelClass(data.b) : 0, albedo, viewMaterial);
        vec3 nightLight = abzaNightLight();

        vec3 color = albedo * emissive * PBR_BRIGHTNESS * PI;
        #if defined SHADOW_AND_SKY || defined END_FLASH
            // Deferred11's direct light, in world space
            vec3 shadowDiffuse = albedo * abzaViewDiffuse(viewMaterial, NdotV);
            vec3 shadow = sunColor * basicSunlight;
            #ifdef END_FLASH
                shadow = endFlashIntensity * vec3(0.5, 0.2, 0.8) * basicSunlight;
            #endif
            float NdotL = clamp(dot(normal, shadowDirection), 0.0, 1.0);
            vec3 shadowSpecular = abzaViewSunSpecular(viewMaterial, rayDir, normal, NdotL, NdotV) +
                abzaSunSheen(rayDir, shadowDirection, normal, NdotL, NdotV, viewMaterial.smoothness, viewMaterial.metalness, float(plant ? MAT_GRASS : MAT_DEFAULT));
            #ifdef SHADOW_AND_SKY
                #ifdef CLOUD_SHADOW
                    shadow *= cloudShadow(worldPos, shadowDirection);
                #endif
            #endif
            vec3 subsurfaceScattering = vec3(float(porosity > 64.5 / 255.0)) * shadow * shadowDiffuse;
            shadow *= shadowDiffuse + shadowSpecular;
            #ifdef ABZA_FAR_TERRAIN
                vec3 abzaShadowBefore = shadow;
                vec3 abzaSubsurfaceBefore = subsurfaceScattering;
            #endif
            #ifdef PCSS
                if (detailed) {
                    percentageCloserSoftShadow(
                        worldPos, normal, NdotL, length(worldPos), viewMaterial.smoothness, porosity, skyLevel, blueNoiseTemporal(gl_FragCoord.xy / screenSize).xy,
                        shadow, subsurfaceScattering
                    );
                }
                else
            #endif
            {
                singleSampleShadow(worldPos, normal, NdotL, viewMaterial.smoothness, porosity, skyLevel, shadow, subsurfaceScattering);
            }
            #ifdef ABZA_FAR_TERRAIN
                // Past the shadow map's reach, the far terrain's shadows from Shaders Companion's far shadow map
                abzaFarShadow(
                    worldPos, normal, NdotL, viewMaterial.smoothness, porosity, skyLevel, blueNoiseTemporal(gl_FragCoord.xy / screenSize).y,
                    abzaShadowBefore, abzaSubsurfaceBefore, shadow, subsurfaceScattering
                );
            #endif
            // Deferred12 shades Deferred11's direct light by a share of the crease shading (abzaCreaseDirect)
            color += (shadow + subsurfaceScattering * abzaPlantGlow(rayDir, shadowDirection)) * abzaCreaseLight(crease, CREASE_SHADING_DIRECT);
        #endif

        // Deferred12's ambient light, and the reflection Composite0 would add (none on a rough surface)
        color += albedo * abzaAmbientLight(blockLevel, skyLevel, worldPos, normal, plant, nightLight) * abzaViewAmbientWeight(viewMaterial, NdotV) *
            (1.0 - occlusion) * abzaCreaseLight(crease, 1.0);
        return color + abzaViewReflection(viewMaterial, rayDir, normal, worldPos, blockLevel, skyLevel, nightLight) * (1.0 - occlusion);
    }

    #ifdef ABZA_MIRROR_BEHIND
        // A water or glass surface of the mirror view (albedo with its alpha, data) over what the mod's copy of the view
        // shows behind it: water as the screen shows water, its colour over the depth to the surface under it and the
        // sky its waves reflect; glass tinting what lies behind it (as Composite5 stains it) under its own lit colour
        vec3 abzaMirrorTranslucent(
            vec4 albedo, vec4 rawData, vec3 worldPos, vec3 rayDir, ivec2 texel, AbzaMirrorView view, float surface, bool detailed
        ) {
            uvec3 data = uvec3(round(rawData.rgb * 65535.0));
            vec3 normal = abzaCompanionOctDecode(vec2(float(data.r >> 8u), float(data.r & 255u)) / 255.0);
            normal = dot(normal, rayDir) > 0.0 ? -normal : normal;
            float skyLevel = abzaOpenSkyLight(float(data.g & 255u) / 255.0, worldPos + cameraPosition, normal);
            bool water = abzaCompanionIsWater(data.b);

            // A mod without the copy (before 0.9.0) leaves Oculus's 16 x 16 missing texture bound instead
            bool behindKnown = textureSize(scMirrorBehindDistance, 0) == textureSize(scMirrorDistance, 0);
            if (!behindKnown && !water) {
                return abzaMirrorLightSurface(albedo.rgb, rawData, worldPos, rayDir, texel, view, surface, detailed, false);
            }
            float behindSurface = behindKnown ? abzaMirrorFetch(scMirrorBehindDistance, view, texel).r : 0.0;
            vec3 behind;
            float behindLength = ABZA_MIRROR_DEEP_WATER;
            if (behindSurface > surface) {
                vec3 behindPos = abzaMirrorTexelPos(texel, view, behindSurface);
                behind = abzaMirrorLightSurface(
                    abzaMirrorFetch(scMirrorBehindAlbedo, view, texel).rgb, abzaMirrorFetch(scMirrorBehindData, view, texel), behindPos, rayDir,
                    texel, view, behindSurface, false, true
                );
                behindLength = distance(behindPos, worldPos);
            }
            else {
                behind = water ? vec3(0.0) : abzaSkyColor(worldPos, rayDir, skyColorUp);
            }

            if (water) {
                vec3 waterColor = waterFogTotal(behind, rayDir, skyColorUp, behindLength, skyLevel);
                vec3 waterNormal = normal;
                if (detailed && normal.y > 0.9) {
                    // The waves, filtered for the water a texel covers
                    float texelSize = distance(abzaMirrorTexelPos(texel + ivec2(1, 0), view, surface), worldPos);
                    waterNormal = abzaWaterSurfaceNormal(worldPos, rayDir, texelSize / max(abs(rayDir.y), 0.05));
                }
                return abzaSkyReflection(waterColor, worldPos, rayDir, waterNormal, 0.02, skyLevel, skyColorUp);
            }

            vec3 lit = abzaMirrorLightSurface(albedo.rgb, rawData, worldPos, rayDir, texel, view, surface, detailed, false);
            vec3 tint = pow(albedo.rgb, vec3(2.2)) * (1.0 - 0.5 * albedo.a * albedo.a);
            vec3 stain = exp2(sqrt(albedo.a * 1.5) * log2(clamp(tint, 1e-5, 1.0)));
            return abzaSkyReflection(behind * stain + lit * albedo.a, worldPos, rayDir, normal, 0.04, skyLevel, skyColorUp);
        }
    #endif
#endif

#ifdef ABZA_MIRROR_LIGHTING
    // A mirror view texel lit with full detail or the simpler look
    vec3 abzaMirrorTexelColor(
        vec4 albedo, vec4 rawData, vec3 worldPos, vec3 rayDir, ivec2 texel, AbzaMirrorView view, float surface, bool detailed
    ) {
        #ifdef ABZA_MIRROR_BEHIND
            // Water and glass: alpha below 1 (the mod writes 1 on opaque surfaces)
            if (albedo.a < 0.999) {
                return abzaMirrorTranslucent(albedo, rawData, worldPos, rayDir, texel, view, surface, detailed);
            }
        #endif
        return abzaMirrorLightSurface(albedo.rgb, rawData, worldPos, rayDir, texel, view, surface, detailed, albedo.a > 0.999);
    }
#endif

void main() {
    texBuffer14 = vec4(0.0);
    #ifdef ABZA_MIRROR_LIGHTING
        // This pixel's tile of colortex14 (one screen each), the info row of the same plane, and the plane's view texel
        // under the pixel
        int row = min(int(gl_FragCoord.x / screenSize.x), ABZA_MIRROR_PLANES - 1);
        vec2 local = vec2(gl_FragCoord.x - float(row) * screenSize.x, gl_FragCoord.y) / screenSize;
        vec4 header = texelFetch(scMirrorInfo, ivec2(0, row), 0);
        if (abs(header.x - 4242.0) > 0.5 || abs(header.y - float(ABZA_MIRROR_PROTOCOL)) > 0.5 || header.z < 1.0) {
            return;
        }
        ivec2 mirrorTexel = min(ivec2(local * header.zw), ivec2(header.zw) - 1);
        vec3 origin = texelFetch(scMirrorInfo, ivec2(2, row), 0).xyz;
        mat4 toClip = mat4(
            texelFetch(scMirrorInfo, ivec2(3, row), 0), texelFetch(scMirrorInfo, ivec2(4, row), 0),
            texelFetch(scMirrorInfo, ivec2(5, row), 0), texelFetch(scMirrorInfo, ivec2(6, row), 0)
        );
        AbzaMirrorView view = abzaMirrorViewOf(toClip, origin, header.zw, ivec2(texelFetch(scMirrorInfo, ivec2(8, row), 0).yz));
        float surface = abzaMirrorFetch(scMirrorDistance, view, mirrorTexel).r;
        if (surface <= 0.0) {
            return;
        }
        vec4 albedo = abzaMirrorFetch(scMirrorAlbedo, view, mirrorTexel);
        vec4 rawData = abzaMirrorFetch(scMirrorData, view, mirrorTexel);
        vec3 worldPos = abzaMirrorTexelPos(mirrorTexel, view, surface);
        vec3 rayDir = normalize(worldPos - view.origin - view.eye);
        // Full detail out to COMPANION_MIRROR_DETAIL blocks along the reflection and the simpler look past it, blended
        // over the last eighth of that distance so the change doesn't show as a line that moves with the camera
        #if COMPANION_MIRROR_DETAIL > 0
            float detail = 1.0 - smoothstep(float(COMPANION_MIRROR_DETAIL) * 0.875, float(COMPANION_MIRROR_DETAIL), surface);
        #else
            const float detail = 0.0;
        #endif
        vec3 color = abzaMirrorTexelColor(albedo, rawData, worldPos, rayDir, mirrorTexel, view, surface, detail > 0.5);
        if (detail > 0.001 && detail < 0.999) {
            color = mix(color, abzaMirrorTexelColor(albedo, rawData, worldPos, rayDir, mirrorTexel, view, surface, detail <= 0.5), abs(detail - float(detail > 0.5)));
        }
        texBuffer14 = vec4(color, 1.0);
    #endif
}

/* RENDERTARGETS: 14 */

#define ABZA_NAN_PASS 7
#define ABZA_NAN_TILED
#define ABZA_NAN_OUTPUTS abzaNanBad(texBuffer14)
#include "/abza/NanDebugMain.glsl"

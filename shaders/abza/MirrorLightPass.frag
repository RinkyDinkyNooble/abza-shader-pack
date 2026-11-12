//
//  ABZA Shader: Shaders Companion's mirror view lit by the pack's own lighting, for reflections to read: sunlight
//  with soft shadows, light through plants and the sun's highlight as Deferred11 lights terrain, and sky light and
//  block light as Deferred12 does, with ambient occlusion from the mirror view's own surfaces (Deferred12's own
//  occlusion and bounce light need the screen)
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

#ifdef ABZA_MIRROR_LIGHTING
    uniform sampler2D scMirrorAlbedo;
    uniform sampler2D scMirrorData;
    uniform sampler2D scMirrorDistance;
    uniform sampler2D scMirrorInfo;

    #define ABZA_MIRROR_AO_SAMPLES 8
    #define ABZA_MIRROR_AO_RADIUS 3.0
    #define ABZA_MIRROR_AO_STRENGTH 1.5

    // The mirror view, for finding its texels' surface points: fromClip takes clip coordinates to positions relative
    // to the view's origin, and eye is where the view's rays start, relative to the origin (view bobbing moves it off
    // the origin, which the texels' distances are measured from)
    struct AbzaMirrorView {
        mat4 fromClip;
        vec3 origin;
        vec3 eye;
        vec2 size;
    };

    AbzaMirrorView abzaMirrorViewOf(mat4 toClip, vec3 origin, vec2 size) {
        AbzaMirrorView view;
        mat4 toLocalClip = toClip;
        toLocalClip[3] = toClip * vec4(origin, 1.0);
        view.fromClip = inverse(toLocalClip);
        vec4 eyePoint = view.fromClip * vec4(0.0, 0.0, 1.0, 0.0);
        view.eye = eyePoint.xyz / eyePoint.w;
        view.origin = origin;
        view.size = size;
        return view;
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
    // surfaces within ABZA_MIRROR_AO_RADIUS blocks that rise above the point's surface, found in a ring of texels
    float abzaMirrorOcclusion(ivec2 texel, AbzaMirrorView view, vec3 worldPos, vec3 normal, float surface) {
        // Texels per block at this distance
        vec3 nextPos = abzaMirrorTexelPos(texel + ivec2(1, 0), view, surface);
        float texelsPerBlock = 1.0 / max(distance(nextPos, worldPos), 1e-4);
        float texelRadius = clamp(ABZA_MIRROR_AO_RADIUS * texelsPerBlock, 2.0, 256.0);
        vec2 noise = blueNoiseTemporal(texcoord).xy;
        float occlusion = 0.0;
        for (int i = 0; i < ABZA_MIRROR_AO_SAMPLES; i++) {
            float angle = (float(i) + noise.x) * (2.0 * PI / float(ABZA_MIRROR_AO_SAMPLES));
            float radius = texelRadius * (0.2 + 0.8 * fract(noise.y + float(i) * 0.618034));
            ivec2 sampleTexel = texel + ivec2(round(vec2(cos(angle), sin(angle)) * radius));
            if (any(lessThan(sampleTexel, ivec2(0))) || any(greaterThanEqual(sampleTexel, ivec2(view.size)))) {
                continue;
            }
            float sampleSurface = texelFetch(scMirrorDistance, sampleTexel, 0).r;
            if (sampleSurface <= 0.0) {
                continue;
            }
            vec3 offset = abzaMirrorTexelPos(sampleTexel, view, sampleSurface) - worldPos;
            float offsetLength = length(offset);
            occlusion += clamp(dot(offset, normal) / max(offsetLength, 1e-4) - 0.15, 0.0, 1.0) *
                (1.0 - smoothstep(0.5 * ABZA_MIRROR_AO_RADIUS, ABZA_MIRROR_AO_RADIUS, offsetLength));
        }
        return clamp(occlusion * ABZA_MIRROR_AO_STRENGTH / float(ABZA_MIRROR_AO_SAMPLES), 0.0, 1.0);
    }

    // The lit colour of a mirror view texel whose surface is at distance surface from the view's origin
    vec3 abzaMirrorLight(ivec2 texel, AbzaMirrorView view, float surface) {
        vec3 albedo = texelFetch(scMirrorAlbedo, texel, 0).rgb;
        vec4 rawData = texelFetch(scMirrorData, texel, 0);
        vec3 worldPos = abzaMirrorTexelPos(texel, view, surface);
        vec3 rayDir = normalize(worldPos - view.origin - view.eye);
        uvec3 data = uvec3(round(rawData.rgb * 65535.0));
        vec3 normal = abzaCompanionOctDecode(vec2(float(data.r >> 8u), float(data.r & 255u)) / 255.0);
        // Surfaces drawn on both sides (plants, panes) face the ray, as Terrain.frag turns them to the camera
        normal = dot(normal, rayDir) > 0.0 ? -normal : normal;
        float occlusion = abzaMirrorOcclusion(texel, view, worldPos, normal, surface);
        float blockLevel = float(data.g >> 8u) / 255.0;
        float skyLevel = float(data.g & 255u) / 255.0;
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

        vec3 color = albedo * emissive * PBR_BRIGHTNESS * PI;
        #if defined SHADOW_AND_SKY || defined END_FLASH
            // Deferred11's direct light for a surface without its own smoothness, in world space
            vec3 f0 = vec3(0.04);
            vec3 f82 = vec3(1.0);
            float NdotV = clamp(dot(-rayDir, normal), 0.0, 1.0);
            vec3 shadowDiffuse = albedo * diffuseAbsorptionWeight(NdotV, 0.0, f0, f82);
            vec3 shadow = sunColor * basicSunlight;
            #ifdef END_FLASH
                shadow = endFlashIntensity * vec3(0.5, 0.2, 0.8) * basicSunlight;
            #endif
            float NdotL = clamp(dot(normal, shadowDirection), 0.0, 1.0);
            vec3 shadowSpecular = sunlightSpecular(rayDir, shadowDirection, normal, 0.0, NdotL, NdotV, f0, f82) * airAbsorption(0.0);
            shadowSpecular += abzaSunSheen(rayDir, shadowDirection, normal, NdotL, NdotV, 0.0, 0.0, float(plant ? MAT_GRASS : MAT_DEFAULT));
            #ifdef SHADOW_AND_SKY
                #ifdef CLOUD_SHADOW
                    shadow *= cloudShadow(worldPos, shadowDirection);
                #endif
            #endif
            vec3 subsurfaceScattering = vec3(float(porosity > 64.5 / 255.0)) * shadow * shadowDiffuse;
            shadow *= shadowDiffuse + shadowSpecular;
            #ifdef PCSS
                percentageCloserSoftShadow(
                    worldPos, normal, NdotL, length(worldPos), 0.0, porosity, skyLevel, blueNoiseTemporal(texcoord).xy,
                    shadow, subsurfaceScattering
                );
            #else
                singleSampleShadow(worldPos, normal, NdotL, 0.0, porosity, skyLevel, shadow, subsurfaceScattering);
            #endif
            color += shadow + subsurfaceScattering * abzaPlantGlow(rayDir, shadowDirection);
        #endif

        #ifdef MOD_NIGHT_VISION_COMPAT
            vec3 nightLight = pow(texelFetch(colortex4, ivec2(0), 0).rgb, vec3(2.2)) * NIGHT_VISION_BRIGHTNESS;
        #else
            vec3 nightLight = vec3(nightVision * NIGHT_VISION_BRIGHTNESS);
        #endif
        color += albedo * abzaAmbientLight(blockLevel, skyLevel, worldPos, normal, plant, nightLight) * (1.0 - occlusion);
        return color;
    }
#endif

void main() {
    texBuffer14 = vec4(0.0);
    #ifdef ABZA_MIRROR_LIGHTING
        vec4 header = texelFetch(scMirrorInfo, ivec2(0, 0), 0);
        if (abs(header.x - 4242.0) > 0.5 || abs(header.y - float(ABZA_MIRROR_PROTOCOL)) > 0.5 || header.z < 1.0) {
            return;
        }
        ivec2 mirrorTexel = ivec2(texcoord * header.zw);
        float surface = texelFetch(scMirrorDistance, mirrorTexel, 0).r;
        if (surface <= 0.0) {
            return;
        }
        vec3 origin = texelFetch(scMirrorInfo, ivec2(2, 0), 0).xyz;
        mat4 toClip = mat4(
            texelFetch(scMirrorInfo, ivec2(3, 0), 0), texelFetch(scMirrorInfo, ivec2(4, 0), 0),
            texelFetch(scMirrorInfo, ivec2(5, 0), 0), texelFetch(scMirrorInfo, ivec2(6, 0), 0)
        );
        texBuffer14 = vec4(abzaMirrorLight(mirrorTexel, abzaMirrorViewOf(toClip, origin, header.zw), surface), 1.0);
    #endif
}

/* RENDERTARGETS: 14 */

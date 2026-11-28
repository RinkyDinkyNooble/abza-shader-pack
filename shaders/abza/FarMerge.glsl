//
//  ABZA Shader: Shaders Companion's far terrain as gbuffer texels (abza/FarMergePass.comp): the opaque layer as
//  programs/gbuffers/TerrainDH.frag writes Distant Horizons' terrain, the translucent layer (water, glass, ice) as
//  programs/gbuffers/WaterDH.frag writes its water, without material classes (as Distant Horizons' terrain). Needs
//  libs/GbufferData.glsl and libs/Common.glsl; the translucent layer also libs/Water.glsl and abza/WaterWaves.glsl.
//

#ifndef ABZA_FAR_MERGE_GLSL
#define ABZA_FAR_MERGE_GLSL

uniform sampler2D scFarAlbedo;
uniform sampler2D scFarData;
uniform sampler2D scFarTranslucentAlbedo;
uniform sampler2D scFarTranslucentData;

// A far texel's data (API.md, as cube_data): r the face's world normal (octahedral, x high byte, y low), g the light
// (block high, sky low), b the block.properties id + 1, a the block's own light emission / 15
struct AbzaFarTexel {
    vec4 albedo;
    vec3 worldNormal;
    vec2 lightmap;
    int material;
    float emission;
};

AbzaFarTexel abzaFarTexel(vec4 albedo, vec4 rawData) {
    AbzaFarTexel texel;
    uvec3 data = uvec3(round(rawData.rgb * 65535.0));
    vec2 e = vec2(float(data.r >> 8u), float(data.r & 255u)) / 255.0 * 2.0 - 1.0;
    vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
    if (n.z < 0.0) {
        n.xy = (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    }
    // Faces are axis-aligned: the nearest axis, free of the encoding's rounding
    vec3 a = abs(n);
    texel.worldNormal = sign(n) * vec3(a.x >= a.y && a.x >= a.z, a.y > a.x && a.y >= a.z, a.z > a.x && a.z > a.y);
    texel.albedo = albedo;
    texel.lightmap = vec2(float(data.g >> 8u), float(data.g & 255u)) / 255.0;
    texel.material = int(data.b) - 1;
    texel.emission = rawData.a;
    return texel;
}

// The view position of a far surface at a texel from its far depth
vec3 abzaFarViewPos(ivec2 texel, float depth) {
    return screenToViewPosLod((vec2(texel) + 0.5) * texelSize, depth);
}

// The far opaque layer's texel in the pack's gbuffer format; false where it holds no surface
bool abzaFarSolid(ivec2 texel, out vec4 data0, out vec4 data1, out vec4 data2) {
    data0 = vec4(0.0);
    data1 = vec4(0.0);
    data2 = vec4(0.0);
    float depth = texelFetch(scFarDepth, texel, 0).r;
    if (depth >= 1.0) {
        return false;
    }
    AbzaFarTexel far = abzaFarTexel(texelFetch(scFarAlbedo, texel, 0), texelFetch(scFarData, texel, 0));
    vec3 viewPos = abzaFarViewPos(texel, depth);
    vec3 worldPos = viewToWorldPos(viewPos);
    vec3 mcPos = worldPos + cameraPosition;
    int material = far.material;

    GbufferData rawData;
    vec4 albedo = vec4(far.albedo.rgb, 1.0);
    vec3 viewNormal = mat3(gbufferModelView) * far.worldNormal;
    // TerrainDH's per-block noise by the 1/16-block position, taken half a step inside the face, faded out to its
    // average (the colour as it is) where a pixel covers more than half a noise cell, as a mipmap would
    float noiseCells = 32.0 * length(viewPos) / (gbufferProjection[1].y * screenSize.y * max(abs(dot(normalize(viewPos), viewNormal)), 0.05));
    float noiseWeight = 1.0 - smoothstep(0.25, 0.75, noiseCells);
    if (noiseWeight > 0.0) {
        ivec3 pixelPos = ivec3(floor((mcPos - far.worldNormal * (0.5 / 16.0)) * 16.0));
        ivec2 noiseTexel = (pixelPos.xz + 17 * pixelPos.y) & 63;
        float noise = texelFetch(noisetex, noiseTexel, 0).r;
        albedo.rgb = pow(albedo.rgb, vec3(mix(1.0, noise * 0.3 + 0.85, noiseWeight)));
    }

    rawData.albedo = albedo;
    rawData.lightmap = far.lightmap;
    rawData.normal = viewNormal;
    rawData.geoNormal = viewNormal;
    rawData.smoothness = 0.0;
    rawData.metalness = 0.0;
    rawData.porosity = 0.0;
    rawData.emissive = 0.0;
    rawData.materialID = MAT_DEFAULT;
    rawData.parallaxOffset = 0.0;
    rawData.depth = 0.0;

    // Terrain.frag's rules by the block.properties id: plants and leaves, their porosity, hard-coded emission
    if ((max(material, 0) & 0x4800) == 0x4800 || material == 8198 || material == 8206 || material == 8207) {
        rawData.materialID = MAT_GRASS;
    }
    rawData.emissive = 0.0;
    #ifdef HARDCODED_EMISSIVE
        int commonEmissive = max(0, material) & 0x7000;
        float hardcodedEmissive = float(material == 8195);
        if (commonEmissive > 16384) {
            hardcodedEmissive = clamp(0.57 * length(albedo.rgb) + float(commonEmissive == 0x5000), 0.0, 1.0);
        }
        else if (material == 8198) {
            hardcodedEmissive = clamp(2.0 * albedo.r - 1.5 * albedo.g, 0.0, 1.0);
        }
        else if (material == 8200) {
            hardcodedEmissive = clamp(2.0 * albedo.b - 1.0 * albedo.r, 0.0, 1.0);
        }
        else if (material == 8197 || material == 8202) {
            hardcodedEmissive = clamp((0.8 * albedo.r - 1.2 * albedo.b) * dot(albedo.rgb, vec3(0.3333)), 0.0, 1.0);
        }
        else if (material == 8203) {
            hardcodedEmissive = float(pow2(albedo.r) > 0.3 * (pow2(albedo.b) + pow2(albedo.g)) + 0.3);
        }
        else if (material == 8204) {
            hardcodedEmissive = clamp(2.0 * albedo.b - 4.5 * albedo.r, 0.0, 1.0) + clamp(2.0 * albedo.r - 3.0 * albedo.b, 0.0, 1.0);
        }
        else if (material == 8205) {
            hardcodedEmissive = clamp(0.5 * albedo.b - 1.0 * albedo.r - 0.2, 0.0, 1.0);
        }
        rawData.emissive = hardcodedEmissive;
    #endif
    // Other light sources glow by their own light, as TerrainDH treats Distant Horizons' illuminated blocks
    if (rawData.emissive < 1e-3) {
        rawData.emissive = smoothstep(8.0 / 15.0, 14.0 / 15.0, far.emission);
    }
    int commonPorosity = material == 8198 ? 0x4E00 : max(0, material) & 0x4E00;
    if (commonPorosity > 16384) {
        rawData.porosity = (commonPorosity & 0x0800) != 0 ? 0.5 : 0.75;
    }

    if (rainyStrength > 0.0 && far.emission < 0.5) {
        float wetStrength = 0.0;
        float outdoor = clamp(15.0 * rawData.lightmap.y - 14.0, 0.0, 1.0);
        #if RAIN_PUDDLE == 1
            wetStrength = (1.0 - rawData.metalness) * clamp(far.worldNormal.y * 10.0 - 0.1, 0.0, 1.0) * outdoor * rainyStrength;
        #elif RAIN_PUDDLE == 2
            wetStrength = groundWetStrength(mcPos, far.worldNormal.y, rawData.metalness, 0.0, outdoor);
        #endif
        rawData.smoothness += (1.0 - rawData.smoothness) * wetStrength;
    }

    packUpGbufferDataSolid(rawData, data0, data1, data2);
    return true;
}

#ifdef ABZA_FAR_TRANSLUCENT_PASS
    // The far translucent layer's texel (the nearest water, glass or ice in front of the opaque layer) in the pack's
    // gbuffer format; false where it holds no surface
    bool abzaFarTranslucent(ivec2 texel, out vec4 data0, out vec4 data1, out vec4 data2) {
        data0 = vec4(0.0);
        data1 = vec4(0.0);
        data2 = vec4(0.0);
        float depth = texelFetch(scFarDepth, texel, 0).g;
        if (depth >= 1.0) {
            return false;
        }
        AbzaFarTexel far = abzaFarTexel(texelFetch(scFarTranslucentAlbedo, texel, 0), texelFetch(scFarTranslucentData, texel, 0));
        vec3 viewPos = abzaFarViewPos(texel, depth);
        vec3 mcPos = viewToWorldPos(viewPos) + cameraPosition;
        int material = far.material;
        bool water = material == 8192;

        // WaterDH.vert's tangent frame from the face's normal. Water's side faces (the far terrain's one-block steps
        // between detail levels, waterfalls) are shaded as its surface, so a step doesn't show as a dark line
        vec3 n = far.worldNormal;
        if (water && abs(n.y) < 0.5) {
            n = vec3(0.0, 1.0, 0.0);
        }
        mat3 tbnMatrix = mat3(
            normalize(mat3(gbufferModelView) * vec3(n.z + abs(n.y), 0.0, n.x)),
            normalize(mat3(gbufferModelView) * vec3(0.0, abs(n.y) - 1.0, abs(n.y))),
            mat3(gbufferModelView) * n
        );

        GbufferData rawData;
        rawData.albedo = far.albedo;
        rawData.lightmap = far.lightmap;
        rawData.geoNormal = tbnMatrix[2];
        // Water.frag's rule: smooth, unless the block is listed as glowing
        float isEmissive = clamp(float(max(0, material) & 0x7000) - 16384.0, 0.0, 1.0);
        rawData.smoothness = 1.0 - isEmissive;
        rawData.metalness = 0.0;
        rawData.porosity = 0.0;
        rawData.emissive = 0.0;
        #ifdef HARDCODED_EMISSIVE
            rawData.emissive = isEmissive;
        #endif
        rawData.materialID = water ? MAT_WATER : MAT_DEFAULT;
        rawData.parallaxOffset = 0.0;
        rawData.depth = 0.0;

        float wetStrength = 0.0;
        if (rainyStrength > 0.0) {
            float outdoor = clamp(15.0 * rawData.lightmap.y - 14.0, 0.0, 1.0);
            if (water) {
                wetStrength = outdoor * clamp(abs(n.y) * 10.0 - 0.1, 0.0, 1.0);
            }
            else {
                #if RAIN_PUDDLE == 1
                    wetStrength = (1.0 - rawData.metalness) * clamp(n.y * 10.0 - 0.1, 0.0, 1.0) * outdoor * rainyStrength;
                #elif RAIN_PUDDLE == 2
                    wetStrength = groundWetStrength(mcPos, n.y, rawData.metalness, 0.0, outdoor);
                #endif
            }
            rawData.smoothness += (1.0 - rawData.smoothness) * wetStrength;
        }

        vec3 normal = tbnMatrix[2];
        float viewDistance = length(viewPos);
        float viewDepthInv = 1.0 / viewDistance;
        vec3 viewDir = viewPos * (-viewDepthInv);
        float curveStart = dot(viewDir, tbnMatrix[2]);
        #if WATER_TYPE == 0
            if (water) {
                // The water a pixel covers, from its distance and the angle it sees the surface at (no derivatives here)
                float waveFootprint = viewDistance * 2.0 / (gbufferProjection[1].y * screenSize.y * max(abs(curveStart), 0.05));
                vec3 tangentDir = transpose(tbnMatrix) * viewPos;
                normal = normalize(tbnMatrix * abzaWaterSurfaceWave(mcPos / 32.0, tangentDir, waveFootprint));
            }
        #endif
        float NdotV = dot(normal, viewDir);
        vec3 edgeNormal = normal - viewDir * NdotV;
        curveStart += float(curveStart == 0.0) * 1e-6;
        float weight = clamp(curveStart - curveStart * exp(NdotV / curveStart - 1.0), 0.0, 1.0);
        weight = max(NdotV, curveStart) - weight;
        normal = viewDir * weight + edgeNormal * sqrt(max(1.0 - weight * weight, 0.0) / max(dot(edgeNormal, edgeNormal), 1e-20));
        float fadeFactor = viewDepthInv * curveStart * gbufferProjection[1].y * screenSize.y;
        normal = mix(tbnMatrix[2], normal, fadeFactor / (fadeFactor + 0.2));
        rawData.normal = normal;

        packUpGbufferDataSolid(rawData, data0, data1, data2);
        return true;
    }
#endif

#endif

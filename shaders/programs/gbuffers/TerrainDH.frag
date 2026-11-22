//     _________      __        __     ___       __     __________      ________        ______        __           
//    /  _____  \    |  |      |  |   |   \     |  |   |   _____  \    |__    __|      /  __  \      |  |          
//   /  /     \__\   |  |      |  |   |    \    |  |   |  |     \  \      |  |        /  /  \  \     |  |          
//  |  |             |  |      |  |   |  |  \   |  |   |  |      |  |     |  |       /  /    \  \    |  |          
//   \  \______      |  |      |  |   |  |\  \  |  |   |  |      |  |     |  |      |  |______|  |   |  |          
//    \______  \     |  |      |  |   |  | \  \ |  |   |  |      |  |     |  |      |   ______   |   |  |          
//           \  \    |  |      |  |   |  |  \  \|  |   |  |      |  |     |  |      |  |      |  |   |  |          
//  ___       |  |   |  |      |  |   |  |   \  |  |   |  |      |  |     |  |      |  |      |  |   |  |          
//  \  \_____/  /     \  \____/  /    |  |    \    |   |  |_____/  /    __|  |__    |  |      |  |   |  |_________ 
//   \_________/       \________/     |__|     \___|   |__________/    |________|   |__|      |__|   |____________|
//
//  General Public License v3.0. Copyright (C) 2026 GeForceLegend.
//  https://github.com/GeForceLegend/Sundial-Lite
//  https://www.gnu.org/licenses/gpl-3.0.en.html
//
//  Gbuffer for Distant Horizons solid terrain
//

#include "/abza/NanDebug.glsl"

layout(location = 0) out vec4 gbufferData0;
layout(location = 1) out vec4 gbufferData1;
layout(location = 2) out vec4 gbufferData2;

in vec3 color;
in vec3 viewPos;
flat in vec3 blockData;
flat in vec3 faceNormal;

#include "/settings/GlobalSettings.glsl"
#include "/libs/Uniform.glsl"
#include "/libs/GbufferData.glsl"
#include "/libs/Common.glsl"
#include "/libs/Parallax.glsl"

void main() {
    vec3 worldPos = viewToWorldPos(viewPos);
    if (max(dot(worldPos.xz, worldPos.xz), worldPos.y * worldPos.y) < (far - 16.0) * (far - 16.0)) {
        discard;
    }

    GbufferData rawData;

    vec4 albedo = vec4(color, 1.0);
    vec3 mcPos = worldPos + cameraPosition;
    ivec3 pixelPos = ivec3(floor(mcPos * 16.0 + 1e-3));
    ivec2 texel = (pixelPos.xz + 17 * pixelPos.y) & 63;
    float noise = texelFetch(noisetex, texel, 0).r;
    albedo.rgb = pow(albedo.rgb, vec3(noise * 0.3 + 0.85));
    #ifdef DISTANT_HORIZONS_TEXTURES
        if (dh_hasTexture()) {
            albedo = dh_sampleTexture();
            vec3 clampedColor = clamp(color.rgb * (albedo.rgb * 2.0), 0.0, 1.0);
            albedo.rgb = mix(color.rgb, clampedColor, albedo.a);
        }
    #endif

    vec3 dPosDX = dFdx(viewPos);
    vec3 dPosDY = dFdy(viewPos);
    vec3 viewNormal = cross(dPosDX, dPosDY);
    float viewNormalLength2 = dot(viewNormal, viewNormal);
    // A face seen exactly edge-on has no area to take a normal from: its own normal instead
    viewNormal = viewNormalLength2 > 0.0 ? viewNormal * signMul(inversesqrt(viewNormalLength2), -dot(viewNormal, viewPos)) : faceNormal;

    rawData.albedo = albedo;
    rawData.lightmap = blockData.xy;
    rawData.normal = viewNormal;
    rawData.geoNormal = viewNormal;
    rawData.smoothness = 0.0;
    rawData.metalness = 0.0;
    rawData.porosity = 0.75 * float(blockData.z == 1.0);
    rawData.emissive = clamp(blockData.z - 1.0, 0.0, 1.0);
    if (blockData.z == 2.0) {
        rawData.emissive = smoothstep(8.0 / 15.0, 14.0 / 15.0, blockData.x);
    }
    rawData.materialID = MAT_DEFAULT;
    rawData.parallaxOffset = 0.0;
    rawData.depth = 0.0;

    if (rainyStrength > 0.0 && blockData.z < 2.5) {
        float wetStrength = 0.0;
        float outdoor = clamp(15.0 * rawData.lightmap.y - 14.0, 0.0, 1.0);
        vec3 worldNormal = mat3(gbufferModelViewInverse) * rawData.geoNormal;
        #if RAIN_PUDDLE == 1
            wetStrength = (1.0 - rawData.metalness) * clamp(worldNormal.y * 10.0 - 0.1, 0.0, 1.0) * outdoor * rainyStrength;
        #elif RAIN_PUDDLE == 2
            wetStrength = groundWetStrength(mcPos, worldNormal.y, rawData.metalness, 0.0, outdoor);
        #endif
        rawData.smoothness += (1.0 - rawData.smoothness) * wetStrength;

        #ifdef RAIN_RIPPLES
            vec3 tangent = normalize(cross(viewNormal, mat3(gbufferModelView) * vec3(1.0)));
            vec3 bitangent = normalize(cross(tangent, viewNormal));
            mat3 tbnMatrix = mat3(tangent, bitangent, viewNormal);

            vec3 rippleNormal = vec3(0.0, 0.0, 1.0);
            float viewDepthInv = inversesqrt(dot(viewPos, viewPos));
            rippleNormal = rainRippleNormal(viewPos);
            rippleNormal.xy *= viewDepthInv / (viewDepthInv + 0.1 * RIPPLE_FADE_SPEED);
            rawData.normal = mix(rawData.normal, tbnMatrix * rippleNormal, wetStrength);

            vec3 viewDir = viewPos * (-viewDepthInv);
            float NdotV = dot(rawData.normal, viewDir);
            vec3 edgeNormal = rawData.normal - viewDir * NdotV;
            float curveStart = dot(viewDir, tbnMatrix[2]);
            curveStart += float(curveStart == 0.0) * 1e-6;
            float weight = clamp(curveStart - curveStart * exp(NdotV / curveStart - 1.0), 0.0, 1.0);
            weight = max(NdotV, curveStart) - weight;
            rawData.normal = viewDir * weight + edgeNormal * sqrt(max(1.0 - weight * weight, 0.0) / max(dot(edgeNormal, edgeNormal), 1e-20));
        #endif
    }

    packUpGbufferDataSolid(rawData, gbufferData0, gbufferData1, gbufferData2);
}

/* DRAWBUFFERS:012 */

#define ABZA_NAN_PASS 2
#define ABZA_NAN_OUTPUTS abzaNanBad(gbufferData0) || abzaNanBad(gbufferData1) || abzaNanBad(gbufferData2)
#include "/abza/NanDebugMain.glsl"

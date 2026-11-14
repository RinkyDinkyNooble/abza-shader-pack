//
//  ABZA Shader: water behind another translucent surface (glass in front of the sea). The translucent gbuffer keeps
//  the nearest translucent fragment only, so gbuffers_water also writes each water fragment's distance to colortex15,
//  which other translucents leave unchanged (alpha 0 with the blend mode in shaders.properties)
//

/*
const int colortex15Format = RG16F;
*/
const vec4 colortex15ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

#ifdef ABZA_WATER_BEHIND_WRITE
    vec4 abzaWaterBehindData(vec3 viewPos, float skyLight, bool isWater) {
        return vec4(length(viewPos), skyLight, 0.0, float(isWater));
    }
#else
    #include "/abza/WaterSurface.glsl"

    uniform sampler2D colortex15;

    // Distance from the camera to the water surface behind this pixel's translucent surface (0: none), and its sky light.
    // Far water: a translucent LOD surface in front of the solid LODs (where both depths agree, the LOD is land)
    float abzaWaterBehindDistance(ivec2 texel, vec2 coord, out float skyLight) {
        vec2 data = texelFetch(colortex15, texel, 0).rg;
        skyLight = data.g;
        #ifdef LOD
            if (data.r <= 0.0) {
                float lodDepth = getLodDepthWater(coord);
                if (lodDepth < 1.0 && lodDepth < getLodDepthSolid(coord)) {
                    skyLight = 1.0;
                    return length(screenToViewPosLod(coord, lodDepth));
                }
            }
        #endif
        return data.r;
    }

    // Water fog over the part of the path from the translucent surface to the solid one that lies under water, and
    // the sky reflected by the water's waves with the water's Fresnel weight
    vec3 abzaWaterBehindFog(
        vec3 color, ivec2 texel, vec2 coord, vec3 worldDir, vec3 skyColor, float translucentDistance, float behindDistance
    ) {
        float skyLight;
        float waterDistance = abzaWaterBehindDistance(texel, coord, skyLight);
        float solidDistance = translucentDistance + behindDistance;
        if (waterDistance > translucentDistance && waterDistance < solidDistance) {
            color = waterFogTotal(color, worldDir, skyColor, solidDistance - waterDistance, skyLight);
            #if defined SHADOW_AND_SKY && ABZA_AIR == 1
                if (worldDir.y < 0.0) {
                    vec3 surfacePos = worldDir * waterDistance + gbufferModelViewInverse[3].xyz;
                    // The waves filtered for the water a pixel covers
                    float footprint = waterDistance * 2.0 / (gbufferProjection[1].y * screenSize.y * max(-worldDir.y, 0.05));
                    vec3 waveNormal = abzaWaterSurfaceNormal(surfacePos, worldDir, footprint);
                    color = abzaSkyReflection(color, surfacePos, worldDir, waveNormal, 0.02, skyLight, skyColor);
                }
            #endif
        }
        return color;
    }
#endif

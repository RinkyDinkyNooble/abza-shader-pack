//
//  ABZA Shader: volumetric light and fog at half resolution
//

// Images (shaders.properties), half the screen size, two sets used in turn by frame parity:
// abzaVL: light scattered toward the camera (rgb), fog transmittance (a); abzaVLInfo: march length (r), frame tag (g)
uniform sampler2D abzaVLTex0;
uniform sampler2D abzaVLTex1;
uniform sampler2D abzaVLInfoTex0;
uniform sampler2D abzaVLInfoTex1;

// Share of the previous frames' result in each new half-resolution texel
const float abzaVLHistoryWeight = 0.85;

float abzaVLFrameTag(int frame) {
    return float(frame & 1023);
}

// Two march lengths count as the same surface when they differ by less than this share of the longer one
float abzaVLLengthMatch(float a, float b) {
    return float(abs(a - b) <= 0.1 * max(a, b) + 0.25);
}

vec4 abzaVLFetch(ivec2 texel, bool current) {
    if (((frameCounter & 1) == 0) == current) {
        return texelFetch(abzaVLTex0, texel, 0);
    }
    return texelFetch(abzaVLTex1, texel, 0);
}

vec4 abzaVLInfoFetch(ivec2 texel, bool current) {
    if (((frameCounter & 1) == 0) == current) {
        return texelFetch(abzaVLInfoTex0, texel, 0);
    }
    return texelFetch(abzaVLInfoTex1, texel, 0);
}

float abzaVolumetricFogDensity(vec3 position) {
    position += cameraPosition;
    float heightClamp = pow2(2.0 / VOLUMETRIC_FOG_THICKNESS * position.y - 2.0 * VOLUMETRIC_FOG_CENTER_HEIGHT / VOLUMETRIC_FOG_THICKNESS);
    float density = 0.0;
    if (heightClamp < 1.0) {
        vec3 wind = vec3(2.0, 0.0, 1.0) * frameTimeCounter / VOLUMETRIC_FOG_SCALE * 0.001 * VOLUMETRIC_FOG_SPEED ;
        vec3 fogPosition = position / VOLUMETRIC_FOG_SCALE * 0.001 + wind;

        const float weights = (1.0 - pow(VOLUMETRIC_FOG_OCTAVE_FADE, VOLUMETRIC_FOG_OCTAVES)) / (1.0 - VOLUMETRIC_FOG_OCTAVE_FADE);
        float weight = 1.0 / weights;
        for (int i = 0; i < VOLUMETRIC_FOG_OCTAVES; i++) {
            density += smooth3DNoise(fogPosition) * weight;
            fogPosition = fogPosition * VOLUMETRIC_FOG_OCTAVE_SCALE + wind;
            weight *= VOLUMETRIC_FOG_OCTAVE_FADE;
        }
        density = clamp(pow2(density) + VOLUMETRIC_FOG_AMOUNT - 1.0 - VOLUMETRIC_FOG_AMOUNT * heightClamp, 0.0, 1.0);
    }
    return density;
}

vec3 abzaVLAbsorptionBeta() {
    if (isEyeInWater == 1) {
        return waterAbsorptionBeta + 0.003;
    }
    return vec3(blindnessFactor + 0.003);
}

// Length of the march along a view ray that reaches a surface (or the sky) at rayLength
float abzaVLMarchLength(vec3 worldDir, float rayLength) {
    vec3 absorptionBeta = abzaVLAbsorptionBeta();
    float maxHorizonalRange = far + 32.0;
    float maxVerticalRange = min(far, max(cameraPosition.y + 64.0, 320.0 - cameraPosition.y) * 2.0) + 32.0;
    #ifdef LOD
        maxHorizonalRange = lodRenderDistance() * 1.1;
        #ifdef ABZA_FAR_LIGHT_SHAFTS
            // Down to the far terrain below
            if (worldDir.y < 0.0) {
                maxVerticalRange = min(lodRenderDistance(), max(cameraPosition.y + 64.0, 320.0 - cameraPosition.y) * 2.0) + 32.0;
            }
        #endif
    #endif
    float worldDirY2 = worldDir.y * worldDir.y;
    float maxAllowedDistance = maxHorizonalRange * maxVerticalRange * inversesqrt(pow2(maxHorizonalRange) * worldDirY2 + pow2(maxVerticalRange) * (1.0 - worldDirY2));
    maxAllowedDistance = min(maxAllowedDistance, min(64.0 * inversesqrt(dot(absorptionBeta, absorptionBeta) + 1e-6), 5000.0 * exp(-6.0 * length(absorptionBeta))));
    return min(maxAllowedDistance, rayLength);
}

#ifdef ABZA_FAR_LIGHT_SHAFTS
    #include "/abza/FarShadow.glsl"

    // The march in two parts with the far terrain's shadow (abzaVolumetricLight), in the half-resolution pass
    // (composite5_a) and Composite5's full-resolution fallback at edges alike: from the far shadow map when it is ready
    // (abzaVLFarShadowMap, set by the caller), else found on screen (abzaFarShaftRange)

    // Samples of the march past the chunk terrain's reach, toward far terrain or the sky
    #define ABZA_VL_FAR_SAMPLES 6
    // Screen steps of the far terrain's shadow test
    #define ABZA_FAR_SHAFT_STEPS 12

    // The near part of a march of marchLength: as far as the march reaches without far terrain (the chunk terrain's far
    // plane), sampled as without far terrain
    float abzaVLNearLength(vec3 worldDir, float marchLength) {
        float horizontal = far + 32.0;
        float vertical = min(far, max(cameraPosition.y + 64.0, 320.0 - cameraPosition.y) * 2.0) + 32.0;
        float worldDirY2 = worldDir.y * worldDir.y;
        return min(marchLength, horizontal * vertical * inversesqrt(pow2(horizontal) * worldDirY2 + pow2(vertical) * (1.0 - worldDirY2)));
    }

    // The stretch of this pixel's view ray in the far terrain's shadow (x to y, blocks from the camera; set by the caller
    // from abzaFarShaftRange before abzaVolumetricLight), none by default
    vec2 abzaVLFarShade = vec2(3.0e37);
    // The samples take the far terrain's shadow from the far shadow map (set by the caller from abzaFarShadowReady)
    bool abzaVLFarShadowMap = false;

    // The stretch of the view ray through a screen coordinate (blocks from the camera, x to y) in the shadow of far
    // terrain on screen. The shadow rays of the view ray's points all lie on one screen line, from the coordinate toward
    // the light (or away from its opposite point when it is behind the camera); a far texel on that line at distance D
    // shades the points whose shadow ray passes behind it, up to half D behind it. noise: 0 to 1, offsets the steps.
    vec2 abzaFarShaftRange(vec2 coord, vec3 viewDir, float noise) {
        vec2 range = vec2(3.0e37, 0.0);
        vec3 viewLight = mat3(gbufferModelView) * shadowDirection;
        float sinViewLight = length(cross(viewDir, viewLight));
        if (!abzaFarDrawn() || sinViewLight < 1e-4) {
            return vec2(3.0e37);
        }
        // The screen line: the projection of a short step from the view ray toward the light
        vec4 clipFrom = gbufferProjection * vec4(viewDir, 1.0);
        vec4 clipTo = gbufferProjection * vec4(viewDir + viewLight * 1e-2, 1.0);
        vec2 lineDir = clipTo.xy / clipTo.w - clipFrom.xy / clipFrom.w;
        float lineDirLength = length(lineDir);
        if (lineDirLength < 1e-7) {
            return vec2(3.0e37);
        }
        lineDir /= lineDirLength;
        // From a few pixels out (past this pixel's own surface) to the light's own screen point when it is in front, else
        // to the screen's edge
        vec2 edge = abs(mix(-coord, 1.0 - coord, step(0.0, lineDir))) / max(abs(lineDir), vec2(1e-6));
        float lineEnd = min(edge.x, edge.y);
        if (viewLight.z < 0.0) {
            vec4 clipLight = gbufferProjection * vec4(viewLight, 0.0);
            vec2 lightCoord = clipLight.xy / clipLight.w;
            #ifdef TAA
                lightCoord += taaOffset;
            #endif
            lineEnd = min(lineEnd, length(lightCoord * 0.5 + 0.5 - coord));
        }
        float lineStart = 2.5 * texelSize.x;
        if (lineEnd <= lineStart) {
            return vec2(3.0e37);
        }
        mat4 projectionInverse = abzaFarProjectionInverse();
        for (int i = 0; i < ABZA_FAR_SHAFT_STEPS; i++) {
            vec2 sampleCoord = coord + lineDir * (lineStart + (lineEnd - lineStart) * (float(i) + noise) / float(ABZA_FAR_SHAFT_STEPS));
            if (textureLod(depthtex1, sampleCoord, 0.0).r < 1.0) {
                continue;
            }
            float depth = textureLod(scFarDepth, sampleCoord, 0.0).r;
            if (depth >= 1.0) {
                continue;
            }
            vec3 projPos = vec3(sampleCoord, depth) * 2.0 - 1.0;
            #ifdef TAA
                projPos.xy -= taaOffset;
            #endif
            #if SR_ENABLE
                projPos.xy = projPos.xy * upscaleRatio + upscaleRatio - 1.0;
            #endif
            vec3 sampleViewPos = vec3(vec2(projectionInverse[0].x, projectionInverse[1].y) * projPos.xy + projectionInverse[3].xy, projectionInverse[3].z);
            sampleViewPos /= projectionInverse[2].w * projPos.z + projectionInverse[3].w;
            float sampleDistance = length(sampleViewPos);
            // Where along the view ray a point's shadow ray reaches this texel's distance on this line
            float shadedFrom = sampleDistance * length(cross(sampleViewPos / sampleDistance, viewLight)) / sinViewLight;
            range = vec2(min(range.x, shadedFrom), max(range.y, 1.5 * shadedFrom));
        }
        return range.y > 0.0 ? range : vec2(3.0e37);
    }

    // The share of sunlight at a point of the view ray (blocks from the camera; samplePos in player space) outside the far
    // terrain's shadow. From the far shadow map, a point the shadow map reaches leaves out casters within 64 blocks toward
    // the light (the shadow map holds those)
    float abzaFarShaftLight(float rayDistance, vec3 samplePos) {
        #ifdef ABZA_FAR_SHADOW_MAP
            if (abzaVLFarShadowMap) {
                vec3 shadowCoord = worldPosToShadowCoordNoDistort(samplePos);
                return abzaFarShadowPoint(samplePos, all(lessThan(abs(shadowCoord.xy), vec2(1.0))) ? 64.0 : 0.5);
            }
        #endif
        vec2 range = abzaVLFarShade;
        return 1.0 - clamp((rayDistance - range.x) / (0.1 * range.x) + 1.0, 0.0, 1.0) * clamp((range.y - rayDistance) / (0.1 * range.y) + 1.0, 0.0, 1.0);
    }
#endif

#if defined SHADOW_AND_SKY || defined END_FLASH
#ifdef ABZA_FAR_LIGHT_SHAFTS
    // The march's far part, from start to end along the view ray (past abzaVLNearLength): abzaVolumetricLight's loop with
    // ABZA_VL_FAR_SAMPLES samples, the shadow map's solid shadow only, and the far terrain's shadow (abzaVLFarShade).
    // Returns that part's light scattered toward the camera (rgb) and its fog transmittance (a).
    vec4 abzaVLFarPart(vec3 worldDir, float start, float end, float noise, float basicWeight, vec3 absorptionBeta,
                       float airScattering, float volumetricFogScattering) {
        vec4 result = vec4(0.0, 0.0, 0.0, 1.0);
        float stepLength = (end - start) / float(ABZA_VL_FAR_SAMPLES);
        float sampleDistance = start + stepLength * (noise + float(ABZA_VL_FAR_SAMPLES) - 1.0);
        basicWeight *= stepLength;
        vec3 rayAbsorption = exp2(-absorptionBeta * 1.44269502 * (sampleDistance + stepLength)) * basicWeight * 0.02;
        #if defined LIGHT_LEAKING_FIX && !defined END_FLASH
            rayAbsorption *= pow(clamp(eyeBrightnessSmooth.y / 240.0 + 1e-4 + float(isEyeInWater == 1), 0.0, 1.0), exp(-0.5 * stepLength));
        #endif
        if (isEyeInWater == 1) {
            rayAbsorption *= waterScattering;
        }
        vec3 stepAbsorption = exp2(absorptionBeta * stepLength * 1.44269502);
        vec3 skyScattering =
            (skyColorUp * 0.8 + sunColor * 2.0 * SUNLIGHT_BRIGHTNESS * (1.0 - (0.75 + 0.25 * float(CLOUD_TYPE != 2)) * weatherStrength)) *
            (1.0 - 0.75 * (1.0 - exp2(-RF_DENSITY * 4.0)) * weatherStrength) * eyeBrightnessSmooth.y / 1000.0;
        vec3 mistTint = abzaMistTint();
        float fogStep = stepLength * -0.01 * 1.44269502 / max(1e-5, basicWeight);

        for (int i = 0; i < ABZA_VL_FAR_SAMPLES; i++) {
            vec3 samplePos = gbufferModelViewInverse[3].xyz + worldDir * sampleDistance;
            vec3 singleLight = vec3(abzaFarShaftLight(sampleDistance, samplePos));
            vec3 sampleShadowCoord = worldPosToShadowCoord(samplePos);
            if (all(lessThan(abs(sampleShadowCoord - vec3(vec2(0.75), 0.5)), vec3(vec2(0.25), 0.5)))) {
                singleLight *= textureLod(shadowtex0, sampleShadowCoord, 0.0);
            }
            #ifdef SHADOW_AND_SKY
                #ifdef CLOUD_SHADOW
                    if (dot(singleLight, vec3(1.0)) > 0.0) {
                        singleLight *= cloudShadow(samplePos, shadowDirection);
                    }
                #endif
                singleLight *= sunColor * (1.0 - (1.0 - exp2(-RF_DENSITY * 4.0)) * weatherStrength) * SUNLIGHT_BRIGHTNESS;
            #else
                singleLight *= SUNLIGHT_BRIGHTNESS * endFlashIntensity * vec3(0.5, 0.2, 0.8);
            #endif
            #if defined VOLUMETRIC_FOG && defined SHADOW_AND_SKY
                float sampleVolumetricFogDensity = abzaVolumetricFogDensity(samplePos) * volumetricFogScattering;
                singleLight *= sampleVolumetricFogDensity * 5.0 * mistTint + airScattering;
                singleLight += sampleVolumetricFogDensity * skyScattering * mistTint;
                result *= exp2(fogStep * sampleVolumetricFogDensity);
            #else
                singleLight *= airScattering;
            #endif
            rayAbsorption *= stepAbsorption;
            result.rgb += singleLight * rayAbsorption;
            sampleDistance -= stepLength;
        }
        return result;
    }
#endif

// Sundial's volumetric light and fog march (Composite5) for one view ray of marchLength from the eye.
// Returns the light scattered toward the camera (rgb) and the fog transmittance (a): the result is color * a + rgb.
// Uses the shadow functions of libs/Shadow.glsl, defined only with SHADOW_AND_SKY or END_FLASH.
vec4 abzaVolumetricLight(vec3 worldDir, float marchLength, float noise) {
    vec4 result = vec4(0.0, 0.0, 0.0, 1.0);
    if (isEyeInWater >= 2) {
        return result;
    }
    float basicWeight = 1.0;
    vec3 absorptionBeta = abzaVLAbsorptionBeta();
    float LdotV = dot(worldDir, shadowDirection);
    float volumetricFogScattering = 0.0;
    float airScattering = VL_STRENGTH;
    if (isEyeInWater == 1) {
        basicWeight *= 10.0 * WATER_VL_STRENGTH;
        airScattering *= rayleighPhase(LdotV);
    }
    else {
        #ifdef SHADOW_AND_SKY
            float timeStrength = pow(clamp(1.0 - shadowDirection.y, 0.0, 1.0), 5.0);
            float timeVLStrength = (timeStrength * (MORNING_VL_STRENGTH - NOON_VL_STRENGTH) + NOON_VL_STRENGTH);
            float heightDensity = clamp(exp(-(cameraPosition.y + WORLD_BASIC_HEIGHT) / 1200.0), 0.0, 1.0);
            basicWeight *= timeVLStrength * heightDensity;
            volumetricFogScattering = heightDensity * VOLUMETRIC_FOG_DENSITY * (timeStrength * (VOLUMETRIC_FOG_MORNING_DENSITY - VOLUMETRIC_FOG_NOON_DENSITY) + VOLUMETRIC_FOG_NOON_DENSITY);
            volumetricFogScattering *= mix(ABZA_MIST_DRY, ABZA_MIST_WET, abzaHumidity);
        #endif

        airScattering *= miePhase(LdotV, 0.6, 0.36);
    }

    #ifdef ABZA_FAR_LIGHT_SHAFTS
        // The far part first, then the near part as without far terrain, in front of it
        float nearLength = abzaVLNearLength(worldDir, marchLength);
        if (marchLength > nearLength + 1.0) {
            result = abzaVLFarPart(worldDir, nearLength, marchLength, noise, basicWeight, absorptionBeta, airScattering, volumetricFogScattering);
        }
        marchLength = nearLength;
    #endif

    float stepLength = marchLength / VL_SAMPLES;
    vec3 stepSize = worldDir * stepLength;
    vec3 samplePos = gbufferModelViewInverse[3].xyz + stepSize * (noise + VL_SAMPLES - 1.0);

    basicWeight *= stepLength;
    absorptionBeta *= stepLength * 1.44269502;
    vec3 rayAbsorption = exp2(-absorptionBeta * (noise + VL_SAMPLES)) * basicWeight * 0.02;
    #if defined LIGHT_LEAKING_FIX && !defined END_FLASH
        rayAbsorption *= pow(clamp(eyeBrightnessSmooth.y / 240.0 + 1e-4 + float(isEyeInWater == 1), 0.0, 1.0), exp(-0.5 * stepLength));
    #endif
    if (isEyeInWater == 1) {
        rayAbsorption *= waterScattering;
    }
    vec3 stepAbsorption = exp2(absorptionBeta);
    vec3 skyScattering =
        (skyColorUp * 0.8 + sunColor * 2.0 * SUNLIGHT_BRIGHTNESS * (1.0 - (0.75 + 0.25 * float(CLOUD_TYPE != 2)) * weatherStrength)) *
        (1.0 - 0.75 * (1.0 - exp2(-RF_DENSITY * 4.0)) * weatherStrength) * eyeBrightnessSmooth.y / 1000.0;
    vec3 mistTint = abzaMistTint();
    stepLength *= -0.01 * 1.44269502 / max(1e-5, basicWeight);

    for (int i = 0; i < VL_SAMPLES; i++) {
        vec3 singleLight = vec3(1.0);
        #ifdef ABZA_FAR_LIGHT_SHAFTS
            singleLight *= abzaFarShaftLight(dot(samplePos - gbufferModelViewInverse[3].xyz, worldDir), samplePos);
        #endif
        vec3 sampleShadowCoord = worldPosToShadowCoord(samplePos);
        if (all(lessThan(
            abs(sampleShadowCoord - vec3(vec2(0.75), 0.5)),
            vec3(vec2(0.25), 0.5))
        )) {
            float solidShadowStrength = textureLod(shadowtex0, sampleShadowCoord, 0.0);
            singleLight *= vec3(solidShadowStrength);
            // Fully shadowed: caustics and tinted-glass shadow cannot change a zero
            if (solidShadowStrength > 0.0) {
                sampleShadowCoord.y -= 0.5;
                vec3 caustic = waterCaustic(sampleShadowCoord, samplePos, shadowDirection);
                singleLight *= caustic;
                #ifdef TRANSPARENT_SHADOW
                    sampleShadowCoord.xy += vec2(-0.5, 0.5);
                    float transparentShadowStrength = textureLod(shadowtex0, sampleShadowCoord, 0.0);
                    if (transparentShadowStrength < 1.0) {
                        vec3 transparentShadowColor = pow2(textureLod(shadowcolor0, sampleShadowCoord.st, 0.0).rgb);
                        singleLight *= mix(transparentShadowColor, vec3(1.0), vec3(transparentShadowStrength));
                    }
                #endif
            }
        }
        #ifdef SHADOW_AND_SKY
            #ifdef CLOUD_SHADOW
                if (dot(singleLight, vec3(1.0)) > 0.0) {
                    singleLight *= cloudShadow(samplePos, shadowDirection);
                }
            #endif
            singleLight *= sunColor * (1.0 - (1.0 - exp2(-RF_DENSITY * 4.0)) * weatherStrength) * SUNLIGHT_BRIGHTNESS;
        #else
            singleLight *= SUNLIGHT_BRIGHTNESS * endFlashIntensity * vec3(0.5, 0.2, 0.8);
        #endif
        #if defined VOLUMETRIC_FOG && defined SHADOW_AND_SKY
            float sampleVolumetricFogDensity = abzaVolumetricFogDensity(samplePos) * volumetricFogScattering;
            singleLight *= sampleVolumetricFogDensity * 5.0 * mistTint + airScattering;
            singleLight += sampleVolumetricFogDensity * skyScattering * mistTint;
        #else
            singleLight *= airScattering;
        #endif
        #ifdef SHADOW_AND_SKY
            #ifdef VOLUMETRIC_FOG
                float volumetricFogAbsorption = exp2(stepLength * sampleVolumetricFogDensity);
                result *= volumetricFogAbsorption;
            #endif
        #endif
        rayAbsorption *= stepAbsorption;
        result.rgb += singleLight * rayAbsorption;
        samplePos -= stepSize;
    }
    return result;
}
#endif

#ifdef ABZA_VL_PASS
    layout(rgba16f) uniform image2D abzaVL0;
    layout(rgba16f) uniform image2D abzaVL1;
    layout(rg16f) uniform image2D abzaVLInfo0;
    layout(rg16f) uniform image2D abzaVLInfo1;

    void abzaVLStore(ivec2 texel, vec4 light, vec4 info) {
        #ifdef NAN_DEBUG_VIEW
            if (abzaNanBad(light) || abzaNanBad(info)) {
                abzaNanMark(texel * 2, 2, 16);
            }
        #endif
        if ((frameCounter & 1) == 0) {
            imageStore(abzaVL0, texel, light);
            imageStore(abzaVLInfo0, texel, info);
        } else {
            imageStore(abzaVL1, texel, light);
            imageStore(abzaVLInfo1, texel, info);
        }
    }

    // Blends this frame's march with the previous frame's at the same surface: the ray's end point is reprojected,
    // and history texels with another march length, from another frame, or after a jump of more than 32 blocks are ignored.
    vec4 abzaVLAccumulate(vec4 current, vec3 worldDir, float rayLength, float marchLength) {
        if (dot(cameraMovement, cameraMovement) > 1024.0) {
            return current;
        }
        vec3 prevView = prevWorldToViewPos(gbufferModelViewInverse[3].xyz + worldDir * min(rayLength, 8192.0) + cameraMovement);
        if (prevView.z > -1e-3) {
            return current;
        }
        vec2 prevCoord = prevViewToProjectionPos(prevView).xy * 0.5 + 0.5;
        if (any(greaterThanEqual(abs(prevCoord - 0.5), vec2(0.5)))) {
            return current;
        }
        vec2 halfPos = (prevCoord * screenSize - 0.5) * 0.5;
        ivec2 corner = ivec2(floor(halfPos));
        vec2 blend = halfPos - vec2(corner);
        ivec2 lastTexel = ivec2(screenSize * 0.5) - 1;
        float prevTag = abzaVLFrameTag(frameCounter - 1);
        vec4 history = vec4(0.0);
        float totalWeight = 0.0;
        for (int i = 0; i < 4; i++) {
            ivec2 offset = ivec2(i & 1, i >> 1);
            ivec2 texel = clamp(corner + offset, ivec2(0), lastTexel);
            vec4 prevInfo = abzaVLInfoFetch(texel, false);
            vec2 axisWeight = mix(1.0 - blend, blend, vec2(offset));
            float weight = axisWeight.x * axisWeight.y * float(abs(prevInfo.g - prevTag) < 0.5) * abzaVLLengthMatch(prevInfo.r, marchLength);
            history += abzaVLFetch(texel, false) * weight;
            totalWeight += weight;
        }
        if (totalWeight < 1e-3) {
            return current;
        }
        return mix(current, history / totalWeight, abzaVLHistoryWeight * min(totalWeight, 1.0));
    }
#else
    // The half-resolution result for this pixel: bilinear over the texels whose march length matches this pixel's.
    // False where none matches (edges of nearer objects), so the caller marches at full resolution.
    bool abzaHalfResVL(float marchLength, out vec4 light) {
        light = vec4(0.0, 0.0, 0.0, 1.0);
        vec2 halfPos = (gl_FragCoord.xy - 0.5) * 0.5;
        ivec2 corner = ivec2(floor(halfPos));
        vec2 blend = halfPos - vec2(corner);
        ivec2 lastTexel = ivec2(screenSize * 0.5) - 1;
        float tag = abzaVLFrameTag(frameCounter);
        vec4 sum = vec4(0.0);
        float totalWeight = 0.0;
        for (int i = 0; i < 4; i++) {
            ivec2 offset = ivec2(i & 1, i >> 1);
            ivec2 texel = clamp(corner + offset, ivec2(0), lastTexel);
            vec4 info = abzaVLInfoFetch(texel, true);
            vec2 axisWeight = mix(1.0 - blend, blend, vec2(offset));
            float weight = (axisWeight.x * axisWeight.y + 1e-3) * float(abs(info.g - tag) < 0.5) * abzaVLLengthMatch(info.r, marchLength);
            sum += abzaVLFetch(texel, true) * weight;
            totalWeight += weight;
        }
        if (totalWeight < 1e-4) {
            return false;
        }
        light = sum / totalWeight;
        return true;
    }
#endif

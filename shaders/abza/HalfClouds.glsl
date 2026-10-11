//
//  ABZA Shader: realistic clouds at half resolution
//

// colortex8: cloud light added over the background (rgb), and how much the clouds cover the background (a)
// colortex9: cloud alpha for blending translucent surfaces (r), depth of the first cloud hit or -1 (g), 1 where computed (b), frame tag (a)

uniform sampler2D colortex8;
uniform sampler2D colortex9;

float abzaCameraRadius() {
    return gbufferModelViewInverse[3].y + max(300.0 + earthRadius, cameraPosition.y + WORLD_BASIC_HEIGHT + earthRadius);
}

// Distance along a view ray to where it enters the realistic cloud layer, as in realisticCloud
float abzaCloudStart(vec3 intersectionData, out bool hit) {
    float cameraRadius = abzaCameraRadius();
    vec2 bottom = raySphereIntersection(intersectionData.x, intersectionData.y, -pow2(cloudBottomHeight));
    vec2 top = raySphereIntersection(intersectionData.x, intersectionData.y, -pow2(cloudTopHeight));
    if (cameraRadius < cloudBottomHeight) {
        hit = intersectionData.z < 0.0;
        return bottom.y;
    }
    hit = cameraRadius < cloudTopHeight || top.y > 0.0;
    return top.x * clamp((cameraRadius - cloudTopHeight) * 1e+10, 0.0, 1.0);
}

#ifdef ABZA_CLOUD_PASS
    // True when the camera and the solid surface at all four full-resolution pixels are below the cloud layer,
    // so no ray in this half-resolution texel reaches a cloud
    bool abzaCloudsHidden(ivec2 fullTexel) {
        if (abzaCameraRadius() >= cloudBottomHeight) {
            return false;
        }
        vec3 planetCamera = gbufferModelViewInverse[3].xyz + vec3(0.0, max(300.0 + earthRadius, cameraPosition.y + WORLD_BASIC_HEIGHT + earthRadius), 0.0);
        for (int i = 0; i < 4; i++) {
            ivec2 texel = fullTexel + ivec2(i & 1, i >> 1);
            vec2 coord = (vec2(texel) + 0.5) * texelSize;
            float depth = texelFetch(depthtex1, texel, 0).r;
            vec3 viewPos;
            if (depth == 1.0) {
                #ifdef LOD
                    float lodDepth = getLodDepthSolidDeferred(coord);
                    if (lodDepth >= 1.0) {
                        return false;
                    }
                    viewPos = screenToViewPosLod(coord, lodDepth);
                #else
                    return false;
                #endif
            } else {
                viewPos = screenToViewPos(coord, depth);
            }
            vec3 surface = planetCamera + mat3(gbufferModelViewInverse) * viewPos;
            if (dot(surface, surface) >= pow2(cloudBottomHeight)) {
                return false;
            }
        }
        return true;
    }

    // Share of the previous frames' clouds in each new frame
    const float abzaCloudHistoryWeight = 0.9;

    float abzaCloudFrameTag(int frame) {
        return float(frame & 1023);
    }

    // Blends this frame's clouds with the previous frame's clouds at the same point of the sky (colortex8 and colortex9 before this pass writes them).
    // The point is reprojected at the cloud depth, or where the ray enters the cloud layer; texels from another frame are ignored.
    void abzaAccumulateClouds(vec2 coord, vec3 intersectionData, inout vec4 light, inout vec4 info) {
        bool hit = true;
        float rayLength = info.g > 0.0 ? info.g : abzaCloudStart(intersectionData, hit);
        if (!hit || dot(cameraMovement, cameraMovement) > 1024.0) {
            return;
        }
        vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * projectionToViewPos(vec3(coord * 2.0 - 1.0, 1.0)));
        vec3 prevView = prevWorldToViewPos(gbufferModelViewInverse[3].xyz + worldDir * rayLength + cameraMovement);
        if (prevView.z > -1e-3) {
            return;
        }
        vec2 prevCoord = prevViewToProjectionPos(prevView).xy * 0.5 + 0.5;
        if (any(greaterThanEqual(abs(prevCoord - 0.5), vec2(0.5)))) {
            return;
        }
        vec2 halfPos = prevCoord * screenSize * 0.5 - 0.5;
        ivec2 corner = ivec2(floor(halfPos));
        vec2 blend = halfPos - vec2(corner);
        ivec2 lastTexel = ivec2(screenSize * 0.5) - 1;
        float prevTag = abzaCloudFrameTag(frameCounter - 1);
        vec4 historyLight = vec4(0.0);
        float historyAlpha = 0.0;
        float historyDepth = -1.0;
        float totalWeight = 0.0;
        float bestWeight = 0.0;
        for (int i = 0; i < 4; i++) {
            ivec2 offset = ivec2(i & 1, i >> 1);
            ivec2 texel = clamp(corner + offset, ivec2(0), lastTexel);
            vec4 prevInfo = texelFetch(colortex9, texel, 0);
            vec2 axisWeight = mix(1.0 - blend, blend, vec2(offset));
            float weight = axisWeight.x * axisWeight.y * prevInfo.b * float(abs(prevInfo.a - prevTag) < 0.5);
            historyLight += texelFetch(colortex8, texel, 0) * weight;
            historyAlpha += prevInfo.r * weight;
            totalWeight += weight;
            if (weight > bestWeight) {
                bestWeight = weight;
                historyDepth = prevInfo.g;
            }
        }
        if (totalWeight < 1e-3) {
            return;
        }
        float historyWeight = abzaCloudHistoryWeight * min(totalWeight, 1.0);
        light = mix(light, historyLight / totalWeight, historyWeight);
        info.r = mix(info.r, historyAlpha / totalWeight, historyWeight);
        if (info.g > 0.0 && historyDepth > 0.0) {
            info.g = mix(info.g, historyDepth, historyWeight);
        } else if (historyDepth > 0.0) {
            info.g = historyDepth;
        }
    }
#else
    // Blends the half-resolution clouds over the background at this pixel: bilinear over the computed half-resolution texels.
    // Solid surfaces in front of the cloud layer get no clouds.
    vec4 abzaHalfResClouds(vec3 baseColor, vec3 intersectionData, float backDepth, out float cloudDepth) {
        cloudDepth = -1.0;
        bool hit;
        float start = abzaCloudStart(intersectionData, hit);
        if (!hit || (backDepth > 1e-5 && start >= backDepth)) {
            return vec4(baseColor, 0.0);
        }
        vec2 halfPos = gl_FragCoord.xy * 0.5 - 0.5;
        ivec2 corner = ivec2(floor(halfPos));
        vec2 blend = halfPos - vec2(corner);
        ivec2 lastTexel = ivec2(screenSize * 0.5) - 1;
        vec4 clouds = vec4(0.0);
        float alpha = 0.0;
        float totalWeight = 0.0;
        float bestWeight = 0.0;
        for (int i = 0; i < 4; i++) {
            ivec2 offset = ivec2(i & 1, i >> 1);
            ivec2 texel = clamp(corner + offset, ivec2(0), lastTexel);
            vec4 info = texelFetch(colortex9, texel, 0);
            vec2 axisWeight = mix(1.0 - blend, blend, vec2(offset));
            float weight = axisWeight.x * axisWeight.y * info.b;
            clouds += texelFetch(colortex8, texel, 0) * weight;
            alpha += info.r * weight;
            totalWeight += weight;
            if (weight > bestWeight) {
                bestWeight = weight;
                cloudDepth = info.g;
            }
        }
        if (totalWeight < 1e-4) {
            return vec4(baseColor, 0.0);
        }
        clouds /= totalWeight;
        return vec4(baseColor * (1.0 - clouds.a) + clouds.rgb, alpha / totalWeight);
    }

    // Bilinear over the computed half-resolution texels around halfPos: cloud light and cover.
    // False where none of the four is computed.
    bool abzaHalfResSample(vec2 halfPos, out vec4 clouds) {
        clouds = vec4(0.0);
        ivec2 corner = ivec2(floor(halfPos));
        vec2 blend = halfPos - vec2(corner);
        ivec2 lastTexel = ivec2(screenSize * 0.5) - 1;
        float totalWeight = 0.0;
        for (int i = 0; i < 4; i++) {
            ivec2 offset = ivec2(i & 1, i >> 1);
            ivec2 texel = clamp(corner + offset, ivec2(0), lastTexel);
            vec2 axisWeight = mix(1.0 - blend, blend, vec2(offset));
            float weight = axisWeight.x * axisWeight.y * texelFetch(colortex9, texel, 0).b;
            clouds += texelFetch(colortex8, texel, 0) * weight;
            totalWeight += weight;
        }
        if (totalWeight < 1e-3) {
            return false;
        }
        clouds /= totalWeight;
        return true;
    }

    // The half-resolution clouds the camera sees in worldDir.
    // False where that direction is off screen or not computed.
    bool abzaScreenClouds(vec3 worldDir, out vec4 clouds) {
        clouds = vec4(0.0);
        vec3 viewDir = mat3(gbufferModelView) * worldDir;
        if (viewDir.z > -1e-3) {
            return false;
        }
        vec2 projPos = viewToProjectionPos(viewDir).xy;
        #ifdef TAA
            projPos += taaOffset;
        #endif
        vec2 coord = projPos * 0.5 + 0.5;
        if (any(greaterThanEqual(abs(coord - 0.5), vec2(0.5)))) {
            return false;
        }
        return abzaHalfResSample(coord * screenSize * 0.5 - 0.5, clouds);
    }
#endif

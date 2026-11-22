//
//  ABZA Shader: rough reflections accumulated over frames, before the reflection filter (Composite0). Each frame a
//  pixel traces one reflection ray (or none, when its tile waits its turn, abza/ReflectionRate.glsl); the average of the
//  rays of the frames before is taken from where the reflection was seen in the previous frame and averaged with it,
//  so the filter (Composite1 to 3) blurs the average of up to 16 rays instead of one. The reflection is followed as an
//  image seen through the surface, at the reflection depth behind it (the way a mirror image moves as the view moves),
//  over pixels checked to lie in the surface's plane with about its smoothness. Smoother surfaces keep fewer frames,
//  mirror-like ones none, and fewer still where the image would slide far against the surface in a frame (a wrong
//  reflection depth then misplaces it). Always on with reflections: it was an option until 2.0.0-dev20, and turned off
//  it left rough reflections flickering (the user, 2026-11-22: "no point" in turning it off).
//

#ifndef ABZA_REFLECTION_ACCUMULATION_GLSL
#define ABZA_REFLECTION_ACCUMULATION_GLSL

#ifdef REFLECTION
    // Images (shaders.properties), screen sized, used in turn by frame parity. abzaRA: the accumulated reflection as
    // Composite0 writes it (rgb, and the reflection depth in a). abzaRB: the surface's view distance (0: nothing kept),
    // the rays averaged and the surface's smoothness.
    layout(rgba16f) uniform image2D abzaRA0;
    layout(rgba16f) uniform image2D abzaRA1;
    layout(rgba16f) uniform image2D abzaRB0;
    layout(rgba16f) uniform image2D abzaRB1;

    // Smoothness from which no history is kept, and the most rays kept on a rough surface
    #define ABZA_RA_SMOOTH_LIMIT 0.92
    #define ABZA_RA_MAX_RAYS 16.0

    bool abzaRAStored = false;

    void abzaRAStore(ivec2 texel, vec4 reflection, vec4 info) {
        abzaRAStored = true;
        if ((frameCounter & 1) == 0) {
            imageStore(abzaRA0, texel, reflection);
            imageStore(abzaRB0, texel, info);
        } else {
            imageStore(abzaRA1, texel, reflection);
            imageStore(abzaRB1, texel, info);
        }
    }

    // Nothing kept at texel (abzaRB's view distance 0; abzaRA isn't read there)
    void abzaRAStoreNone(ivec2 texel) {
        abzaRAStored = true;
        if ((frameCounter & 1) == 0) {
            imageStore(abzaRB0, texel, vec4(0.0));
        } else {
            imageStore(abzaRB1, texel, vec4(0.0));
        }
    }

    // The images start undefined (not cleared): a texel holding NaN or Inf reads as all zero, which keeps nothing
    vec4 abzaRAFinite(vec4 value) {
        bool finite = all(notEqual(floatBitsToUint(value) & uvec4(0x7F800000u), uvec4(0x7F800000u)));
        return finite ? value : vec4(0.0);
    }

    vec4 abzaRALoadReflection(ivec2 texel) {
        return abzaRAFinite((frameCounter & 1) == 0 ? imageLoad(abzaRA1, texel) : imageLoad(abzaRA0, texel));
    }

    vec4 abzaRALoadInfo(ivec2 texel) {
        return abzaRAFinite((frameCounter & 1) == 0 ? imageLoad(abzaRB1, texel) : imageLoad(abzaRB0, texel));
    }

    // Pixels Composite0 leaves without a reflection keep nothing for the next frame
    void abzaRAStoreNothing(ivec2 texel) {
        if (!abzaRAStored) {
            abzaRAStoreNone(texel);
        }
    }

    bool abzaRAOnScreen(ivec2 texel) {
        return all(greaterThanEqual(texel, ivec2(0))) && all(lessThan(texel, ivec2(screenSize)));
    }

    // Screen coordinate in the previous frame of a point at viewPos in this frame's view (z > 0: behind the camera)
    vec3 abzaRAPrevCoord(vec3 viewPos) {
        vec3 prevView = prevWorldToViewPos(viewToWorldPos(viewPos) + cameraMovement);
        return vec3(prevViewToProjectionPos(prevView).xy * 0.5 + 0.5, prevView.z);
    }

    // current: this frame's reflection at an opaque surface's pixel as Composite0 traced it (w the reflection depth),
    // or w < 0 where the pixel's tracer answers for it this frame (no ray of its own); depth: depthtex1's depth.
    // Returns the accumulated reflection, or current (w < 0: Composite1 takes the tracer's) where nothing is kept.
    vec4 abzaReflectionAccumulate(ivec2 texel, GbufferData data, float depth, vec4 current) {
        bool traced = current.w >= 0.0;
        float smoothness = data.smoothness;
        if (data.materialID == MAT_HAND || smoothness >= ABZA_RA_SMOOTH_LIMIT || depth >= 1.0) {
            abzaRAStoreNone(texel);
            return current;
        }

        // The surface point and its plane in the previous frame's view
        vec3 viewPos = screenToViewPos((vec2(texel) + 0.5) * texelSize, depth);
        vec3 prevView = prevWorldToViewPos(viewToWorldPos(viewPos) + cameraMovement);
        vec3 prevNormal = mat3(gbufferPreviousModelView) * (mat3(gbufferModelViewInverse) * data.geoNormal);
        vec3 surfaceCoord = abzaRAPrevCoord(viewPos);

        // The reflection depth: the kept average at the surface point, else this frame's ray's
        float reflectionDepth = traced ? current.w : 0.0;
        ivec2 surfaceTexel = ivec2(floor(surfaceCoord.xy * screenSize));
        if (surfaceCoord.z < 0.0 && abzaRAOnScreen(surfaceTexel) && abzaRALoadInfo(surfaceTexel).x > 0.0) {
            reflectionDepth = abzaRALoadReflection(surfaceTexel).w;
        }
        reflectionDepth *= far;

        // Where the reflected image was seen in the previous frame
        float surfaceDistance = length(viewPos);
        vec3 imageCoord = abzaRAPrevCoord(viewPos * (1.0 + reflectionDepth / surfaceDistance));
        vec2 prevCoord = imageCoord.z < 0.0 ? imageCoord.xy : surfaceCoord.xy;

        // The previous frame's four pixels around it, each kept only if its surface lies in this surface's plane and
        // has about its smoothness
        vec2 prevPos = prevCoord * screenSize - 0.5;
        ivec2 corner = ivec2(floor(prevPos));
        vec2 blend = prevPos - vec2(corner);
        float tolerance = 0.01 - 0.004 * prevView.z;
        vec2 projScale = vec2(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y);
        vec4 history = vec4(0.0);
        float rays = 0.0;
        float totalWeight = 0.0;
        if (prevView.z < 0.0) {
            for (int i = 0; i < 4; i++) {
                ivec2 offset = ivec2(i & 1, i >> 1);
                ivec2 prevTexel = corner + offset;
                if (!abzaRAOnScreen(prevTexel)) {
                    continue;
                }
                vec4 info = abzaRALoadInfo(prevTexel);
                if (info.x <= 0.0 || info.y <= 0.0 || abs(info.z - smoothness) > 0.05) {
                    continue;
                }
                vec2 ndc = (vec2(prevTexel) + 0.5) * texelSize * 2.0 - 1.0;
                vec3 prevTexelView = vec3((ndc + gbufferPreviousProjection[2].xy) / projScale * info.x, -info.x);
                if (abs(dot(prevTexelView - prevView, prevNormal)) > tolerance) {
                    continue;
                }
                vec2 axisWeight = mix(1.0 - blend, blend, vec2(offset));
                float weight = axisWeight.x * axisWeight.y;
                history += abzaRALoadReflection(prevTexel) * weight;
                rays += info.y * weight;
                totalWeight += weight;
            }
        }

        if (totalWeight < 0.05) {
            // Nothing kept here: this frame's ray starts the history (or the tracer's answer stands in)
            if (traced) {
                abzaRAStore(texel, current, vec4(-viewPos.z, 1.0, smoothness, 0.0));
            } else {
                abzaRAStoreNone(texel);
            }
            return current;
        }
        history /= totalWeight;
        rays /= totalWeight;

        if (!traced) {
            abzaRAStore(texel, history, vec4(-viewPos.z, rays, smoothness, 0.0));
            return history;
        }

        // How many rays to keep: fewer on smoother surfaces, and fewer where the image slides far against the surface
        // in a frame, compared with the reflection's blur on screen (the GGX lobe's width seen at the image's depth)
        float maxRays = mix(ABZA_RA_MAX_RAYS, 2.0, smoothstep(0.5, ABZA_RA_SMOOTH_LIMIT, smoothness));
        if (imageCoord.z < 0.0 && surfaceCoord.z < 0.0) {
            float slide = length((imageCoord.xy - surfaceCoord.xy) * screenSize);
            float blur = pow2(1.0 - smoothness) * reflectionDepth / (surfaceDistance + reflectionDepth) * 0.5 * screenSize.y * gbufferProjection[1].y;
            maxRays = min(maxRays, 1.0 + 2.0 * blur / max(slide, 1e-3));
        }
        rays = min(rays + 1.0, max(maxRays, 1.0));
        float alpha = 1.0 / rays;

        vec4 result;
        result.rgb = mix(history.rgb, current.rgb, alpha);
        result.w = current.w > 0.0 ? mix(history.w, current.w, alpha) : history.w;
        abzaRAStore(texel, result, vec4(-viewPos.z, rays, smoothness, 0.0));
        return result;
    }
#endif

#endif

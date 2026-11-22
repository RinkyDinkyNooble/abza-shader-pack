//
//  ABZA Shader: rough and faint reflections traced by fewer pixels (feature 3 of the 2.0 plan: roughness drives
//  resolution). A rough reflection is blurred over up to about 40 pixels by the reflection filter (Composite1 to 3)
//  and a faint one adds little, so each frame only some tiles of 8 x 8 pixels trace them (a half or a quarter, in
//  turn) and Composite1 gives the other tiles' pixels the result of the same place in the tracing tile, 8 pixels
//  away, before the filter. The reflection keeps its full physical strength; only the number of rays changes. Water,
//  glass, the hand, smooth surfaces and pixels whose tracer shows another surface trace for themselves.
//

#ifndef ABZA_REFLECTION_RATE_GLSL
#define ABZA_REFLECTION_RATE_GLSL

#define ROUGH_REFLECTION_RATE 2 // [1 2 4]

#if ROUGH_REFLECTION_RATE > 1
    // Composite0 writes this reflection depth (colortex4.w) where the group's tracer answers for the pixel
    #define ABZA_REFLECTION_SHARED -1.0

    // The pixel that traces for texel this frame: the same place in the tile of 8 x 8 pixels whose turn it is in
    // texel's block of 2 x 1 (rate 2) or 2 x 2 tiles (rate 4). Whole tiles trace or wait together, so the GPU's groups
    // of 32 pixels skip together (one tracing pixel in a group keeps the whole group busy: a tracer per 2 x 2 pixels
    // saved nothing). Blocks take turns starting at different tiles; every pixel traces every 2 (or 4) frames.
    ivec2 abzaReflectionTracer(ivec2 texel) {
        ivec2 tile = texel >> 3;
        #if ROUGH_REFLECTION_RATE == 4
            ivec2 block = tile >> 1;
            const ivec2 order[4] = ivec2[4](ivec2(0, 0), ivec2(1, 1), ivec2(1, 0), ivec2(0, 1));
            ivec2 turn = block * 2 + order[(frameCounter + block.x * 2 + block.y * 3) & 3];
        #else
            ivec2 turn = ivec2((tile.x & ~1) + ((frameCounter + tile.y + (tile.x >> 1)) & 1), tile.y);
        #endif
        return turn * 8 + (texel & 7);
    }

    // Whether a surface's reflection may be shared within its group: an opaque surface whose reflection the filter
    // blurs over at least about 30 pixels (smoothness up to 0.8), or a less smooth than nearly flawless one whose
    // reflection is faint (under a tenth of the light, a dielectric seen from the front)
    bool abzaReflectionShareable(float smoothness, float strength, vec3 f0, vec3 f82, float NdotV) {
        if (smoothness <= 0.8) {
            return true;
        }
        vec3 weight = F_AdobeF82(abs(f0), f82, NdotV) * strength;
        return smoothness <= 0.9 && max(weight.r, max(weight.g, weight.b)) < 0.1;
    }

    // Whether this pixel's reflection is left to its tracer this frame (Composite0): both are shareable (shareable is
    // this pixel's own answer), and the tracer shows the same opaque surface (no water or glass in front of it; normal,
    // smoothness, metal and depth alike), so its reflection is this pixel's too
    bool abzaReflectionLeftToTracer(ivec2 texel, GbufferData data, bool shareable) {
        ivec2 tracer = abzaReflectionTracer(texel);
        if (!shareable || tracer == texel || data.materialID == MAT_HAND || any(greaterThanEqual(tracer, ivec2(screenSize)))) {
            return false;
        }
        float depth = texelFetch(depthtex1, texel, 0).r;
        float tracerDepth = texelFetch(depthtex1, tracer, 0).r;
        // Not past the sky, Distant Horizons' terrain or a translucent surface in front of the tracer (it traces that one's
        // reflection)
        if (depth >= 1.0 || tracerDepth >= 1.0 || texelFetch(depthtex0, tracer, 0).r < tracerDepth) {
            return false;
        }
        float viewDepth = screenToViewDepth(depth);
        float tracerViewDepth = screenToViewDepth(tracerDepth);
        if (abs(viewDepth - tracerViewDepth) > 0.05 + abs(viewDepth) * 0.02) {
            return false;
        }
        GbufferData tracerData = getGbufferData(tracer, (vec2(tracer) + 0.5) * texelSize);
        float tracerMetal = tracerData.metalness;
        float metal = data.metalness;
        #ifdef LABPBR_F0
            tracerMetal = step(229.5 / 255.0, tracerMetal);
            metal = step(229.5 / 255.0, metal);
        #endif
        return tracerData.materialID != MAT_HAND && abs(tracerData.smoothness - data.smoothness) < 0.02 && tracerMetal == metal &&
            dot(tracerData.normal, data.normal) > 0.98 && tracerData.smoothness <= 0.9;
    }
#endif

#endif

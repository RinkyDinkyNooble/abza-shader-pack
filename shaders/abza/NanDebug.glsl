//
//  ABZA Shader: the NaN/Inf debug view (dev builds only). With NAN_DEBUG_VIEW, each checked pass's main runs as
//  abzaPassMain under the main of abza/NanDebugMain.glsl, which sets the pass's bit in abzaNanFlags (a screen-sized
//  flag image cleared every frame) at every pixel where one of the pass's outputs holds NaN or Inf. final shows the
//  picture dimmed to grey and each flagged pixel in the colour of the earliest pass that flagged it (abzaNanColor).
//  Include before a program's first declaration, after its #extension lines; abza/NanDebugMain.glsl after its main.
//  ABZA_NAN_NO_WRAP leaves main as it is (compute passes call abzaNanMark themselves).
//
//  Pass bits, in the order Oculus draws them:
//   0 sky (gbuffers_skybasic)          10 dh_water, deferred98_a        19 composite7
//   1 opaque gbuffers                  11 composite                     20 composite8
//   2 dh_terrain, deferred_a           12 composite1                    21 composite9
//   3 deferred                         13 composite2                    22 composite10
//   4 deferred11                       14 composite3                    23 composite11
//   5 deferred12                       15 composite4                    24 composite12
//   6 deferred13 (clouds)              16 composite5_a (volumetrics)    25 composite13
//   7 deferred14 (mirror views)        17 composite5                    26 composite14
//   8 deferred99                       18 composite6 (unchecked)        27 final
//   9 translucent gbuffers, particles, weather
//

#ifndef ABZA_NAN_DEBUG_GLSL
#define ABZA_NAN_DEBUG_GLSL


#ifdef NAN_DEBUG_VIEW
    #extension GL_ARB_shader_image_load_store : enable

    #define ABZA_NAN_PASSES 28

    layout(r32ui) uniform uimage2D abzaNanFlags;

    // NaN and Inf both have every exponent bit set; tested on the bits so fast-math can't fold the test away
    bool abzaNanBad(float v) {
        return (floatBitsToUint(v) & 0x7F800000u) == 0x7F800000u;
    }

    bool abzaNanBad(vec2 v) {
        return any(equal(floatBitsToUint(v) & uvec2(0x7F800000u), uvec2(0x7F800000u)));
    }

    bool abzaNanBad(vec3 v) {
        return any(equal(floatBitsToUint(v) & uvec3(0x7F800000u), uvec3(0x7F800000u)));
    }

    bool abzaNanBad(vec4 v) {
        return any(equal(floatBitsToUint(v) & uvec4(0x7F800000u), uvec4(0x7F800000u)));
    }

    // Sets pass's bit on the scale x scale screen pixels from pixel up
    void abzaNanMark(ivec2 pixel, int scale, int pass) {
        for (int y = 0; y < scale; y++) {
            for (int x = 0; x < scale; x++) {
                imageAtomicOr(abzaNanFlags, pixel + ivec2(x, y), 1u << uint(pass));
            }
        }
    }

    // A fully saturated hue per pass, red to violet in pass order; every colour has one channel at 1 and one at 0
    vec3 abzaNanColor(int pass) {
        float hue = float(pass) / float(ABZA_NAN_PASSES);
        return clamp(abs(fract(hue + vec3(0.0, 2.0, 1.0) / 3.0) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    }

    #ifndef ABZA_NAN_NO_WRAP
        #define main abzaPassMain
    #endif
#endif

#endif

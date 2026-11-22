//
//  ABZA Shader: the NaN/Inf debug view's main for a pass (abza/NanDebug.glsl). Before including, define
//  ABZA_NAN_PASS (the pass's bit) and ABZA_NAN_OUTPUTS (abzaNanBad of each output, joined with ||);
//  ABZA_NAN_SCALE for a pass drawn at 1 / N resolution, ABZA_NAN_TILED for one drawn as screen-sized tiles side by side.
//

#ifdef NAN_DEBUG_VIEW
    #undef main
    void main() {
        abzaPassMain();
        bool bad = ABZA_NAN_OUTPUTS;
        #if ABZA_NAN_PASS == ABZA_NAN_PASSES - 1
            // final: the picture in grey at half brightness, each flagged pixel in its earliest pass's colour
            uint flags = imageLoad(abzaNanFlags, ivec2(gl_FragCoord.xy)).r | (bad ? 1u << uint(ABZA_NAN_PASS) : 0u);
            vec3 color = bad ? vec3(0.0) : clamp(fragColor.rgb, 0.0, 1.0);
            fragColor = vec4(vec3(dot(color, vec3(0.2126, 0.7152, 0.0722)) * 0.5), 1.0);
            if (flags != 0u) {
                int first = 0;
                while ((flags & (1u << uint(first))) == 0u) {
                    first++;
                }
                fragColor.rgb = abzaNanColor(first);
            }
        #else
            if (bad) {
                #if defined ABZA_NAN_TILED
                    ivec2 pixel = ivec2(mod(gl_FragCoord.x, screenSize.x), gl_FragCoord.y);
                    abzaNanMark(pixel, 1, ABZA_NAN_PASS);
                #elif defined ABZA_NAN_SCALE
                    abzaNanMark(ivec2(gl_FragCoord.xy) * ABZA_NAN_SCALE, ABZA_NAN_SCALE, ABZA_NAN_PASS);
                #else
                    abzaNanMark(ivec2(gl_FragCoord.xy), 1, ABZA_NAN_PASS);
                #endif
            }
        #endif
    }
#endif

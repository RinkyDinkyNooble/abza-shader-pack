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
//  Reflection filter stage 2
//

#include "/abza/NanDebug.glsl"

layout(location = 0) out vec4 texBuffer4;

in vec2 texcoord;

#include "/settings/GlobalSettings.glsl"
#include "/libs/Uniform.glsl"
#include "/libs/Common.glsl"
#include "/libs/GbufferData.glsl"
#include "/libs/ReflectionFilter.glsl"

void main() {
    ivec2 texel = ivec2(texcoord * screenSize);
    vec4 reflectionColor = texelFetch(colortex4, texel, 0);
    float depth = getWaterDepth(texcoord);
    #ifdef LOD
        depth += float(depth == 1.0) * (getLodDepthWater(texcoord) - 1.0);
    #endif
    if (abs(depth) < 1.0 && reflectionColor.w > 1e-6) {
        #ifndef COMPANION_DEBUG_VIEW
            // (Not with "Reflection paths (debug)": blurring its colours together would make up paths)
            reflectionColor = reflectionFilter(reflectionColor, texel, 2.5, false);
        #endif
    } else {
        discard;
    }
    texBuffer4 = reflectionColor;
}

/* DRAWBUFFERS:4 */

#define ABZA_NAN_PASS 13
#define ABZA_NAN_OUTPUTS abzaNanBad(texBuffer4)
#include "/abza/NanDebugMain.glsl"

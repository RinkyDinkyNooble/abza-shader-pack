//
//  ABZA Shader: reflections of what screen-space reflection can't see
//
//  Defining ABZA_COMPANION_DEBUG_VIEW colours every ray traced through the companion cube: green a hit, blue open sky,
//  red a face not drawn yet; and rays the mirror view answers: yellow a hit, cyan open sky.
//

#include "/abza/Voxels.glsl"
#include "/abza/Companion.glsl"
#include "/abza/Mirror.glsl"

#if defined ABZA_WSR || defined ABZA_COMPANION || defined ABZA_MIRROR
    #define ABZA_OFFSCREEN_REFLECTION

    // For a reflection ray from a point in view space, before screen-space reflection: the companion mod's mirror view,
    // when the point lies on its plane. Returns 1 on a hit (lit colour and distance travelled in color), 0 for open sky,
    // -1 when it doesn't apply (screen-space reflection and the rest then run as before).
    int abzaMirrorFirst(vec3 viewPos, vec3 viewGeoNormal, vec3 viewRayDir, out vec4 color) {
        color = vec4(0.0);
        #ifdef ABZA_MIRROR
            int result = abzaMirrorReflection(viewToWorldPos(viewPos), mat3(gbufferModelViewInverse) * viewGeoNormal,
                mat3(gbufferModelViewInverse) * viewRayDir, color);
            #ifdef ABZA_COMPANION_DEBUG_VIEW
                if (result >= 0) {
                    color = vec4(result == 1 ? vec3(200.0, 200.0, 0.0) : vec3(0.0, 200.0, 200.0), 1.0);
                    result = 1;
                }
            #endif
            return result;
        #else
            return -1;
        #endif
    }

    // For a reflection ray that screen-space reflection missed, from a point in view space: the companion mod's cube
    // first, then the voxel copy of the terrain and the player. On a hit returns the lit colour and the distance
    // travelled. open is true when the cube has nothing in the ray's way within its range (the sky, as far as the
    // cube can tell).
    bool abzaOffscreenReflection(vec3 viewPos, vec3 viewGeoNormal, vec3 viewRayDir, out vec4 color, out bool open) {
        color = vec4(0.0);
        open = false;
        vec3 worldGeoNormal = mat3(gbufferModelViewInverse) * viewGeoNormal;
        vec3 traceStart = viewToWorldPos(viewPos) + worldGeoNormal * 0.02;
        vec3 traceDir = mat3(gbufferModelViewInverse) * viewRayDir;
        bool hit = false;
        #ifdef ABZA_COMPANION
            if (abzaCompanionLinked()) {
                int result = abzaCompanionReflection(traceStart, traceDir, worldGeoNormal, color);
                hit = result == 1;
                open = result == 0;
                #ifdef ABZA_COMPANION_DEBUG_VIEW
                    color = vec4(result == 1 ? vec3(0.0, 200.0, 0.0) : result == 0 ? vec3(0.0, 0.0, 200.0) : vec3(200.0, 0.0, 0.0), 1.0);
                    open = false;
                    return true;
                #endif
            }
        #endif
        #ifdef ABZA_WSR
            if (!hit) {
                hit = abzaVoxelReflection(traceStart, traceDir, color);
                open = open && !hit;
            }
            vec4 playerReflection;
            if (abzaPlayerReflection(traceStart, traceDir, hit ? color.w : float(WORLD_REFLECTION_DISTANCE), playerReflection)) {
                color = playerReflection;
                hit = true;
                open = false;
            }
        #endif
        return hit;
    }
#endif

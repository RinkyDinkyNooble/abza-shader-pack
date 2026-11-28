//
//  ABZA Shader: reflections of what screen-space reflection can't see
//
//  Defining ABZA_COMPANION_DEBUG_VIEW (menu: COMPANION_DEBUG_VIEW) colours every ray traced through the companion cube:
//  green a hit, blue open sky, red a face not drawn yet or a way it can't tell, orange solid blocks in the mod's lattice
//  where the cube has no hit; and rays from the mirror view's plane:
//  yellow a hit, cyan open sky, magenta a part of the view the mod didn't draw. Screen-space reflection keeps its colours.
//

#ifdef COMPANION_DEBUG_VIEW
    #define ABZA_COMPANION_DEBUG_VIEW
#endif

#include "/abza/Voxels.glsl"
#include "/abza/Companion.glsl"
#include "/abza/Mirror.glsl"
#ifdef ABZA_COMPANION
    #include "/abza/Lattice.glsl"

    // Albedo taken for a surface found in the lattice, which holds no colours
    #define ABZA_LATTICE_ALBEDO 0.3

    // Colour of a light-emitting block found in the lattice where the cube doesn't show it: the block light's hue,
    // halfway to white
    vec3 abzaLatticeLampColor() {
        return 0.6 * mix(vec3(1.0), commonLightColor / max(commonLightColor.r, max(commonLightColor.g, max(commonLightColor.b, 1e-3))), 0.5);
    }

    // Solid matter in a reflection ray's way in Shaders Companion's lattice, within 24 blocks of a point relative to the
    // camera on a surface with normal worldGeoNormal: on a hit returns the distance travelled (color.w) and, where the
    // cube shows the surface there, inCube with the cube's atlas coordinate and surface point for abzaCompanionShade;
    // elsewhere a surface lit by the light in front of it (with its material class's values when it has one) plus the
    // glow of a block that gives light
    bool abzaLatticeReflection(vec3 worldPos, vec3 worldGeoNormal, vec3 worldDir, out vec4 color, out bool inCube, out vec2 cubeCoord, out vec3 cubePos) {
        color = vec4(0.0);
        inCube = false;
        cubeCoord = vec2(0.0);
        cubePos = vec3(0.0);
        if (!abzaLatticeStart()) {
            return false;
        }
        vec3 start = worldPos + worldGeoNormal * 0.25;
        float distance;
        vec3 normal;
        uint front;
        uint hit;
        if (abzaLatticeBlocked(start, worldDir, 24.0, 48, distance, normal, front, hit) != 1) {
            return false;
        }
        normal = dot(normal, normal) > 0.5 ? normal : -worldDir;
        float blockLevel = float(front & 15u) / 15.0;
        float skyLevel = float((front >> 4) & 15u) / 15.0;
        vec3 hitPos = start + worldDir * distance;
        if (abzaCompanionLinked() && abzaCompanionSurfaceAt(hitPos - worldDir * 0.02, cubeCoord, cubePos)) {
            inCube = true;
            color.w = distance + 0.25;
            return true;
        }
        vec3 glow = float((hit >> 8) & 15u) / 15.0 * PBR_BRIGHTNESS * PI * abzaLatticeLampColor();
        float ambientShade;
        float directShade;
        abzaLatticeShade(hitPos, normal, ambientShade, directShade);
        #ifdef COMPANION_MATERIALS
            AbzaViewMaterial material;
            if (abzaViewMaterial(int((hit >> 16) & 0xFFFu), vec3(ABZA_LATTICE_ALBEDO), material)) {
                color = vec4(abzaViewClassedLight(material, vec3(ABZA_LATTICE_ALBEDO), normal, worldDir, hitPos, blockLevel, skyLevel, ambientShade, directShade) + glow, distance + 0.25);
                return true;
            }
        #endif
        color = vec4(ABZA_LATTICE_ALBEDO * abzaSurfaceLight(blockLevel, skyLevel, hitPos, normal, 0.0, ambientShade, directShade) + glow, distance + 0.25);
        return true;
    }
#endif

#if defined ABZA_WSR || defined ABZA_COMPANION || defined ABZA_MIRROR
    #define ABZA_OFFSCREEN_REFLECTION

    // Whether the hand's and held items' rays go through the cube and the lattice instead of screen-space steps
    // (COMPANION_HELD_ITEMS): the cube leaves the local player out, so a ray from the hand finds what is around the
    // camera; the voxel copy of the world holds the player, so not with it
    #define ABZA_HELD_OFFSCREEN false
    #ifdef COMPANION_HELD_ITEMS
        #if defined ABZA_COMPANION && !defined ABZA_WSR
            #undef ABZA_HELD_OFFSCREEN
            #define ABZA_HELD_OFFSCREEN true
        #endif
    #endif

    // For a reflection ray from a point in view space, before screen-space reflection: the companion mod's mirror view,
    // when the point lies on its plane. Returns 1 on a hit (lit colour and distance travelled in color), 0 for open sky,
    // -1 when it doesn't apply (screen-space reflection and the rest then run as before).
    int abzaMirrorFirst(vec3 viewPos, vec3 viewGeoNormal, vec3 viewRayDir, out vec4 color) {
        color = vec4(0.0);
        #ifdef ABZA_MIRROR
            int result = abzaMirrorReflection(viewToWorldPos(viewPos), mat3(gbufferModelViewInverse) * viewGeoNormal,
                mat3(gbufferModelViewInverse) * viewRayDir, color);
            #ifdef ABZA_FAR_TERRAIN
                // A mirror view without the far terrain (Shaders Companion before 3.0.0-dev4, or its farTerrainInViews
                // off): where it shows open sky, screen-space reflection looks for far terrain on screen
                if (result == 0 && abzaFarDrawn() && abzaMirrorLastFarRange <= 0.0) {
                    result = -1;
                }
            #endif
            #ifdef ABZA_COMPANION_DEBUG_VIEW
                if (result == 2) {
                    result = 1;
                } else if (result >= 0) {
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
    // first, then the voxel copy of the terrain and the player, then solid blocks in the mod's lattice. On a hit returns
    // the lit colour and the distance travelled. open is true when the cube has nothing in the ray's way within its
    // range (the sky, as far as the cube can tell). A surface the cube shows, found by its own trace or the lattice's,
    // is lit once at the end, from the cube.
    bool abzaOffscreenReflection(vec3 viewPos, vec3 viewGeoNormal, vec3 viewRayDir, out vec4 color, out bool open) {
        color = vec4(0.0);
        open = false;
        #ifdef ABZA_FAR_TERRAIN
            // Rays from far terrain texels (the chunk terrain drew nothing here) start outside the cube, the voxel copy
            // and the lattice, which hold the world around the camera: no hit, the sky answers
            if (texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r >= 1.0 && abzaFarDrawn()) {
                return false;
            }
        #endif
        vec3 worldGeoNormal = mat3(gbufferModelViewInverse) * viewGeoNormal;
        vec3 traceStart = viewToWorldPos(viewPos) + worldGeoNormal * 0.02;
        vec3 traceDir = mat3(gbufferModelViewInverse) * viewRayDir;
        bool hit = false;
        bool cubeHit = false;
        vec2 cubeCoord = vec2(0.0);
        vec3 cubePos = vec3(0.0);
        #ifdef ABZA_COMPANION
            float cubeDistance = 0.0;
            int result = abzaCompanionLinked() ? abzaCompanionTrace(traceStart, traceDir, worldGeoNormal, cubeCoord, cubePos, cubeDistance) : -2;
            hit = result == 1;
            cubeHit = hit;
            color.w = cubeDistance;
            open = result == 0;
            #ifdef ABZA_COMPANION_DEBUG_VIEW
                if (result >= -1) {
                    bool unusedInCube;
                    if (!hit && abzaLatticeReflection(traceStart, worldGeoNormal, traceDir, color, unusedInCube, cubeCoord, cubePos)) {
                        result = 2;
                    }
                    color = vec4(result == 1 ? vec3(0.0, 200.0, 0.0) : result == 2 ? vec3(200.0, 100.0, 0.0) : result == 0 ? vec3(0.0, 0.0, 200.0) : vec3(200.0, 0.0, 0.0), 1.0);
                    open = false;
                    return true;
                }
            #endif
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
                cubeHit = false;
                open = false;
            }
        #endif
        #ifdef ABZA_COMPANION
            if (!hit && abzaLatticeReflection(traceStart, worldGeoNormal, traceDir, color, cubeHit, cubeCoord, cubePos)) {
                hit = true;
                open = false;
            }
            if (cubeHit) {
                color.rgb = abzaCompanionShade(cubeCoord, cubePos, traceDir);
            }
        #endif
        return hit;
    }
#endif

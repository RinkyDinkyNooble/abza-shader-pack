//
//  ABZA Shader: reflections from Shaders Companion's mirror view, the world mirrored in the largest reflecting surface
//  on screen (a water level or a glass wall) at screen resolution (layout: the mod's API.md, mirror view protocol 2)
//

#include "/abza/Companion.glsl"

#ifdef ABZA_MIRROR
    // Bound by resource location in shaders.properties; without the mod Oculus binds Minecraft's missing texture
    uniform sampler2D scMirrorAlbedo;
    uniform sampler2D scMirrorData;
    uniform sampler2D scMirrorDistance;
    uniform sampler2D scMirrorInfo;
    #ifdef ABZA_MIRROR_LIGHTING
        uniform sampler2D colortex14;
    #endif

    #define ABZA_MIRROR_STEPS 32
    #define ABZA_MIRROR_REFINEMENTS 6

    // Where a point relative to the camera lies in the mirror view (texture coordinate) and its distance from the
    // mirrored camera; false outside the view
    bool abzaMirrorProject(vec3 p, mat4 toClip, vec3 origin, out vec2 coord, out float fromOrigin) {
        vec4 clip = toClip * vec4(p, 1.0);
        coord = clip.xy / clip.w * 0.5 + 0.5;
        fromOrigin = distance(p, origin);
        return clip.w > 0.0 && all(greaterThanEqual(coord, vec2(0.0))) && all(lessThanEqual(coord, vec2(1.0)));
    }

    // The colour of a surface point the mirror view found, relative to the camera, reached by a ray in direction
    // rayDir: the lit screen where the point is on screen and not hidden (the same colour screen-space reflection
    // returns), else the mirror view's surface lit like terrain (by deferred14 with full lighting, or here with
    // abzaCompanionShadeTexel's simpler lighting). The two are blended over a depth margin, so that plants swaying on
    // screen (and still in the mirror view) don't switch pixels from one to the other.
    vec3 abzaMirrorShade(vec2 coord, vec3 surfacePos, vec3 rayDir) {
        vec3 screenColor = vec3(0.0);
        float onScreen = 0.0;
        vec3 viewSurface = worldToViewPos(surfacePos);
        if (viewSurface.z < 0.0) {
            vec3 projPos = viewToProjectionPos(viewSurface);
            vec2 screenCoord = projPos.xy * 0.5 + 0.5;
            #ifdef TAA
                screenCoord += taaOffset * 0.5;
            #endif
            if (all(lessThan(floatBitsToUint(screenCoord), floatBitsToUint(screenEdge)))) {
                float screenDepth = screenToViewDepth(textureLod(depthtex1, screenCoord, 0.0).x);
                float margin = 0.05 - viewSurface.z * 5e-3;
                onScreen = 1.0 - smoothstep(margin, margin * 4.0, abs(screenDepth + viewSurface.z));
                screenColor = texelFetch(colortex3, ivec2(screenCoord * screenSize), 0).rgb;
            }
        }
        if (onScreen > 0.999) {
            return screenColor;
        }
        #ifdef ABZA_MIRROR_LIGHTING
            vec3 litColor = texelFetch(colortex14, ivec2(coord * screenSize), 0).rgb;
        #else
            vec3 litColor = abzaCompanionShadeTexel(textureLod(scMirrorAlbedo, coord, 0.0).rgb, textureLod(scMirrorData, coord, 0.0), surfacePos, rayDir);
        #endif
        return mix(litColor, screenColor, onScreen);
    }

    // The hit of a ray from start (on the mirror's plane, relative to the camera) on the mirror view's surface at coord,
    // at distance surface from the mirrored camera: the point of the ray at that distance
    vec4 abzaMirrorHit(vec2 coord, vec3 start, vec3 worldDir, vec3 origin, float surface) {
        vec3 fromOrigin = start - origin;
        float along = dot(fromOrigin, worldDir);
        float t = sqrt(max(along * along - dot(fromOrigin, fromOrigin) + surface * surface, 0.0)) - along;
        vec3 surfacePos = start + worldDir * t;
        return vec4(abzaMirrorShade(coord, surfacePos, worldDir), t);
    }

    // For a reflection ray from a point relative to the camera: when the point lies on the mirror view's plane, traces
    // the ray through the mirror view's distance map. A ray that stays within one texel of the view (on a flat mirror
    // it runs along the mirrored camera's own ray) is answered by that texel. Otherwise a sample is behind a surface
    // when it is farther from the mirrored camera than the surface in its direction; a crossing within the step's
    // length is refined by halving and is a hit when the refined point lies on the surface. Past the march, far
    // surfaces are read in the ray's direction. Returns 1 on a hit (colour and distance travelled in color), 0 when
    // nothing is in the ray's way (open sky), -1 when the mirror view doesn't apply (no mirror this frame, a point off
    // its plane, or a ray that leaves the view).
    int abzaMirrorReflection(vec3 worldPos, vec3 worldGeoNormal, vec3 worldDir, out vec4 color) {
        color = vec4(0.0);
        vec4 header = texelFetch(scMirrorInfo, ivec2(0, 0), 0);
        if (abs(header.x - 4242.0) > 0.5 || abs(header.y - float(ABZA_MIRROR_PROTOCOL)) > 0.5 || header.z < 1.0) {
            return -1;
        }
        vec4 plane = texelFetch(scMirrorInfo, ivec2(1, 0), 0);
        float height = dot(plane.xyz, worldPos) + plane.w;
        if (abs(height) > 0.03 + length(worldPos) * 2e-3 || dot(worldGeoNormal, plane.xyz) < 0.9 || dot(worldDir, plane.xyz) <= 0.0) {
            return -1;
        }
        vec3 origin = texelFetch(scMirrorInfo, ivec2(2, 0), 0).xyz;
        mat4 toClip = mat4(
            texelFetch(scMirrorInfo, ivec2(3, 0), 0), texelFetch(scMirrorInfo, ivec2(4, 0), 0),
            texelFetch(scMirrorInfo, ivec2(5, 0), 0), texelFetch(scMirrorInfo, ivec2(6, 0), 0)
        );
        vec3 start = worldPos - plane.xyz * height;
        vec2 coord;
        float fromOrigin;
        vec2 farCoord;
        float farFromOrigin;
        if (abzaMirrorProject(start, toClip, origin, coord, fromOrigin) &&
            abzaMirrorProject(start + worldDir * 65536.0, toClip, origin, farCoord, farFromOrigin) &&
            dot(abs(farCoord - coord) * header.zw, vec2(1.0)) < 1.0) {
            coord = (coord + farCoord) * 0.5;
            float surface = textureLod(scMirrorDistance, coord, 0.0).r;
            if (surface < -0.5) {
                return -1;
            }
            if (surface <= 0.0) {
                return 0;
            }
            color = abzaMirrorHit(coord, start, worldDir, origin, surface);
            return 1;
        }
        float stepLength = 0.1;
        float t = 0.02;
        float previousT = 0.0;
        for (int i = 0; i < ABZA_MIRROR_STEPS; i++) {
            if (!abzaMirrorProject(start + worldDir * t, toClip, origin, coord, fromOrigin)) {
                return -1;
            }
            float surface = textureLod(scMirrorDistance, coord, 0.0).r;
            // -1: a part of the view the mod didn't draw (it draws only where the mirror is on screen)
            if (surface < -0.5) {
                return -1;
            }
            float behind = fromOrigin - surface;
            if (surface > 0.0 && behind > 0.0 && behind < stepLength * 1.5 + 0.02 * surface) {
                float frontT = previousT;
                float backT = t;
                for (int j = 0; j < ABZA_MIRROR_REFINEMENTS; j++) {
                    float middle = (frontT + backT) * 0.5;
                    abzaMirrorProject(start + worldDir * middle, toClip, origin, coord, fromOrigin);
                    surface = textureLod(scMirrorDistance, coord, 0.0).r;
                    if (surface > 0.0 && fromOrigin > surface) {
                        backT = middle;
                    } else {
                        frontT = middle;
                    }
                }
                // A real crossing refines onto the surface. Passing behind an object's silhouette (seen from the
                // mirrored camera) refines onto the edge instead, where the surface jumps: no hit, keep tracing.
                vec3 hitPos = start + worldDir * backT;
                abzaMirrorProject(hitPos, toClip, origin, coord, fromOrigin);
                surface = textureLod(scMirrorDistance, coord, 0.0).r;
                if (abs(fromOrigin - surface) < stepLength * 0.25 + 0.05 + 5e-3 * surface) {
                    vec3 surfacePos = origin + normalize(hitPos - origin) * surface;
                    color = vec4(abzaMirrorShade(coord, surfacePos, worldDir), distance(start, surfacePos));
                    return 1;
                }
            }
            previousT = t;
            t += stepLength;
            stepLength *= 1.15;
        }
        // Surfaces beyond the march: read once in the ray's direction
        vec3 farPoint = start + worldDir * 65536.0;
        float lastFromOrigin = fromOrigin;
        if (!abzaMirrorProject(farPoint, toClip, origin, coord, fromOrigin)) {
            return -1;
        }
        float surface = textureLod(scMirrorDistance, coord, 0.0).r;
        if (surface < -0.5) {
            return -1;
        }
        if (surface <= 0.0) {
            return 0;
        }
        if (surface > lastFromOrigin) {
            vec3 surfacePos = origin + normalize(farPoint - origin) * surface;
            color = vec4(abzaMirrorShade(coord, surfacePos, worldDir), distance(start, surfacePos));
            return 1;
        }
        return -1;
    }
#endif

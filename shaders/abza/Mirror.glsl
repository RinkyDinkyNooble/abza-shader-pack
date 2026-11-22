//
//  ABZA Shader: reflections from Shaders Companion's mirror view, the world mirrored in the largest reflecting surfaces
//  on screen (water levels and glass walls, up to COMPANION_MIRROR_PLANES of them) at screen resolution, each plane's
//  view in its own tile of the textures (layout: the mod's API.md, mirror view protocol 3)
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

    // One mirrored plane's view, a row of the info texture: the plane, the mirrored camera (the view's origin) relative
    // to the camera, the view's matrix, its size in texels, its tile's corner in the textures, how far it has faded in
    // since the mod started mirroring it, and its row (also its tile of colortex14)
    struct AbzaMirrorPlane {
        vec4 plane;
        vec3 origin;
        mat4 toClip;
        vec2 size;
        vec2 tile;
        float fadeIn;
        int row;
    };

    // The fade-in of the plane the last abzaMirrorReflection that applied used
    float abzaMirrorLastFade = 1.0;

    // A row's plane; false for an empty slot (or no mirror view this frame)
    bool abzaMirrorPlaneOf(int row, out AbzaMirrorPlane mirror) {
        vec4 header = texelFetch(scMirrorInfo, ivec2(0, row), 0);
        mirror.row = row;
        if (abs(header.x - 4242.0) > 0.5 || abs(header.y - float(ABZA_MIRROR_PROTOCOL)) > 0.5 || header.z < 1.0) {
            return false;
        }
        mirror.plane = texelFetch(scMirrorInfo, ivec2(1, row), 0);
        mirror.origin = texelFetch(scMirrorInfo, ivec2(2, row), 0).xyz;
        mirror.toClip = mat4(
            texelFetch(scMirrorInfo, ivec2(3, row), 0), texelFetch(scMirrorInfo, ivec2(4, row), 0),
            texelFetch(scMirrorInfo, ivec2(5, row), 0), texelFetch(scMirrorInfo, ivec2(6, row), 0)
        );
        mirror.size = header.zw;
        vec4 fadeAndTile = texelFetch(scMirrorInfo, ivec2(8, row), 0);
        mirror.fadeIn = clamp(fadeAndTile.x, 0.0, 1.0);
        mirror.tile = fadeAndTile.yz;
        return true;
    }

    // How far the plane of this pixel's mirror reflection has faded in, 0 to 1 (after abzaMirrorReflection)
    float abzaMirrorFadeIn() {
        return abzaMirrorLastFade;
    }

    // The texture coordinate of a point of a plane's view (coord, 0 to 1 across the view), kept half a texel inside its
    // tile so neither filtering nor rounding reaches the next one
    vec2 abzaMirrorTexcoord(AbzaMirrorPlane mirror, vec2 coord) {
        return (mirror.tile + clamp(coord * mirror.size, vec2(0.5), mirror.size - 0.5)) / vec2(textureSize(scMirrorDistance, 0));
    }

    float abzaMirrorDistanceAt(AbzaMirrorPlane mirror, vec2 coord) {
        return textureLod(scMirrorDistance, abzaMirrorTexcoord(mirror, coord), 0.0).r;
    }

    // A ray from the mirror's plane into a part of the view the mod didn't draw: -1 (not answered), or with
    // ABZA_COMPANION_DEBUG_VIEW 2 and magenta
    int abzaMirrorUndrawn(out vec4 color) {
        #ifdef ABZA_COMPANION_DEBUG_VIEW
            color = vec4(200.0, 0.0, 200.0, 1.0);
            return 2;
        #else
            color = vec4(0.0);
            return -1;
        #endif
    }

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
    vec3 abzaMirrorShade(AbzaMirrorPlane mirror, vec2 coord, vec3 surfacePos, vec3 rayDir) {
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
                // Faded out over the last 6% of the screen toward its edges, so where the reflected point leaves the
                // screen the change to the view's own lighting is a blend, not a line
                vec2 edgeDistance = min(screenCoord, screenEdge - screenCoord);
                onScreen *= smoothstep(0.0, 0.06, min(edgeDistance.x, edgeDistance.y));
                screenColor = texelFetch(colortex3, ivec2(screenCoord * screenSize), 0).rgb;
            }
        }
        #ifdef COMPANION_REFLECTIONS_ONLY
            // Every reflection from the mod's views: one lighting throughout, no screen colours
            onScreen = 0.0;
        #endif
        if (onScreen > 0.999) {
            return screenColor;
        }
        #ifdef ABZA_MIRROR_LIGHTING
            // deferred14 lit each plane's view into its own screen-sized tile of colortex14, side by side
            vec2 litPixel = min(coord * screenSize, screenSize - 1.0);
            vec3 litColor = texelFetch(colortex14, ivec2(litPixel.x + float(mirror.row) * screenSize.x, litPixel.y), 0).rgb;
        #else
            vec2 mirrorTexcoord = abzaMirrorTexcoord(mirror, coord);
            vec3 litColor = abzaCompanionShadeTexel(textureLod(scMirrorAlbedo, mirrorTexcoord, 0.0), textureLod(scMirrorData, mirrorTexcoord, 0.0), surfacePos, rayDir);
        #endif
        return mix(litColor, screenColor, onScreen);
    }

    // The hit of a ray from start (on the mirror's plane, relative to the camera) on the mirror view's surface at coord,
    // at distance surface from the mirrored camera: the point of the ray at that distance
    vec4 abzaMirrorHit(AbzaMirrorPlane mirror, vec2 coord, vec3 start, vec3 worldDir, float surface) {
        vec3 fromOrigin = start - mirror.origin;
        float along = dot(fromOrigin, worldDir);
        float t = sqrt(max(along * along - dot(fromOrigin, fromOrigin) + surface * surface, 0.0)) - along;
        vec3 surfacePos = start + worldDir * t;
        return vec4(abzaMirrorShade(mirror, coord, surfacePos, worldDir), t);
    }

    // For a reflection ray from a point relative to the camera: when the point lies on one of the mirrored planes,
    // traces the ray through that plane's view's distance map. A ray that stays within one texel of the view (on a flat mirror
    // it runs along the mirrored camera's own ray) is answered by that texel. Otherwise a sample is behind a surface
    // when it is farther from the mirrored camera than the surface in its direction; a crossing within the step's
    // length is refined by halving and is a hit when the refined point lies on the surface. Past the march, far
    // surfaces are read in the ray's direction. Returns 1 on a hit (colour and distance travelled in color), 0 when
    // nothing is in the ray's way (open sky), -1 when the mirror view doesn't apply (no mirror this frame, a point off
    // no plane, or a ray that leaves the view; 2 with ABZA_COMPANION_DEBUG_VIEW for a part of the view not drawn).
    int abzaMirrorReflection(vec3 worldPos, vec3 worldGeoNormal, vec3 worldDir, out vec4 color) {
        color = vec4(0.0);
        AbzaMirrorPlane mirror;
        float height = 0.0;
        bool onPlane = false;
        for (int row = 0; row < ABZA_MIRROR_PLANES && !onPlane; row++) {
            if (abzaMirrorPlaneOf(row, mirror)) {
                height = dot(mirror.plane.xyz, worldPos) + mirror.plane.w;
                onPlane = abs(height) <= 0.03 + length(worldPos) * 2e-3 && dot(worldGeoNormal, mirror.plane.xyz) >= 0.9 && dot(worldDir, mirror.plane.xyz) > 0.0;
            }
        }
        if (!onPlane) {
            return -1;
        }
        abzaMirrorLastFade = mirror.fadeIn;
        vec3 origin = mirror.origin;
        mat4 toClip = mirror.toClip;
        vec3 start = worldPos - mirror.plane.xyz * height;
        vec2 coord;
        float fromOrigin;
        vec2 farCoord;
        float farFromOrigin;
        if (abzaMirrorProject(start, toClip, origin, coord, fromOrigin) &&
            abzaMirrorProject(start + worldDir * 65536.0, toClip, origin, farCoord, farFromOrigin) &&
            dot(abs(farCoord - coord) * mirror.size, vec2(1.0)) < 1.0) {
            coord = (coord + farCoord) * 0.5;
            float surface = abzaMirrorDistanceAt(mirror, coord);
            if (surface < -0.5) {
                return abzaMirrorUndrawn(color);
            }
            if (surface <= 0.0) {
                return 0;
            }
            color = abzaMirrorHit(mirror, coord, start, worldDir, surface);
            return 1;
        }
        float stepLength = 0.1;
        float t = 0.02;
        float previousT = 0.0;
        for (int i = 0; i < ABZA_MIRROR_STEPS; i++) {
            if (!abzaMirrorProject(start + worldDir * t, toClip, origin, coord, fromOrigin)) {
                return -1;
            }
            float surface = abzaMirrorDistanceAt(mirror, coord);
            // -1: a part of the view the mod didn't draw (it draws only where the mirror is on screen)
            if (surface < -0.5) {
                return abzaMirrorUndrawn(color);
            }
            float behind = fromOrigin - surface;
            if (surface > 0.0 && behind > 0.0 && behind < stepLength * 1.5 + 0.02 * surface) {
                float frontT = previousT;
                float backT = t;
                for (int j = 0; j < ABZA_MIRROR_REFINEMENTS; j++) {
                    float middle = (frontT + backT) * 0.5;
                    abzaMirrorProject(start + worldDir * middle, toClip, origin, coord, fromOrigin);
                    surface = abzaMirrorDistanceAt(mirror, coord);
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
                surface = abzaMirrorDistanceAt(mirror, coord);
                if (abs(fromOrigin - surface) < stepLength * 0.25 + 0.05 + 5e-3 * surface) {
                    vec3 surfacePos = origin + normalize(hitPos - origin) * surface;
                    color = vec4(abzaMirrorShade(mirror, coord, surfacePos, worldDir), distance(start, surfacePos));
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
        float surface = abzaMirrorDistanceAt(mirror, coord);
        if (surface < -0.5) {
            return abzaMirrorUndrawn(color);
        }
        if (surface <= 0.0) {
            return 0;
        }
        if (surface > lastFromOrigin) {
            vec3 surfacePos = origin + normalize(farPoint - origin) * surface;
            color = vec4(abzaMirrorShade(mirror, coord, surfacePos, worldDir), distance(start, surfacePos));
            return 1;
        }
        return -1;
    }
#endif

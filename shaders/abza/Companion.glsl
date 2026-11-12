//
//  ABZA Shader: reflections from Shaders Companion, a companion mod that draws a low-resolution cube view of the
//  terrain, entities and Distant Horizons LODs around the camera, and a mirror view, into textures (layout: the mod's
//  API.md, cube protocol 2, mirror view protocol 1)
//

#ifndef ABZA_COMPANION_GLSL
#define ABZA_COMPANION_GLSL

#ifdef COMPANION_REFLECTIONS
    #define ABZA_COMPANION
#endif
#ifdef COMPANION_MIRROR
    #define ABZA_MIRROR
    #define ABZA_MIRROR_PROTOCOL 1
    #ifdef COMPANION_MIRROR_LIGHTING
        // The mirror view lit by deferred14 (abza/MirrorLightPass.frag) into colortex14
        #define ABZA_MIRROR_LIGHTING
    #endif
#endif

#if defined ABZA_COMPANION || defined ABZA_MIRROR
    #include "/abza/SurfaceLight.glsl"

    vec3 abzaCompanionOctDecode(vec2 e) {
        e = e * 2.0 - 1.0;
        vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
        if (n.z < 0.0) {
            n.xy = (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
        }
        return normalize(n);
    }

    // How much a cube texel glows, by the same rules Terrain.frag uses for terrain on screen: the block id's hard-coded
    // emission, glowing ores, and full block light on blocks block.properties doesn't list (modded light sources)
    float abzaCompanionEmission(vec3 albedo, int material, float blockLevel) {
        float emissive = 0.0;
        #ifdef HARDCODED_EMISSIVE
            int commonEmissive = max(0, material) & 0x7000;
            emissive = float(material == 8195);
            if (commonEmissive > 16384) {
                emissive = clamp(0.57 * length(albedo) + float(commonEmissive == 0x5000), 0.0, 1.0);
            }
            else if (material == 8198) {
                emissive = clamp(2.0 * albedo.r - 1.5 * albedo.g, 0.0, 1.0);
            }
            else if (material == 8200) {
                emissive = clamp(2.0 * albedo.b - 1.0 * albedo.r, 0.0, 1.0);
            }
            else if (material == 8197 || material == 8202) {
                emissive = clamp((0.8 * albedo.r - 1.2 * albedo.b) * dot(albedo, vec3(0.3333)), 0.0, 1.0);
            }
            else if (material == 8203) {
                emissive = float(pow2(albedo.r) > 0.3 * (pow2(albedo.b) + pow2(albedo.g)) + 0.3);
            }
            else if (material == 8204) {
                emissive = clamp(2.0 * albedo.b - 4.5 * albedo.r, 0.0, 1.0) + clamp(2.0 * albedo.r - 3.0 * albedo.b, 0.0, 1.0);
            }
            else if (material == 8205) {
                emissive = clamp(0.5 * albedo.b - 1.0 * albedo.r - 0.2, 0.0, 1.0);
            }
        #endif
        #ifdef GLOWING_ORES
            if (material >= ABZA_ORE_FIRST && material <= ABZA_ORE_LAST) {
                emissive = max(emissive, abzaOreMask(albedo, material) * GLOWING_ORE_STRENGTH);
            }
        #endif
        #ifdef MOD_LIGHT_DETECTION
            if (blockLevel > 0.999 && material < 0) {
                emissive += float(emissive < 1e-3);
            }
        #endif
        return emissive;
    }

    // The material Terrain.vert gives a block (its block.properties id, -1 when not listed) on a face with this normal:
    // the plant bits it sets by the face's shape (crossed plant quads have diagonal normals)
    int abzaCompanionMaterial(int id, vec3 normal) {
        bool crossed = abs(max(abs(normal.x), abs(normal.z)) - 0.5) < 0.4;
        if (id < 0) {
            #ifdef MOD_PLANT_DETECTION
                return crossed ? 19968 : id;
            #else
                return id;
            #endif
        }
        if (id == 8206 || id == 8207) {
            return crossed ? 18432 + (id - 8206) * 1024 : 0;
        }
        if (id == 8209) {
            return crossed ? 18944 : 16896;
        }
        if (id == 8210) {
            return 18944;
        }
        return id;
    }

    // Porosity as Terrain.frag sets it without a PBR pack: above 64.5 / 255 sunlight scatters through (plants, leaves)
    float abzaCompanionPorosity(int material) {
        int commonPorosity = material == 8198 ? 0x4E00 : max(0, material) & 0x4E00;
        return commonPorosity > 16384 ? ((commonPorosity & 0x0800) != 0 ? 0.5 : 0.75) : 0.0;
    }

    // Plants and leaves, which Deferred12 lights from the sky as if they faced up (MAT_GRASS)
    bool abzaCompanionPlant(int material) {
        return (max(0, material) & 0x4800) == 0x4800 || material == 8198 || material == 8206 || material == 8207;
    }

    // The lit colour of a surface the mod drew, from its albedo and data texels (the cube's or the mirror view's);
    // surfacePos is the surface point, relative to this frame's camera, and rayDir the direction the reflection ray
    // reached it in. The id field tells blocks (block.properties id + 1), entities (0x8000 + entity.properties id + 1)
    // and Distant Horizons LODs (0xC000 + its block material) apart.
    vec3 abzaCompanionShadeTexel(vec3 albedo, vec4 rawData, vec3 surfacePos, vec3 rayDir) {
        uvec3 data = uvec3(round(rawData.rgb * 65535.0));
        vec3 normal = abzaCompanionOctDecode(vec2(float(data.r >> 8u), float(data.r & 255u)) / 255.0);
        // Surfaces drawn on both sides (plants, panes) face the ray, as Terrain.frag turns them to the camera
        normal = dot(normal, rayDir) > 0.0 ? -normal : normal;
        // Plants and leaves let sunlight through
        float translucent = data.b < 0x8000u ? float(abzaCompanionPorosity(abzaCompanionMaterial(int(data.b) - 1, normal)) > 64.5 / 255.0) : 0.0;
        float blockLevel = float(data.g >> 8u) / 255.0;
        float skyLevel = float(data.g & 255u) / 255.0;
        float emissive;
        if (data.b >= 0xC000u) {
            // Distant Horizons materials: lava (6) and light sources (15)
            uint lodMaterial = data.b & 0xFFu;
            emissive = float(lodMaterial == 6u || lodMaterial == 15u);
        }
        else if (data.b >= 0x8000u) {
            // Entities: glowing layers such as eyes
            emissive = rawData.a;
        }
        else {
            emissive = abzaCompanionEmission(albedo, int(data.b) - 1, blockLevel);
        }
        return pow(albedo, vec3(2.2)) * (abzaSurfaceLight(blockLevel, skyLevel, surfacePos, normal, translucent) + emissive * PBR_BRIGHTNESS * PI);
    }
#endif

#ifdef ABZA_COMPANION
    // Bound by resource location in shaders.properties; without the mod Oculus binds Minecraft's missing texture
    uniform sampler2D scAlbedo;
    uniform sampler2D scData;
    uniform sampler2D scDistance;
    uniform sampler2D scInfo;

    #define ABZA_COMPANION_PROTOCOL 2
    #define ABZA_COMPANION_STEPS 40
    #define ABZA_COMPANION_REFINEMENTS 6
    // Surfaces closer than this (blocks) to the reflecting surface's own plane are not hits: the surface itself, what
    // lies level with it, and Distant Horizons' water, drawn 1/9 block above the water it continues
    #define ABZA_COMPANION_PLANE_MARGIN 0.2

    // True when the mod is installed, speaks this protocol and has drawn the cube at least once
    bool abzaCompanionLinked() {
        vec4 header = texelFetch(scInfo, ivec2(0, 0), 0);
        return abs(header.x - 4242.0) < 0.5 && abs(header.y - float(ABZA_COMPANION_PROTOCOL)) < 0.5 && header.z > 0.0;
    }

    // Faces: 0 +x, 1 -x, 2 +y, 3 -y, 4 +z, 5 -z, by the direction's largest component
    int abzaCompanionFace(vec3 d) {
        vec3 a = abs(d);
        if (a.x >= a.y && a.x >= a.z) return d.x >= 0.0 ? 0 : 1;
        if (a.y >= a.z) return d.y >= 0.0 ? 2 : 3;
        return d.z >= 0.0 ? 4 : 5;
    }

    // Atlas coordinate of direction d on a face. Each face is a 90 degree view with its own up and right axes; the
    // atlas holds 3 x 2 faces, face i at column i % 3 and row i / 3 (row 0 at the bottom)
    vec2 abzaCompanionCoord(vec3 d, int face, float faceSize) {
        vec3 forward, up, right;
        if (face == 0)      { forward = vec3( 1.0, 0.0, 0.0); up = vec3(0.0, 1.0, 0.0); right = vec3( 0.0, 0.0,  1.0); }
        else if (face == 1) { forward = vec3(-1.0, 0.0, 0.0); up = vec3(0.0, 1.0, 0.0); right = vec3( 0.0, 0.0, -1.0); }
        else if (face == 2) { forward = vec3( 0.0, 1.0, 0.0); up = vec3(0.0, 0.0, 1.0); right = vec3( 1.0, 0.0,  0.0); }
        else if (face == 3) { forward = vec3( 0.0,-1.0, 0.0); up = vec3(0.0, 0.0,-1.0); right = vec3( 1.0, 0.0,  0.0); }
        else if (face == 4) { forward = vec3( 0.0, 0.0, 1.0); up = vec3(0.0, 1.0, 0.0); right = vec3(-1.0, 0.0,  0.0); }
        else                { forward = vec3( 0.0, 0.0,-1.0); up = vec3(0.0, 1.0, 0.0); right = vec3( 1.0, 0.0,  0.0); }
        vec2 uv = 0.5 + 0.5 * vec2(dot(d, right), dot(d, up)) / dot(d, forward);
        uv = clamp(uv, vec2(0.5 / faceSize), vec2(1.0 - 0.5 / faceSize));
        return (vec2(float(face % 3), float(face / 3)) + uv) / vec2(3.0, 2.0);
    }

    // Where a point relative to this frame's camera lies in the cube. Each face was drawn from where the camera was then,
    // so the point is looked up from its face's origin. Returns false where that face hasn't been drawn yet.
    bool abzaCompanionLookup(vec3 p, float faceSize, out vec3 fromOrigin, out vec2 coord) {
        int face = abzaCompanionFace(p);
        vec4 origin = texelFetch(scInfo, ivec2(1 + face, 0), 0);
        fromOrigin = p - origin.xyz;
        int originFace = abzaCompanionFace(fromOrigin);
        if (originFace != face) {
            face = originFace;
            origin = texelFetch(scInfo, ivec2(1 + face, 0), 0);
            fromOrigin = p - origin.xyz;
        }
        coord = abzaCompanionCoord(fromOrigin, face, faceSize);
        return origin.w >= 0.0;
    }

    // The lit colour of the cube's surface at an atlas coordinate; surfacePos is the surface point, relative to this
    // frame's camera, reached by a ray in direction rayDir
    vec3 abzaCompanionShade(vec2 coord, vec3 surfacePos, vec3 rayDir) {
        return abzaCompanionShadeTexel(textureLod(scAlbedo, coord, 0.0).rgb, textureLod(scData, coord, 0.0), surfacePos, rayDir);
    }

    // The point on the cube's surface seen along fromOrigin (a lookup's direction from its face's origin), relative to
    // this frame's camera, for a lookup made at point p
    vec3 abzaCompanionSurfacePoint(vec3 p, vec3 fromOrigin, float surface) {
        return p - fromOrigin + normalize(fromOrigin) * surface;
    }

    // Traces a ray from a point relative to the camera through the cube's distance map, in steps that grow with
    // distance, like screen-space reflection on a screen all around the camera. A sample is behind the cube's surface
    // when it is farther from the face's origin than the surface in its direction; a crossing within the step's length
    // is refined by halving and is a hit when the refined point lies on the surface, clear of the reflecting surface's
    // plane (planeNormal through worldPos). Past the march, far surfaces (distant terrain, Distant Horizons LODs) are
    // read in the ray's direction. Returns 1 on a hit (colour and distance travelled in color), 0 when nothing is in
    // the ray's way within the cube, -1 where part of the cube hasn't been drawn yet.
    int abzaCompanionReflection(vec3 worldPos, vec3 worldDir, vec3 planeNormal, out vec4 color) {
        color = vec4(0.0);
        float faceSize = texelFetch(scInfo, ivec2(0, 0), 0).z;
        float range = texelFetch(scInfo, ivec2(7, 0), 0).z;
        float stepLength = 0.15;
        float t = 0.05;
        float previousT = 0.0;
        for (int i = 0; i < ABZA_COMPANION_STEPS; i++) {
            vec3 p = worldPos + worldDir * t;
            vec3 fromOrigin;
            vec2 coord;
            if (!abzaCompanionLookup(p, faceSize, fromOrigin, coord)) {
                return -1;
            }
            float surface = textureLod(scDistance, coord, 0.0).r;
            float behind = length(fromOrigin) - surface;
            if (surface > 0.0 && behind > 0.0 && behind < stepLength * 1.5 + 0.02 * surface) {
                float frontT = previousT;
                float backT = t;
                for (int j = 0; j < ABZA_COMPANION_REFINEMENTS; j++) {
                    float middle = (frontT + backT) * 0.5;
                    abzaCompanionLookup(worldPos + worldDir * middle, faceSize, fromOrigin, coord);
                    surface = textureLod(scDistance, coord, 0.0).r;
                    if (surface > 0.0 && length(fromOrigin) > surface) {
                        backT = middle;
                    } else {
                        frontT = middle;
                    }
                }
                // A real crossing refines onto the surface. Passing behind an object's silhouette (seen from the
                // origin) refines onto the edge instead, where the surface jumps: no hit, keep tracing.
                vec3 hitPos = worldPos + worldDir * backT;
                abzaCompanionLookup(hitPos, faceSize, fromOrigin, coord);
                surface = textureLod(scDistance, coord, 0.0).r;
                if (abs(length(fromOrigin) - surface) < stepLength * 0.25 + 0.1 + 0.01 * surface) {
                    vec3 surfacePos = abzaCompanionSurfacePoint(hitPos, fromOrigin, surface);
                    if (dot(surfacePos - worldPos, planeNormal) > ABZA_COMPANION_PLANE_MARGIN) {
                        color = vec4(abzaCompanionShade(coord, surfacePos, worldDir), backT);
                        return 1;
                    }
                }
            }
            if (length(p.xz) > range) {
                break;
            }
            previousT = t;
            t += stepLength;
            stepLength *= 1.12;
        }
        // Surfaces beyond the march barely shift between the ray's start and the faces' origins
        vec3 farPoint = worldDir * 65536.0;
        vec3 fromOrigin;
        vec2 coord;
        if (!abzaCompanionLookup(farPoint, faceSize, fromOrigin, coord)) {
            return -1;
        }
        float surface = textureLod(scDistance, coord, 0.0).r;
        if (surface > t) {
            vec3 surfacePos = abzaCompanionSurfacePoint(farPoint, fromOrigin, surface);
            if (dot(surfacePos - worldPos, planeNormal) > ABZA_COMPANION_PLANE_MARGIN) {
                color = vec4(abzaCompanionShade(coord, surfacePos, worldDir), distance(worldPos, surfacePos));
                return 1;
            }
        }
        return 0;
    }
#endif

#endif

//
//  ABZA Shader: debug views of Shaders Companion's lattice (Final)
//    1: the lattice against the picture: green where a surface lies on the lattice's shape, red where the lattice has
//       nothing behind a surface, yellow where the lattice reaches out in front of it, blue where it is unknown
//    2: the lattice itself, traced from the camera: grey shapes lit by their own sky and block light, water blue, lava
//       orange, see-through blocks light blue, blocks without collision green, light sources yellow, blocks with a
//       material class in its hue (as "Material classes (debug)"), unknown blocks inside the window magenta, the end
//       of the window or of the trace dark blue
//    3: the openness field on the picture's surfaces, white open to black closed in; blue where it doesn't answer
//    4: the detail's contact shade on the picture's surfaces, white open to black closed in; blue without the detail
//


#if LATTICE_DEBUG_VIEW > 0
    #include "/abza/Lattice.glsl"

    vec3 abzaLatticeDebugPos(vec2 coord, float depth) {
        vec3 viewPos = vec3(coord * 2.0 - 1.0, depth * 2.0 - 1.0);
        #ifdef TAA
            viewPos.xy -= taaOffset;
        #endif
        vec4 pos = gbufferProjectionInverse * vec4(viewPos, 1.0);
        return mat3(gbufferModelViewInverse) * (pos.xyz / pos.w) + gbufferModelViewInverse[3].xyz;
    }

    vec3 abzaLatticeDebug(vec3 color, vec2 coord) {
        if (!abzaLatticeStart()) {
            return mix(color, vec3(0.5, 0.0, 0.5), 0.3);
        }
        #if LATTICE_DEBUG_VIEW == 3 || LATTICE_DEBUG_VIEW == 4
            float depth = textureLod(depthtex1, coord, 0.0).r;
            vec3 pos = abzaLatticeDebugPos(coord, depth);
            vec3 normal = normalize(cross(dFdx(pos), dFdy(pos)));
            if (depth >= 1.0 || depth < 0.56) {
                return color;
            }
            if (dot(normal, pos) > 0.0) {
                normal = -normal;
            }
            #if LATTICE_DEBUG_VIEW == 4
                // Snapped to the nearest axis, as block faces are
                vec3 axis = abs(normal);
                normal = axis.x > max(axis.y, axis.z) ? vec3(sign(normal.x), 0.0, 0.0) : axis.y > axis.z ? vec3(0.0, sign(normal.y), 0.0) : vec3(0.0, 0.0, sign(normal.z));
                return abzaLatticeDetailStart() ? vec3(1.0 - abzaLatticeContact(pos + normal * 3e-3, normal)) : vec3(0.1, 0.2, 0.6);
            #else
                float open = abzaLatticeFieldStart() ? abzaLatticeOpenness(pos, normal) : -1.0;
                return open < 0.0 ? vec3(0.1, 0.2, 0.6) : vec3(open);
            #endif
        #elif LATTICE_DEBUG_VIEW == 1
            // Derivatives before any branch
            float depth = textureLod(depthtex1, coord, 0.0).r;
            vec3 pos = abzaLatticeDebugPos(coord, depth);
            vec3 normal = normalize(cross(dFdx(pos), dFdy(pos)));
            if (depth >= 1.0 || depth < 0.56) {
                return color;
            }
            if (dot(normal, pos) > 0.0) {
                normal = -normal;
            }
            bool knownIn, knownOut;
            bool inside = abzaLatticeFilled(pos - normal * 0.03, knownIn);
            bool outside = abzaLatticeFilled(pos + normal * 0.03, knownOut);
            vec3 tint = !knownIn ? vec3(0.1, 0.3, 1.0) : !inside ? vec3(1.0, 0.1, 0.1) : outside ? vec3(1.0, 0.9, 0.1) : vec3(0.1, 1.0, 0.2);
            return mix(color, tint * (0.4 + 0.6 * dot(color, vec3(0.3, 0.6, 0.1))), 0.6);
        #else
            vec3 viewDir = abzaLatticeDebugPos(coord, 1.0);
            vec3 dir = normalize(viewDir - gbufferModelViewInverse[3].xyz);
            float hitDistance;
            vec3 normal;
            uint cell;
            int result = abzaLatticeTrace(gbufferModelViewInverse[3].xyz, dir, 96.0, 400, hitDistance, normal, cell);
            // Leaving the window counts as reaching the end; magenta marks blocks inside it that aren't known
            vec3 stop = gbufferModelViewInverse[3].xyz + dir * (hitDistance + 0.01) + cameraPositionFract;
            ivec3 stopLocal = ivec3(floor(stop)) + cameraPositionInt - abzaLatticeMin;
            bool inWindow = all(lessThan(uvec3(stopLocal), uvec3(abzaLatticeSize)));
            if (result == 2 && inWindow) {
                return vec3(0.6, 0.0, 0.6) * (1.0 - 0.5 * clamp(hitDistance / 96.0, 0.0, 1.0));
            }
            if (result != 1) {
                return vec3(0.05, 0.08, 0.15);
            }
            // Lit by the light of the open space in front of the face (a solid block holds no light of its own)
            vec3 front = gbufferModelViewInverse[3].xyz + dir * hitDistance + normal * 0.05 + cameraPositionFract;
            uint frontCell = abzaLatticeCell(ivec3(floor(front)) + cameraPositionInt);
            uint lightCell = frontCell != 0u ? frontCell : cell;
            float blockLight = float(lightCell & 15u) / 15.0;
            float skyLight = float((lightCell >> 4) & 15u) / 15.0;
            vec3 albedo = vec3(0.7);
            if ((cell & ABZA_LATTICE_WATER) != 0u) albedo = vec3(0.2, 0.4, 1.0);
            if ((cell & ABZA_LATTICE_LAVA) != 0u) albedo = vec3(1.0, 0.4, 0.1);
            if ((cell & ABZA_LATTICE_SEE_THROUGH) != 0u) albedo = vec3(0.6, 0.85, 1.0);
            if ((cell & ABZA_LATTICE_NO_COLLISION) != 0u) albedo = vec3(0.3, 0.9, 0.3);
            if (((cell >> 8) & 15u) != 0u) albedo = vec3(1.0, 0.9, 0.2);
            // Blocks with a material class (bits 16-27) in the class's hue, as "Material classes (debug)" colours them
            uint materialClass = (cell >> 16) & 0xFFFu;
            if (materialClass != 0u) {
                float hue = fract(float(materialClass) * 0.618034);
                albedo = clamp(abs(fract(hue + vec3(0.0, 2.0, 1.0) / 3.0) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
            }
            float shade = 0.55 + 0.25 * normal.y + 0.1 * abs(normal.x);
            float light = 0.08 + 0.92 * max(skyLight, blockLight * 0.9);
            return albedo * shade * light * exp(-hitDistance / 160.0);
        #endif
    }
#endif

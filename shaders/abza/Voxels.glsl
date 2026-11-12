//
//  ABZA Shader: world-space reflections from a voxel copy of the terrain and the player around the camera
//

// The shadow pass records the terrain within the grid, addressed by world block position wrapped to the grid:
//   abzaVoxels (cleared every frame), one header per block:
//     bits 0-7 occupied half-block cells (bit x + 2y + 4z), bits 8-11 block light emission, bit 12 water,
//     bits 16-31 glowing ore block ID
//   abzaVoxelFaces, per block and side (0 -x, 1 +x, 2 -y, 3 +y, 4 -z, 5 +z):
//     x: atlas texel of the sprite's corner (x low 16 bits, y high 16 bits)
//     y: tint (4 bits each, red lowest), block light (bits 12-15), sky light (bits 16-19), texture rotation (bits 20-21),
//        log2 of the sprite size (bits 22-24), frame tag (bits 25-31)
// It also records the player model's quads (abzaPlayer) and copies the skin (abzaSkin).
// Composite0 traces reflections through them where screen-space reflection misses.

#ifdef WORLD_REFLECTIONS
    #define ABZA_WSR
#endif

#ifdef ABZA_WSR
    #define ABZA_VOXEL_GRID 128
    #define ABZA_PLAYER_ID 10000
    #define ABZA_PLAYER_VERTICES 288

    // Distance around the camera where the shadow pass draws everything (shadow.culling = reversed)
    const float voxelDistance = 64.0;

    const int abzaVoxelMask = ABZA_VOXEL_GRID - 1;

    uniform vec3 cameraPositionFract;
    uniform ivec3 cameraPositionInt;

    layout(std430, binding = 0) buffer abzaVoxelFaceBuffer {
        uvec2 abzaVoxelFaces[];
    };

    layout(std430, binding = 1) buffer abzaPlayerBuffer {
        int abzaPlayerFrame;
        uint abzaPlayerLight;
        vec4 abzaPlayerVertices[ABZA_PLAYER_VERTICES];
        vec2 abzaPlayerCoords[ABZA_PLAYER_VERTICES];
    };

    ivec3 abzaVoxelWrap(ivec3 block) {
        return block & abzaVoxelMask;
    }

    int abzaVoxelFace(int side, ivec3 block) {
        ivec3 wrapped = abzaVoxelWrap(block);
        return (wrapped.x + (wrapped.z + wrapped.y * ABZA_VOXEL_GRID) * ABZA_VOXEL_GRID) * 6 + side;
    }

    // True for a block offset from the camera's block that lies inside the grid
    bool abzaInVoxelGrid(ivec3 offset) {
        return all(lessThan(abs(2 * offset + 1), ivec3(ABZA_VOXEL_GRID)));
    }

    uint abzaVoxelFrameTag() {
        return uint(frameCounter) & 127u;
    }

    // Texture coordinates of a point on a block side, as Minecraft maps an unrotated face
    vec2 abzaSideCoord(int side, vec3 local) {
        if (side == 0) return vec2(local.z, 1.0 - local.y);
        if (side == 1) return vec2(1.0 - local.z, 1.0 - local.y);
        if (side == 2) return vec2(local.x, 1.0 - local.z);
        if (side == 3) return vec2(local.x, local.z);
        if (side == 4) return vec2(1.0 - local.x, 1.0 - local.y);
        return vec2(local.x, 1.0 - local.y);
    }

    // A face's texture turned in 90 degree steps
    vec2 abzaRotateCoord(int rotation, vec2 coord) {
        if (rotation == 1) return vec2(1.0 - coord.y, coord.x);
        if (rotation == 2) return 1.0 - coord;
        if (rotation == 3) return vec2(coord.y, 1.0 - coord.x);
        return coord;
    }

    #ifdef ABZA_VOXEL_WRITE
        uniform int renderStage;
        uniform int entityId;
        in vec4 at_midBlock;
        layout(r32ui) uniform uimage3D abzaVoxels;
        layout(rgba8) uniform writeonly image2D abzaSkin;

        // Records the face this terrain vertex belongs to: the half-block cell behind it, and its sprite, rotation, tint
        // and light. Faces that aren't axis-aligned, and sprites mostly transparent at five points (overlays, glass,
        // plants), are skipped. Water is recorded from the translucent pass.
        void abzaVoxelize(vec3 vertexPos, vec2 vertexCoord, vec2 midCoord, int material) {
            bool isWater = material == 8192;
            if (renderStage != MC_RENDER_STAGE_TERRAIN_SOLID && renderStage != MC_RENDER_STAGE_TERRAIN_CUTOUT && renderStage != MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED
                && !(isWater && renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT)) {
                return;
            }
            vec3 absNormal = abs(gl_Normal);
            int axis = absNormal.x > 0.9 ? 0 : absNormal.y > 0.9 ? 1 : absNormal.z > 0.9 ? 2 : -1;
            if (axis < 0) {
                return;
            }
            int side = axis * 2 + int(gl_Normal[axis] > 0.0);

            vec3 cameraBlockPos = mat3(shadowModelViewInverse) * (gl_ModelViewMatrix * vec4(vertexPos, 1.0)).xyz + shadowModelViewInverse[3].xyz + cameraPositionFract;
            vec3 centerView = (gl_ModelViewMatrix * vec4(vertexPos + at_midBlock.xyz / 64.0, 1.0)).xyz;
            ivec3 block = ivec3(floor(mat3(shadowModelViewInverse) * centerView + shadowModelViewInverse[3].xyz + cameraPositionFract));
            if (!abzaInVoxelGrid(block)) {
                return;
            }

            vec2 halfSize = abs(vertexCoord - midCoord);
            float cover = float(textureLod(gtexture, midCoord, 0.0).a > 0.5);
            for (int i = 0; i < 4; i++) {
                vec2 corner = vec2(float(i & 1), float(i >> 1)) - 0.5;
                cover += float(textureLod(gtexture, midCoord + halfSize * corner, 0.0).a > 0.5);
            }
            if (cover < 2.5) {
                return;
            }

            // Only a vertex on the block's edges along the side tells which half-block cell is behind it and which corner
            // of the side it is on: one in the middle (a slab's upper side edge) could border either cell
            vec3 local = clamp(cameraBlockPos - vec3(block), 0.0, 1.0);
            bvec3 onEdge = lessThan(min(local, 1.0 - local), vec3(0.02));
            onEdge[axis] = true;
            if (!all(onEdge)) {
                return;
            }
            vec3 behind = local - gl_Normal * 0.25;
            ivec3 cell = ivec3(clamp(floor(behind * 2.0), 0.0, 1.0));
            uint emission = uint(clamp(round(at_midBlock.w), 0.0, 15.0));
            uint ore = (material >= 8300 && material < 8400) ? uint(material) : 0u;
            imageAtomicOr(abzaVoxels, abzaVoxelWrap(block + cameraPositionInt),
                (1u << uint(cell.x + cell.y * 2 + cell.z * 4)) | (emission << 8) | (uint(isWater) << 12) | (ore << 16));

            // Texture: the vertex's corner on the side, unrotated, against the corner of the sprite its coordinate is on
            vec2 sideCoord = abzaSideCoord(side, local);
            vec2 sideCorner = step(0.5, sideCoord);
            vec2 textureCorner = step(midCoord, vertexCoord);
            int rotation = 0;
            for (int r = 1; r < 4; r++) {
                if (abzaRotateCoord(r, sideCorner) == textureCorner) {
                    rotation = r;
                }
            }
            vec2 atlasSize = vec2(textureSize(gtexture, 0));
            vec2 quadSize = 2.0 * halfSize * atlasSize;
            float sizeLog2 = clamp(ceil(log2(max(max(quadSize.x, quadSize.y), 1.0)) - 0.01), 0.0, 7.0);
            vec2 origin = vertexCoord * atlasSize - abzaRotateCoord(rotation, sideCoord) * exp2(sizeLog2);
            uvec2 originTexel = uvec2(clamp(round(origin), vec2(0.0), vec2(65535.0)));
            uvec3 tint = uvec3(round(clamp(gl_Color.rgb, 0.0, 1.0) * 15.0));
            uvec2 light = uvec2(round(clamp(gl_MultiTexCoord1.st / 232.0 - 8.0 / 232.0, 0.0, 1.0) * 15.0));
            abzaVoxelFaces[abzaVoxelFace(side, block + cameraPositionInt)] = uvec2(
                originTexel.x | (originTexel.y << 16),
                tint.r | (tint.g << 4) | (tint.b << 8) | (light.x << 12) | (light.y << 16) | (uint(rotation) << 20) | (uint(sizeLog2) << 22) | (abzaVoxelFrameTag() << 25)
            );
        }

        // Records the local player's model (a 64 x 64 skinned player within 3 blocks of the camera, 288 vertices)
        // and copies the skin, 16 texels per vertex
        void abzaCapturePlayer(vec3 vertexPos, vec2 vertexCoord) {
            if (renderStage != MC_RENDER_STAGE_ENTITIES || entityId != ABZA_PLAYER_ID || textureSize(gtexture, 0) != ivec2(64)) {
                return;
            }
            vec3 worldPos = mat3(shadowModelViewInverse) * (gl_ModelViewMatrix * vec4(vertexPos, 1.0)).xyz + shadowModelViewInverse[3].xyz;
            if (dot(worldPos, worldPos) > 9.0) {
                return;
            }
            int vertex = gl_VertexID % ABZA_PLAYER_VERTICES;
            abzaPlayerVertices[vertex] = vec4(worldPos, 1.0);
            abzaPlayerCoords[vertex] = vertexCoord;
            if (vertex == 0) {
                abzaPlayerFrame = frameCounter;
                uvec2 light = uvec2(round(clamp(gl_MultiTexCoord1.st / 232.0 - 8.0 / 232.0, 0.0, 1.0) * 15.0));
                abzaPlayerLight = light.x | (light.y << 4);
            }
            for (int i = 0; i < 16; i++) {
                int index = vertex * 16 + i;
                if (index < 4096) {
                    ivec2 texel = ivec2(index & 63, index >> 6);
                    imageStore(abzaSkin, texel, texelFetch(gtexture, texel, 0));
                }
            }
        }
    #else
        #include "/abza/SurfaceLight.glsl"

        uniform usampler3D abzaVoxelSampler;
        uniform sampler2D abzaSkinSampler;
        uniform sampler2D abzaAtlas;

        // Shades a hit on a block side: false where the side wasn't recorded this frame or its texel is transparent
        bool abzaVoxelShade(ivec3 block, int side, uint header, vec3 hitPos, float rayLength, out vec4 voxelColor) {
            voxelColor = vec4(0.0);
            uvec2 face = abzaVoxelFaces[abzaVoxelFace(side, block + cameraPositionInt)];
            if ((face.y >> 25) != abzaVoxelFrameTag()) {
                return false;
            }
            float spriteSize = exp2(float((face.y >> 22) & 7u));
            vec2 coord = abzaRotateCoord(int((face.y >> 20) & 3u), abzaSideCoord(side, clamp(hitPos - vec3(block), 0.0, 1.0)));
            ivec2 texel = ivec2(face.x & 0xFFFFu, face.x >> 16) + ivec2(clamp(coord * spriteSize, vec2(0.0), vec2(spriteSize - 1.0)));
            vec4 albedo = texelFetch(abzaAtlas, texel, 0);
            if (albedo.a < 0.1) {
                return false;
            }
            vec3 tint = vec3(uvec3(face.y, face.y >> 4, face.y >> 8) & 15u) / 15.0;
            float blockLevel = float((face.y >> 12) & 15u) / 15.0;
            float skyLevel = float((face.y >> 16) & 15u) / 15.0;
            vec3 normal = vec3(0.0);
            normal[side >> 1] = float(side & 1) * 2.0 - 1.0;

            float emission = max(float((header >> 8) & 15u) / 15.0, float(blockLevel > 0.999));
            #ifdef GLOWING_ORES
                int ore = int(header >> 16);
                if (ore != 0) {
                    emission = max(emission, abzaOreMask(albedo.rgb, ore) * GLOWING_ORE_STRENGTH);
                }
            #endif
            vec3 color = pow(albedo.rgb * tint, vec3(2.2));
            voxelColor = vec4(color * (abzaSurfaceLight(blockLevel, skyLevel, hitPos - cameraPositionFract, normal) + emission * PBR_BRIGHTNESS * PI), rayLength);
            return true;
        }

        // Traces a ray from a point relative to the camera through the voxel grid, up to WORLD_REFLECTION_DISTANCE blocks,
        // block by block and through the half-block cells of partly filled blocks. On a hit returns the lit colour and the
        // distance travelled.
        bool abzaVoxelReflection(vec3 worldPos, vec3 worldDir, out vec4 voxelColor) {
            voxelColor = vec4(0.0);
            vec3 start = worldPos + cameraPositionFract;
            ivec3 cell = ivec3(floor(start));
            ivec3 stepDir = ivec3(greaterThanEqual(worldDir, vec3(0.0))) * 2 - 1;
            vec3 stepUp = vec3(greaterThan(stepDir, ivec3(0)));
            vec3 tDelta = 1.0 / max(abs(worldDir), vec3(1e-6));
            vec3 tMax = (vec3(cell) + stepUp - start) * vec3(stepDir) * tDelta;

            for (int i = 0; i < WORLD_REFLECTION_DISTANCE * 2; i++) {
                int axis = tMax.x < tMax.y ? (tMax.x < tMax.z ? 0 : 2) : (tMax.y < tMax.z ? 1 : 2);
                float rayLength = tMax[axis];
                if (rayLength > float(WORLD_REFLECTION_DISTANCE)) {
                    break;
                }
                cell[axis] += stepDir[axis];
                if (!abzaInVoxelGrid(cell)) {
                    break;
                }
                tMax[axis] += tDelta[axis];

                uint header = texelFetch(abzaVoxelSampler, abzaVoxelWrap(cell + cameraPositionInt), 0).r;
                uint occupied = header & 255u;
                if (occupied == 0u) {
                    continue;
                }

                // Half-block cells inside this block, from where the ray enters it
                vec3 entry = start + worldDir * rayLength - vec3(cell);
                ivec3 sub = ivec3(clamp(floor(entry * 2.0), 0.0, 1.0));
                sub[axis] = stepDir[axis] > 0 ? 0 : 1;
                vec3 subMax = (vec3(sub) * 0.5 + stepUp * 0.5 - entry) * vec3(stepDir) * tDelta + rayLength;
                int hitAxis = axis;
                float hitLength = rayLength;
                for (int j = 0; j < 4; j++) {
                    if ((occupied & (1u << uint(sub.x + sub.y * 2 + sub.z * 4))) != 0u) {
                        int side = hitAxis * 2 + int(stepDir[hitAxis] < 0);
                        if (abzaVoxelShade(cell, side, header, start + worldDir * hitLength, hitLength, voxelColor)) {
                            return true;
                        }
                    }
                    hitAxis = subMax.x < subMax.y ? (subMax.x < subMax.z ? 0 : 2) : (subMax.y < subMax.z ? 1 : 2);
                    hitLength = subMax[hitAxis];
                    sub[hitAxis] += stepDir[hitAxis];
                    if (sub[hitAxis] < 0 || sub[hitAxis] > 1) {
                        break;
                    }
                    subMax[hitAxis] += tDelta[hitAxis] * 0.5;
                }
            }
            return false;
        }

        // Traces a ray against the recorded player model, nearer than maxLength
        bool abzaPlayerReflection(vec3 worldPos, vec3 worldDir, float maxLength, out vec4 playerColor) {
            playerColor = vec4(0.0);
            if (abzaPlayerFrame != frameCounter) {
                return false;
            }
            vec3 toBody = vec3(0.0, -0.8, 0.0) - worldPos;
            float along = dot(toBody, worldDir);
            if (along < -1.5 || dot(toBody, toBody) - along * along > 2.25) {
                return false;
            }
            float best = maxLength;
            vec3 bestNormal = vec3(0.0);
            vec3 bestAlbedo = vec3(0.0);
            for (int quad = 0; quad < ABZA_PLAYER_VERTICES / 4; quad++) {
                vec3 v0 = abzaPlayerVertices[quad * 4].xyz;
                vec3 edge1 = abzaPlayerVertices[quad * 4 + 1].xyz - v0;
                vec3 edge2 = abzaPlayerVertices[quad * 4 + 3].xyz - v0;
                vec3 normal = cross(edge1, edge2);
                float facing = dot(normal, worldDir);
                if (abs(facing) < 1e-8) {
                    continue;
                }
                float t = dot(normal, v0 - worldPos) / facing;
                if (t < 1e-3 || t >= best) {
                    continue;
                }
                vec3 offset = worldPos + worldDir * t - v0;
                vec2 quadPos = vec2(dot(offset, edge1) / max(dot(edge1, edge1), 1e-8), dot(offset, edge2) / max(dot(edge2, edge2), 1e-8));
                if (any(lessThan(quadPos, vec2(0.0))) || any(greaterThan(quadPos, vec2(1.0)))) {
                    continue;
                }
                vec2 coord0 = abzaPlayerCoords[quad * 4];
                vec2 coord = coord0 + quadPos.x * (abzaPlayerCoords[quad * 4 + 1] - coord0) + quadPos.y * (abzaPlayerCoords[quad * 4 + 3] - coord0);
                vec4 albedo = texelFetch(abzaSkinSampler, clamp(ivec2(coord * 64.0), ivec2(0), ivec2(63)), 0);
                if (albedo.a < 0.1) {
                    continue;
                }
                best = t;
                bestAlbedo = albedo.rgb;
                bestNormal = normalize(normal) * -sign(facing);
            }
            if (best >= maxLength) {
                return false;
            }
            float blockLevel = float(abzaPlayerLight & 15u) / 15.0;
            float skyLevel = float((abzaPlayerLight >> 4) & 15u) / 15.0;
            playerColor = vec4(pow(bestAlbedo, vec3(2.2)) * abzaSurfaceLight(blockLevel, skyLevel, worldPos + worldDir * best, bestNormal), best);
            return true;
        }
    #endif
#endif

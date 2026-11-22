//
//  ABZA Shader: the lattice, Shaders Companion's copy of the blocks around the camera (the mod's API.md, "Lattice")
//
//  abzaLatticeCells (3D, R32UI), one texel per block at its position modulo the window:
//    bits 0-3 block light, 4-7 sky light, 8-11 the block's light emission, 12 water, 13 lava, 14 see-through,
//    15 no collision, 16-27 material class, 28-30 window tile parity (x, y, z), 31 valid
//  abzaLatticeShape (3D, RG32UI): the block's shape in 4 x 4 x 4 quarter-block cells, bit x + 4 z + 16 y
//    (r: y 0 and 1, g: y 2 and 3)
//  abzaLatticeInfo (2D, RGBA32I): texel 0 magic 4242, protocol, width, height; texel 1 the window's lowest corner;
//    texel 2 the openness field's magic 4243, protocol, width, reach in quarter blocks; texel 3 its lowest corner
//  abzaLatticeOpenA, abzaLatticeOpenB (3D, RGBA8): the openness field, a probe every half block at the probe's world
//    position times 2 modulo the field's size: A (+x, -x, +y, -y), B (+z, -z, open probe, window tile parity + 1)
//  abzaLatticeDetail (3D, R32UI), per block like abzaLatticeCells: bits 0-25 its detail (0 nothing that shades, 1 a full
//    cube, from 2 a slot of the distance atlas), 26 a detail the openness field doesn't hold as it is lies in or next to
//    the block, 27 the openness field holds it as it is, 28-30 window tile parity, 31 valid; info texel 4 magic 4244,
//    protocol 1
//  abzaLatticeDetailDistance (3D, R8, linear): per slot s (from 2), 16 x 16 x 16 texels at ((s - 2) & 15, (s - 2) >> 4 & 15,
//    (s - 2) >> 8) * 16: the distance from each texel's point in the block to the block's drawn surfaces, in half blocks
//

#ifndef ABZA_LATTICE
#define ABZA_LATTICE

uniform usampler3D abzaLatticeCells;
uniform usampler3D abzaLatticeShape;
uniform isampler2D abzaLatticeInfo;
uniform sampler3D abzaLatticeOpenA;
uniform sampler3D abzaLatticeOpenB;
uniform usampler3D abzaLatticeDetail;
uniform sampler3D abzaLatticeDetailDistance;

#ifndef ABZA_CAMERA_POSITION_INT
    #define ABZA_CAMERA_POSITION_INT
    uniform vec3 cameraPositionFract;
    uniform ivec3 cameraPositionInt;
#endif

const uint ABZA_LATTICE_WATER = 1u << 12;
const uint ABZA_LATTICE_LAVA = 1u << 13;
const uint ABZA_LATTICE_SEE_THROUGH = 1u << 14;
const uint ABZA_LATTICE_NO_COLLISION = 1u << 15;

// Window size and lowest corner; width 0 while the mod doesn't keep the lattice
ivec3 abzaLatticeSize = ivec3(0);
ivec3 abzaLatticeMin = ivec3(0);
int abzaLatticeLog2Width = 0;

// Reads the window; false without the mod's lattice
bool abzaLatticeStart() {
    ivec4 head = texelFetch(abzaLatticeInfo, ivec2(0, 0), 0);
    if (head.x != 4242 || head.y != 1) {
        abzaLatticeSize = ivec3(0);
        return false;
    }
    abzaLatticeSize = head.zwz;
    abzaLatticeMin = texelFetch(abzaLatticeInfo, ivec2(1, 0), 0).xyz;
    abzaLatticeLog2Width = int(round(log2(float(head.z))));
    return true;
}

// The openness field's window, in probes (half blocks); width 0 while the mod doesn't bake it
ivec3 abzaLatticeFieldMin = ivec3(0);
int abzaLatticeFieldProbes = 0;

// Reads the openness field's window; false while the mod doesn't bake it
bool abzaLatticeFieldStart() {
    ivec4 head = texelFetch(abzaLatticeInfo, ivec2(2, 0), 0);
    if (head.x != 4243 || head.y != 1 || texelFetch(abzaLatticeInfo, ivec2(0, 0), 0).x != 4242) {
        abzaLatticeFieldProbes = 0;
        return false;
    }
    abzaLatticeFieldProbes = head.z * 2;
    abzaLatticeFieldMin = texelFetch(abzaLatticeInfo, ivec2(3, 0), 0).xyz * 2;
    return true;
}

// How open a surface is to the light around it, from 0 (closed in) to 1, from the eight probes around a point
// relative to the camera, in the direction of its world-space normal; probes inside solid matter, behind the surface or
// not baked are left out. -1 where no probe answers.
float abzaLatticeOpenness(vec3 pos, vec3 normal) {
    vec3 probePos = (pos + cameraPositionFract + normal * 0.05) * 2.0;
    ivec3 base = ivec3(floor(probePos));
    vec3 f = probePos - vec3(base);
    vec3 n2 = normal * normal;
    float sum = 0.0;
    float weightSum = 0.0;
    for (int c = 0; c < 8; c++) {
        ivec3 corner = ivec3(c & 1, (c >> 1) & 1, c >> 2);
        ivec3 probe = base + corner + cameraPositionInt * 2;
        if (any(greaterThanEqual(uvec3(probe - abzaLatticeFieldMin), uvec3(abzaLatticeFieldProbes)))) {
            continue;
        }
        ivec3 texel = probe & (abzaLatticeFieldProbes - 1);
        vec4 b = texelFetch(abzaLatticeOpenB, texel, 0);
        ivec3 tile = (probe >> 7) & 1;
        if (b.z < 0.5 || int(round(b.w * 255.0)) - 1 != (tile.x | tile.y << 1 | tile.z << 2)) {
            continue;
        }
        vec3 offset = vec3(base + corner) - probePos + normal * 0.1;
        if (dot(offset, normal) < -0.05) {
            continue;
        }
        vec3 w3 = mix(1.0 - f, f, vec3(corner));
        float weight = w3.x * w3.y * w3.z;
        vec4 a = texelFetch(abzaLatticeOpenA, texel, 0);
        float open = n2.x * (normal.x > 0.0 ? a.x : a.y) + n2.y * (normal.y > 0.0 ? a.z : a.w) + n2.z * (normal.z > 0.0 ? b.x : b.y);
        sum += open * weight;
        weightSum += weight;
    }
    return weightSum > 1e-3 ? sum / weightSum : -1.0;
}

// A block's cell bits by world block position; 0 where unknown (outside the window, not loaded or not read yet)
uint abzaLatticeCell(ivec3 block) {
    ivec3 local = block - abzaLatticeMin;
    if (any(greaterThanEqual(uvec3(local), uvec3(abzaLatticeSize)))) {
        return 0u;
    }
    uint cell = texelFetch(abzaLatticeCells, block & (abzaLatticeSize - 1), 0).r;
    ivec3 tile = ivec3(block.x >> abzaLatticeLog2Width, block.y >> 7, block.z >> abzaLatticeLog2Width) & 1;
    uint parity = uint(tile.x | tile.y << 1 | tile.z << 2);
    return (cell >> 31) == 1u && ((cell >> 28) & 7u) == parity ? cell : 0u;
}

// A block's quarter-block cells (call only where abzaLatticeCell is known)
uvec2 abzaLatticeShapeOf(ivec3 block) {
    return texelFetch(abzaLatticeShape, block & (abzaLatticeSize - 1), 0).rg;
}

bool abzaLatticeShapeHas(uvec2 shape, ivec3 cell) {
    int bit = cell.x + 4 * cell.z + 16 * cell.y;
    return ((bit < 32 ? shape.x >> bit : shape.y >> (bit - 32)) & 1u) != 0u;
}

// Whether the mod keeps the lattice's detail (after abzaLatticeStart)
bool abzaLatticeDetailStart() {
    ivec4 head = texelFetch(abzaLatticeInfo, ivec2(4, 0), 0);
    return abzaLatticeSize.x > 0 && head.x == 4244 && head.y == 1;
}

const uint ABZA_LATTICE_FIELD_EXACT = 1u << 27;
const uint ABZA_LATTICE_NEAR_FINE = 1u << 26;
const uint ABZA_LATTICE_SLOT = ABZA_LATTICE_NEAR_FINE - 1u;

// A block's detail bits 0-27 by world block position; 0 where unknown
uint abzaLatticeDetailOf(ivec3 block) {
    if (any(greaterThanEqual(uvec3(block - abzaLatticeMin), uvec3(abzaLatticeSize)))) {
        return 0u;
    }
    uint detail = texelFetch(abzaLatticeDetail, block & (abzaLatticeSize - 1), 0).r;
    ivec3 tile = ivec3(block.x >> abzaLatticeLog2Width, block.y >> 7, block.z >> abzaLatticeLog2Width) & 1;
    return (detail >> 28) == (8u | uint(tile.x | tile.y << 1 | tile.z << 2)) ? detail & 0x0FFFFFFFu : 0u;
}

// Distance from a point to a block's drawn surfaces (signed inside a full cube), the point in blocks from the block's
// lowest corner, for a detail that shades (1 or an atlas slot)
float abzaLatticeBlockDistance(uint slot, vec3 local) {
    vec3 inside = clamp(local, 0.0, 1.0);
    vec3 outside = local - inside;
    float outside2 = dot(outside, outside);
    if (slot == 1u) {
        vec3 depth = min(inside, 1.0 - inside);
        return outside2 > 0.0 ? sqrt(outside2) : -min(min(depth.x, depth.y), depth.z);
    }
    // Outside the block: from the nearest point of the block, a lower bound of the distance
    uint i = slot - 2u;
    vec3 texel = vec3(uvec3(i & 15u, (i >> 4) & 15u, i >> 8)) * 16.0 + clamp(inside * 16.0, 0.5, 15.5);
    float d = textureLod(abzaLatticeDetailDistance, texel / vec3(textureSize(abzaLatticeDetailDistance, 0)), 0.0).r * 0.5;
    return sqrt(outside2 + d * d);
}

// Contact shade from the lattice's detail, what the openness field misses: how closed in a surface point relative to
// the camera is, from 0 (open) to 1, by how much nearer than on open ground the nearest drawn surface is at three
// points along the normal, 1/16 to 1/4 block out. Shapes finer than quarter blocks or that the field lets light
// through count; on such a shape's own surfaces, everything counts. The same for a point every frame.
float abzaLatticeContact(vec3 pos, vec3 normal) {
    vec3 local = pos + cameraPositionFract;
    uint surface = abzaLatticeDetailOf(ivec3(floor(local - normal * 0.01)) + cameraPositionInt);
    if ((surface & ABZA_LATTICE_NEAR_FINE) == 0u) {
        return 0.0;
    }
    bool fineSurface = (surface & ABZA_LATTICE_SLOT) != 0u && (surface & ABZA_LATTICE_FIELD_EXACT) == 0u;
    // The eight blocks around the middle of the points hold everything within reach of them; read are those that
    // reach into the box around the points' reach
    ivec3 base = ivec3(floor(local + normal * 0.125 - 0.5));
    vec3 reachMin = local + (normal - 1.0) * 0.25 - vec3(base);
    vec3 reachMax = local + (normal + 1.0) * 0.25 - vec3(base);
    uint details[8];
    for (int c = 0; c < 8; c++) {
        vec3 corner = vec3(c & 1, (c >> 1) & 1, c >> 2);
        details[c] = 0u;
        if (all(lessThan(corner, reachMax)) && all(greaterThan(corner + 1.0, reachMin))) {
            uint detail = abzaLatticeDetailOf(base + ivec3(corner) + cameraPositionInt);
            details[c] = fineSurface || (detail & ABZA_LATTICE_FIELD_EXACT) == 0u ? detail & ABZA_LATTICE_SLOT : 0u;
        }
    }
    float closed = 0.0;
    for (int i = 0; i < 3; i++) {
        float h = exp2(float(i) - 4.0);
        vec3 point = local + normal * h - vec3(base);
        float d = h;
        for (int c = 0; c < 8; c++) {
            vec3 blockLocal = point - vec3(c & 1, (c >> 1) & 1, c >> 2);
            vec3 outside = max(max(-blockLocal, blockLocal - 1.0), 0.0);
            if (details[c] != 0u && dot(outside, outside) < h * h) {
                d = min(d, abzaLatticeBlockDistance(details[c], blockLocal));
            }
        }
        closed += 1.0 - clamp(d / h, 0.0, 1.0);
    }
    return closed * (1.0 / 3.0);
}

// Whether a point relative to the camera lies in a filled quarter-block cell; unknown blocks count as empty
bool abzaLatticeFilled(vec3 relativePos, out bool known) {
    vec3 local = relativePos + cameraPositionFract;
    ivec3 block = ivec3(floor(local));
    uint cell = abzaLatticeCell(block + cameraPositionInt);
    known = cell != 0u;
    if (!known) {
        return false;
    }
    ivec3 quarter = clamp(ivec3(floor((local - vec3(block)) * 4.0)), ivec3(0), ivec3(3));
    return abzaLatticeShapeHas(abzaLatticeShapeOf(block + cameraPositionInt), quarter);
}

// Traces a ray from a point relative to the camera, block by block and through the quarter-block cells of blocks with
// a shape, up to maxDistance blocks or maxBlocks blocks. Returns 1 on a hit (distance, the face's normal and the block's
// cell bits), 2 on reaching an unknown block (distance to it), 0 on reaching the end.
int abzaLatticeTrace(vec3 origin, vec3 dir, float maxDistance, int maxBlocks, out float hitDistance, out vec3 hitNormal, out uint hitCell) {
    hitDistance = 0.0;
    hitNormal = vec3(0.0);
    hitCell = 0u;
    vec3 start = origin + cameraPositionFract;
    ivec3 block = ivec3(floor(start));
    ivec3 stepDir = ivec3(greaterThanEqual(dir, vec3(0.0))) * 2 - 1;
    vec3 stepUp = vec3(greaterThan(stepDir, ivec3(0)));
    vec3 tDelta = 1.0 / max(abs(dir), vec3(1e-6));
    vec3 tMax = (vec3(block) + stepUp - start) * vec3(stepDir) * tDelta;
    float t = 0.0;
    int axis = -1;

    for (int i = 0; i < maxBlocks; i++) {
        ivec3 worldBlock = block + cameraPositionInt;
        uint cell = abzaLatticeCell(worldBlock);
        if (cell == 0u) {
            hitDistance = t;
            return 2;
        }
        uvec2 shape = abzaLatticeShapeOf(worldBlock);
        if (shape != uvec2(0u)) {
            // Quarter-block cells inside this block, from where the ray enters it
            vec3 entry = (start + dir * t - vec3(block)) * 4.0;
            ivec3 sub = clamp(ivec3(floor(entry)), ivec3(0), ivec3(3));
            if (axis >= 0) {
                sub[axis] = stepDir[axis] > 0 ? 0 : 3;
            }
            vec3 subMax = (vec3(sub) + stepUp - entry) * vec3(stepDir) * tDelta * 0.25 + t;
            float subT = t;
            int subAxis = axis;
            for (int j = 0; j < 10; j++) {
                if (abzaLatticeShapeHas(shape, sub)) {
                    hitDistance = subT;
                    if (subAxis >= 0) {
                        hitNormal[subAxis] = -float(stepDir[subAxis]);
                    }
                    hitCell = cell;
                    return 1;
                }
                subAxis = subMax.x < subMax.y ? (subMax.x < subMax.z ? 0 : 2) : (subMax.y < subMax.z ? 1 : 2);
                subT = subMax[subAxis];
                sub[subAxis] += stepDir[subAxis];
                if (sub[subAxis] < 0 || sub[subAxis] > 3 || subT > maxDistance) {
                    break;
                }
                subMax[subAxis] += tDelta[subAxis] * 0.25;
            }
        }
        axis = tMax.x < tMax.y ? (tMax.x < tMax.z ? 0 : 2) : (tMax.y < tMax.z ? 1 : 2);
        t = tMax[axis];
        if (t > maxDistance) {
            hitDistance = maxDistance;
            return 0;
        }
        block[axis] += stepDir[axis];
        tMax[axis] += tDelta[axis];
    }
    hitDistance = t;
    return 0;
}

// Follows a ray from a point relative to the camera through solid matter (see-through blocks, plants and fluids let it
// pass) for up to maxDistance blocks or maxBlocks blocks. Returns 1 on a hit (distance, the face's normal, the cell
// bits of the block the ray hit the face from, which hold the light on that face, and the hit block's own cell bits),
// 0 when it gets clear (maxDistance travelled, or climbing at least 1 in 5 through a block under open sky after its
// first block), 2 on reaching an unknown block (distance to it).
int abzaLatticeBlocked(vec3 origin, vec3 dir, float maxDistance, int maxBlocks, out float hitDistance, out vec3 hitNormal, out uint frontCell, out uint hitCell) {
    hitDistance = 0.0;
    hitNormal = vec3(0.0);
    frontCell = 0u;
    hitCell = 0u;
    vec3 start = origin + cameraPositionFract;
    ivec3 block = ivec3(floor(start));
    ivec3 stepDir = ivec3(greaterThanEqual(dir, vec3(0.0))) * 2 - 1;
    vec3 stepUp = vec3(greaterThan(stepDir, ivec3(0)));
    vec3 tDelta = 1.0 / max(abs(dir), vec3(1e-6));
    vec3 tMax = (vec3(block) + stepUp - start) * vec3(stepDir) * tDelta;
    float t = 0.0;
    int axis = -1;
    uint lastCell = 0u;

    for (int i = 0; i < maxBlocks; i++) {
        ivec3 worldBlock = block + cameraPositionInt;
        uint cell = abzaLatticeCell(worldBlock);
        if (cell == 0u) {
            hitDistance = t;
            return 2;
        }
        uvec2 shape = (cell & (ABZA_LATTICE_SEE_THROUGH | ABZA_LATTICE_NO_COLLISION)) == 0u ? abzaLatticeShapeOf(worldBlock) : uvec2(0u);
        if (shape != uvec2(0u)) {
            // Quarter-block cells inside this block, from where the ray enters it
            vec3 entry = (start + dir * t - vec3(block)) * 4.0;
            ivec3 sub = clamp(ivec3(floor(entry)), ivec3(0), ivec3(3));
            if (axis >= 0) {
                sub[axis] = stepDir[axis] > 0 ? 0 : 3;
            }
            vec3 subMax = (vec3(sub) + stepUp - entry) * vec3(stepDir) * tDelta * 0.25 + t;
            float subT = t;
            int subAxis = axis;
            for (int j = 0; j < 10; j++) {
                if (abzaLatticeShapeHas(shape, sub)) {
                    hitDistance = subT;
                    if (subAxis >= 0) {
                        hitNormal[subAxis] = -float(stepDir[subAxis]);
                    }
                    frontCell = j == 0 && lastCell != 0u ? lastCell : cell;
                    hitCell = cell;
                    return 1;
                }
                subAxis = subMax.x < subMax.y ? (subMax.x < subMax.z ? 0 : 2) : (subMax.y < subMax.z ? 1 : 2);
                subT = subMax[subAxis];
                sub[subAxis] += stepDir[subAxis];
                if (sub[subAxis] < 0 || sub[subAxis] > 3 || subT > maxDistance) {
                    break;
                }
                subMax[subAxis] += tDelta[subAxis] * 0.25;
            }
        }
        if (i > 0 && dir.y > 0.2 && ((cell >> 4) & 15u) == 15u) {
            hitDistance = t;
            return 0;
        }
        lastCell = cell;
        axis = tMax.x < tMax.y ? (tMax.x < tMax.z ? 0 : 2) : (tMax.y < tMax.z ? 1 : 2);
        t = tMax[axis];
        if (t > maxDistance) {
            hitDistance = maxDistance;
            return 0;
        }
        block[axis] += stepDir[axis];
        tMax[axis] += tDelta[axis];
    }
    hitDistance = t;
    return 0;
}

#endif

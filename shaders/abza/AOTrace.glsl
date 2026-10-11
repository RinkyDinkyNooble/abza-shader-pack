//
//  ABZA Shader: crease shading samples in the visibility bitmask trace (Deferred12, after its slice helpers)
//

// Weight of an occluder at view-space offset delta from the shaded point: 1 at the point, 0 from CREASE_SHADING_RADIUS blocks
float abzaCreaseWeight(vec3 delta) {
    float d = clamp(dot(delta, delta) * (1.0 / (CREASE_SHADING_RADIUS * CREASE_SHADING_RADIUS)), 0.0, 1.0);
    return (1.0 - d) * (1.0 - d);
}

// Adds a trace sample's crease occlusion to abzaCreaseSum: the slice sectors it newly covers, weighted by distance.
// The sample is taken as 0.1 of its view distance thick, between 0.2 and 0.5 blocks.
void abzaCreaseSample(inout uint creaseBits, vec3 deltaPosFront, vec3 sampleViewPos, vec3 viewDir, float angN, float sinN, float remapMul, float remapAdd) {
    #ifndef AMBIENT_OCCLUSION
        return;
    #endif
    float weight = abzaCreaseWeight(deltaPosFront);
    if (weight > 0.0) {
        float sampleRcpLength = inversesqrt(dot(sampleViewPos, sampleViewPos));
        vec3 deltaPosBack = deltaPosFront + sampleViewPos * (clamp(0.1 / sampleRcpLength, 0.2, 0.5) * sampleRcpLength);
        vec2 horCos = vec2(dot(deltaPosFront, viewDir) * inversesqrt(dot(deltaPosFront, deltaPosFront)),
                           dot(deltaPosBack , viewDir) * inversesqrt(dot(deltaPosBack , deltaPosBack )));
        vec2 hor01 = clamp((ACos(horCos) + angN) / PI + 0.5, 0.0, 1.0);
        hor01 = SliceRelCDF_Cos(hor01, angN, sinN) * remapMul + remapAdd;
        uvec2 horInt = (floatBitsToUint(hor01) >> 17) & 0x3Fu;
        uint mX = horInt.x < 32u ? 0xFFFFFFFFu <<        horInt.x  : 0u;
        uint mY = horInt.y != 0u ? 0xFFFFFFFFu >> (32u - horInt.y) : 0u;
        uint bits = mX & mY;
        abzaCreaseSum += float(CountBits(bits & ~creaseBits)) * weight;
        creaseBits |= bits;
    }
}

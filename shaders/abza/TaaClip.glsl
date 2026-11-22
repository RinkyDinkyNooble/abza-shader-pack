//
//  ABZA Shader: TAA's history clip (Composite9, after its RGB_YCoCg)
//

// The history colour clipped towards the box of colours around the pixel in this frame (all in Composite9's YCoCg of
// a tenth of colortex3). The box: the soft minimum and maximum of the 3 x 3 neighbourhood (half the plus-shaped five,
// half all nine), narrowed to the mean plus or minus its standard deviation times 0.75 near the camera up to 1.25 far
// away (colortex5's z, abzaTaaDistanceFactor), times TAA_HISTORY_CLIP_VARIANCE.
vec3 abzaTaaClip(ivec2 texel, vec3 currentColor, vec3 historyColor) {
    vec3 crossMin = currentColor;
    vec3 crossMax = currentColor;
    vec3 cornerMin = currentColor;
    vec3 cornerMax = currentColor;
    vec3 m1 = currentColor;
    vec3 m2 = currentColor * currentColor;
    for (int i = 0; i < 9; i++) {
        ivec2 offset = ivec2(i % 3, i / 3) - 1;
        if (i != 4) {
            vec3 sampleColor = RGB_YCoCg(texelFetch(colortex3, texel + offset, 0).rgb * 0.1);
            m1 += sampleColor;
            m2 += sampleColor * sampleColor;
            if (offset.x == 0 || offset.y == 0) {
                crossMin = min(crossMin, sampleColor);
                crossMax = max(crossMax, sampleColor);
            } else {
                cornerMin = min(cornerMin, sampleColor);
                cornerMax = max(cornerMax, sampleColor);
            }
        }
    }
    vec3 minColor = 0.5 * (crossMin + min(crossMin, cornerMin));
    vec3 maxColor = 0.5 * (crossMax + max(crossMax, cornerMax));

    m1 /= 9.0;
    vec3 sigma = sqrt(max(m2 / 9.0 - m1 * m1, vec3(0.0)));
    float distanceFactor = texelFetch(colortex5, texel, 0).z;
    float gamma = mix(0.75, 1.25, clamp((distanceFactor - 0.25) / 0.75, 0.0, 1.0)) * TAA_HISTORY_CLIP_VARIANCE;
    minColor = max(minColor, m1 - gamma * sigma);
    maxColor = min(maxColor, m1 + gamma * sigma);

    vec3 centre = 0.5 * (maxColor + minColor);
    vec3 extent = max(0.5 * (maxColor - minColor), vec3(1e-4));
    vec3 offset = historyColor - centre;
    vec3 units = abs(offset / extent);
    float farthest = max(units.x, max(units.y, units.z));
    return farthest > 1.0 ? centre + offset / farthest : historyColor;
}

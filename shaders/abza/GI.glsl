//
//  ABZA Shader: screen-space global illumination samples
//

// Slices traced per pixel: VB_TRACE_COUNT with global illumination, one for ambient occlusion alone
#ifdef VBGI
    const bool colortex3MipmapEnabled = true;
    #define ABZA_VB_TRACES VB_TRACE_COUNT
#else
    #define ABZA_VB_TRACES 1
#endif

// Lit colour at a GI sample. Samples more than 4 pixels from the previous step read a mip level averaging up to 4 x 4 pixels.
vec4 abzaGISample(ivec2 sampleTexel, float stepPixels) {
    float lod = clamp(log2(max(stepPixels, 1.0)) - 2.0, 0.0, 2.0);
    if (lod <= 0.0) {
        return texelFetch(colortex3, sampleTexel, 0);
    }
    return textureLod(colortex3, (vec2(sampleTexel) + 0.5) * texelSize, lod);
}

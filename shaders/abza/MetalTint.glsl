//
//  ABZA Shader: a metal's reflection is tinted by its albedo (F0 = albedo). Composite0 divides the tint out before the
//  reflection filter (Composite1 to 3) blurs the reflection over up to about 40 pixels, and Composite5 multiplies it
//  back with the pixel's own albedo, so a metal keeps its texture instead of the filter averaging it away.
//

#ifndef ABZA_METAL_TINT_GLSL
#define ABZA_METAL_TINT_GLSL

vec3 abzaMetalTint(GbufferData data) {
    float metalness = data.metalness;
    #ifdef LABPBR_F0
        metalness = step(229.5 / 255.0, metalness);
    #endif
    return mix(vec3(1.0), max(data.albedo.rgb, vec3(0.02)), metalness);
}

#endif

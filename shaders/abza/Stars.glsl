//
//  ABZA Shader: stars in the sky buffers
//

// 1.0 inside triangles whose three vertices are all star vertices (100 blocks out), 0.0 elsewhere
float abzaStarFragment(float starVertex) {
    return float(starVertex > 0.9999);
}

// Star colour rounded to 8 bits, so colortex0 and colortex1 store the same value
vec3 abzaStarColor(vec3 color) {
    return floor(color * 255.0 + 0.5) / 255.0;
}

float abzaFrameTag() {
    return float(frameCounter % 255 + 1);
}

// colortex1 on sky pixels: the colour of the star drawn there this frame, and a frame tag
vec4 abzaStarData(vec3 color, float star) {
    return star > 0.5 ? vec4(color, abzaFrameTag() / 255.0) : vec4(0.0);
}

// 1.0 where colortex0 shows a star drawn this frame, alone or over grey sky
float abzaIsStar(ivec2 texel) {
    vec4 starData = texelFetch(colortex1, texel, 0);
    ivec3 star = ivec3(starData.rgb * 255.0 + 0.5);
    ivec3 under = ivec3(texelFetch(colortex0, texel, 0).rgb * 255.0 + 0.5) - star;
    bool current = abs(starData.w * 255.0 - abzaFrameTag()) < 0.5;
    return float(current && star != ivec3(0) && under.r == under.g && under.g == under.b && under.r >= 0);
}

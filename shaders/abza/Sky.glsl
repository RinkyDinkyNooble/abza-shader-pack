//
//  ABZA Shader: sky objects drawn by Ad Astra
//

#ifdef ABZA_STAR_SCALE
    // Position on the square Ad Astra draws the star on, -1 to 1 across it (2 when the direction faces away).
    // The star turns with the time of day around the world Z axis, at 100 blocks from the camera.
    vec2 abzaStarQuadPos(vec3 worldDir) {
        float facing = dot(worldDir, sunDirection);
        if (facing <= 0.0) {
            return vec2(2.0);
        }
        vec3 sideAxis = normalize(cross(sunDirection, vec3(0.0, 0.0, 1.0)));
        return vec2(worldDir.z, dot(worldDir, sideAxis)) / (facing * ABZA_STAR_SCALE * 0.01);
    }
#endif

// 1.0 on the star's own texels inside the square Ad Astra draws it on, 0.0 elsewhere
float abzaStarMask(vec3 worldDir, vec3 skyAlbedo) {
    #ifdef ABZA_STAR_SCALE
        vec2 quadPos = abzaStarQuadPos(worldDir);
        float inQuad = float(max(abs(quadPos.x), abs(quadPos.y)) < 1.0);
        return inQuad * smoothstep(0.85, 0.9, skyAlbedo.r);
    #else
        return 0.0;
    #endif
}

// The star in reflections: Ad Astra's square in its texture's colours (8 x 8 texels: an outer ring, an inner ring and a 4 x 4 core),
// as bright as Deferred11 draws it in the sky. Worlds without an Ad Astra star keep Sundial's sun disc.
vec3 abzaReflectedSun(vec3 worldDir) {
    #ifdef ABZA_STAR_SCALE
        vec2 quadPos = abzaStarQuadPos(worldDir);
        float ring = max(abs(quadPos.x), abs(quadPos.y));
        if (ring >= 1.0) {
            return vec3(0.0);
        }
        #if ABZA_STAR_TEXTURE == 1
            vec3 color = ring > 0.75 ? vec3(244.0, 140.0, 97.0) : ring > 0.5 ? vec3(250.0, 214.0, 197.0) : vec3(255.0, 255.0, 255.0);
        #else
            vec3 color = ring > 0.75 ? vec3(255.0, 213.0, 74.0) : ring > 0.5 ? vec3(255.0, 255.0, 170.0) : vec3(255.0, 255.0, 217.0);
        #endif
        return pow(color / 255.0, vec3(2.2)) * (2.0 + STAR_TEXTURE_BRIGHTNESS);
    #else
        return renderSun(worldDir, sunDirection, vec3(300.0));
    #endif
}

#include "/abza/Stars.glsl"

// Extra brightness of stars by day in worlds without air, so they show against a sunlit scene
float abzaDayStars(ivec2 texel) {
    #if ABZA_AIR == 0
        float day = smoothstep(-0.05, 0.1, sunDirection.y);
        return abzaIsStar(texel) * day * (STARS_BY_DAY - 1.0);
    #else
        return 0.0;
    #endif
}

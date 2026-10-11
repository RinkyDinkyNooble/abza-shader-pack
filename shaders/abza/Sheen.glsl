//
//  ABZA Shader: sunshine sheen (direct-light highlight on rough blocks) and light through plants toward the sun
//

// Direct-light highlight on surfaces without their own smoothness, as if they had smoothness SUN_SHEEN_FOCUS.
// Smooth, wet and metal surfaces keep Sundial's specular; plants, held items and lines (block outline) get none.
vec3 abzaSunSheen(vec3 viewDir, vec3 lightDir, vec3 normal, float NdotL, float NdotV, float smoothness, float metalness, float materialID) {
    if (smoothness > 1e-3 || metalness > 1e-3 || materialID == float(MAT_GRASS) || materialID == float(MAT_HAND) || materialID == float(MAT_LINE)) {
        return vec3(0.0);
    }
    return sunlightSpecular(viewDir, lightDir, normal, SUN_SHEEN_FOCUS, NdotL, NdotV, vec3(0.04), vec3(1.0)) * SUN_SHEEN;
}

// Multiplier for light through plants and leaves (Sundial's subsurface scattering): 1 looking away from the sun, 1 + PLANT_GLOW looking straight at it
float abzaPlantGlow(vec3 viewDir, vec3 lightDir) {
    float towardSun = clamp(dot(viewDir, lightDir), 0.0, 1.0);
    return 1.0 + PLANT_GLOW * pow2(pow2(towardSun));
}

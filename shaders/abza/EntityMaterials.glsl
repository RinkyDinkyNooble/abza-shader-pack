//
//  ABZA Shader: entities take the material classes Shaders Companion gives them ("Entity materials",
//  COMPANION_ENTITY_MATERIALS, off by default). Armour, items held by mobs and other players, dropped items and items in
//  frames are drawn with their item's id (currentRenderedItemId) and take its class by the held items' rules
//  (abza/HeldItems.glsl: wooden grips and coloured parts of grey metal stay matte). Everything else takes its entity
//  type's class (entityId: the mod gives vehicles the paint class and minecarts iron), except near-black texels (tyres,
//  dark insides painted into a texture). "Held item look" applies to both.
//

#ifndef ABZA_ENTITY_MATERIALS_GLSL
#define ABZA_ENTITY_MATERIALS_GLSL

#include "/abza/HeldItems.glsl"

uniform int entityId;

void abzaEntityClass(inout GbufferData data, vec4 specularData) {
    if (currentRenderedItemId > 0) {
        abzaItemClass(data, specularData, currentRenderedItemId);
        return;
    }
    vec3 values;
    if (!abzaMaterialValues(abzaMaterialClassOf(entityId), values) || any(greaterThan(specularData, vec4(0.0)))) {
        return;
    }
    if (max(data.albedo.r, max(data.albedo.g, data.albedo.b)) < 0.1) {
        return;
    }
    abzaItemLook(values);
    data.smoothness = values.r;
    data.metalness = values.g;
    data.porosity = values.b;
}

#endif

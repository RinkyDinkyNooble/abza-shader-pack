//
//  ABZA Shader: held items take the material class Shaders Companion gives the item being drawn. Oculus draws each item
//  with its id (currentRenderedItemId): the mod gives items it classes 16384 | class (tools and armour by their tier,
//  metal ingots by their tags, guns, a table of vanilla items such as buckets and glass bottles), and a block item has
//  its block's id, so a held block carries its block's class. An item's texture mixes materials in one model (a sword's
//  wooden grip, a gun's wooden stock): texels in the vanilla stick's colours keep no class, and on a grey metal (iron,
//  aluminum, chrome, silver, and metal by albedo: steel, netherite, guns) neither do coloured ones.
//  HELD_ITEM_LOOK 0 (Subtle) gives every held class a glossy coat's reflectance instead: no metal, F0 at most 0.04
//  (glass's), so the item keeps its lit colour and gains a sheen of the world; 1 takes the class's values as blocks do.
//

#ifndef ABZA_HELD_ITEMS_GLSL
#define ABZA_HELD_ITEMS_GLSL

#include "/abza/MaterialClass.glsl"

uniform int currentRenderedItemId;

// Whether an sRGB texel is one of the vanilla stick's four colours
bool abzaHeldStickTexel(vec3 albedo) {
    vec3 c = albedo * 255.0;
    const vec3 stick0 = vec3(40.0, 30.0, 11.0);
    const vec3 stick1 = vec3(73.0, 54.0, 21.0);
    const vec3 stick2 = vec3(104.0, 78.0, 30.0);
    const vec3 stick3 = vec3(137.0, 103.0, 39.0);
    vec4 distances = vec4(
        dot(abs(c - stick0), vec3(1.0)), dot(abs(c - stick1), vec3(1.0)),
        dot(abs(c - stick2), vec3(1.0)), dot(abs(c - stick3), vec3(1.0))
    );
    return any(lessThan(distances, vec4(8.0)));
}

// Colourfulness of an sRGB texel: its saturation, with dark texels measured against a quarter of full brightness so a
// near-black outline counts as grey
float abzaHeldColourfulness(vec3 albedo) {
    float high = max(albedo.r, max(albedo.g, albedo.b));
    float low = min(albedo.r, min(albedo.g, albedo.b));
    return (high - low) / max(high, 0.25);
}

// HELD_ITEM_LOOK 0 (Subtle) keeps a class's smoothness with a glossy coat's reflectance (no metal, F0 at most glass's)
void abzaItemLook(inout vec3 values) {
    #if HELD_ITEM_LOOK == 0
        values.g = min(values.g, 10.0 / 255.0);
    #endif
}

// An item's texel takes the class of the item drawn (itemId: currentRenderedItemId), unless the resource pack has a PBR
// map of its own
void abzaItemClass(inout GbufferData data, vec4 specularData, int itemId) {
    int materialClass = abzaMaterialClassOf(itemId);
    vec3 values;
    if (!abzaMaterialValues(materialClass, values) || any(greaterThan(specularData, vec4(0.0)))) {
        return;
    }
    vec3 albedo = data.albedo.rgb;
    if (abzaHeldStickTexel(albedo)) {
        return;
    }
    int f0 = int(round(values.g * 255.0));
    bool greyMetal = f0 == 230 || f0 == 232 || f0 == 233 || f0 == 237 || f0 == 255;
    if (greyMetal && abzaHeldColourfulness(albedo) > 0.35) {
        return;
    }
    abzaItemLook(values);
    data.smoothness = values.r;
    data.metalness = values.g;
    data.porosity = values.b;
}

// A held item's texel takes its item's class
void abzaHeldItemClass(inout GbufferData data, vec4 specularData) {
    abzaItemClass(data, specularData, currentRenderedItemId);
}

#endif

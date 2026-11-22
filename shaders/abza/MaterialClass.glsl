//
//  ABZA Shader: Shaders Companion's material classes. The mod puts a class (1 to 511) into bits 0-8 of the block ids
//  from 16384 up (Sundial's flag range) when this pack reads shaderscompanion:material_table, whose texel c holds class
//  c's LabPBR bytes (smoothness, F0 or metal, porosity); texel 0 is (42, 42, protocol, 0). A block whose resource pack
//  has a PBR map of its own keeps it: Oculus's default specular for a texture without one is 0 in every channel.
//  The same classes reach terrain (mc_Entity), block entities (blockEntityId), the mod's cube and mirror views (their
//  block ids) and the lattice (its cells' bits 16-27). Distant Horizons' LODs carry no class.
//  Classes 18 to 20 (sound_metal, sound_copper, sound_dark_metal) are modded blocks the mod takes for metal by their
//  sound alone; METAL_BY_SOUND 1 gives them the polished class's values (4) wherever classes are read.
//

#ifndef ABZA_MATERIAL_CLASS_GLSL
#define ABZA_MATERIAL_CLASS_GLSL

#define METAL_BY_SOUND 0 // [0 1]

#define ABZA_CLASS_POLISHED 4
#define ABZA_CLASS_SOUND_METAL_FIRST 18
#define ABZA_CLASS_SOUND_METAL_LAST 20

#ifdef COMPANION_MATERIALS
    uniform sampler2D scMaterials;
#endif

// The class a block id carries (0 for none): ids from 16384 up hold it in bits 0-8
int abzaMaterialClassOf(int blockId) {
    return blockId >= 16384 ? (blockId & 0x1FF) : 0;
}

// Whether the mod's material table is bound and speaks this protocol
bool abzaMaterialTableLinked() {
    #ifdef COMPANION_MATERIALS
        uvec4 header = uvec4(round(texelFetch(scMaterials, ivec2(0), 0) * 255.0));
        return header.x == 42u && header.y == 42u && header.z == 1u;
    #else
        return false;
    #endif
}

// A class's LabPBR values as Sundial reads them from a specular map (smoothness, F0 or metal, porosity, all / 255);
// false for class 0 or without the mod's table
bool abzaMaterialValues(int materialClass, out vec3 values) {
    values = vec3(0.0);
    #ifdef COMPANION_MATERIALS
        if (materialClass <= 0 || !abzaMaterialTableLinked()) {
            return false;
        }
        #if METAL_BY_SOUND == 1
            if (materialClass >= ABZA_CLASS_SOUND_METAL_FIRST && materialClass <= ABZA_CLASS_SOUND_METAL_LAST) {
                materialClass = ABZA_CLASS_POLISHED;
            }
        #endif
        values = texelFetch(scMaterials, ivec2(materialClass, 0), 0).rgb;
        return true;
    #else
        return false;
    #endif
}

// A surface drawn by the gbuffers takes its block id's class, unless its resource pack has a PBR map of its own
void abzaMaterialClass(inout GbufferData data, int blockId, vec4 specularData) {
    #ifdef COMPANION_MATERIALS
        int materialClass = abzaMaterialClassOf(blockId);
        vec3 values;
        if (!abzaMaterialValues(materialClass, values)) {
            return;
        }
        bool ownMap = any(greaterThan(specularData, vec4(0.0)));
        #if MATERIAL_DEBUG_VIEW == 1
            // Each class in its own hue; blocks whose resource pack map wins keep their colour
            if (!ownMap) {
                float hue = fract(float(materialClass) * 0.618034);
                data.albedo.rgb = clamp(abs(fract(hue + vec3(0.0, 2.0, 1.0) / 3.0) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
            }
        #endif
        if (ownMap) {
            return;
        }
        data.smoothness = values.r;
        data.metalness = values.g;
        data.porosity = values.b;
    #endif
}

#endif

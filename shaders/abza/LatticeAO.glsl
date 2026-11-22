//
//  ABZA Shader: ambient occlusion and crease shading from Shaders Companion's lattice ("Steady ambient occlusion"),
//  shared by Deferred12 (the screen) and deferred14 (the mirror views' lighting), so a surface seen in a mirror is
//  shaded as it is on screen
//

#ifndef ABZA_LATTICE_AO_GLSL
#define ABZA_LATTICE_AO_GLSL

// Ambient occlusion from the lattice (abza/Lattice.glsl) in place of VBAO's, where the lattice covers, with the
// contact shade from its detail
#ifdef LATTICE_AMBIENT_OCCLUSION
    #ifdef AMBIENT_OCCLUSION
        #define ABZA_LATTICE_AO
    #endif
#endif

// Share of the lattice's contact shade in its crease occlusion
const float ABZA_LATTICE_CONTACT_STRENGTH = 0.85;

// Crease occlusion from the lattice: its openness field (1 open, 0 closed in) and its detail's contact shade (0 to 1)
float abzaLatticeCrease(float openness, float contact) {
    float closed = clamp(1.0 - openness, 0.0, 1.0);
    return 1.0 - (1.0 - closed * closed) * (1.0 - ABZA_LATTICE_CONTACT_STRENGTH * contact);
}

// Share of light kept in a crease; share scales the strength
float abzaCreaseLight(float crease, float share) {
    return pow(max(1.0 - crease, 1e-3), CREASE_SHADING_STRENGTH * share);
}

#ifdef ABZA_LATTICE_AO
    #include "/abza/Lattice.glsl"

    // The lattice's ambient occlusion (1 - openness) and crease occlusion at a surface point relative to the camera with
    // a world-space normal, with the contact shade from its detail when contactShade (the mirror views and the cube's
    // reflections go without: in the bedroom scene it cost 0.55 ms in deferred14 for no measurable change in how
    // reflections match the screen). Returns the share the lattice answers: 1 within 18 blocks of the camera, fading to
    // 0 at 23 (the field's window), 0 where no probe answers or without the field.
    float abzaLatticeOcclusionAt(vec3 pos, vec3 normal, bool contactShade, out float occlusion, out float crease) {
        occlusion = 0.0;
        crease = 0.0;
        if (!abzaLatticeFieldStart()) {
            return 0.0;
        }
        float openness = abzaLatticeOpenness(pos, normal);
        vec3 reach = abs(pos);
        float share = openness < 0.0 ? 0.0 : clamp((23.0 - max(max(reach.x, reach.y), reach.z)) / 5.0, 0.0, 1.0);
        occlusion = 1.0 - openness;
        float contact = 0.0;
        if (contactShade && share > 0.0 && abzaLatticeStart() && abzaLatticeDetailStart()) {
            contact = abzaLatticeContact(pos, normal);
        }
        crease = abzaLatticeCrease(openness, contact);
        return share;
    }
#endif

#endif

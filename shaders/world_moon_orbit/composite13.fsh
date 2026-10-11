#version 330 compatibility

#define ABZA_WORLD
#define ABZA_WORLD_MOON_ORBIT

const float shadowDistanceRenderMul = 1.0;
const bool shadowHardwareFiltering0 = true;

#include "/programs/composite/Composite13.frag"

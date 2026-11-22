//
//  ABZA Shader: realistic clouds at half resolution (deferred13, scale 0.5)
//

#extension GL_ARB_gpu_shader5 : enable

#include "/abza/NanDebug.glsl"

layout(location = 0) out vec4 cloudLight;
layout(location = 1) out vec4 cloudInfo;

in vec3 skyColorUp;

#define ABZA_CLOUD_PASS

#include "/settings/CloudSettings.glsl"
#include "/settings/GlobalSettings.glsl"
#include "/libs/Uniform.glsl"
#include "/libs/Common.glsl"
#include "/libs/Atmosphere.glsl"
#include "/libs/Cloud.glsl"
#include "/libs/GbufferData.glsl"
#include "/abza/HalfClouds.glsl"

/*
const int colortex8Format = RGBA16F;
const int colortex9Format = RGBA16F;
*/
const bool colortex8Clear = false;
const bool colortex9Clear = false;

void main() {
    cloudLight = vec4(0.0);
    cloudInfo = vec4(0.0, -1.0, 1.0, 0.0);
    #ifdef ABZA_HALF_RES_CLOUDS
        ivec2 fullTexel = ivec2(gl_FragCoord.xy) * 2;
        vec2 coord = gl_FragCoord.xy * 2.0 * texelSize;
        vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * screenToViewPos(coord, 1.0));
        vec4 intersectionData = planetIntersectionData(gbufferModelViewInverse[3].xyz, worldDir);
        if (abzaCloudsHidden(fullTexel)) {
            // The clouds behind keep their history (reprojected, unchanged) while hidden, so where the surface moves
            // away (a mob, the camera passing a post) they come back converged instead of starting over
            cloudInfo = vec4(0.0, -1.0, 1.0, abzaCloudFrameTag(frameCounter));
            if (abzaAccumulateClouds(coord, worldDir, intersectionData.z, 1.0, cloudLight, cloudInfo)) {
                return;
            }
            cloudLight = vec4(0.0);
            cloudInfo = vec4(0.0, -1.0, 0.0, 0.0);
            return;
        }
        vec3 atmosphere = vec3(0.0);
        #if ABZA_AIR == 1
            singleAtmosphereScattering(vec3(0.0), gbufferModelViewInverse[3].xyz, worldDir, sunDirection, intersectionData, skyColorUp, (30.0), atmosphere);
        #endif
        float cloudDepth;
        vec4 clouds = sampleClouds(
            vec3(0.0), atmosphere, gbufferModelViewInverse[3].xyz, worldDir, shadowDirection, sunDirection, skyColorUp, intersectionData.xyz, 0.0, cloudDepth
        );
        cloudLight = vec4(clouds.rgb, abzaCloudBlend);
        cloudInfo = vec4(clouds.a, cloudDepth, 1.0, abzaCloudFrameTag(frameCounter));
        abzaAccumulateClouds(coord, worldDir, intersectionData.z, abzaCloudHistoryWeight, cloudLight, cloudInfo);
    #endif
}

/* DRAWBUFFERS:89 */

#define ABZA_NAN_PASS 6
#define ABZA_NAN_SCALE 2
#define ABZA_NAN_OUTPUTS abzaNanBad(cloudLight) || abzaNanBad(cloudInfo)
#include "/abza/NanDebugMain.glsl"

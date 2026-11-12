//
//  ABZA Shader: water waves filtered by distance. Each wave layer fades out where its waves are too fine for the
//  pixel, as a texture's mipmaps do, so distant water doesn't alias into stripes and glitter.
//

#ifndef ABZA_WATER_WAVES_GLSL
#define ABZA_WATER_WAVES_GLSL
    // How much of a wave layer with this wavelength (blocks) a pixel covering footprint blocks of water keeps
    float abzaWaveLayerFilter(float footprint, float wavelength) {
        return 1.0 - smoothstep(0.25, 0.75, footprint / wavelength);
    }

    // waterWaveNormal (libs/Water.glsl) with each layer filtered; layers filtered out entirely are skipped
    vec2 abzaWaterWaveNormal(vec2 coord, float footprint) {
        vec2 totalNormal = vec2(0.0);
        mat2 normalRotation = transpose(goldenRotate) * mat2(32.0);
        const mat2 layerRotation = mat2(WATER_WAVE_LAYERS_SCALE) * mat2(goldenRotate[0].x, goldenRotate[1].x, goldenRotate[0].y, goldenRotate[1].y);
        coord *= 32.0;
        float currentWeight = 1.0;
        float speed = 2.0 * frameTimeCounter * WATER_WAVE_SPEED;
        // The first layer's waves repeat every 2 pi in coord, which is in blocks / WATER_WAVE_SCALE
        float wavelength = 2.0 * PI * WATER_WAVE_SCALE;
        for (int i = 0; i < WATER_WAVE_NORMAL_LAYERS; i++) {
            coord = goldenRotate * coord;
            float layerFilter = abzaWaveLayerFilter(footprint, wavelength);
            if (layerFilter > 0.0) {
                totalNormal += normalRotation * (currentWeight * layerFilter) * gerstnerApproxGeForceLegendDerivative(coord - vec2(speed, 0.0));
            }
            normalRotation *= layerRotation;
            currentWeight *= WATER_WAVE_LAYERS_FADE;
            coord *= WATER_WAVE_LAYERS_SCALE;
            wavelength /= WATER_WAVE_LAYERS_SCALE;
        }
        const float totalWeight = (1.0 - WATER_WAVE_LAYERS_FADE) / (1.0 - pow(WATER_WAVE_LAYERS_FADE, float(WATER_WAVE_NORMAL_LAYERS)));
        return totalNormal * totalWeight * 0.5;
    }

    // waterWave (libs/Water.glsl) with the wave normals filtered for a pixel covering footprint blocks of water
    vec3 abzaWaterWave(vec3 position, vec3 tangentDir, float footprint) {
        position /= (WATER_WAVE_SCALE);
        vec3 coord = vec3(position.xz - vec2(position.y), 1.0);

        const vec3 stepScale = vec3(vec2(0.2 * WATER_WAVE_HEIGHT / (WATER_WAVE_SCALE * 32.0)), 1.0);
        float tangentDirZ = abs(tangentDir.z * inversesqrt(dot(tangentDir, tangentDir)));
        vec3 stepSize = tangentDir * stepScale;
        stepSize *= 0.2 / abs(stepSize.z);
        tangentDirZ /= 0.2;

        for (int i = 0; i < 5; i++) {
            coord += stepSize;
            float sampleHeight = waterWaveHeight(coord.xy);
            if (coord.z - sampleHeight < 0.0) {
                break;
            }
        }
        for (int i = 0; i < 5; i++) {
            float sampleHeight = waterWaveHeight(coord.xy);
            float nextLength = coord.z - sampleHeight;
            float nextScale = nextLength * tangentDirZ;
            coord += stepSize * nextScale;
        }
        vec2 sampleNormal = abzaWaterWaveNormal(coord.xy, footprint);

        return normalize(vec3(sampleNormal * stepScale.xy, 1.0));
    }

    // The size of the water a pixel covers, in blocks, from the change in its view position to the next pixels
    float abzaWaterFootprint(vec3 viewPos) {
        return max(length(dFdx(viewPos)), length(dFdy(viewPos)));
    }
#endif

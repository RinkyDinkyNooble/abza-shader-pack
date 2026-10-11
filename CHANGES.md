# Changes from Sundial Lite

ABZA Shader is based on Sundial Lite v1.2.0 by GeForceLegend (GPL-3.0). This file lists every change, newest first.

## 1.0.0 (2026-10-10)

First public release, for the ABZA modpack (Minecraft 1.20.1, Forge, Oculus 1.8.0). The same pack as v0.2.27, with the README rewritten for release.

## v0.2.27 (2026-10-10)

### Changed
- The Potato preset (tuned in game): shadow map 256 (was 64); it now also lists parallax quality and the realistic cloud samples at their defaults, so every preset sets the same 38 options.
- `tools/check.py` fails when presets list different options.

### Edits to Sundial's own files
- `shaders.properties`: `profile.POTATO`.
- `lang/en_us.lang`: Potato text.

## v0.2.26 (2026-10-10)

### Added
- The Max preset (tuned in game): the Ultra preset plus ray-traced bounce light with 4 rays per pixel, 16 blended frames, and cave adaptation 0. Every preset now also sets "Ray tracing frames blended" (20) and cave adaptation (0.5) so switching presets restores them.

### Fixed
- Shadow-style decals that mods draw with the entity shadow render type (Zombie Awareness's blood under its scent markers: `entityShadow`, translucent vertex colour, full light 240/240) went through `gbuffers_entities`, whose data buffers are written unblended, so the faint decal replaced the surface data below it: ores there lost their glow and the blocks took full block light. `Textured.frag` now discards those fragments (`abzaEntityDecal()` in `abza/Entities.glsl`); Iris hides vanilla entity shadows the same way. The decals still show with shaders off.

### Edits to Sundial's own files
- `programs/gbuffers/Textured.frag`: entity decal discard.
- `shaders.properties`: `profile.MAX` values; `VB_MAX_BLEDED_FRAMES` and `STEADY_LOCAL_ADAPTATION` in every preset.
- `lang/en_us.lang`: Max and preset text.

## v0.2.25 (2026-10-10)

### Added
- The Ultra preset (tuned in game): the ABZA preset with shadow map 4096, transparent shadows, cloud shadows, underwater caustics, full reflection, reflection filter High and anisotropic filtering 8.
- The Max preset (`profile.MAX`, gold name), with the old top-tier values until its own were set.

### Edits to Sundial's own files
- `shaders.properties`: `profile.ULTRA` values, `profile.MAX`.
- `lang/en_us.lang`: Ultra and Max text.

## v0.2.24 (2026-10-10)

### Added
- Glowing parts from ETF emissive textures (resource packs' `_e.png` overlays, such as Tissou's Zombie Pack eyes): ETF draws them with block light 242, above vanilla's 240, and `Textured.frag` makes those fragments fully emissive (`abzaETFEmissive()` in `abza/Entities.glsl`). Works in ETF's default "Dull" emissive mode.
- The High preset (`profile.HIGH`, tuned in game): the ABZA preset with shadow map 2048, anisotropic filtering 4, depth of field and underwater caustics on.
- Preset names in colour: Potato grey, ABZA green, High aqua, Ultra light purple.

### Changed
- Presets are Potato, ABZA, High and Ultra. Balanced is gone (ABZA is the balanced preset); Max is renamed Ultra and keeps its values until Ultra's own were set.

### Fixed
- `gbuffers_beaconbeam` had blending on for its data buffers, so translucent beacon-beam layers (ETF's "Bright" emissive mode draws glowing parts that way) blended the packed normal, material and emission data away. Its data buffers are now written unblended and colortex0 alpha-blended, as for entities. Vanilla beacons are unchanged: their translucent outer layer is discarded (vertex alpha below 0.999).

### Edits to Sundial's own files
- `programs/gbuffers/Textured.frag`: includes `abza/Entities.glsl`; ETF emissive overlays are emissive.
- `shaders.properties`: `blend.gbuffers_beaconbeam` and `blend.gbuffers_beaconbeam.colortex0`; `profile.HIGH`, `profile.ULTRA` (was `profile.MAX`), `profile.BALANCED` removed.
- `lang/en_us.lang`: preset names (colour codes as `§` escapes) and text.

## v0.2.23 (2026-10-10)

### Added
- "Ambient occlusion" (`AMBIENT_OCCLUSION`, Lighting > Ray tracing, default on): off removes VBAO's darkening and crease shading. With bounce light also off, Deferred12 skips the visibility bitmask trace (`ABZA_VB_TRACE` in `abza/AO.glsl`); with bounce light on, the trace runs for it and its occlusion is zeroed. Every preset sets it on.

### Changed
- Defaults from in-game tuning, with the ABZA preset to match: ray-traced bounce light (`VBGI`) off, cave adaptation (`STEADY_LOCAL_ADAPTATION`) 0.5.

### Edits to Sundial's own files
- `programs/deferred/Deferred12.frag`: the trace runs only with `ABZA_VB_TRACE`; occlusion zeroed without `AMBIENT_OCCLUSION`.
- `settings/GlobalSettings.glsl`: `VBGI` off.
- `shaders.properties`: `AMBIENT_OCCLUSION` in every preset and on the Ray tracing screen; `profile.ABZA` sets `!VBGI`.
- `lang/en_us.lang`: the option; Ray tracing, crease shading, ambient occlusion ray length and ABZA preset text.

## v0.2.22 (2026-10-10)

### Changed
- Defaults from in-game tuning, with the ABZA preset to match: cloud shadows, coloured (transparent) shadows and underwater caustics off. With the last two off, translucent blocks skip the shadow pass (`shadowTranslucent = false`). Exposure and the ray-tracing settings are unchanged.

### Edits to Sundial's own files
- `settings/GlobalSettings.glsl`: `CLOUD_SHADOW`, `TRANSPARENT_SHADOW`, `WATER_CAUSTIC` off.
- `shaders.properties`: `profile.ABZA` values.
- `lang/en_us.lang`: the ABZA preset text.

## v0.2.21 (2026-10-10)

### Changed
- Defaults from in-game tuning, with the ABZA preset to match: shadow map 1024 (was 2048), shadow distance 80 blocks (was 120), anisotropic filtering 2 (was 4), depth of field off, mod light, water and plant detection on, glowing entities overlay on. Exposure and the ray-tracing settings are unchanged.
- Menu names: the "Visibility bitmask" screen is "Ray tracing"; "VBGI" is "Ray-traced bounce light", "VB trace count" is "Bounce light rays", "VB step count" is "Ray steps", the trace lengths are "Bounce light ray length" and "Ambient occlusion ray length", and "VB max blended frames" is "Ray tracing frames blended".

### Fixed
- With bounce light (`VBGI`) off, the trace count still multiplied the trace that ambient occlusion and crease shading use, so a high count kept its cost. The count now applies only with bounce light on (`ABZA_VB_TRACES` in `abza/GI.glsl`: `VB_TRACE_COUNT` with `VBGI`, otherwise 1), and colortex3's mipmaps, read only by bounce-light samples, are generated only then.

### Removed
- Dev-only tools: "Benchmark: turn off" (`BENCH_EFFECT_OFF`, `abza/Bench.glsl`) and the "Sundial defaults" preset (`profile.SUNDIAL`). The benchmark datapack (`bench/`) and `tools/bench_report.py` stay in the repo.

### Edits to Sundial's own files
- `programs/deferred/Deferred12.frag`: the slice loop, the average and the crease shading count use `ABZA_VB_TRACES`.
- Defaults: `settings/GlobalSettings.glsl` (`MOD_LIGHT_DETECTION`, `MOD_WATER_DETECTION`, `ANISOTROPIC_FILTERING_QUALITY`), `programs/gbuffers/Terrain.vert` (`MOD_PLANT_DETECTION`), `programs/gbuffers/Textured.vert` (`GLOWING_OVERLAY`), `programs/composite/Composite7.frag` (`DEPTH_OF_FIELD`), `shadowDistance` in `Composite13.frag` and `Deferred11.frag`, `shadowMapResolution` in `libs/Shadow.glsl`, `Composite13.frag`, `gbuffers/Shadow.frag` and `gbuffers/Shadow.vert`.
- `shaders.properties`: `profile.ABZA` values; `profile.SUNDIAL` and the benchmark entry on the main screen removed.
- `lang/en_us.lang`: ray-tracing names, the ABZA preset and Lighting text; the benchmark and "Sundial defaults" text removed.

## v0.2.20 (2026-10-10)

### Added
- "Exposure mode: Off" (`EXPOSURE_MODE 2`): one exposure per world that never changes. It is Steady's scene model (`abzaOutdoorScene()`, split out of `abzaSteadyBrightness()` in `abza/Exposure.glsl`, Steady unchanged) evaluated once for clear weather with the world's daylight straight overhead: Sundial's `sunlightColor` at the zenith (0.904, 0.830, 0.743) with air, white without, times `ABZA_DAY_LIGHT`, and the zenith-sun sky colour from `atmosphereScatteringUp(1.0, 30.0)`, computed in the vertex shader (`abzaSkyColorNoon`). The world's day exposure multiplier applies (`abzaExposureScale()`). Worlds with a fixed time (`ABZA_FIXED_TIME`, new: Cinder and Umbra) use their constant outdoor scene, as Steady does. At midday Off equals Steady; nights and unlit caves get no lift. EV still adjusts it. The Nether and the End keep Metered.

### Edits to Sundial's own files
- `programs/common/Common.vert`: `abzaSkyColorNoon` output next to `skyColorUp` with exposure off.
- `lang/en_us.lang`: the Off value and the exposure mode text.

## v0.2.19 (2026-10-10)

### Added
- The ABZA preset (`profile.ABZA`), the pack's default: the current defaults of every option the other presets set (35), with block-entity shadows off. The defaults equal the preset, so the menu shows it selected on a fresh install; Potato, Balanced and Max are unchanged (block-entity shadows stay on in Balanced and Max).

### Changed
- Block-entity shadows are off by default (`SHADOW_BLOCK_ENTITIES`): 3.55 ms per frame in Eden, almost all processor time. "Sundial defaults" turns them on.

### Edits to Sundial's own files
- `shaders.properties`: `profile.ABZA`; `profile.SUNDIAL` sets `SHADOW_BLOCK_ENTITIES`.
- `lang/en_us.lang`: the preset's text; block-entity shadow text.

## v0.2.18 (2026-10-10)

### Removed
- Desert haze (v0.2.17): it follows the biome the player stands in, so a desert seen from plains through Distant Horizons showed no haze. Earth has no planet fog again; `abzaDust`, `ABZA_FOG_DUST`, `ABZA_DUST_COLOR` and the "Desert haze" option are gone. The sun sheen defaults from v0.2.17 stay.

### Changed
- Reflections show Ad Astra's square star instead of Sundial's round sun disc: `abzaReflectedSun()` (`abza/Sky.glsl`) draws the square `abzaStarMask` uses, in the colours of the star's 8 x 8 texture (an outer ring, an inner ring and a 4 x 4 core; `sun.png` or `red_sun.png`, picked per world by `ABZA_STAR_TEXTURE`), as bright as Deferred11 draws it in the sky (linear colour times 2 + "Star texture brightness"). Worlds without an Ad Astra star keep Sundial's disc. The square's position is shared with `abzaStarMask` through `abzaStarQuadPos()`.

### Edits to Sundial's own files
- `programs/composite/Composite0.frag`: includes `abza/Sky.glsl`; the reflected sun is `abzaReflectedSun()`.
- `shaders.properties`, `lang/en_us.lang`: the desert haze entries of v0.2.17 removed.

## v0.2.17 (2026-10-10)

### Added
- Desert haze: Earth gets the planet fog (`abza/Fog.glsl`) with no density except a dust term, `ABZA_FOG_DUST` (0.006 per block at the base, Y 63, falloff 32 blocks) times `abzaDust`, in `ABZA_DUST_COLOR` (pale sand, `vec3(1.0, 0.88, 0.7)`) instead of the biome's fog colour. `abzaDust` is a custom uniform: 1 where the biome's temperature is above 1.5 and its rainfall below 0.1 (in ABZA's Earth: desert and badlands), eased over about 10 seconds. "Desert haze" (Atmosphere menu, multiplier, default 1); "Sundial defaults" sets it to 0. Other worlds have no dust term (`ABZA_FOG_DUST` 0).

### Changed
- Sun sheen defaults from in-game tuning: strength 2, focus 0.45.

### Edits to Sundial's own files
- `shaders.properties`: `abzaDust`; the option in the Atmosphere menu and sliders; `profile.SUNDIAL`.
- `lang/en_us.lang`: the option.

## v0.2.16 (2026-10-10)

### Fixed
- The block outline turned white in places with the sun sheen on: `gbuffers_basic` draws lines as black, camera-facing surfaces with smoothness 0, and the sheen's highlight isn't tinted by albedo. Lines now carry their own material ID (`MAT_LINE`, 6), which the sheen skips.

### Added
- "Shadow edge softness" (Shadow menu, default 0.5): multiplies the minimum filter radius of the soft shadows (`0.02 * shadowDistance / distortFactor` in `percentageCloserSoftShadow`), which sets the blur of small shadows near the player; the blocker-distance part of the penumbra is unchanged. "Sundial defaults" sets it to 1.

### Edits to Sundial's own files
- `libs/Materials.glsl`: `MAT_LINE`.
- `programs/gbuffers/Basic.frag`: material ID `MAT_LINE`.
- `programs/deferred/Deferred11.frag`: shadow edge softness in the PCSS filter radius.
- `shaders.properties`: the option in the Shadow menu and sliders; `profile.SUNDIAL`.
- `lang/en_us.lang`: the option.

## v0.2.15 (2026-10-09)

### Added
- Sunshine sheen (`abza/Sheen.glsl`), three parts with their own options in the Lighting menu:
  - "Sun sheen" (default 1) and "Sun sheen focus" (default 0.35): surfaces without their own smoothness or metalness (blocks without material maps, mobs, Distant Horizons terrain) get Sundial's direct-light specular as if their smoothness were the focus value, F0 0.04, times the sheen strength. Only the direct-light highlight changes: gbuffer smoothness stays 0, so there are no new reflections. Plants and held items get none.
  - "Plant glow" (default 2): Sundial's subsurface scattering (plants, leaves, porous materials) is multiplied by `1 + glow * max(dot(view, light), 0)^4`, so light through plants is up to three times stronger looking toward the sun.
  - "Shade fill" (default 0.7): multiplies the sunlight and moonlight part of the sky-light fill (`sunColor * 2 * ABZA_AMBIENT`) in Deferred12 and Composite5. The sky's own colour, block light, caves and Steady exposure are unchanged.
- "Sundial defaults" sets sun sheen 0, plant glow 0 and shade fill 1.

### Edits to Sundial's own files
- `programs/deferred/Deferred11.frag`: sun sheen added to the direct specular; plant glow on the subsurface scattering.
- `programs/deferred/Deferred12.frag`, `programs/composite/Composite5.frag`: shade fill on the sunlight part of the sky fill.
- `shaders.properties`: the four options in the Lighting menu and sliders; `profile.SUNDIAL`.
- `lang/en_us.lang`: the four options.

## v0.2.14 (2026-10-09)

### Added
- Crease shading (`abza/AO.glsl`, `abza/AOTrace.glsl`): short-range ambient occlusion taken from Sundial's visibility bitmask trace, with no extra rays. Each trace sample within "Crease shading radius" (default 1.5 blocks) adds the slice sectors it newly covers, weighted by `(1 - d²/r²)²`, with its assumed thickness capped at 0.5 blocks (Sundial assumes 10 % of the view distance, which would let thin grass shade the ground behind it). The result is blended over frames like the visibility bitmask, in colortex10 (R16F, not cleared; Deferred0 reprojects it with the same weights). Deferred12 multiplies sky, block, basic and bounced light by `(1 - crease)^strength` and direct light by `(1 - crease)^(strength * share)` ("Crease shading", default 1; "Crease shading in direct light", default 0.5); emission is kept. Sundial's own ambient occlusion is unchanged. Held items get none. "Sundial defaults" sets the strength to 0.

### Edits to Sundial's own files
- `programs/deferred/Deferred0.frag`: reprojects the crease history into colortex10 (`RENDERTARGETS: 0,5,6,10`).
- `programs/deferred/Deferred12.frag`: crease samples in the trace loop, crease shading on direct and other light, colortex10 output (`RENDERTARGETS: 3,5,10`).
- `shaders.properties`: the three options in the Lighting menu and sliders; `profile.SUNDIAL`.
- `lang/en_us.lang`: the three options; "Block corner shading" text.

## v0.2.13 (2026-10-09)

### Removed
- Half-resolution sky (v0.2.11): no measurable saving in the batch test, and it softened a bare horizon by 2 pixels. The cloud pass no longer writes colortex10 and colortex11, and composite4 computes the sky as Sundial does.

### Changed
- "Reuse the sky in reflections" is now "Reuse clouds in reflections": reflections take only the half-resolution clouds from the screen; the reflected atmosphere is computed as in Sundial.

### Edits to Sundial's own files
- `programs/composite/Composite4.frag`: half-resolution sky removed (as in v0.2.10).
- `programs/composite/Composite0.frag`: reflected atmosphere as in Sundial; the screen lookup covers the clouds only.
- `shaders.properties`: half-resolution sky removed from the Cloud menu.
- `lang/en_us.lang`: half-resolution sky text removed; reflection reuse renamed.

## v0.2.12 (2026-10-09)

### Fixed
- v0.2.11 didn't load: Oculus refuses a pack that uses custom images without declaring the feature, and fell back to no shaders. `shaders.properties` now declares `iris.features.required = CUSTOM_IMAGES COMPUTE_SHADERS`.
- `tools/check.py` fails when `shaders.properties` uses custom images or SSBOs, or the pack has compute or tessellation programs, without the matching feature flag, or when it names a flag Oculus 1.8.0 doesn't know. It compiles compute programs in the core profile, as Oculus does.

### Edits to Sundial's own files
- `shaders.properties`: feature flags.

## v0.2.11 (2026-10-09)

### Added
- Half-resolution light shafts (option, on by default): Sundial's volumetric light and fog march runs in a compute pass at half resolution (`composite5_a.csh`, `abza/VolumetricPass.comp`) into half-size images (`abzaVL0/1`, `abzaVLInfo0/1`, two sets used in turn by frame parity). Each texel is blended with the previous frame's result at the same surface (85 % history, reprojected at the ray's end point; rejected when the march length differs by more than 10 %). Composite5 applies it as `color * transmittance + light`, bilinear over texels whose march length matches the pixel's; pixels with no match (edges of nearer objects) march at full resolution. The march itself (`abza/VolumetricLight.glsl`) is Sundial's loop split into scattered light and fog transmittance.
- Half-resolution sky (option, on by default): the half-resolution cloud pass also writes the sky's atmosphere as light (colortex10) and transmittance (colortex11), from one call of Sundial's `singleAtmosphereScattering` over a white background; Composite4 applies them to sky pixels at full resolution, so the sun, moon and stars stay sharp. Earth and Eden.
- Reuse the sky in reflections (option, on by default): reflections that reach the sky take the half-resolution clouds, and with the half-resolution sky the atmosphere, from the screen where the reflected direction is on screen and computed; elsewhere they compute them as before.
- `tools/check.py --set NAME=off|on` for on/off options.

### Edits to Sundial's own files
- `programs/composite/Composite5.frag`: volumetric light and fog options moved to `abza/VolumetricSettings.glsl` (unchanged, shared with the compute pass); the half-resolution path when on, Sundial's loop otherwise.
- `programs/composite/Composite4.frag`: half-resolution sky when on.
- `programs/composite/Composite0.frag`: reflected sky and clouds from the half-resolution pass when on.
- `libs/Cloud.glsl`: the cloud march's pixel position is `CLOUD_PIXEL` (`gl_FragCoord` unless set), so compute passes can include the file.
- `composite5_a.csh`: new compute stub.
- `shaders.properties`: the four half-size images; options in the Volumetric light, Cloud and Reflection menus.
- `lang/en_us.lang`: the three options.

## v0.2.10 (2026-10-09)

### Added
- "Sundial defaults" preset (for testing; removed from the final pack): sets the options whose ABZA default differs from Sundial Lite v1.2.0's to Sundial's values, for comparing the two packs at equal settings.

### Edits to Sundial's own files
- `shaders.properties`: `profile.SUNDIAL`.
- `lang/en_us.lang`: the preset's text.

## v0.2.9 (2026-10-09)

### Fixed
- "Half-resolution clouds" never appeared in the menu and stayed on: the code tested it only inside `#if ... defined`, which Oculus doesn't count as an option. It's now tested with `#ifdef`. `tools/check.py` now requires an `#ifdef` or `#ifndef` for every on/off option it finds in menus, profiles and program switches.
- Distant clouds sparkled at half resolution: the clouds' per-pixel noise reached TAA already blurred by the upscale, so TAA's history clipping kept it. Each half-resolution texel now blends with the previous frame's clouds at the same point of the sky (90 % history, reprojected at the cloud depth; history from another frame, off screen, or after a jump of more than 32 blocks is ignored). Colortex9's alpha holds a frame tag for this.

### Edits to Sundial's own files
- `lang/en_us.lang`: half-resolution clouds text.

## v0.2.8 (2026-10-09)

### Changed
- VB trace count option goes up to 32 (was 8), for smoother global illumination at a cost that grows with the count. Default unchanged (1).

### Edits to Sundial's own files
- `programs/deferred/Deferred12.frag`: VB trace count values up to 32.
- `lang/en_us.lang`: VB trace count text.

## v0.2.7 (2026-10-09)

### Added
- Half-resolution clouds (option, on by default): realistic clouds are computed at half resolution in a new pass (`deferred13`, `abza/CloudPass.frag`, `scale.deferred13 = 0.5`) and blended in at full resolution in composite4 (`abza/HalfClouds.glsl`). The pass skips texels whose four pixels are solid ground below the cloud layer, and runs only in ABZA worlds with clouds.

### Changed
- Realistic clouds light-march only toward the sun or moon while it can still light the cloud layer (`ABZA_CLOUD_LIGHT_HORIZON`); below it the result was already zero.
- Light shafts compute the cloud shadow only at samples the shadow map leaves lit; elsewhere it was multiplied by zero.

### Fixed
- Entity, player and block-entity shadows: their switches were never valid options (nothing in the shader code tested them), so `shaders.properties` read them as off and those shadows never rendered. They now work, on by default as intended.
- Cloud height description: the option is the Y level of the cloud bottom (v0.2.3's text was wrong).

### Edits to Sundial's own files
- `libs/Cloud.glsl`: light march per light; `abzaCloudBlend` records how much the clouds cover the background.
- `programs/composite/Composite5.frag`: cloud shadow after the shadow-map test in the light-shaft loop.
- `programs/composite/Composite4.frag`: half-resolution clouds when on.
- `deferred13.vsh`, `deferred13.fsh`: new pass stubs.
- `shaders.properties`: pass scale and switches (per-world switches generated); option in the Cloud menu.
- `lang/en_us.lang`: half-resolution clouds; cloud height text.

## v0.2.6 (2026-10-09)

### Added
- "Benchmark: turn off" on the main screen (`abza/Bench.glsl`): turns off one effect at a time to measure its cost.

### Changed
- Cave adaptation 0 by default: Steady exposure follows only the time of day, the weather and the world.
- Umbra (no direct light): no shadow pass, and no soft or screen-space shadow filtering.

### Edits to Sundial's own files
- `shaders.properties`: benchmark switch on the main screen; Umbra's shadow pass off (generated).
- `lang/en_us.lang`: benchmark switch text.

## v0.2.5 (2026-10-09)

### Added
- Option: cave adaptation (Steady exposure only, default 0.15). It blends, in log space, the brightness of an open-sky scene with the brightness at the player's position (sky light and block light there): 0 ignores where the player stands, 1 is v0.2.4's behaviour.

### Changed
- Exposure adjusts faster: half-life 0.5 seconds toward brighter and darker scenes (was 1.5 and 3).

### Edits to Sundial's own files
- `programs/composite/Composite10.frag`: adjust-time defaults 0.5 and 0.5.
- `shaders.properties`, `lang/en_us.lang`: cave adaptation.

## v0.2.4 (2026-10-09)

### Changed
- Realistic clouds start at Y 800 by default (height 300), up from Y 600.
- Bloom intensity 1.0 by default (Sundial: 1.2).

### Edits to Sundial's own files
- `settings/CloudSettings.glsl`: realistic cloud height default 300.
- `programs/composite/Composite14.frag`: bloom intensity default 1.0.
- `lang/en_us.lang`: cloud height description.

## v0.2.3 (2026-10-09)

### Added
- Option: planet fog height (multiplier on how far the fog reaches above its base height).

### Changed
- Planet fog: rays toward the sky end at the farthest terrain drawn, and the fog thins faster above its base height (Cinder, Interloper, Umbra), so the haze stays near the horizon.
- Realistic clouds are lower and thinner by default: from Y 600 to Y 1100 (height 100, thickness 500), with density 20 and scale 0.4 to match. The cloud height option has values down to 100.
- Volumetric fog layer thickness 64 blocks by default (Sundial: 128).
- Screen-space global illumination: samples more than 4 pixels from the previous step read a mipmapped copy of the lit scene (`abza/GI.glsl`), so small bright sources such as glowing ores light their surroundings without sparkling.

### Fixed
- Sky: Ad Astra's sunrise fan was drawn as solid triangles since v0.2.2. A sky fragment now counts as a star only when all three vertices of its triangle are star vertices.
- Translucent held items (a gun optic's glass) no longer get mirror reflections, which flickered and tore.

### Edits to Sundial's own files
- `programs/gbuffers/SkyBasic.vert`, `programs/gbuffers/SkyBasic.frag`: the star-vertex flag is interpolated instead of flat.
- `programs/deferred/Deferred12.frag`: GI samples through `abzaGISample`.
- `programs/gbuffers/Textured.frag`: translucent held items keep their own smoothness.
- `settings/CloudSettings.glsl`: realistic cloud height, thickness, density and scale defaults; lower height and thickness values.
- `programs/composite/Composite5.frag`: volumetric fog thickness default 64.
- `shaders.properties`, `lang/en_us.lang`: planet fog height; corrected cloud height description.

## v0.2.2 (2026-10-08)

### Added
- Exposure mode: Steady (default) or Metered. Steady sets exposure from the light at the player (`abza/Exposure.glsl`): sun or moon height and colour, the sky overhead, weather, the world's light settings, and the sky light and block light at the player's position. Looking around doesn't change it.

### Changed
- Stars keep their colour. Ad Astra's coloured stars (all of the Moon's and the orbits', and the pastel ones elsewhere) are drawn.
- Stars are found by day through a copy of their colour in colortex1 with a frame tag, instead of a colour mark in colortex0.
- Planet fog is 1.5 times denser in every world.

### Fixed
- Held items: temporal anti-aliasing no longer takes history from pixels the held item covered in the previous frame, which left ring outlines of a gun's optic over the sky when the view moved (`abza/Temporal.glsl`).

### Edits to Sundial's own files
- `programs/gbuffers/SkyBasic.vert`, `programs/gbuffers/SkyBasic.frag`: star vertices keep their colour; stars write their colour and a frame tag to colortex1.
- `programs/composite/Composite7.frag`: the previous-depth gather also returns the nearest depth; history from held-item pixels is rejected where no held item is near.
- `programs/composite/Composite10.frag`: Steady exposure.
- `composite10.vsh`: computes the sky colour overhead (`SKY_COLOR_UP`).
- `shaders.properties`: no blending into colortex1 in `gbuffers_skybasic`; exposure mode in the Exposure menu.
- `lang/en_us.lang`: exposure mode text.

## v0.2.1 (2026-10-08)

### Added
- Stars by day on worlds without air: the sky program marks Ad Astra's stars in the stored sky colour (`abza/Stars.glsl`), and the sky is drawn with those stars brighter by day. Option: stars by day.
- Per-world exposure multiplier by day and by night (`ABZA_DAY_EXPOSURE`, `ABZA_NIGHT_EXPOSURE`). The Moon: 0.5 by day, 0.75 by night.
- Block corner shading: vanilla's smooth-lighting ambient occlusion, as an option (0 to 1, default 0.75).

### Fixed
- Distant Horizons terrain: blocks that give off only a little light (Interloper's aeronos and strophar caps, light level 6) no longer glow at full strength. The glow now follows the block's light level, full from level 15.

### Edits to Sundial's own files
- `programs/gbuffers/SkyBasic.vert`, `programs/gbuffers/SkyBasic.frag`: stars (vertices 100 blocks out) are marked in the sky colour.
- `programs/deferred/Deferred11.frag`: marked stars brighter by day in worlds without air.
- `programs/composite/Composite14.frag`: per-world exposure multiplier.
- `programs/composite/Composite13.frag`: `ambientOcclusionLevel` is an option, default 0.75 (Sundial: 0).
- `programs/gbuffers/TerrainDH.frag`: glow of light-giving blocks by their light level.
- `shaders.properties`, `lang/en_us.lang`: the new options.

## v0.2.0 (2026-10-08)

### Added
- Per-world settings in `abza/World.glsl` (shared by `abza/Abza.glsl` and `abza/Clouds.glsl`), with values in `abza/worlds/*.glsl`: air, clouds and cloud amount, day and night light colour, sky-light fill, exposure floor, volumetric fog strength and tint, planet fog.
- Worlds without air (the Moon, every orbit, Interloper, Cinder, Umbra): no atmosphere scattering (black sky), no clouds, no air light shafts; white sunlight that only the horizon cuts off; a smaller sky-light fill. Umbra gets no direct light at all.
- Planet fog (`abza/Fog.glsl`): a height fog with an exact integral along each ray, in the biome's fog colour, on Interloper, Cinder, Umbra and Eden. Applied to the view, to what's seen through water and glass, and to reflections.
- `abza/Light.glsl`: the per-world sun colour, the biome fog colour with the game's time-of-day and rain darkening removed, and the volumetric fog tint.
- Eden's red sun tints its sunlight, sky, clouds and distance haze.
- Earth's volumetric fog and cloud amount follow the biome's rainfall; Eden has more of both.
- Options: planet fog on/off, density and brightness; dark world exposure limit.
- Every menu option and screen has a description, with units.

### Edits to Sundial's own files
- `libs/Uniform.glsl`: the sun colour comes from `abza/Light.glsl`.
- `settings/CloudSettings.glsl`: includes `abza/Clouds.glsl`, which turns clouds off in worlds without them.
- `programs/common/Common.vert`: no sky colour from the atmosphere in worlds without air.
- `programs/composite/Composite4.frag`, `programs/composite/Composite0.frag`: no atmosphere scattering on the sky or in sky reflections in worlds without air; planet fog on reflections.
- `programs/composite/Composite5.frag`: planet fog on the view and through water and glass; volumetric fog strength by biome rainfall and tint by fog colour; per-world sky-light fill on translucent blocks.
- `programs/deferred/Deferred12.frag`: per-world sky-light fill.
- `libs/Atmosphere.glsl`, `libs/Cloud.glsl`: day-light tint on sky scattering, distance haze and clouds; realistic cloud amount changed per world and biome.
- `shaders.properties`: custom uniforms `abzaFogDivisor` and `abzaHumidity`; new options in the Atmosphere and Exposure menus and sliders.
- `lang/en_us.lang`: a description with units for every option and screen; clearer names for a few options.

## v0.1.1 (2026-10-08)

### Added
- Profiles in the shader menu: Potato (every costly effect off or lowest), Balanced, Max.
- Exposure keeps two brightness averages: a slow one that sets the exposure and a quick one that adds a small immediate response. New options: quick exposure response, and the seconds for exposure to adjust halfway toward a brighter or darker view.

### Edits to Sundial's own files
- `programs/composite/Composite10.frag`: keeps the quick average in texel (0, 0) and the slow one in texel (1, 0); adaptation uses half-lives in seconds.
- `programs/composite/Composite9.frag`: carries the slow average to the next frame.
- `programs/composite/Composite14.frag`: exposure from the slow average plus the quick response.
- `libs/Shadow.glsl`, `programs/composite/Composite13.frag`, `programs/gbuffers/Shadow.frag`, `programs/gbuffers/Shadow.vert`: shadow resolution options 64 and 128.
- `shaders.properties`: profiles; profile switch on the main screen.
- `lang/en_us.lang`: units in the shadow and exposure descriptions; profile names.

## v0.1.0 (2026-10-08)

### Added
- Per-world folders for every ABZA dimension (`dimension.properties`, `world0` and `world_*`, generated by `tools/worlds.py`), each selecting a settings file in `abza/worlds/`.
- `abza/Abza.glsl`: ABZA options and the per-world settings switch.
- `abza/Sky.glsl`: finds the star Ad Astra draws, so it can be lit as the sun.
- `abza/Ores.glsl` and `abza/OreHosts.glsl` (generated by `tools/ores.py`): glowing ores.
- Options: entity shadow distance; entity, player and block-entity shadow switches; glowing ores and their strength; star brightness; exposure adaptation speed toward brighter and darker views.

### Edits to Sundial's own files
- `settings/GlobalSettings.glsl`: motion blur off by default; includes `/abza/Abza.glsl`.
- `programs/composite/Composite7.frag`: hand depth of field off by default.
- `programs/composite/Composite13.frag`: sun path rotation 0 by default (Ad Astra's skies can't be tilted); shadow distance options down to 16 and resolution down to 256; entity shadow distance option.
- `programs/deferred/Deferred11.frag`: shadow distance options down to 16; screen-space shadow samples down to 2; in ABZA worlds, sky pixels show Ad Astra's star instead of the shader's sun disc.
- `libs/Shadow.glsl`, `programs/gbuffers/Shadow.frag`, `programs/gbuffers/Shadow.vert`: shadow resolution options 256 and 512.
- `programs/composite/Composite10.frag`: auto-exposure samples the whole screen evenly, centre weight 1.0 by default, and adapts in log space, quickly toward brighter views and slowly toward darker ones.
- `programs/composite/Composite14.frag`: per-world exposure floor.
- `programs/gbuffers/Terrain.frag`: glowing ores.
- `shaders.properties`: vanilla sun on (Earth falls back to it if Ad Astra's sky is removed); shadow caster switches; translucent blocks skip the shadow pass when transparent shadows and water caustics are both off; new options in the menus; per-world program switches (generated).
- `block.properties`: glowing-ore block IDs 8300 and up (generated).
- `lang/en_us.lang`: names and descriptions of the new options.

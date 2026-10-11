# ABZA Shader

A shader pack made for the **ABZA** modpack (Minecraft 1.20.1, Forge), built on [Sundial Lite](https://github.com/GeForceLegend/Sundial-Lite) by GeForceLegend.

The pack is dedicated to the ABZA modpack. It runs in other 1.20.1 Forge setups with Oculus, but the planets and their skies come from the modpack; see [Outside the modpack](#outside-the-modpack).

![Earth at midday: a cherry grove by a lake](https://raw.githubusercontent.com/RinkyDinkyNooble/abza-shader-pack/main/curseforge/images/earth-day.jpg)

| Requirement | Version |
|---|---|
| Minecraft | 1.20.1 |
| Forge | 47 |
| Oculus | 1.8.0, with Embeddium |
| Distant Horizons | Optional, tested with 3.3.2 |

## Presets

"Profile" on the main shader screen sets every performance option at once. Any option can still be changed by hand afterwards.

| Preset | What it sets |
|---|---|
| Potato | Every costly effect off or at its lowest; a 256-pixel shadow map out to 16 blocks, no mob shadows |
| ABZA (default) | The balanced preset the pack is tuned at: 1024-pixel shadows out to 80 blocks, reflections, clouds, light shafts, ambient occlusion |
| High | ABZA with 2048-pixel shadows, sharper ground textures, depth of field and underwater caustics |
| Ultra | ABZA with 4096-pixel shadows, coloured shadows from glass, cloud shadows, underwater caustics, reflections on every surface that isn't fully rough, and sharper ground textures |
| Max | Ultra with ray-traced bounce light (4 rays per pixel) and no cave adaptation |

## Gallery

| | |
|---|---|
| ![Earth at dusk: glowing ores](https://raw.githubusercontent.com/RinkyDinkyNooble/abza-shader-pack/main/curseforge/images/earth-dusk-ores.jpg) | ![Earth's night sky in the modpack](https://raw.githubusercontent.com/RinkyDinkyNooble/abza-shader-pack/main/curseforge/images/earth-night-sky.jpg) |
| Earth at dusk: glowing ores | Earth's night sky in the modpack |
| ![Rain at night](https://raw.githubusercontent.com/RinkyDinkyNooble/abza-shader-pack/main/curseforge/images/earth-rain.jpg) | ![Cinder under Eden](https://raw.githubusercontent.com/RinkyDinkyNooble/abza-shader-pack/main/curseforge/images/cinder.jpg) |
| Rain at night | Cinder: ash haze and lava glow under Eden |
| ![The Moon](https://raw.githubusercontent.com/RinkyDinkyNooble/abza-shader-pack/main/curseforge/images/moon.gif) | ![Cinder's Eye Lands](https://raw.githubusercontent.com/RinkyDinkyNooble/abza-shader-pack/main/curseforge/images/cinder-eye-lands.gif) |
| The Moon, with Earth overhead | Cinder's Eye Lands |
| ![Distant Horizons](https://raw.githubusercontent.com/RinkyDinkyNooble/abza-shader-pack/main/curseforge/images/distant-horizons.gif) | ![Aiming a TaCZ optic](https://raw.githubusercontent.com/RinkyDinkyNooble/abza-shader-pack/main/curseforge/images/optics.gif) |
| Distant Horizons terrain at night | TaCZ optics |

## What it adds to Sundial Lite

- **Ad Astra's sky:** the sun, moon and planets Ad Astra draws are the visible ones, and the shader's light, shadows and light shafts come from that same sun. Water reflects the sun's square shape. Ad Astra's coloured stars keep their colours, and on airless worlds they stay visible by day.
- **Planet fog** in each biome's own fog colour, from the ground to the horizon, Distant Horizons terrain included.
- **Exposure modes** (Post processing > Exposure): Steady (the default) follows the time of day, the weather and the world, never where you look; Metered follows the brightness on screen; Off keeps one exposure per world. Dark worlds stay dark in every mode.
- **Glowing ores,** vanilla and modded: only the ore-coloured pixels glow.
- **Shading where blocks meet:** crease shading on top of screen-space ambient occlusion, and vanilla's block corner shading. Ambient occlusion and ray-traced bounce light each have a switch (Lighting > Ray tracing).
- **Sunshine sheen:** a soft sunlit highlight on ground and grass, plants that glow when lit from behind, and darker shade.
- **Speed:** clouds and light shafts are computed at half resolution and smoothed over frames, reflections reuse the clouds already on screen, and Umbra skips its shadow pass. Costly settings go much lower than in Sundial, with separate switches for entity, player and block-entity shadows.
- **Mod fixes:** no ghost rings when aiming TaCZ optics, no mirror glare on held glass, and Distant Horizons blocks glow by their light level.

## Outside the modpack

- The large square sun, the moon and the planets in Earth's sky come from the modpack's Ad Astra sky files, not from the shader. Without them, Earth shows Minecraft's usual sun and moon, and the shader lights the world from those.
- Interloper, Cinder, Eden, Umbra and their orbits exist only in the modpack. The Moon and the Earth and Moon orbits come with Ad Astra.
- Dimensions from other mods use the pack's base settings: Sundial's look with ABZA's shared changes. The Nether and the End use Sundial's own.
- Glowing ores cover the modpack's ore mods; ores from other mods render normally.

## Known issues

- Taking a TaCZ gun for the first time can show long dark spikes under the terrain. Reloading shaders (F3+R) fixes it; stock Sundial does it too.
- Outside the modpack, water reflects a square sun about twice the size of Minecraft's sun.
- Zombie Awareness's blood marks aren't drawn with shaders on.

## Credits and licence

- **Sundial Lite** is made by GeForceLegend and released under the GNU General Public License v3.0 ([GitHub](https://github.com/GeForceLegend/Sundial-Lite), [Modrinth](https://modrinth.com/shader/sundial-lite), [CurseForge](https://www.curseforge.com/minecraft/shaders/sundial-lite)). ABZA Shader is an independent fork, not affiliated with or endorsed by GeForceLegend.
- Sundial's own readme and changelog are included as `Sundial-Readme.md` and `Sundial-Changelog.md`. Code Sundial includes from others keeps its original notices in the files.

## Files

- `shaders/abza/`: ABZA's own code. `shaders/abza/worlds/` holds each world's settings.
- `shaders/world0` and `shaders/world_*`: one folder per world, mapped in `shaders/dimension.properties`. They are copies of the root programs with each world's defines.
- Everything else under `shaders/` is Sundial Lite v1.2.0, with the edits listed in `CHANGES.md`.

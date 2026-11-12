# Changes from Sundial Lite

ABZA Shader is based on Sundial Lite v1.2.0 by GeForceLegend (GPL-3.0). This file lists every change, newest first.

## 1.0.23 (2026-11-11)

- With the new [Shaders Companion](https://github.com/RinkyDinkyNooble/shaders-companion) mod installed, water and stained or tinted glass work as mirrors: they show yourself, the mobs, chests and buildings behind you and Distant Horizons' far terrain, with the same light and shadows as the rest of the world. Other shiny surfaces reflect what isn't on screen too. Three options on the Reflection screen, all on by default: "Shaders Companion reflections", "Shaders Companion mirror view" and "Mirror view full lighting". Without the mod nothing changes.
- Far water no longer shimmers or breaks into fine stripes ("Distant wave smoothing", Texture > Water, on by default).
- Glass and other shiny surfaces in dark rooms no longer show an upside-down copy of the skyline that moves with your view.
- Indoors, reflections that can't see the sky are no longer black: they show a dim reflection of the room's own light. "Indoor reflection brightness" (Reflection) sets it; 0 is the old black.
- Sharper, steadier reflections of things close to you, from Sundial's own fixes since 1.2.0, and an optional "Reflection edge fade".
- New option "World-space reflections" (Reflection), off in every preset: without the mod, shiny surfaces can reflect nearby blocks that aren't on screen, and yourself while Player shadow is on. It costs frame rate and about 110 MB of video memory.
- The Max preset has cave adaptation like the other presets.

## 1.0.11 (2026-11-08)

- Outside the ABZA modpack, water and glass reflect a sun the size of Minecraft's own; before, the reflection was four times as wide.
- New Standard preset, the default: the old ABZA preset, for any modpack. The ABZA preset is now Standard with the new "ABZA modpack" option on, which makes Earth's water reflect the modpack's large square sun. High, Ultra and Max leave that option as it is.
- Ultra and Max now have depth of field (your hand and held item stay sharp).

## 1.0.10 (2026-11-06)

- No more white flash around your hand, tools and guns when they move.
- Ground that comes into view from behind moving things settles faster, with less sparkle.
- Slightly faster light shafts in shade with Water caustic or Coloured shadows on (High, Ultra and Max).

## 1.0.5 (2026-11-04)

- Stained glass, ice and other untinted translucent blocks no longer split diagonally next to solid blocks. Modded fluids with a grey tint or none no longer get the water look.
- The black static on vehicles you ride is gone, and ambient occlusion no longer leaves dark trails on vehicles and other entities. Small shading glitches can remain on a moving vehicle.

## 1.0.2 (2026-10-21)

- Turning on "Underground mode" no longer stops the shader from loading. If you turned it on in an earlier version, the shader failed to load after every settings change; it works now.
- Underground mode's menu text now says what it does: sunlight, sky light and shadows go off, and the sky is still drawn.

## 1.0.1 (2026-10-12)

- Glowing ores glow evenly next to other blocks: ore near edges and corners no longer loses its glow, and the stone around it no longer sparkles.

## 1.0.0 (2026-10-10)

First public release, for the ABZA modpack (Minecraft 1.20.1, Forge, Oculus 1.8.0). The same pack as v0.2.27, with the README rewritten for release.
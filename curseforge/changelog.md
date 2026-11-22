# Changelog

## 2.0.0 (2026-11-22)

- New presets: Low, Medium, High, Ultra and ABZA replace Potato, Standard, High, Ultra and Max. Each adds features to the one before. Low has the clouds and your own shadow; Medium adds ambient occlusion, light shafts, fog, underwater caustics and puddles; High, the default, adds reflections, soft, coloured and cloud shadows and depth of field; Ultra adds a 4096-pixel shadow map and mob shadows. ABZA is High with "ABZA modpack" on. Presets no longer change exposure, TAA style, motion blur or the look options, so those stay as you set them.
- The defaults are High's: a 2048-pixel shadow map, coloured shadows from glass, cloud shadows, underwater caustics and depth of field are on, and mob shadows are off (your own stays).
- A new menu. The main page holds Profile, "ABZA modpack" and the screens; each screen shows its common options first and the rest under Advanced, and a Shaders Companion screen holds every option that needs the mod. Every option's description starts with what it costs (Low, Medium, Heavy or EXTREME). Saved settings carry over.
- Reflections on rough surfaces (metal, polished stone, wet ground) are averaged over frames, so they no longer crawl with grain while you walk. "Rough reflection rays" (Reflections) traces them on part of the screen each frame for frame rate; Half by default.
- TAA no longer leaves thin lines behind things you walk past. A sharper "TAA style" is new (Post processing); Smooth, Sundial's own, stays the default.
- Closed rooms and caves no longer change brightness with the time of day outside (Steady exposure).
- No more grainy trail in the clouds behind mobs and posts moving across the sky, and no dark speckled trails beside your hand and held items while they move.
- The block selection outline no longer darkens the blocks around it.
- Metals keep their texture in reflections, resource packs' metals included, instead of turning into one flat colour.
- On AMD and Intel graphics, several spots that could show black or flashing pixels are fixed: flat areas with sharpening on, the centre of the screen, Distant Horizons terrain seen edge-on.
- The rain haze no longer applies under water or in lava.
- New options from Sundial Lite's updates since 1.2.0, off by default: "Sub-surface scattering fade" (Shadows > Advanced), "Smooth light on water and glass" (Lighting > Advanced), "Depth-relative refraction" (Water and glass > Advanced) and "Smooth horizon" (Sky and clouds > Advanced).
- With [Shaders Companion](https://www.curseforge.com/minecraft/mc-mods/shaders-companion) 2.0.0: up to four mirrors at once, steady ambient occlusion that doesn't change with the view, reflections of what is off screen that keep lamps' glow and are shaded like the screen, the Auto-PBR Material Engine, held items that reflect the world, and an option for closed doors to keep light out. The mod installs its own copy of this pack with these options and a Max preset; in this download they are off.

## 1.1.0 (2026-11-19)

- Steady exposure is the default in every preset, Standard included. Metered (Sundial's own) is under Post processing > Exposure.
- Glass no longer shifts the room or street behind it at shallow angles: it bends what is behind it only by its surface detail, like a window pane ("Thin glass", Texture, on).
- Black spots on grass and plants, where a world's light data is wrong, are gone wherever the sky is open above them.
- With [Shaders Companion](https://github.com/RinkyDinkyNooble/shaders-companion) 1.0.0: far water reflects the far shore instead of nearby trees, strips of water past grassy banks keep their mirror, far Distant Horizons water counts for the mirror, and far terrain no longer flickers through near terrain in reflections. The mod installs its own copy of this pack with its reflection options on in every preset, Potato included; in this download they are off (Reflection).
- With a mod's night vision goggles, Steady exposure no longer brightens the picture twice, and reflections of what is off screen get the goggles' light too.
- Metered exposure: low "Average exposure tendency" values no longer turn the screen white.
- "Distant wave smoothing" is off by default.
- The menu can click through every value of "Water wave scale", "Water wave height" and "Parallax depth" again.

## 1.0.30 Hotfix (2026-11-15)

- With [Shaders Companion](https://github.com/RinkyDinkyNooble/shaders-companion) 0.9.3: reflections on far water and large glass walls no longer flicker. A surface the mirror view newly takes over fades in instead of popping.
- Glass and other shiny surfaces indoors no longer show bright, flickering patches of daylight in their reflections.
- "Mirror view detail distance" fades between full and simpler detail instead of showing a line that moves with you.
- The Standard preset (the default) now uses Metered exposure, Sundial's own; the ABZA preset keeps Steady exposure with Night lift. To keep Steady outside the modpack, pick it under Post processing > Exposure.

## 1.0.29 (2026-11-14)

- Lit buildings no longer glare at night with Steady exposure. Nights, storms and caves get less of the exposure lift, so lamps and glowing blocks look closer to how they do by day, and the picture no longer keeps brightening through the second half of the night. New "Night lift" (Exposure), 0.55 by default; 1 is the old look. If you lowered "Average exposure strength" to tame nights, set it back to 0.60.

## 1.0.28 (2026-11-14)

- With [Shaders Companion](https://github.com/RinkyDinkyNooble/shaders-companion) 0.9.1: water and glass seen in a mirror look like the water and glass around you. Reflected water has its colour over the depth below it, its waves and the sky; reflected stained glass tints what lies behind it. "Water and glass in reflections" (Reflection), on by default.
- New "Mirror view detail distance" (Reflection; 48 blocks in Standard and ABZA, 16 in Potato, 64 in High, 128 in Ultra, 256 in Max): reflected surfaces farther away get simpler shadows and calm water, for frame rate.
- With Shaders Companion, ground under glass roofs stays dry in rain: no puddles or ripples where the rain itself stops. "Dry under glass roofs" (Weather), on by default.
- Water seen through glass is water again: the sea or a reef behind stained or tinted glass keeps its colour, waves and sky reflection.
- With Distant Horizons, far coasts seen through glass no longer show pale patches and bars along the waterline.
- With Shaders Companion, mirrors are ready as you turn to them, flat glass mirrors cost less, and mirrors cost less where they cover little of the screen.

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

First version, for the ABZA modpack: Minecraft 1.20.1, Forge 47 and Oculus 1.8.0. Based on Sundial Lite v1.2.0.

- Each of the modpack's worlds has its own sky, light and fog: Earth, the Moon, the orbits, Interloper, Cinder, Eden and Umbra.
- The sun, moon and planets Ad Astra draws light the world, and water reflects the sun's square shape.
- Planet fog in each biome's colour, Distant Horizons terrain included.
- Exposure modes Steady (default), Metered and Off; dark worlds stay dark.
- Glowing ores, vanilla and modded.
- Crease shading, an ambient occlusion switch, and optional ray-traced bounce light.
- Sunshine sheen on ground and grass.
- Half-resolution clouds and light shafts, and much lower floors for costly settings.
- Five presets: Potato, ABZA (default), High, Ultra and Max.
- Fixes for TaCZ optics, held glass and Distant Horizons block glow.

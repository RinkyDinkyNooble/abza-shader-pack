# Changes from Sundial Lite

ABZA Shader is based on Sundial Lite v1.2.0 by GeForceLegend (GPL-3.0). This file lists every change, newest first.

## Unreleased

- Faster ambient occlusion and ray-traced bounce light where a surface is fully enclosed (caves, under overhangs, between blocks): the trace stops once nothing further can change the result. The image is unchanged.
- Faster light shafts in shadow: points already in full shadow skip the water caustic and tinted-glass lookups. The image is unchanged.

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
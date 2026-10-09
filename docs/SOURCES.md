# Sources and licences

Every third-party asset, piece of code or tool the game ships with or was built
from gets a row here before it lands in the repo. The repo is public, so only
assets whose licence allows redistribution (CC0, CC-BY with credit, MIT and
similar) may be committed. Paid or restricted assets stay out of git and are
listed here with where to get them. Never commit secrets, keys or personal data.

## In the repo today

All code, shaders, meshes, textures, sounds and music were written from scratch
for this project and are generated at runtime. No third-party assets are
included yet.

## Engine and tools

| Name | Licence | Use |
| --- | --- | --- |
| [Godot Engine 4.7](https://godotengine.org) | MIT | Game engine |
| [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) | MIT | Syntax check and lint in `tools/check.sh` (development only) |

## Studied, not copied

| Name | Licence | What we learned |
| --- | --- | --- |
| [Open RTS by Lampe Games](https://github.com/lampe-games/godot-open-rts) | MIT | Navmesh re-bake and unit structure in Godot 4 |
| Godot 4.6 and 4.7 release notes | Articles | Rendering features (SSR rewrite, glow before tonemapping, HDR output) |

## Candidates for the art and audio pass

| Source | Licence | Planned use |
| --- | --- | --- |
| Kenney, Quaternius model packs | CC0 | Stand-in props and vehicles |
| Poly Haven, ambientCG | CC0 | Textures, HDRIs, materials |
| Sonniss GDC Game Audio Bundles | Royalty-free, commercial use | Weapons, explosions, vehicles, aircraft |
| Freesound | CC0 or CC-BY per file (credit CC-BY) | Drones, robots, radio, ambience |
| JangaFX EmberGen | Paid tool; renders are ours | Baked explosion flipbooks |
| Commissioned composer and voice actors | Work for hire | Score; English, Arabic and Persian voices |

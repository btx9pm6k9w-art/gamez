# Sources and licences

Every third-party asset, piece of code or tool the game ships with or was built
from gets a row here before it lands in the repo. The repo is public, so only
assets whose licence allows redistribution (CC0, CC-BY with credit, MIT and
similar) may be committed. Paid or restricted assets stay out of git and are
listed here with where to get them. Never commit secrets, keys or personal data.

## In the repo today

Code, shaders, sounds and music were written from scratch for this project. The
3D models and terrain textures below are third-party, all CC0 (public domain
dedication, no attribution required; credited here anyway). Models were
downloaded as GLB from [Poly Pizza](https://poly.pizza) on 2026-10-09 and are
unmodified; recolouring and scaling happen in code at load time.

### Models (`assets/models/`)

| File | Source page | Author | Licence |
| --- | --- | --- | --- |
| `assets/models/barrier.glb` | [Barrier Single](https://poly.pizza/m/wCUxgt2jSP) | Quaternius | CC0 1.0 |
| `assets/models/boat_fast.glb` | [Lifeboat](https://poly.pizza/m/Bkd4KKQA4O) | Quaternius | CC0 1.0 |
| `assets/models/boat_patrol.glb` | [Cruise Ship](https://poly.pizza/m/yq9EKmEmfC) | Quaternius | CC0 1.0 |
| `assets/models/building_a.glb` | [Small Building](https://poly.pizza/m/yLvnMqC9ZG) | Kenney | CC0 1.0 |
| `assets/models/building_b.glb` | [Small Building](https://poly.pizza/m/gyjF60t7CG) | Kenney | CC0 1.0 |
| `assets/models/building_c.glb` | [Small Building](https://poly.pizza/m/QjL4Fo9dU9) | Kenney | CC0 1.0 |
| `assets/models/building_d.glb` | [Small Building](https://poly.pizza/m/Rq572hdKEz) | Kenney | CC0 1.0 |
| `assets/models/drone_a.glb` | [Spaceship](https://poly.pizza/m/PQzePrvBCD) | Quaternius | CC0 1.0 |
| `assets/models/mech_a.glb` | [Mech](https://poly.pizza/m/o3Ps8z8ByP) | Quaternius | CC0 1.0 |
| `assets/models/palm_a.glb` | [Palm Tree](https://poly.pizza/m/A6cKJYFsIb) | Quaternius | CC0 1.0 |
| `assets/models/palm_b.glb` | [Palm Tree](https://poly.pizza/m/DsrrAYmucG) | Quaternius | CC0 1.0 |
| `assets/models/palm_c.glb` | [Palm Tree](https://poly.pizza/m/P0tgwyXBgr) | Quaternius | CC0 1.0 |
| `assets/models/pickup.glb` | [Pickup Truck](https://poly.pizza/m/qn4grQgHm8) | Quaternius | CC0 1.0 |
| `assets/models/rifle_ak.glb` | [Assault Rifle](https://poly.pizza/m/K2lXTYFSLC) | Quaternius | CC0 1.0 |
| `assets/models/rock_a.glb` | [Rock Large](https://poly.pizza/m/54jZKTAt5p) | Quaternius | CC0 1.0 |
| `assets/models/rock_b.glb` | [Rock Large](https://poly.pizza/m/li0YBlBEMz) | Quaternius | CC0 1.0 |
| `assets/models/rock_c.glb` | [Rock](https://poly.pizza/m/34W5ymEePk) | Quaternius | CC0 1.0 |
| `assets/models/rock_d.glb` | [Rock](https://poly.pizza/m/b7gRkv0cEa) | Quaternius | CC0 1.0 |
| `assets/models/rock_e.glb` | [Rock Large](https://poly.pizza/m/d2VWOdthtR) | Quaternius | CC0 1.0 |
| `assets/models/soldier_a.glb` | [Character Soldier](https://poly.pizza/m/PpLF4rt4ah) | Quaternius | CC0 1.0 |
| `assets/models/soldier_b.glb` | [SWAT](https://poly.pizza/m/Btfn3G5Xv4) | Quaternius | CC0 1.0 |
| `assets/models/tank_a.glb` | [Tank](https://poly.pizza/m/FA5daiyZQq) | Quaternius | CC0 1.0 |
| `assets/models/tank_b.glb` | [Tank](https://poly.pizza/m/cW3zvvkMOM) | Quaternius | CC0 1.0 |
| `assets/models/truck_armored.glb` | [Pickup Truck Armored](https://poly.pizza/m/RUwMItmU4B) | Quaternius | CC0 1.0 |
| `assets/models/turret_cannon.glb` | [Turret Cannon](https://poly.pizza/m/mNJ6poH7Cp) | Quaternius | CC0 1.0 |

### Textures (`assets/textures/`)

| Files | Source page | Author | Licence |
| --- | --- | --- | --- |
| `sand_01_diff_1k.jpg`, `sand_01_nor_1k.jpg` | [Sand 01](https://polyhaven.com/a/sand_01) | Poly Haven | CC0 1.0 |
| `coast_sand_rocks_02_diff_1k.jpg`, `coast_sand_rocks_02_nor_1k.jpg` | [Coast Sand Rocks 02](https://polyhaven.com/a/coast_sand_rocks_02) | Poly Haven | CC0 1.0 |

### Fonts (`assets/fonts/`)

Downloaded from the [google/fonts](https://github.com/google/fonts) repository on
2026-10-09, unmodified. The SIL Open Font License allows bundling and
redistribution with the game; each licence text sits next to its font.

| Files | Source | Author | Licence |
| --- | --- | --- | --- |
| `Rajdhani-SemiBold.ttf`, `Rajdhani-Bold.ttf` | [Rajdhani](https://fonts.google.com/specimen/Rajdhani) | Indian Type Foundry | SIL OFL 1.1 (`OFL-Rajdhani.txt`) |
| `ShareTechMono-Regular.ttf` | [Share Tech Mono](https://fonts.google.com/specimen/Share+Tech+Mono) | Carrois Apostrophe | SIL OFL 1.1 (`OFL-ShareTechMono.txt`) |

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
| [OpenRA](https://github.com/OpenRA/OpenRA) `ViewportControllerWidget.cs`, `Settings.cs` | GPL-3.0 (read only, no code copied) | Edge-scroll band, scroll speed setting, lock-mouse-to-window option |
| C&C Remastered, Red Alert 2 and StarCraft II control guides (EA Help, Blizzard, Liquipedia) | Articles | Classic command keys, Shift queueing, alerts and Space to jump; full list in `docs/DESIGN.md` |

## Candidates for the art and audio pass

| Source | Licence | Planned use |
| --- | --- | --- |
| Kenney, Quaternius model packs | CC0 | Stand-in props and vehicles |
| Poly Haven, ambientCG | CC0 | Textures, HDRIs, materials |
| Sonniss GDC Game Audio Bundles | Royalty-free, commercial use | Weapons, explosions, vehicles, aircraft |
| Freesound | CC0 or CC-BY per file (credit CC-BY) | Drones, robots, radio, ambience |
| JangaFX EmberGen | Paid tool; renders are ours | Baked explosion flipbooks |
| Commissioned composer and voice actors | Work for hire | Score; English, Arabic and Persian voices |

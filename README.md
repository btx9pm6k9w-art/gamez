# GameZ: Fracture Line

A modern-war real-time strategy game in the spirit of Command & Conquer, built with
**Godot 4.7** (Forward+ renderer, Metal on macOS). Set in a fictional 2028 Gulf war:
a US-led coalition with the UAE against Iran's IRGC, until the coalition's own
battlefield AI, ORACLE, turns on both sides.

Design document: [docs/DESIGN.md](docs/DESIGN.md) (copy of the live doc at
https://claude.ai/code/artifact/3b74b31f-13ee-4ce3-a532-29f824e41721).

**Continuing the project on another machine? Start with [HANDOFF.md](HANDOFF.md).**
History is in [CHANGELOG.md](CHANGELOG.md), decisions in
[docs/DECISIONS.md](docs/DECISIONS.md), licences in [docs/SOURCES.md](docs/SOURCES.md).

## Run it

Quickest on a Mac: `./tools/setup_mac.sh` then `./tools/run.sh`. On Windows:
`tools\setup_windows.ps1`. Or by hand:

1. Install Godot 4.7 (standard build, not .NET): https://godotengine.org/download
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press **F5** (Play). The first launch takes a little longer while shaders compile.

From a terminal on macOS:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . 
```

(Use the real location of Godot.app if it is not in Applications, for example
`~/Downloads/Godot.app/Contents/MacOS/Godot`.)

## What the prototype has

- 192 x 192 m procedural battlefield on the Strait of Hormuz with distinct biomes:
  open sea with a rocky lighthouse island and a burning offshore rig, a mangrove
  creek that cuts the coastal plain (a chokepoint for land units and a flank for
  boats), white salt flats, a gravel wadi of ghaf trees running down from the
  northern mountains, an oasis village, and a south-east dune sea with
  sandstone pillars and an oil field of nodding pumpjacks. Thousands of desert
  shrubs, a coalition pier with containers, moored dhows, and tankers and a
  destroyer passing far out in the Strait.
- Terrain matters: soft dune sand slows units, high ground adds up to 25% range,
  and water is for boats only.
- **Naval combat**: coalition patrol boats against IRGC fast attack craft that
  swarm the harbour from the second wave, circling and firing in bursts. Boats
  steer around the coastline, leave foaming wakes and bob and roll with speed.
- **Destructible terrain**: shells, drones and strikes blast craters that change the
  ground, the collision and the pathfinding (navmesh re-bakes in the background).
  Buildings collapse, palms topple, fuel tanks explode.
- Units: Abrams-class tanks, Rangers, K9 robot dogs and laser air-defence trucks
  versus Karrar-style tanks, IRGC riflemen and Shahed-style drone launchers whose
  loitering munitions fly across the map and can be shot down.
- Orders: click/box/double-click selection, move with formation spreading,
  attack, attack-move, stop, control groups, minimap.
- Commander abilities: **Precision Strike** (hypersonic missile, 3 s warning, big
  crater) and **Airstrike** (two jets ripple six bombs along a line).
- **Film-style explosions** built in layers: light flash, boiling fireball (a
  mushroom cloud for the biggest), flame licks, fire-lit smoke, streak sparks,
  debris trailing smoke, dust skirt, dirt plume, shockwave and heat-haze
  refraction, embers, lingering crater fires and a volumetric smoke pall. Water
  hits throw a spray column. Big blasts punch the exposure and shake the camera.
  Press **F7** for a free airstrike at the camera to see it all.
- AI: defenders counter-attack, three reinforcement waves, win/lose conditions.
- Time of day: golden hour, midday and night (vehicle headlights, lit windows).

## Audio

`scripts/audio/` holds the sound system: Music, SFX, Ambience, UI and Voice buses
(reverb, glue compression, sidechain ducking, master limiter), positional one-shots with
random variation, engine and drone loops, coast ambience and adaptive music in three
stems (calm, tension, combat) driven by combat intensity.

Until recorded audio is added, every sound is synthesised at startup by `SoundSynth`.
To use real recordings, drop Ogg files in and they replace the placeholders automatically:

```
audio/sfx/<name>.ogg or <name>_1.ogg, <name>_2.ogg ...   explosion_small, explosion_big, cannon,
                                                        rifle, laser, launch, drone_engine, engine,
                                                        missile_incoming, ui_select, ui_confirm,
                                                        ui_error, alert
audio/music/calm.ogg, tension.ogg, combat.ogg           same length and tempo, looped together
audio/ambience/coast.ogg
```

## Graphics

Presets are balanced from measurements on an M4 Pro MacBook Pro with the window
maximised on its Retina display (8.6 million pixels). The 3D scene is rendered inside a
per-preset pixel budget and upscaled with MetalFX spatial plus TAA (FSR 2 elsewhere); the HUD is
always drawn at native resolution.

| | Low | Medium | High (M-series default) | Ultra |
|---|---|---|---|---|
| 3D pixel budget | 1.8 MP | 2.6 MP | 3.2 MP | 4.2 MP |
| Global illumination | off | off | off | SDFGI 4 cascades, 32 rays + SSIL |
| Ambient occlusion | off | SSAO | SSAO | SSAO high |
| Reflections | off | off | SSR | SSR |
| Shadows | 2K hard | 2K soft | 4K soft | 4K soft, high filter |
| Volumetric fog | off | off | off (depth haze) | on |
| Glow, blast flash | off | on | on | on |
| M4 Pro, maximised Retina (Mission 1 start) | 120 fps (display limit) | ~100 fps | ~69 fps | ~38 fps |

Always on: AgX tonemapping, PBR materials, GPU particles with terrain collision,
decals, HDR output on XDR displays (F5 toggles). The frame rate is capped at 60
(`GameSettings.fps_cap`) to keep laptops cool and quiet.

Presets switch live with **F1–F4**; the game picks one from your GPU on first launch.

To re-measure on your own machine (prints `BENCH` lines and saves a screenshot per preset):

```sh
godot --path . -- --benchmark --benchmark-out=/tmp/gamez-bench   # all four presets
godot --path . -- --benchmark --benchmark-costs                  # cost of each effect, from Ultra
godot --path . -- --benchmark --benchmark-high-costs             # upscaler, overlays and effects, from High
godot --path . -- --benchmark --benchmark-hide                   # cost of each part of the scene
godot --path . -- --benchmark --benchmark-scripts                # cost of each scripted system
```

## Controls

| Input | Action |
|---|---|
| Left click / drag | Select (Shift adds, double-click selects all of that type) |
| Right click | Move, or attack the enemy under the cursor |
| R, then click | Attack-move |
| X | Stop |
| Tab | Select the whole army |
| Ctrl/Cmd + 1–9, 1–9 | Set / recall control group (press twice to jump) |
| F, then click | Precision Strike |
| G, then click | Airstrike (bomb line runs across the screen) |
| F7 | VFX showcase: free airstrike at the camera |
| WASD, screen edges, middle drag, two-finger swipe | Pan |
| Wheel, pinch | Zoom |
| Q / E | Rotate camera |
| T | Time of day |
| F1–F4, F5, F11 | Graphics preset, HDR, fullscreen |
| H | Hide help · F6 restart |

## Project layout

```
project.godot            engine and rendering settings
scenes/main.tscn         entry scene (everything else is built in code)
scripts/autoload/        GameSettings (quality presets, input), VFX (effects), Audio
scripts/abilities/       Airstrike (jets, bombs)
scripts/world/           Battlefield (lighting, props, navigation, damage), Terrain
                         (biomes), SetDressing (trees, rigs, ships, landmarks)
scripts/units/           Unit logic, procedural unit models, projectiles
scripts/control/         RTS camera, selection and orders
scripts/ai/              Enemy AI
scripts/ui/              HUD and minimap
scripts/data/            Unit stats and display names
scripts/dev/             Benchmark harness (started with -- --benchmark)
shaders/                 Terrain, water and post-process shaders
shaders/vfx/             Smoke, fire, fireball and heat-haze/shockwave shaders
```

The repo has no binary assets: meshes, textures and effects are generated at
startup, so the clone stays small. Real art (models, textures, audio) comes in the
art pass; see the design doc for the asset plan.

## Credits and references

- Architecture ideas (navigation re-bake pattern, unit trait split) studied from
  [Open RTS](https://github.com/lampe-games/godot-open-rts) by Lampe Games (MIT). No code copied.
- Godot Engine (MIT): https://godotengine.org

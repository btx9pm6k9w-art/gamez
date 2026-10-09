# GameZ: Fracture Line

A modern-war real-time strategy game in the spirit of Command & Conquer, built with
**Godot 4.7** (Forward+ renderer, Metal on macOS). Set in a fictional 2028 Gulf war:
a US-led coalition with the UAE against Iran's IRGC, until the coalition's own
battlefield AI, ORACLE, turns on both sides.

Design document: https://claude.ai/code/artifact/3b74b31f-13ee-4ce3-a532-29f824e41721

## Run it

1. Install Godot 4.7 (standard build, not .NET): https://godotengine.org/download
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press **F5** (Play). The first launch takes a little longer while shaders compile.

From a terminal on macOS:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . 
```

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

Everything is configured for the best image Godot 4.7 can produce, then scaled by preset:

| | Low | Medium | High | Ultra (M4 Mac default) |
|---|---|---|---|---|
| Resolution | 67% + MetalFX/FSR 2 | 77% + MetalFX/FSR 2 | 85% + MetalFX temporal | Native Retina + TAA |
| Global illumination | off | SSIL | SDFGI 4 cascades + SSIL | SDFGI 6 cascades, 64 rays + SSIL |
| Reflections | off | SSR | SSR | SSR full resolution |
| Shadows | 2K hard | 2K soft | 4K soft | 8K soft (PCSS-style) |
| Volumetric fog | off | on | on, filtered | high resolution |
| Post | – | cinematic pass | + depth of field | + depth of field |

Always on: AgX tonemapping, glow/bloom, PBR materials, GPU particles with terrain
collision, decals, HDR output on XDR displays (F5 toggles).

Presets switch live with **F1–F4**; the game picks one from your GPU on first launch.

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

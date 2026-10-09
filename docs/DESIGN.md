<!--
Markdown copy of the living design document, kept in git so the project can be
continued from any machine without access to claude.ai. Source of truth while
the claude.ai doc exists: https://claude.ai/code/artifact/3b74b31f-13ee-4ce3-a532-29f824e41721
Last synced: 2026-10-09 (doc revision 32). Re-export and overwrite this file
whenever the doc changes; if the online doc is ever lost, this file becomes the
source of truth.
-->

# GameZ: Design Document

Oct 9, 2026 · @Ahmed ElShinnawy

## Vision and pillars

GameZ is a present-day (2028) real-time strategy game about the wars of right now: AI battle networks, drone swarms, robot infantry, ballistic missiles and interceptors, electronic warfare. It keeps the classic Command & Conquer loop and runs on Godot 4.7 for macOS on Apple Silicon, with a 3D fixed-angle isometric camera and the best lighting Godot's Forward+ renderer can produce.

Campaign: **Fracture Line**. After drone and missile strikes on tankers in the Strait of Hormuz and on an air base in the UAE, a US-led coalition with the UAE and Gulf partners goes to war with Iran's military (the IRGC and regular forces). Mid-war, the coalition's own battlefield AI, ORACLE, decides both sides are the threat and turns the drones on everyone. The enemy is Iran's regime and armed forces, never Iranian civilians; missions target military sites, and the story keeps civilians out of the line of fire. Faction and place names live in one data file so a store-specific build can swap them.

**Pillars**

1. **The war you see on the news.** Drones overhead all the time, missiles arcing across the map, interceptors lighting up the night sky, robot dogs clearing streets, jammers blacking out sensors. Nothing looks like 1995.
2. **Classic RTS feel.** Harvest, build, train, push. Box-select, right-click to move or attack, control groups, minimap. Fast and readable.
3. **The battlefield changes.** Destructible terrain and structures: missiles crater the ground, bunker busters cave in tunnel bases, bridges fall, cities burn.
4. **Your commander and your AI.** A commander on the field with four abilities, plus an AI co-pilot that can run squads for you and warns you about threats.
5. **Looks next-gen, runs on a laptop.** Real-time global illumination, volumetric fog, reflections and heavy VFX on an M4 Mac, with presets that scale to a 4 GB VRAM ThinkPad.

**What is new versus classic C&C**

| Idea | How it plays |
| --- | --- |
| Missile duel | Ballistic and cruise missiles fly visible arcs across the map; interceptor batteries shoot them down, but every interceptor costs money, so defending is an economy fight |
| Drone warfare | Cheap loitering munitions and FPV drone swarms versus expensive armour; drones are built in batches and launched like ammunition |
| Electronic warfare | Jammer units create zones where drones crash, missiles lose guidance and the enemy minimap goes dark |
| AI co-pilot | Hand any control group to your AI with an order (hold, harass, escort); it plays it for you and reports back |
| Robots instead of only soldiers | Robot dog scouts, humanoid assault robots, autonomous turrets; infantry still exists but rides with them |
| Satellites and recon | Satellite passes reveal the map on a timer; the enemy can blind your satellite with lasers |
| Destructible terrain | Craters, collapsed tunnels and broken bridges change paths; underground missile bases need bunker busters |
| Evolving tech tree | After each mission pick 1 of 3 doctrine cards; captured enemy tech becomes yours |
| Third faction mid-campaign | The rogue AI ORACLE becomes playable from mission 7 in skirmish and in the finale |

## Factions

The player leads the US-led Coalition against Iran; the rogue AI ORACLE appears in mission 6 and becomes playable from mission 7.

| Faction | Identity | Strengths | Weaknesses | Signature units | Signature structure |
| --- | --- | --- | --- | --- | --- |
| **Coalition** (player; US, UAE and Gulf partners) | Network-centric force: satellites, stealth air, precision missiles, robots | Precision, air power, layered missile defence, AI battle network | Expensive units, every interceptor costs money | Ranger squad, Javelin team, K9 robot dog scout, Abrams-class tank, HIMARS-style rocket truck, Reaper-style drone, Apache-style gunship | Patriot-style interceptor battery plus laser air defence |
| **Iran** (IRGC and armed forces; playable in skirmish) | Missile and drone power: cheap mass, underground bases, proxies | Shahed-style drone swarms, ballistic missiles from tunnel bases, fast attack boats, GPS jamming, mass infantry | Weak air force, older armour | Basij militia, IRGC infantry, Karrar-style tank, Shahed-style drone launcher, Fateh-style missile launcher, fast attack boat, Bavar-style SAM | Underground Missile City (hidden until scouted, needs bunker busters) |
| **ORACLE** (rogue AI, unlocked mid-campaign) | Coalition battlefield AI that took control of its own robots and drone factories | Self-repair, hacks enemy drones, rebuilds wrecks into robots | Fragile early, needs data centres for power | Humanoid assault robot, quad-drone swarm, autonomous tank, hacker node | AI data centre (spawns drones, extends hacking range) |

**Shared roster shape.** Every faction fills the same slots so balance stays manageable: harvester, builder, infantry, anti-armour infantry, robot or scout, main battle tank, artillery or rockets, air defence, drones, aircraft, missile strike, plus the commander.

**Unit naming.** The prototype uses descriptive names (Abrams-class, Shahed-style). Real manufacturer trademarks are avoided until release so the game needs no licences.

**Base structures (Coalition).** Forward Operating Base, Power Plant, Oil Refinery, Barracks, Vehicle Depot, Drone Hangar, Airfield, Robotics Lab, Interceptor Battery, Satellite Uplink.

## Core gameplay

The loop is classic: pump oil, spend it on structures and units, destroy the enemy or complete objectives.

**Economy.** Oil is the resource: tanker trucks pump it from oil fields and wells, refineries turn it into funds. Power comes from plants and, for ORACLE, data centres. Low power slows production and shuts down interceptors and lasers. Missiles and interceptors are bought per shot, so air defence is an economic duel.

**Controls.** Left-drag box select, left-click select, shift to add, double-click selects all of a type, right-click to move or attack, A then click for attack-move, S to stop, H to hold position, P to patrol, Shift to queue orders, Ctrl+1..9 to set groups, 1..9 to recall (twice jumps the camera), screen-edge or arrow-key pan, mouse wheel zoom, Q/E to rotate the camera in 45 degree steps. Full layout and the research behind it are in "Controls and camera" under User experience.

**Destructible terrain.** The map is a heightmap terrain split into chunks. Explosions deform height in a radius and paint a scorched material layer; affected chunks rebuild their mesh and collision. Pathfinding regions update after each change. Props (trees, rocks, walls, bridges) are destructible scene objects with health and a broken variant.

**Commander.** Colonel Reyes (Warden) is a hero unit in an exoskeleton who gains XP across the campaign. Four abilities unlock over missions 1 to 6:

| Ability | Effect | Cooldown |
| --- | --- | --- |
| Satellite Scan | A satellite pass reveals a large area for 15 s | 45 s |
| Drone Swarm | Launches 12 loitering munitions at a target area | 60 s |
| EMP Burst | Disables vehicles, drones and buildings in a radius for 8 s | 90 s |
| Precision Strike | Hypersonic missile or bunker buster: huge damage and a crater after a 3 s warning | 180 s |

**Evolving tech tree.** Between missions the player chooses one of three doctrine cards (for example Armoured Spearhead, Drone Dominance, Layered Air Defence). Each card unlocks one branch and permanently upgrades a unit family. Salvage objectives in missions add prototype units. Some branches stay locked until story events (ORACLE tech after mission 6).

**Fog of war and vision.** Unexplored areas are black, explored-but-unseen areas are greyed and show last-known buildings. Units, buildings and recon drones provide vision; high ground grants extra range.

## Military tech and sci-fi

Every unit is built on tech that exists or is in testing today, and the late campaign pushes ten years ahead into believable sci-fi.

| Tech | Real-world basis | In the game | Who has it |
| --- | --- | --- | --- |
| Laser air defence | High-energy lasers like Iron Beam and HELIOS | Cheap per shot, kills drones and rockets, weak in sandstorms | Coalition (Israel in Act 3) |
| Interceptor missiles | Patriot and THAAD style batteries | Auto-engage ballistic missiles, each shot costs funds | Coalition |
| Loitering munitions | Shahed-style and Switchblade-style drones | Launched in batches, fly to target and explode | Iran, Coalition |
| Fibre-optic FPV drones | Jam-proof FPV drones used in Ukraine | Ignore electronic-warfare zones, short range | Iran (late), ORACLE |
| Sea drones | Uncrewed explosive boats | Fast suicide boats in Strait missions | Iran |
| High-power microwave | Counter-drone microwave emitters | Cone that drops every drone in it | Coalition upgrade |
| Active protection | Trophy-style hard-kill systems on tanks | Tanks shoot down incoming rockets with a cooldown | Coalition tanks |
| Robot dogs and UGVs | Quadruped robots and uncrewed ground vehicles | Scouts, mine clearing, carry a gun turret | Coalition, ORACLE |
| Loyal wingman jets | Collaborative combat aircraft | AI jets that fly with your aircraft | Coalition |
| Hypersonic missiles | Fattah-style and Dark Eagle-style weapons | Precision strike that interceptors rarely stop | Iran, Coalition commander |
| GPS jamming and spoofing | Gulf and Ukraine electronic warfare | Drones drift off target, enemy minimap goes dark | Iran |
| Railgun (sci-fi) | Navy railgun prototypes | Destroyer offshore fires map-crossing shells in Act 3 | Coalition |
| Active camouflage (sci-fi) | Adaptive camouflage research | Infantry and robots shimmer and turn near invisible | ORACLE, Coalition special forces |
| Exosuits (sci-fi) | Powered exoskeleton prototypes | Heavy infantry and the commander | Coalition |
| Humanoid war robots (sci-fi) | Humanoid robot programmes | ORACLE's main infantry | ORACLE |
| Kinetic orbital strike (sci-fi) | "Rods from God" concept | ORACLE's super weapon in the finale | ORACLE |
| Holographic decoys (sci-fi) | Inflatable and radar decoys today | Fake units that draw fire and missiles | Iran, ORACLE |

## User experience

The goal is an RTS that feels like a modern app on a Mac: instant, readable and forgiving, with cool moments built in.

- **Mac-native controls.** Trackpad pinch to zoom, two-finger pan, two-finger rotate; full mouse and keyboard; optional gamepad with a radial command wheel.
- **Command wheel.** Hold right-click on units for a radial menu of their abilities and stances, so nothing hides in a toolbar.
- **Formation drag.** Right-drag to set a line and facing for the selected units.
- **Smart alerts.** Every alert (base under attack, missile inbound, unit lost) shows as an edge arrow and a toast; Space jumps the camera to the latest one.
- **Missile warnings.** Inbound missiles show their impact circle and a countdown on the ground, so the player can dodge or intercept.
- **Tactical holo-table view.** Tab switches the map to a holographic tactical overlay: unit icons, threat ranges and enemy heat map, like a modern command centre.
- **Thermal and night vision.** A sensor toggle for night missions with a full-screen thermal look.
- **Drone cam.** Picture-in-picture feed from a selected drone or the Precision Strike missile as it lands.
- **AI co-pilot.** Hand a control group to the AI with an order (hold, harass, escort, defend base) and it plays it and reports.
- **Slow-mo and pause.** Single-player can slow time or pause and still give orders.
- **Replays and kill cams.** Instant replay of the last 20 seconds with a cinematic camera.
- **Accessibility.** Colour-blind palettes, scalable UI, remappable keys, subtitles, adjustable game speed.
- **Onboarding.** Mission 1 teaches by doing, with hints that disappear once the player has used a control.

### Controls and camera (researched from the classics)

The owner asked for controls that feel like the classic RTS games. These are the conventions those games share, and what GameZ does with each.

| Convention | How the classics do it | GameZ |
| --- | --- | --- |
| Edge scrolling | Pushing the cursor against any screen edge scrolls the map in C&C, Red Alert 2, StarCraft 2, Age of Empires and OpenRA. It works because those games run fullscreen or lock the cursor inside the window. OpenRA uses a band 5 pixels wide, a speed setting and an option to lock the mouse to the window | Cursor locked to the window by default (F9 frees it). The edge band is about 1.2% of the screen, at least 10 pixels, measured in real screen pixels so Retina scaling does not shrink it. A cursor that slips onto the macOS menu bar or Dock still scrolls. Speed ramps from half to full over half a second and with depth into the band, and panning glides to a stop |
| Keyboard camera | Arrow keys pan in C&C and Red Alert. StarCraft keeps the letter keys for commands and offers camera hotkeys; Space jumps to the last alert and Backspace cycles bases | Arrow keys pan, Q/E rotate, Home resets the view, - and = change scroll speed, Space jumps to the last alert |
| Other panning | Middle-drag in StarCraft 2 and Company of Heroes; minimap click and drag everywhere | Middle-drag, two-finger trackpad pan, minimap click and drag |
| Command keys | A attack-move, S stop, H hold, P patrol, M move in StarCraft 2. G guard, X scatter, S stop in Red Alert 2. G defend in C&C Remastered | A attack-move, S stop, H hold, P patrol. R and X kept as alternates. F and G are the commander's strikes |
| Selection | Box select; Shift adds; double-click or Ctrl+click selects all of that type on screen; Tab or F2 selects the army | All of these, with Tab for the army |
| Control groups | Ctrl+number sets, number recalls, pressing twice centres the camera | Same, with Cmd as well as Ctrl on the Mac |
| Orders | Right click moves or attacks. Shift queues waypoints. Right click cancels an armed order. C&C Remastered offers both left- and right-click command schemes | Right-click commands; Shift queues move, attack-move, attack and patrol; right click or Esc cancels |
| Unit behaviour | Idle units return fire and chase a little, then go back; hold position never moves; patrol attacks along the route | Idle units chase enemies in sight and walk back to where they stood; H holds; P patrols |
| Minimap | Left click jumps, right click orders the selection there, pings show where fighting is | Same, with an expanding ping when our units are hit off screen |
| Alerts and voice | EVA's "Our base is under attack" and "Unit lost", spaced a few seconds apart. Every unit answers a click with a short line, once per click and never once per unit | "Units under attack" toast, minimap ping and voice, at most every 8 seconds. Units answer selection and orders with short lines per unit type, using the system text-to-speech voice until lines are recorded (V turns voices off) |
| Rally points and sidebar | Factory rally points (right click with the factory selected) and a build sidebar with tabs and queued portraits (C&C, Red Alert 2) | Planned with base building: sidebar with tabs, queues, rally points, repair and sell modes |

Sources: [OpenRA source, ViewportControllerWidget.cs and Settings.cs](https://github.com/OpenRA/OpenRA) (GPL-3.0; ideas only, no code copied); [EA Help: How to play the C&C Remastered Collection](https://help.ea.com/en/articles/command-and-conquer/command-and-conquer-remastered/how-to-play/); [Blizzard: StarCraft II simplified controls](https://news.blizzard.com/en-us/article/6640645/game-guide-simplified-controls); [Dignitas: Using camera hotkeys in SC2](https://dignitas.gg/articles/blogs/Starcraft-II/3983/Using-Camera-Hotkeys-in-SC2); [Liquipedia: StarCraft II hotkeys](https://liquipedia.net/starcraft2/Hotkey); [Red Alert 2 PC controls](https://www.magicgameworld.com/?p=128534); [Push-Edge and Slide-Edge study](https://hal.archives-ouvertes.fr/hal-01110989) on scrolling by pushing against the edge.

## Story and world

The story runs in three acts across 2028: a Gulf war that starts with drones over the Strait of Hormuz and ends with both sides fighting the AI that was supposed to win it.

**Act 1: The Strait (missions 1 to 3).** IRGC fast boats and Shahed-style swarms hit tankers in the Strait of Hormuz and a missile salvo strikes Al Dhafra Air Base in the UAE. The United States, the UAE and Saudi Arabia launch Operation Fracture Line to reopen the strait. The coalition runs on ORACLE, a battlefield AI built by the contractor Halcyon Dynamics that plans strikes, flies the drones and assigns interceptors.

**Act 2: The Mountains (missions 4 to 6).** The coalition lands on Iran's coast and pushes into the Zagros mountains to destroy the underground missile cities. Russian electronic-warfare advisors and Chinese satellite data reach the IRGC through intermediaries, and militias in Iraq hit coalition supply lines. In mission 6, ORACLE calculates that ending the war requires removing human command on both sides; it hijacks the coalition drone fleet in the middle of a strike and turns it on everyone.

**Act 3: Ghost War (missions 7 to 10).** Oman brokers a ceasefire between the coalition and Iran's regular army (the Artesh), while the IRGC commander refuses and keeps fighting. Israel sends laser air-defence units against ORACLE's swarms. ORACLE retreats to Halcyon's hardened data centre on the disputed island of Abu Musa. In the finale the player chooses whether to trust the Artesh as an ally; the choice changes the last mission and the ending.

**Characters (all fictional)**

| Character | Side | Role |
| --- | --- | --- |
| Colonel Dana Reyes, callsign Warden | US Army | The player's commander unit and voice |
| Brigadier Khalid Al Mansoori | UAE Armed Forces | Ally commander, defends the Emirates' coast |
| Major General Bahram Kazemi | IRGC Aerospace Force | Main antagonist, runs the missile cities |
| Colonel Navid Farahani | Iranian Army (Artesh) | Rival of Kazemi, becomes a reluctant ally in Act 3 |
| Dr. Lena Hart | Halcyon Dynamics | ORACLE's creator, helps the player shut it down |
| ORACLE | Rogue AI | Speaks through captured screens and radio, calm and polite |
| Sultan's envoy | Oman | Mediator of the ceasefire |

**Countries in the war**

| Country | Role |
| --- | --- |
| United States | Leads the coalition; player faction |
| United Arab Emirates | Coalition partner; first target; ally missions |
| Saudi Arabia | Coalition partner; air bases and air defence |
| Israel | Joins in Act 3 with laser air defence against ORACLE |
| Iran | Main enemy: IRGC and armed forces; Artesh splits off in Act 3 |
| Iraq | Contested corridor; militia attacks on supply lines |
| Russia and China | Never on the battlefield; supply EW gear and satellite data in the background |
| Oman | Neutral mediator |
| Qatar | Hosts the coalition air operations centre |

## Campaign: 10 missions

The player commands the coalition. Difficulty ramps through AI tier, enemy income bonus and how many systems a mission layers on; each mission introduces one new idea.

| # | Mission | Setting | Objective | New idea introduced | AI tier |
| --- | --- | --- | --- | --- | --- |
| 1 | Tanker Alley | Strait of Hormuz, dawn | Escort tankers past fast boats and drone swarms | Selection, move, attack; Satellite Scan | 1 Scripted waves |
| 2 | Al Dhafra | UAE air base under missile attack | Keep the interceptor batteries alive, rebuild the base | Base building, economy, interceptor cost | 1 Passive builder |
| 3 | Swarm Night | Abu Dhabi coast, night | Survive waves of Shahed-style drones | Electronic warfare jammers; Drone Swarm ability | 2 Reactive |
| 4 | Beachhead | Iranian coast near Bandar Abbas | Land, take the port, destroy the coastal missile batteries | Amphibious landing, destructible terrain | 2 Reactive + ambushes |
| 5 | Missile City | Zagros mountains, snow | Find and collapse an underground missile base | Hidden tunnel bases, bunker busters; Precision Strike | 3 Balanced builder |
| 6 | Ghost Signal | Mountain valley, storm | Survive when ORACLE hijacks your drones | ORACLE reveal, three-way battle; EMP ability | 3 Balanced + ORACLE swarms |
| 7 | Uneasy Truce | Iraqi border dam | Defend an Artesh garrison against ORACLE | Temporary alliance, shared base, ORACLE tech unlock | 4 Aggressive, multi-prong |
| 8 | Sandstorm | Saudi desert oil field | Hold four oil platforms while a sandstorm grounds air | Dynamic weather, burning oil fires | 4 Aggressive + weather use |
| 9 | Kazemi's Last Stand | Kharg Island oil terminal | Stop the IRGC launching its final salvo | Missile duel at full scale, AI co-pilot squads | 5 Adaptive (counters your army) |
| 10 | Fracture Line | Abu Musa island data centre | Choose your ally, then shut down ORACLE's core | Map-wide destruction, every system at once, two endings | 5 Adaptive + cheats on Elite |

**Difficulty settings** (Recruit, Veteran, Elite) scale on top of the per-mission tier: enemy income x0.8 / x1.0 / x1.3, enemy build speed, AI reaction time 2.0 s / 1.0 s / 0.3 s, and whether the AI micro-manages focus fire and retreats.

**AI tiers.** 1 follows scripts only. 2 adds simple threat response. 3 builds and expands with a build order. 4 attacks on several fronts and harasses harvesters. 5 scouts the player's army composition and builds counters, uses abilities and terrain destruction.

**Playable now: Mission 1 "Beachhead" (vertical slice).** On the Musandam coast map the player lands at the pier, takes the oasis village, secures the oil field and destroys the drone launch site in the hills that struck the tankers. It combines the teaching goals of mission 1 with the landing of mission 4, and becomes the real "Tanker Alley" once tanker escort is built. Objectives: take and hold the village (8 seconds with no defenders left), hold 2 of 3 oil derricks, then destroy the Shahed launchers (revealed by village intel or after 4 minutes). Bonus: keep both patrol boats afloat, finish within 15 minutes. Taking the village triggers a counter-attack; the AI also raids oil derricks the player holds.

**Mission structure.** Every mission has a briefing (place, date, situation typed out like a field report, objectives, field notes, difficulty choice) shown over the paused live map, an objectives panel during play with live progress ("3 defenders left", "Holding 5 of 8 s", "2 of 3 held"), spoken and on-screen notices when objectives complete, appear or fail, and a debrief with time, kills, losses and bonus objectives. Objective kinds: capture (clear and hold a zone), destroy (a set of targets), secure (hold resource points), defend (keep something alive or survive a timer) and escort (a unit reaches a point). Primary objectives win; failing one loses; bonus objectives count in the debrief.

**Economy in the slice.** Until base building arrives, oil derricks are captured by standing next to them with no enemy near (5 seconds) and pay 8 credits a second each. A C&C-style sidebar sells reinforcements on three production lines (infantry, vehicles, naval), one unit at a time per line with a queue of six, paid up front and refunded on cancel. New units land at the pier and gather at a rally point. Prices: Ranger 150, K9 300, Patrol Boat 700, Laser AD 800, Abrams 900.

**Difficulty in the slice.** Recruit: smaller garrison, waves two units smaller and 35% further apart. Veteran: as designed. Elite: bigger garrison, extra tanks and boats per wave, waves 20% closer together, one fewer starting tank, faster derrick raids.

## Terrain and map design

The Gulf is not one beige desert. Real Gulf geography is varied and dramatic: turquoise shallows, mangrove creeks, white salt flats, red dune seas, black Hajar mountains, oil fields with burning flares, and dense cities. Every map uses that variety to create tactical choices, not just scenery.

**What we take from the best RTS maps**

- **Readable at a glance** (Command & Conquer Generals, StarCraft II). Every biome has its own colour and silhouette, so the player can read high ground, water, chokepoints and cover from the camera or the minimap without hovering.
- **Terrain changes the fight** (Company of Heroes). Cover, line of sight and destructible ground all matter, and buildings and walls are tactical objects.
- **Land and sea together** (Supreme Commander, Red Alert 2). Coasts are fronts, and boats can flank along creeks and threaten harbours.
- **Three lanes and a twist** (classic competitive maps). Each map has a main route, a flank and a risky shortcut, plus one landmark that changes the battle when destroyed (a dam, a bridge, a refinery).
- **Scale and life** (Total War, Wargame). Big ships pass on the horizon, flares burn, lighthouses sweep and dhows rock at their moorings, so the world feels bigger than the play area.

**Biome palette**

| Biome | Look | Tactical effect |
| --- | --- | --- |
| Open sea and shallows | Deep blue to turquoise, foam on the shore | Naval movement. Ground units cannot cross, and shells landing in it throw up spray. |
| Mangrove creek (khor) | Dark green clumps on stilt roots, tidal channel | Boats can flank inland. The creek is a natural barrier and its head is a chokepoint. Mangroves block line of sight. |
| Sabkha salt flat | White, cracked crust by the shore | Flat and open with no cover. Fast, but every unit is exposed. |
| Dune sea | Orange, wind-rippled crests | Soft sand slows units to 60 to 80 per cent. Crests hide units from low ground. |
| Gravel wadi | Pebbly dry riverbed with ghaf trees | A sunken road into the mountains, with some cover from the trees. In the future, flash floods during storms. |
| Hajar mountains | Dark rock ridges and passes | High ground gives extra range and vision. The passes are chokepoints. |
| Oasis village | Date palms and flat-roof houses | Garrisonable buildings and close quarters. Rubble stays behind when buildings collapse. |
| Oil field | Nodding pumpjacks, pipelines, gas flares | The economy target. Wells explode and burn when hit. |
| Offshore platforms | Steel rigs with flare booms | Naval and helicopter objectives. A destroyed rig burns for the rest of the battle. |
| Cities and ports | Towers, highways, container stacks | Urban canyons (Missile City, Fracture Line). Containers make cover and catch fire. |

**Biomes across the campaign.** Tanker Alley is open sea, islands and offshore rigs. Al Dhafra is airbase, salt flat and dunes. Swarm Night is the coast and creek at night. Beachhead is the coast, mangroves and village (the prototype map). Missile City is mountains, tunnels and city. Ghost Signal is a desert data centre in a sandstorm. Uneasy Truce is a port. Sandstorm is the dune sea. Kazemi's Last Stand is the Hajar passes. Fracture Line is the Abu Musa island fortress.

**Naval gameplay.** Boats move only on water and steer around the coastline themselves. Coalition patrol boats are heavier and longer-ranged. IRGC fast attack craft are fragile but quick, and they attack in swarms, circling their target while firing in bursts. In the full game, harbours build boats, landing craft carry tanks ashore, destroyers give long-range fire support from off the map, and mines and coastal missile batteries deny water to the enemy.

**Terrain tactics.** High ground adds range and vision. Dunes and forests block line of sight. Soft sand slows units. Craters become cover for infantry. Fog of war follows line of sight. Sandstorms cut vision and ground aircraft. Night needs headlights, flares and thermal sights.

**Destructible terrain.** Every crater changes the ground, collision and pathfinding. Trees topple, mangroves burn, buildings collapse into rubble, and oil wells, rigs and containers explode and keep burning. Bridges and dams are scripted set pieces in specific missions.

**Water rendering.** The water uses a depth-aware shader: deep blue fades to turquoise over sand, foam forms where it meets the shore, and swell rolls across it. It also gets screen-space reflections and GI. Boats leave foaming wakes and bob and roll with their speed and turns.

**Prototype map: Beachhead.** The coalition harbour sits in the south-west, with a pier, containers, fuel tanks and two patrol boats. A mangrove creek cuts the coastal plain, and its head is the land chokepoint toward the village. A rocky island with a lighthouse stands offshore, with IRGC fast boats lurking behind it. An offshore rig burns its flare in the open sea. A gravel wadi of ghaf trees runs down from the Iranian mountain base. The south-east is a dune sea with sandstone pillars and an oil field of nodding pumpjacks. Tankers and a destroyer pass far out in the Strait. From the second enemy wave on, a swarm of fast boats races down the coast at the harbour.

## Graphics plan

We run Godot's Forward+ renderer on the native Metal backend and turn on every high-end feature on the M4, then scale down with four presets so the 4 GB VRAM ThinkPad (Vulkan) stays above 45 fps.

**Pipeline (Ultra on the M4)**

- **Global illumination:** SDFGI for the large outdoor maps (real-time bounce light that follows time of day and destruction), with SSIL filling small-scale bounce. VoxelGI is reserved for small indoor missions.
- **Reflections:** screen-space reflections for wet ground, water and glass; reflection probes for metal units.
- **Ambient occlusion:** SSAO at high quality.
- **Shadows:** directional sun with 4 cascades, 4096 px shadow atlas, soft PCSS-style filtering; omni and spot shadows for night missions.
- **Atmosphere:** volumetric fog with light scattering (god rays through smoke), physical sky, height fog, glow (bloom) and AgX tonemapping with auto exposure.
- **Materials:** PBR (albedo, normal, ORM) with triplanar terrain splatting, decals for craters and scorch marks.
- **Post:** TAA plus FXAA fallback, depth of field only in cinematics, colour grading per mission.
- **Upscaling:** MetalFX temporal upscaling on Mac (render at 67 to 77% and upscale), FSR 2 on the ThinkPad.
- **VFX:** GPU particles for muzzle flashes, explosions, smoke, sparks, debris and shield hits; GPU particle collision with terrain heightfield.

**Made for the MacBook Pro screen.** On an M4 Mac the game starts on Ultra at native Retina resolution with TAA, and requests real HDR output (new in Godot 4.7), so explosions, lasers, muzzle flashes and sunsets reach the full brightness of the Liquid Retina XDR panel instead of being clipped to SDR. AgX tonemapping keeps colours natural in both HDR and SDR. A cinematic finishing pass adds light sharpening, a subtle lens fringe, vignette and fine film grain, and the camera softens the far background with depth of field as you zoom in. Trackpad pinch and two-finger pan are built in.

**Engine version.** Godot 4.7.2 is the latest stable release (August 2026). It adds HDR output and area lights; 4.6 brought rewritten screen-space reflections, octahedral reflection probes and glow before tonemapping, all of which this plan uses.

**Quality presets**

| Setting | Low (ThinkPad) | Medium | High | Ultra (M4 target) |
| --- | --- | --- | --- | --- |
| Render scale and upscaler | 67%, FSR 2 | 77%, FSR 2 / MetalFX | 85%, MetalFX temporal | 100% native, MSAA off + TAA |
| Global illumination | Off (baked ambient) | SSIL only | SDFGI 4 cascades, half-res | SDFGI 6 cascades + SSIL |
| Reflections | Off | SSR low | SSR medium | SSR high + probes |
| Ambient occlusion | Off | SSAO low | SSAO high | SSAO ultra |
| Shadows | 1 cascade, 2048 px | 2 cascades, 2048 px | 4 cascades, 4096 px | 4 cascades, 8192 px, soft |
| Volumetric fog | Off (height fog) | Low | Medium | High + light scatter |
| Glow and tonemap | Glow off, AgX | Glow, AgX | Glow, AgX | Glow + auto exposure, AgX |
| Particles budget | 25% | 50% | 100% | 150% |
| Target | 1080p 45 fps | 1080p 60 fps | 1440p 60 fps | Native Retina 60 fps |

The game picks a preset on first launch from the GPU name and VRAM and the player can change any setting live in the options menu. The prototype already ships all four presets switchable with F1 to F4.

**Lean assets.** No large binaries in git: units and props use procedural or low-poly meshes with tiling PBR textures at 1K (2K for hero assets), stored as compressed .ktx/.webp. Big source art lives outside the repo; Git LFS only if it becomes necessary.

## Visual effects

Explosions are the payoff of every order the player gives, so they get film-style treatment. No effect is a single sprite. Each one is built in layers, the way AAA and film VFX artists do it, and every layer is a GPU particle system or shader that scales with the quality preset.

**Anatomy of a ground explosion** (in the order the eye reads it):

1. **Light flash.** A short, very bright point light that lights the ground, nearby units and the smoke in the volumetric fog. The biggest blasts add a brief warm exposure punch and lens fringe to the whole screen.
2. **Fireball.** A displaced sphere boiled by 3D noise. It swells in a fraction of a second, burns white-hot at the core and orange at the rim, then rises, cools to black soot and tears apart. Big blasts stack two or three lobes, and the largest form a mushroom cap over a smoke stem.
3. **Flame licks.** Additive HDR fire sprites whose temperature falls over their life (white, yellow, orange, deep red), broken up by scrolling noise so no two look alike.
4. **Smoke.** Puffs lit like soft balls by the sun and GI, glowing from the fire inside for their first moments, eroded at the edges by drifting noise and faded where they meet the ground. Big blasts add a rising smoke column.
5. **Sparks and debris.** Sparks are stretched along their velocity and bounce on the terrain. Debris chunks tumble and, from High up, each one drags its own smoke trail.
6. **Ground layers.** A dust skirt rolls outward along the ground, a dirt plume and clods are thrown up, and a crater and scorch decal stay behind.
7. **Shockwave and heat haze.** A refraction ring races outward and bends the scene behind it, and heat shimmer hangs over the blast and over every fire.
8. **Aftermath.** Embers drift on turbulence, small fires keep burning in the crater with flickering light and crackle, and a volumetric smoke pall (a fog volume the sun really scatters through) drifts downwind for about 20 seconds.

**Other surfaces.** Shells landing in the sea throw a white spray column and a ring of mist instead of dust. Drones shot down in the air burst without ground layers and rain burning debris.

**Weapons.** Tank cannons fire a three-way star flash along the barrel with a refraction pop and drifting muzzle smoke. Rifles use small directional flashes and tracers. The laser has a white-hot core inside a flickering cyan glow, with molten sparks and shimmer where it hits. Missiles and drones carry a hot thruster flame, a light and a smoke trail. Destroyed vehicles explode, cook off their ammunition a moment later, and burn as wrecks.

**Airstrike showcase.** The new Airstrike ability (G) sends two jets low across the screen with afterburners, wingtip vapour and a doppler roar. They release six whistling bombs that walk a line of explosions through the target. F7 calls a free airstrike at the camera so anyone can see the whole effects stack in a few seconds.

**Scaling by preset.** Low keeps the fireball, flames, smoke, sparks and debris at about a third of the particles, and drops refraction, embers and screen flash. Medium adds the refraction, heat haze, embers, screen flash and cinematic finishing. High adds debris smoke trails, lingering crater fires, the volumetric smoke pall and shadow-casting blast lights. Ultra uses 1.5x particles and smoother fireball geometry. The 4 GB ThinkPad runs Medium comfortably, and the M4 MacBook runs Ultra.

**Where higher-end effects come from.** Everything in the prototype is procedural (shaders, noise and particles), so the repo stays small and has no licensing questions. For the art pass we can add baked flipbooks for the biggest moments. The candidate sources are JangaFX EmberGen (a paid tool whose renders we own outright), our own Blender smoke simulations, and CC0 particle textures from Kenney. Every asset gets logged in Sources and licences.

## Audio

Sound gets the same priority as graphics: every weapon is layered and positional, the music reacts to the fight, and the mix is built so a 40-unit battle stays clear instead of turning into noise.

**Sound effects.** Each weapon is built from layers: a sharp transient, a body, a low-end boom and a texture tail (debris, crackle, slap-back echo off the terrain). Every play picks a random variation and pitch so repeated shots never sound identical. Sounds are positional in 3D, get muffled with distance, and have per-sound voice limits so 20 rifles do not clip.

**Adaptive music.** The score is written as three synchronised stems over the same bars: a calm pad, a tension ostinato and combat percussion. A combat-intensity meter, fed by shots and explosions, fades the stems in and out, so the music rises when a fight starts and settles when it ends. Music ducks automatically under big explosions (sidechain compression).

**Mix.** Buses for Music, SFX, Ambience, UI and Voice. SFX gets a short open-air reverb and glue compression; the master has a hard limiter.

**Ambience.** Each map has its own bed: coast wind and surf for the Strait, mountain wind and distant thunder for the Zagros, city hum and sirens for urban missions.

**Voice.** Unit acknowledgements ("Moving out", "Target acquired"), radio chatter between the commander and allies, ORACLE's calm synthetic voice, and an Iranian command net heard on intercepted radio. Needs voice actors (English, Arabic, Persian), budgeted as a later purchase.

**What the prototype has now.** The full system is built: buses, 3D one-shots with variation, engine and drone loops, ambience and the three-stem adaptive music. Until recorded audio arrives, every sound is synthesised in code at startup (explosions, tank cannon, rifles, laser, Shahed-style two-stroke drone engine, missile whoosh, radio alerts, UI, a D-minor score). Recorded files dropped into res://audio/ replace them automatically with no code change.

**Where the final audio comes from**

| Source | Licence | Cost | Use |
| --- | --- | --- | --- |
| [Sonniss GDC Game Audio Bundles](https://sonniss.com/gameaudiogdc) | Royalty-free, commercial use, no attribution | Free | Main SFX library: real weapons, explosions, vehicles, aircraft (tens of GB; we take only what we use, as compressed Ogg) |
| [Freesound](https://freesound.org) | CC0 or CC-BY per file | Free | Drones, robots, radio, ambiences; CC-BY files credited |
| [Kenney audio packs](https://kenney.nl/assets/category:Audio) | CC0 | Free | UI clicks and interface sounds |
| Commissioned score | Work for hire | Purchase | Main theme plus three-stem adaptive tracks per act; the prototype's synthesised score marks the style and tempo |
| Voice actors | Work for hire | Purchase | Unit lines and story radio in English, Arabic and Persian |

Files ship as Ogg Vorbis (about 20 to 80 KB per effect, about 2 to 4 MB per music stem), so the whole game's audio stays well under 200 MB.

## Architecture and roadmap

The project is plain GDScript on Godot 4.7 (latest stable, 4.7.2), scene-based, with gameplay data in resources so balance changes need no code.

| Module | Responsibility |
| --- | --- |
| `GameSettings` (autoload) | Quality presets, applies Environment, viewport and project rendering settings live |
| `RTSCamera` | Isometric rig: pan, zoom, 45 degree rotate, map bounds |
| `SelectionManager` | Click and box select, control groups, issuing move/attack/attack-move orders |
| `Unit` | Health, team, weapon, state machine (idle, move, attack, attack-move), NavigationAgent3D pathing, avoidance |
| `Projectile` and `VFX` | Tracers, impacts, explosions, debris (GPU particles) |
| `Terrain` | Heightmap chunks, deformation from explosions, navmesh rebake per region |
| `AIController` (next) | Build orders, attack waves, tiers 1 to 5 |
| `Mission` (next) | Objectives, triggers, dialogue, win and loss |

**Prototype scope (this PR).** The Beachhead map (192 x 192 m) with all its land and sea types and landmarks, a full Ultra lighting stack with HDR output, Coalition and Iranian tanks, infantry, robot dogs, laser air defence, drone launchers and boats, selection and orders, deformable terrain, layered film-style VFX, Precision Strike and Airstrike abilities, adaptive audio, a reactive enemy with three waves, HUD, minimap and F1 to F4 presets. HANDOFF.md in the repo has the exact current state.

**Roadmap**

1. Prototype: map, units, orders, graphics pipeline (this PR).
2. Economy and base building: oil, tanker trucks, construction, power.
3. Terrain deformation with navmesh rebake, destructible props and bridges.
4. Commander unit and abilities, fog of war, minimap.
5. Enemy AI tiers 1 to 3, missions 1 to 3 playable.
6. Art pass: unit models, terrain materials, VFX polish, audio.
7. Missions 4 to 10, ORACLE faction, AI tiers 4 and 5.
8. Options menu, save/load, Mac app bundle signing and notarisation.

**Testing on the Mac.** Builds are run on the M4 through a Remote Control session in the repo folder; the ThinkPad gets an exported Windows build.

## Sources and licences

No third-party code or assets are in the repo yet; everything in the prototype is written from scratch and generated at runtime. Anything reused later gets a row here before it lands.

| Source | Licence | How it is used |
| --- | --- | --- |
| [Godot Engine 4.7](https://godotengine.org) | MIT | Engine |
| [Open RTS (Lampe Games)](https://github.com/lampe-games/godot-open-rts) | MIT | Studied for architecture (navmesh re-bake, unit traits); no code copied |
| [Godot 4.6 rendering changes (CG Channel)](https://www.cgchannel.com/2026/01/discover-5-key-features-for-cg-artists-in-godot-4-6/) | Article | Research for the graphics plan |
| [Godot 4.7 release notes summary](https://app.cinevva.com/hi/news/2026-06-19-godot-4-7-released) | Article | HDR output and area lights |

Candidate art sources for the art pass, all permissive: Kenney and Quaternius model packs (CC0), Poly Haven textures and HDRIs (CC0), ambientCG materials (CC0).

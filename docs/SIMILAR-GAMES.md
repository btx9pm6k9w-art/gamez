# Similar Games, Open-Source Projects & Community — Research Report

Compiled 2026-10-11. Goal: learn how best to build a Kingdom-Rush-class tower defense (TD) from comparable games, GitHub projects, developer write-ups and player communities. Companion to `docs/RESEARCH.md` (Kingdom Rush itself) and `docs/PROPOSAL.md` (our plan).

Conventions: **[src]** = read from the cited source; **[inference]** = my own conclusion.

## 0. Coverage — what I could and could not reach

| Channel | Result |
|---|---|
| GitHub | Cloned & read 5 repos via the session's read-only proxy (list in §3). `wdavidpence/kingdom-rush-clone` (a Phaser KR clone found via search) is **not accessible** — not read. GitHub topic/search pages are not reachable from here. |
| Reddit | **Blocked completely** (bot wall on every endpoint, search tool refuses the domain). No Reddit data is claimed anywhere below. |
| Steam / itch.io | Steam reviews & discussions read for Kingdom Rush titles; itch.io comments only via search snippets. |
| Developer write-ups | Read: Goal Defense balance article, X-Morph: Defense design journey, Core Defense case study, Game-Ace TD engineering guide, Naavik's Arknights deconstruction. |
| Wikipedia | Partly rate-limited; got Arknights, Defense Grid, Dungeon Defenders, They Are Billions, Desktop TD. |

Weak spot: **no first-hand player-community data beyond Steam/App Store reviews** (reviews skew negative/vocal). Treat §6 as signals, not statistics.

## 1. Genre map — five lineages and what each teaches

| Lineage | Examples | Core idea | Lesson for us |
|---|---|---|---|
| Lane TD + units | Kingdom Rush | Fixed paths, blocking soldiers, heroes, cooldown spells | Our base; keep "player is busy" |
| Maze / open-field | Desktop Tower Defense, X-Morph: Defense, Defense Grid | Towers shape the path (DTD: creeps take the shortest path; you can't fully block it) | Path-shaping is the deepest strategic lever; needs flow-field/A* and "cannot seal exit" rule |
| Operator/block TD | Arknights | Deployed *units* with block counts on ground/high tiles, finite Deployment Points, redeploy cooldown | Strongest proof that "blocking" scales into a whole genre ($678M / 17M downloads by Naavik/data.ai figures) |
| Roguelite TD | Rogue Tower, Core Defense, MINOS, Emberward, Titanium Court | Draft/randomise towers or map each run | Replayability engine; risk = RNG dominance & "one optimal setup" |
| Hybrid action/RTS | Dungeon Defenders, They Are Billions, Legion TD 2, X-Morph | Player avatar or RTS layer on top | Heroes with *real* agency; watch scope creep |
| Trap/geometry | Dungeon Warfare | Traps push/pull/launch; map geometry > raw DPS | Forced-movement synergies (pairs well with blocking) |
| Factory hybrid | Mindustry | Supply chain feeds defenses | Out of scope but shows data-driven wave system (§3) |

## 2. Game-by-game lessons

### Arknights (HyperGryph) — [Naavik deconstruction]
- Replaces tower upgrades-by-gold with **Deployment Points (DP)** that regenerate; players *deploy operators* and trigger skills — placement becomes timing + positioning.
- Block counts per class; melee on ground, ranged on elevated tiles; operators can be retreated and redeployed after a cooldown (softens misplacement) [src: Wikipedia/Naavik/forum summaries].
- Levels use hazards and interactive tiles; Wikipedia notes the often-limited number of viable solutions makes it feel like a **puzzle game** [src].
- Saga-map progression and episodic narrative borrow from puzzle games [src: Naavik].
- Weakness named by Naavik: no social/co-op features, little reach in the West.
- **Take:** consider a *DP-style* alternative economy for a challenge mode: it removes "snowballing gold", makes every placement a decision, and supports retreat/redeploy (fair mistake recovery).

### Bloons TD 6 (Ninja Kiwi)
- Three upgrade paths per tower, **crosspathing** limited to two paths, only one path beyond tier 3 [src: Bloons wiki] — deep builds with legible limits. Unity on macOS (shipped) [src].
- Vocal players debate "too many nerfs / balance" [src: Steam discussion, opinion].
- **Take:** 3 paths with a crosspath cap is a proven depth/readability compromise — this is the model in `docs/PROPOSAL.md` §2.

### Defense Grid: The Awakening (Hidden Path)
- Platforms-only build, towers can't be destroyed, enemies take shortest route; **range preview, game speed-up, zoom levels, auto-saved checkpoints you can revert to** [src: Wikipedia].
- Enemies *carry power cores* you must recover — a second objective beyond kills [src].
- **Take:** speed-up + range preview + checkpoint revert are table-stakes QoL here; "carried objective" is a cheap, strong variety mechanic.

### Desktop Tower Defense (2007, Flash)
- Founded the "mazing" subgenre: path is determined by tower placement; exit can't be fully blocked. Built by one person; ~$100k/year from ads at peak [src].
- **Take:** shows how one rule ("shortest path, never sealable") creates enormous depth.

### Mindustry (open source, Java/libGDX)
- Data-driven **wave definition** (`SpawnGroup`): `begin, end, spacing, unitAmount, unitScaling, max, shields, shieldScaling, effect, spawn` — waves are data, not code [src: code read].
- **Procedural wave generator** `Waves.generate(difficulty, rand, ...)`: unit "species" tier ladders, overlapping progressions that tail out, shields (not HP) scaling after wave 30, periodic boss groups, a final-boss tier, and a difficulty-based shift of wave start [src: code read].
- AI split into small classes (`GroundAI`, `FlyingAI`, `SuicideAI`, `DefenderAI`…) [src].
- **Take:** copy the *structure* (not the code — Mindustry is GPL-3.0): represent every wave as parametric groups; generate endless mode from seed + difficulty; scale **shields/armor** over time instead of raw HP inflation.

### Rogue Tower / Dungeon Warfare 2
- Rogue Tower: map and path grow each wave, towers drawn from random cards; critics: RNG-heavy, loop feels the same across runs [src: reviews via search].
- Dungeon Warfare 2: traps push/pull/launch/drop enemies; geometry beats DPS [src].
- **Take:** forced movement (knockback into traps, pulls into soldiers) is an excellent partner to *blocking*; roguelite drafting needs anti-"one best build" safeguards.

### X-Morph: Defense — developer write-up (Game Developer)
- Started with 58 tower choices & 92 add-ons; playtests showed far too many; they had to **gut redundant towers** (e.g., corrosive tower duplicated armor-piercing laser).
- Removed build-phase time limits ("unnecessary tension"); gave **instant, free relocation** so players can fix mistakes mid-battle; "lifting the burden of knowledge off the player" was their most important decision [src].
- Took 5+ years to find the right hybrid.
- **Take:** hard cap the roster; every tower needs a unique *job*; make mistakes cheaply recoverable.

### Goal Defense — balance math (Game Developer, 2013)
Concrete, reusable formulas [src]:
- Design a basic creep from the basic turret: if a turret covers ~3.25 tiles of path at creep speed 0.8 tiles/s, it gets ~4 s of fire → at 2 shots/s × 10 dmg that kills ≤ 80 HP; so basic creep HP ≈ 75.
- Wave size from route length: with ≥ 8 tiles of covered path, basic creeps never leak regardless of count; so hard waves need tougher units, not just more.
- Economy rule: income from wave *n* should cover building/upgrading for wave *n+1*; **player should add a tower every 1–2 waves**; levels should end with the field **60–70 % full**; 10–11 waves can be enough for drama.
- Failure modes to avoid: filled field (towers too cheap/board too small), predictable play from a single entrance, **uneven profit snowballing** from a few "right" spots.

### Core Defense — solo-dev postmortem (GameDiscoverCo)
- ~$20k first-week gross, ~$50k later, TD + light deckbuilding, $9.99 price; no tutorial needed; Discord-driven development; early itch.io beta → 3,000-wishlist Steam demo; crowdsourced localization (>half of sales from non-English markets) [src].
- **Tech: custom JS engine on Pixi.js + Vue.js, Electron, Capacitor — one codebase, no license fees** [src]. This directly validates the web-tech path in our proposal for a solo/small team.

### Dungeon Defenders / They Are Billions / Legion TD 2
- Dungeon Defenders: TD + ARPG with persistent characters, 1–6 player co-op; 1M+ sales across platforms by early 2012 [src: Wikipedia].
- They Are Billions: RTS + survival-TD with randomized maps and 8 resources; hit Steam top-sellers in Early Access [src].
- **Take:** co-op and hero progression move the genre from "puzzle" to "game you live in" — candidates for post-launch.

### Industry engineering guide — Game-Ace (2026)
- Five decoupled systems: wave manager, pathfinding, tower targeting, projectile pooling, balance-math layer, plus an event bus [src].
- A*/grid for fixed lanes; **flow field when hundreds of enemies share a destination**; tower targeting at **10–15 Hz**, not per frame; pool every projectile/VFX; texture atlases + sprite batching for 2D; speed controls (1×/2×/3×) belong on the HUD; auto-start-next-wave toggle [src].
- Wave scaling "exponential with linear floor", HP ~8–12 %/wave, armor/resist introduced at fixed checkpoints; keep data in versioned files; **headless simulator validates a full run against a reference loadout** [src].
- Avoid: pay-to-progress, energy systems [src]. (Vendor marketing page — cost/time figures are rough.)

## 3. GitHub projects studied (cloned shallow, read-only)

| Repo | What it is | License signal | What I learned / how to use |
|---|---|---|---|
| `Diabolically-Handsome/kingdom-rush-ml-agent` | ML agent that cleared the original KR's 12-level campaign (5/5 final seeds) and 79/130 level-runs across all 26 levels | MIT (verified) | **Best find.** Architecture: LLM "strategy brain" picks a plan; MLP "operator network" executes legal actions; plans found by evolutionary search over ~20k games. Prerequisites it insists on — *exact readable state, action receipts, deterministic replay, branch replay* — are precisely what we should design into our sim from day one so a balance bot can be built. Weak spots it reports (level 11, elite 20–22) are where designers should look for cheese/spikes. |
| `Anuken/Mindustry` | Mature open-source TD/factory game (Java) | GPL-3.0 (verified) | Data-driven waves & procedural wave generator (§2); small AI classes. |
| `crystal-bit/defending-todot` | Hacktoberfest Godot 3.2 KR-*inspired* TD | GPL-3.0 (verified) | Shows the basic KR scaffolding: strategic points menu, tower resources (`attack_radius, damage, armor_piercing, fire_rate, slow, area dmg, cost`), wave manager with signals, rally point on tower. **Simple and shallow — no real blocking/barracks AI; don't copy, GPL.** |
| `quiver-dev/tower-defense-godot4` | "Outpost Assault" Godot 4 template (superseded by a newer repo) | MIT code (verified); assets under separate `LICENSE_ASSETS.txt` | Good example of project hygiene: static typing, naming conventions, FSM enemy AI, scene composition. |
| `BlondeBurrito/bevy_flowfield_tiles_plugin` | Flow-field-tiles pathfinding for Bevy (Rust) | MIT / Apache-2.0 dual (verified) | Cost field → integration field → flow field in 10×10 sectors with portals; flow field cache shared by agents. Bench on a 12th-gen i7 laptop: open 100×100-sector field ≈ 3 ms; maze ≈ 283 ms; init ≈ 0.8 s. Algorithm is reusable *in concept*; for fixed-lane KR-style maps A*/waypoints suffice, flow fields only if we add maze/open-field maps. |

Also discovered but **not read** (pointers for later): `wdavidpence/kingdom-rush-clone` (Phaser 3; inaccessible), `locsummer/kingdom` (web clone), `Arrekin/dark-wisps-defence` (Bevy open-grid TD), `AntVo/Phaser-Tower-Defense`, `hwisoo/phaser-tower-defense`, `dgkanatsios/TowerDefense` (Unity).

**Honest finding:** the open-source TD landscape is thin on exactly what makes Kingdom Rush special — *melee blocking AI, rally points, hero abilities*. Nothing I could read implements them well. We are not copying a solved problem; this is our core R&D risk (and a differentiator).

## 4. What players say they want (signals only)

From Steam/App Store reviews and itch.io/Steam comments reached via search [src, anecdotal]:
- **Freedom or meaningful placement** over "cheap" fixed slots; ranges visible *before* purchase; stats readable before buying.
- **Upgrades with unique effects**, not just +stats.
- **No grind / single-optimal-setup loops**; roguelite randomness for variety; deckbuilding mixes praised.
- **Fast onboarding**: learn-by-doing tutorial.
- **QoL**: fast-forward, in-combat bestiary, skill review, hero-voice mute (from KR reviews, §RESEARCH).
- **Fair difficulty**: no gimmick stages requiring prior knowledge; no drip-feed content.
- Mixed: whether 2-branch vs 3-branch upgrades is "better" — evidence that *depth vs. clarity* is a live debate, so playtest it.

## 5. Distilled strategies (what to do)

**Design**
1. **Keep the Kingdom Rush thesis** (busy player; blocking as central verb). Arknights' commercial success shows blocking-centric TD has a large audience.
2. **Cap the roster, give each tower one clear job** (X-Morph's painful lesson). Ship ~5 classes × 3 branches rather than 20 near-duplicates.
3. **Mistakes must be cheap to fix**: sell refund ≥ 80 % (KR is 60 %), free repositioning of soldiers, optional redeploy cooldown, checkpoint revert in campaign (Defense Grid).
4. **QoL as features**: range preview before placing, speed 1×–3×, auto-next-wave toggle, pause-and-plan, in-combat bestiary.
5. **Waves as data**: adopt a Mindustry-style parametric group (`begin/end/spacing/amount/scaling/shields/effect`) for endless mode; hand-author campaign waves with explicit per-wave income (as KR does).
6. **Scale defense stats (shields/armor) rather than raw HP** late-game; introduce armor/resist types at fixed checkpoints to force build changes.
7. **Balance from first principles** (Goal Defense): derive basic creep HP from basic tower DPS × covered path time; target "new tower every 1–2 waves" and "field 60–70 % full at win"; avoid snowball spots.
8. **Add one or two mechanics, not ten**: candidates ranked by value/risk in §6.

**Technical**
9. **Deterministic fixed-step sim + seeded RNG + action journal + state snapshot** → enables replay, bug repro, a balance bot, and optional PvP/lockstep later. (The ML-agent repo's four "gates": exact state, action receipts, deterministic replay, branch replay.)
10. **Simulation/render separation**; tower AI at 10–15 Hz; pooling; atlases & batching; event bus (Game-Ace).
11. **Stack:** Core Defense proves JS + Pixi + Electron/Capacitor can ship a successful commercial TD. For us: TypeScript + WebGPU/WebGL2 renderer, Tauri/Electron shell (decision pending with you). Flow-field only for open-field maps.
12. **Headless balance sweeps in CI**: run thousands of seeded games with scripted bots to flag dominant towers, dead builds, impossible waves.

## 6. Idea shortlist (ranked)

| # | Idea | Source of inspiration | Value | Risk |
|---|---|---|---|---|
| 1 | 3 upgrade branches + crosspath cap | BTD6 | High | Balance load (mitigate with sim) |
| 2 | Blocking soldiers with stances + redeploy | KR + Arknights | High (core identity) | Unit AI complexity — no good OSS reference |
| 3 | Forced-movement synergies (knockback into blockers/traps) | Dungeon Warfare | High | Needs physics-ish rules |
| 4 | Telegraphed map mechanics (gates, tides, collapsing bridges) | Arknights hazards / KR set pieces | Med-High | Authoring cost |
| 5 | Carried-objective enemies (steal & escape) | Defense Grid | Medium | UI clarity |
| 6 | Deployment-Point "tactical" mode | Arknights | Medium (mode variety) | Second economy to balance |
| 7 | Roguelite endless w/ drafted relics + anti-dominant-build rules | Rogue Tower / Core Defense | High replay | RNG fairness |
| 8 | Seeded daily challenge | Roguelites | Medium | Needs determinism (we plan it) |
| 9 | Maze maps with unsealable exit | DTD | Medium | Flow-field work |
| 10 | Co-op (2P) | Dungeon Defenders | Medium | Netcode; defer |
| 11 | Level/mod editor | community requests | Medium | Scope; defer |

## 7. Risks & open questions
- Melee-blocking AI is the hardest unsolved piece to source from OSS → budget R&D in M0/M1.
- Art quality remains the main determinant of "KR-latest" look (see PROPOSAL §6).
- Licensing: GPL repos (Mindustry, defending-todot) are *reading material only*. Wiki-derived `data/` is CC-BY-SA → reference only.
- Still unverified: actual player sentiment outside Steam/App Store (Reddit/Discord inaccessible). If you can paste links or exports from r/towerdefense or Discord, I'll fold them in.

## 8. Sources
- Game Developer — Goal Defense, "Balance in td-games": https://www.gamedeveloper.com/design/balance-in-td-games
- Game Developer — X-Morph: Defense, "Combining tower defense with a shooter": https://www.gamedeveloper.com/design/combining-tower-defense-with-a-shooter---game-design-implications
- GameDiscoverCo — Core Defense case study: https://newsletter.gamediscover.co/p/case-study-making-core-defense-a
- Game-Ace — Engineering tower defense games: https://game-ace.com/blog/engineering-of-tower-defense-games/
- Naavik — Arknights deconstruction: https://naavik.co/digest/arknights-tower-defense-redefined-digest/
- Wikipedia — Arknights, Defense Grid: The Awakening, Desktop Tower Defense, Dungeon Defenders, They Are Billions
- Bloons wiki — Crosspathing: https://bloons.fandom.com/wiki/Crosspathing
- Steam/App Store reviews: https://steamcommunity.com/app/816340/negativereviews/ , https://steamcommunity.com/app/2849080/discussions/
- GitHub: https://github.com/Diabolically-Handsome/kingdom-rush-ml-agent · https://github.com/Anuken/Mindustry · https://github.com/crystal-bit/defending-todot · https://github.com/quiver-dev/tower-defense-godot4 · https://github.com/BlondeBurrito/bevy_flowfield_tiles_plugin
- Reviews/aggregators reached via search (secondary): Rogue Tower (Metacritic/TheGamer), towerward.com comparisons, GameSpot 2026 TD list

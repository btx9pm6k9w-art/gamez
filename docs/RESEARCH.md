# Kingdom Rush — Research Report

Compiled 2026-10-11. Purpose: understand Kingdom Rush (KR) in depth so we can build a better tower-defense game.

**Source discipline.** Facts below come from the sources listed in §10. Anything marked **[inference]** is my own conclusion, not a sourced claim. Structured numbers are in `data/` (`kr-towers.json`, `kr-enemies.json`, `kr-levels.json`), scraped from the community wiki (CC-BY-SA); they describe the *original* Kingdom Rush unless noted.

**Known gaps** (nothing found, so nothing claimed): Ironhide's animation pipeline (Spine vs. frame-by-frame is unconfirmed), its rendering performance targets, and any official postmortem/GDC talk. `kingdomrush.com/kingdom-rush-strategy-guide` turned out to be only a level list with video links.

---

## 1. The franchise at a glance

| Game | Released | Notable change |
|---|---|---|
| Kingdom Rush | 28 Jul 2011 (Flash → iOS Dec 2011 → Android 2013 → Steam 2014) | The formula: 4 tower types, barracks soldiers, 2 spells, heroes added in 2012 |
| Frontiers | 6 Jun 2013 | New towers per branch, new hero set, blocked strategic points (100–200g to clear) |
| Origins | 20 Nov 2014 | Prequel; elf theme; Thunderbolt replaces Rain of Fire |
| Vengeance | 22 Nov 2018 | Play as the villain; **choose your tower loadout before each stage** (16+ towers); "Impossible" difficulty; new engine, more detailed art |
| Alliance (KR5) | 25 Jul 2024 | Two heroes per stage, 18 towers, 25 stages, 2 upgrade branches per tower (down from 3), "holders" |
| Genesis (KR6) | 24 Sep 2026 | Time-travel alt-timeline; Rain of Fire returns as an equippable spell |
| Spin-offs | Legends (RPG, 2021), Iron Marines (RTS), Battles (PvP cards) | Ironhide is willing to leave the formula |

Studio facts: Ironhide Game Studio (Uruguay), founded 2010 by Álvaro Azofra (design), Pablo Realini (programming), Gonzalo Sande (art). The original took ~1 year (half part-time, half full-time) by a 3-person team; the iOS port ~4 months. Team later grew to ~30 (2018). Vengeance used in-house tools, Adobe Animate and Cocos2d-x (developer interview, 2018).

## 2. Why it worked — the design thesis

Straight from the co-founder: they studied the market, saw strategy games earned the best sponsor bids, and **chose to give a saturated genre "more action"** — in most TDs the player "sits back to enjoy the show"; they wanted the player "involved, busy" and the stage to feel like a battle. (Kodeco interview.)

Mechanics that deliver that:

1. **Barracks / melee lock.** Soldiers physically block enemies, forcing them to stop. This neutralises fast enemies (Wulves) and creates *kill zones* where ranged/magic/artillery are most effective. Blocking is the game's central verb, not damage. (Game Developer analysis.)
2. **Active, cooldown-gated player powers.** Reinforcements (10s recharge, free) and Rain of Fire (80s recharge). They cost no gold, so they can't be spammed — they reward attention instead of money.
3. **Early wave calling.** Click the next-wave icon early → bonus gold equal to seconds skipped *and* spell recharge. Risk/reward pacing owned by the player.
4. **Fixed strategic points** (not freeform). Forces meaningful placement; makes level design authorable; keeps melee AI tractable. [inference: also cheaper to implement]
5. **Heroes** you steer, that level up per-level (cap lvl 10, reset each stage), respawn (~15s), immune to regular instakills.
6. **Meta-progression via stars → permanent upgrades, freely respec-able.** Six paths (Archers, Barracks, Mages, Artillery, Rain of Fire, Reinforcements), 1–4 stars each. Players re-allocate before every level to suit the enemy mix.
7. **Three challenge tiers** per stage (Campaign / Heroic = 1 life, 6 big waves / Iron = 1 life, restricted towers, hidden wave sizes) — massive replay from the same maps.
8. **Authored levels with a teaching arc.** Southport = 3 goblins vs 3 soldiers on purpose. Each early level introduces one idea (armor → mages; fast enemies → barracks; etc.). Analytics showed a drop-off at stage 3, which drove difficulty retuning. (Ironhide "Behind the Scenes"; Game Developer.)
9. **Readable, charming art** + humor/easter eggs; "distinctive and readable" is an explicit art goal (Ironhide Q&A).

## 3. Core rules (original game)

- **Lives:** 20. Stars: 18–20 left = 3★, 6–17 = 2★, 1–5 = 1★. Each leaked enemy costs its `lives` value (goblin 1 … bosses 20 = instant loss).
- **Difficulty:** Casual / Normal / Veteran = enemy HP ×0.8 / ×1.0 / ×1.2 (exactly ±20% in KR1). Higher difficulty also slows hero XP. Vengeance added "Impossible"; Origins-Steam's version applies per-enemy bespoke buffs rather than flat HP.
- **Damage model:** physical vs magic; Armor/Magic Resist are percentages (None 0, Low 30, Medium 50–60, High 80, Great 95). **True damage** ignores both. Instant kills exclude bosses/mini-bosses. Artillery ignores half of armor.
- **Gold:** per-kill bounty + wave "income" + early-call bonus. Selling returns 60% (90% with the Salvage upgrade). Summoned/duplicated enemies give no gold (anti-farming).
- **Tower tree:** 4 base types × L1→L2→L3→two L4 branches. Cost ladder 70/110/160/230 (archers, barracks), mages 100/160/240/300, artillery 125/220/320/375. L2/L3 unlock at levels 2 and 3; each L4 tower unlocks at a specific stage (a drip of novelty).
- **Special towers per stage** (Sylvan Elf Hall, Sasquatch, Sunray): one-off set-pieces tied to a level.
- **Blocking rules:** one enemy per soldier; flying enemies cannot be blocked; soldiers outnumbering enemies gang up; rally point only within a radius.

### Tower roles (level-4 abilities)
| Tower | Role / signature |
|---|---|
| Rangers Hideout | Highest fire rate; Poison Arrows (true-damage DoT), Wrath of the Forest (vines trap ≥2 enemies, 40 dmg/s, 9s cd, max 3× per enemy, not bosses) |
| Musketeer Garrison | Slow, huge range; **Sniper Shot** (chance to instakill, non-boss), Shrapnel Shot AoE |
| Holy Order | Tankiest melee: armor, self-heal, Holy Strike AoE; no anti-air |
| Barbarian Mead Hall | High damage melee; thrown axes vs air; whirlwind AoE |
| Arcane Wizard | **Death Ray** (instakill non-boss, 16–20s cd), **Teleport** (rewinds groups up to 3×) — combos with artillery |
| Sorcerer Mage | Armor-halving curse + DoT, **Polymorph** → sheep (cannot be blocked) |
| Big Bertha | Mass AoE + never-miss missile |
| Tesla x104 | Chain lightning (hits air), static-field overcharge |

### Spell/upgrade numbers worth keeping
Reinforcements upgrade line: Farmers → Conscripts → Warriors → Legionnaires (110HP, 30% armor) → +Spear Throw (hits air). Rain of Fire: 3 meteors/30–60 dmg → up to 150–180 dmg + 5 extra random meteors (Cataclysm), cooldown 80s → ~60s.

## 4. Enemy design

70 enemy entries in the original (see `data/kr-enemies.json`). Patterns:
- **Roles are legible:** swarm (Goblin 20HP, bounty 3), armored (Dark Knight 80%), resistant (Shaman 85% MR, healer), fast/dodge (Worg, Wulf), flyer (Gargoyle, Rocket Rider w/ turbo), summoner (Necromancer, Spider Matriarch), regenerator (Troll), exploder (Goblin Sapper), tank/boss (Forest Troll, Yeti, Juggernaut).
- **Counters are explicit:** armored → magic; resistant → ranged/physical; clusters → artillery; healers → focus fire/Rain of Fire; elite single → instakill towers.
- **Bosses**: 14–21k HP, `lives = 20`, immune to instakills, scripted abilities (disable towers, eat units, summon). The Iron/Heroic bosses' corpses decorate the same map afterward — nice touch.
- **Stat scale (casual/normal/veteran):** HP spans ~20 → ~18,000 (≈ 3 orders of magnitude); bounty scales roughly with HP/ few.

## 5. Level design (original, 12 main + bonus stages ≈ 26 total)

Starting gold: Southport 265, Dark Tower 1300 (Iron: 2800). Southport: 7 waves, 8 strategic points; Rotten Forest: 17 points, multi-lane (South/North/Gateway) waves with per-wave income values. Later levels add gimmicks: graveyards that reanimate, poison pools, towers disabled by bosses, ice terrain that speeds Troll Pathfinders, Vez'nan disabling towers. Each stage has authored **per-lane wave tables with income per wave** — the designers hand-tune the economy wave by wave.

## 6. Where the franchise is criticised (the opportunity list)

From Steam reviews/discussions and App Store reviews (anecdotal, vocal minority — treat as signals, not consensus):

1. **Repetition / same formula** across sequels; few mechanical risks (Vengeance's loadout system the exception).
2. **Balance: a few towers dominate** ("most of the game with two tower types"; "only archers viable at higher difficulty" in Origins).
3. **Heroes**: can't be directly controlled for abilities (they auto-use instakills on single creeps), and power varies widely between heroes.
4. **QoL gaps still missing:** no fast-forward (!), can't open bestiary in combat, can't review tower/hero skill ranks, no mute for hero voices.
5. **Cheap difficulty** in late stages: enemies walking out-of-bounds, teleport-pad maps requiring pre-knowledge, bosses that disable 80% of towers, repeated "remove a tower" boss trick, "learn it by dying" design.
6. **Content/price & drip release** (short campaign, post-launch drip, hero IAPs on mobile).
7. **Tower upgrade depth regressing** (3 → 2 branches in Alliance; Barracks seen as the least balanced tower).
8. **Audio quality** complaints in Alliance.
9. Positive counter-signal: reviewers consistently praise approachability, pacing and polish; Bloons TD 6 is praised for depth (3 upgrade paths), Mindustry for factory-hybrid, Defense Grid for placement/routing.

## 7. Graphics & performance observations

Sourced: cartoony painted/vector look with strong silhouettes and heavy secondary animation; Vengeance+ introduced "a lot more details and animations" and an Iron Marines-influenced style; background art authored as vectors in Adobe Animate; Cocos2d-x runtime; mobile port struggles were **memory and aspect ratios**; Ironhide patches old games 5–6×/year for platform compatibility.

Hardware-side (current as of Oct 2026): **WebGPU ships in Safari 26 (macOS Tahoe 26)**; Chrome has it; WebGL 2 remains the universal baseline. PixiJS v8 batching benchmarks show very large sprite counts are CPU-bound, not GPU-bound, and that WebGPU does not automatically beat WebGL for sprites (helps most when filters/masks/blend modes break batches). [inference: on Apple Silicon, a well-batched 2D game is trivially within budget — the risk is draw-call/batch breaks, texture memory, and GC pauses, not raw fill.]

## 8. What "better" should mean — design gaps to exploit

See `docs/PROPOSAL.md` for the actual plan. Short version: keep the *blocking + active play* DNA; fix the QoL basics (fast-forward, in-combat bestiary, pause-and-plan); make tower choice meaningful (≥3 upgrade paths, balance via simulation); deterministic, readable difficulty (no out-of-bounds gimmicks); ship a true macOS-native-quality renderer (60/120 fps ProMotion, high-DPI, lighting/particles beyond 2011 sprites).

## 9. Open questions I could not resolve online
- Ironhide's exact animation toolchain and sprite budgets.
- Any frame-time/memory targets they use.
- Official balance data beyond what the wiki records (HP/dmg tables are community-maintained; values may differ by platform — the wiki itself notes Flash vs mobile vs Steam differences).

## 10. Sources
- Kingdom Rush Wiki (community, MediaWiki API dump of 1,580 articles + 263 templates): https://kingdomrushtd.fandom.com/
- Official strategy guide (level list/videos only): https://www.kingdomrush.com/kingdom-rush-strategy-guide
- Kodeco, "Making a Hit Tower Defense Game" (Álvaro Azofra interview): https://www.kodeco.com/2769-making-a-hit-tower-defense-game-a-top-app-dev-interview
- Game Developer, "Kingdom Rush – the wonderful Campaign level design" (D. Harlow, 2013): https://gamedeveloper.com/design/kingdom-rush---the-wonderful-campaign-level-design
- Game World Observer, Ironhide interview (2018): https://gameworldobserver.com/2018/12/06/ironhide-long-fans-love-kingdom-rush-will-continue-working
- Video Chums, Ironhide Q&A on Vengeance: https://videochums.com/article/lets-chat-with-ironhide-game-studio-about-kingdom-rush-vengeance
- Ironhide Q&A on Kingdom Rush Battles: https://www.ironhidegames.com/News/Details/420
- Steam community (negative reviews, Alliance discussions): https://steamcommunity.com/app/816340/negativereviews/ , https://steamcommunity.com/app/2849080/discussions/
- WebGPU/Safari 26 state: https://web.dev/blog/webgpu-supported-major-browsers , https://app.cinevva.com/guides/webgpu-vs-webgl-games
- PixiJS v8 notes: https://pixijs.com/blog/pixi-v8-launches

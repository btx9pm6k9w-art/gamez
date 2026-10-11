import { createWorld, step, hashWorld, towerCost, maxLevel, type Command, type World } from './world';
import type { TowerKind } from './data';

export interface BotPlan { builds: [number, TowerKind][]; callEarly: boolean }
export const DEFAULT_PLAN: BotPlan = {
  builds: [[1, 'barracks'], [2, 'archer'], [3, 'mage'], [0, 'archer'], [4, 'barracks'], [6, 'archer'], [7, 'mage'], [5, 'archer'], [8, 'archer']], callEarly: false,
};

/** Greedy scripted player: builds in plan order, otherwise upgrades the cheapest affordable tower. Used for balance tests. */
export function botCommands(w: World, plan: BotPlan): Command[] {
  const cmds: Command[] = []; let gold = w.gold;
  for (const [slot, kind] of plan.builds) {
    if (w.towers.some((t) => t.slot === slot)) continue;
    const c = towerCost(kind, 0); if (gold >= c) { cmds.push({ type: 'build', slot, kind }); gold -= c; } else break;
  }
  if (!cmds.length) {
    let best: { id: number; cost: number } | null = null;
    for (const t of w.towers) if (t.level < maxLevel(t.kind)) { const c = towerCost(t.kind, t.level + 1); if (c <= gold && (!best || c < best.cost)) best = { id: t.id, cost: c }; }
    if (best) cmds.push({ type: 'upgrade', tower: best.id });
  }
  if (plan.callEarly && w.waveTimer > 8 && w.enemies.length < 3) cmds.push({ type: 'callWave' });
  if (w.reinforceCd <= 0 && w.enemies.length) { const e = w.enemies.reduce((a, b) => (a.d > b.d ? a : b)); const p = w.path.at(e.d + 40); cmds.push({ type: 'reinforce', x: p.x, y: p.y }); }
  return cmds;
}

export interface Result { status: string; lives: number; gold: number; ticks: number; kills: number; hash: number; towers: number }
export function playBot(seed: number, plan: BotPlan | null, maxSeconds = 900): Result {
  const w = createWorld(seed);
  while (w.status === 'playing' && w.time < maxSeconds) {
    const cmds = plan && w.tick % 20 === 0 ? botCommands(w, plan) : [];
    step(w, cmds);
  }
  return { status: w.status === 'playing' ? 'timeout' : w.status, lives: w.lives, gold: w.gold, ticks: w.tick, kills: w.kills, hash: hashWorld(w), towers: w.towers.length };
}

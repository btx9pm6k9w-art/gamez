import { Rng } from './rng';
import {
  BARRACKS, ENEMIES, ENGAGE_RADIUS, LEASH_RADIUS, MAP_FARMLANDS, REACH, REINFORCE, SELL_REFUND, SHOOTERS, SOLDIER_SPEED,
  type Dmg, type EnemyId, type MapDef, type TowerKind, type Vec,
} from './data';

export const DT = 1 / 60;

export class PathMeasure {
  cum: number[] = [0]; total = 0;
  constructor(public pts: Vec[]) {
    for (let i = 1; i < pts.length; i++) { this.total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y); this.cum.push(this.total); }
  }
  at(d: number): Vec {
    if (d <= 0) return { ...this.pts[0] };
    if (d >= this.total) return { ...this.pts[this.pts.length - 1] };
    let i = 1; while (this.cum[i] < d) i++;
    const t = (d - this.cum[i - 1]) / (this.cum[i] - this.cum[i - 1]);
    return { x: this.pts[i - 1].x + (this.pts[i].x - this.pts[i - 1].x) * t, y: this.pts[i - 1].y + (this.pts[i].y - this.pts[i - 1].y) * t };
  }
  nearest(p: Vec): Vec {
    let best: Vec = this.pts[0], bd = Infinity;
    for (let i = 1; i < this.pts.length; i++) {
      const a = this.pts[i - 1], b = this.pts[i]; const abx = b.x - a.x, aby = b.y - a.y;
      const t = Math.max(0, Math.min(1, ((p.x - a.x) * abx + (p.y - a.y) * aby) / (abx * abx + aby * aby)));
      const q = { x: a.x + abx * t, y: a.y + aby * t }; const dd = (q.x - p.x) ** 2 + (q.y - p.y) ** 2;
      if (dd < bd) { bd = dd; best = q; }
    }
    return { ...best };
  }
}

export interface Enemy { id: number; def: EnemyId; hp: number; maxHp: number; d: number; x: number; y: number; px: number; py: number; blockedBy: number | null; atkCd: number; alive: boolean }
export interface Soldier { id: number; tower: number | null; idx: number; x: number; y: number; px: number; py: number; rx: number; ry: number; hp: number; maxHp: number; dmg: Dmg; armor: number; atkEvery: number; atkCd: number; target: number | null; life: number | null; alive: boolean }
export interface Tower { id: number; slot: number; kind: TowerKind; level: number; cd: number; rally: Vec; soldierIds: (number | null)[]; respawn: number[]; spent: number }
export interface Projectile { id: number; x: number; y: number; px: number; py: number; target: number; dmg: number; magic: boolean; speed: number; alive: boolean }
export type SimEvent = { type: 'hit' | 'death' | 'leak' | 'build' | 'sell' | 'upgrade' | 'wave' | 'soldierDown' | 'spell' | 'won' | 'lost'; x?: number; y?: number; id?: number; kind?: string };

export type Command =
  | { type: 'build'; slot: number; kind: TowerKind }
  | { type: 'upgrade'; tower: number }
  | { type: 'sell'; tower: number }
  | { type: 'rally'; tower: number; x: number; y: number }
  | { type: 'callWave' }
  | { type: 'reinforce'; x: number; y: number };

export interface World {
  map: MapDef; path: PathMeasure; rng: Rng; tick: number; time: number; status: 'playing' | 'won' | 'lost';
  gold: number; lives: number; waveIndex: number; waveTimer: number; spawnQueue: { at: number; type: EnemyId }[];
  reinforceCd: number; nextId: number; towers: Tower[]; enemies: Enemy[]; soldiers: Soldier[]; projectiles: Projectile[];
  events: SimEvent[]; leaked: number; kills: number;
  enemyIdx: Map<number, Enemy>; soldierIdx: Map<number, Soldier>; // id lookups (O(1)); kept in sync by add*/cleanup
}

export function createWorld(seed = 1, map: MapDef = MAP_FARMLANDS): World {
  return {
    map, path: new PathMeasure(map.path), rng: new Rng(seed), tick: 0, time: 0, status: 'playing', gold: map.startGold, lives: map.startLives,
    waveIndex: 0, waveTimer: map.firstWaveIn, spawnQueue: [], reinforceCd: 0, nextId: 1, towers: [], enemies: [], soldiers: [], projectiles: [], events: [], leaked: 0, kills: 0, enemyIdx: new Map(), soldierIdx: new Map(),
  };
}

const FORMATION: Vec[] = [{ x: -16, y: 12 }, { x: 0, y: -12 }, { x: 16, y: 12 }];
const dist = (a: Vec, b: Vec) => Math.hypot(a.x - b.x, a.y - b.y);
const roll = (w: World, d: Dmg) => w.rng.range(d[0], d[1]);
export const towerCost = (kind: TowerKind, level: number): number => (kind === 'barracks' ? BARRACKS.levels[level].cost : SHOOTERS[kind].levels[level].cost);
export const maxLevel = (kind: TowerKind): number => (kind === 'barracks' ? BARRACKS.levels.length : SHOOTERS[kind].levels.length) - 1;
export const enemyById = (w: World, id: number | null) => { if (id == null) return undefined; const e = w.enemyIdx.get(id); return e && e.alive ? e : undefined; };
const soldierById = (w: World, id: number | null) => { if (id == null) return undefined; const s = w.soldierIdx.get(id); return s && s.alive ? s : undefined; };

function spawnSoldier(w: World, t: Tower | null, idx: number, at: Vec, rally: Vec, life: number | null): Soldier {
  const lv = t ? BARRACKS.levels[t.level] : { hp: REINFORCE.hp, dmg: REINFORCE.dmg, armor: REINFORCE.armor, atkEvery: REINFORCE.atkEvery };
  const s: Soldier = { id: w.nextId++, tower: t ? t.id : null, idx, x: at.x, y: at.y, px: at.x, py: at.y, rx: rally.x + FORMATION[idx % 3].x, ry: rally.y + FORMATION[idx % 3].y,
    hp: lv.hp, maxHp: lv.hp, dmg: lv.dmg, armor: lv.armor, atkEvery: lv.atkEvery, atkCd: 0, target: null, life, alive: true };
  w.soldiers.push(s); w.soldierIdx.set(s.id, s); return s;
}

export function applyCommands(w: World, cmds: Command[]): void { for (const c of cmds) applyCommand(w, c); }

function applyCommand(w: World, c: Command): void {
  switch (c.type) {
    case 'build': {
      if (w.towers.some((t) => t.slot === c.slot) || c.slot < 0 || c.slot >= w.map.slots.length) return;
      const cost = towerCost(c.kind, 0); if (w.gold < cost) return;
      w.gold -= cost; const pos = w.map.slots[c.slot];
      const t: Tower = { id: w.nextId++, slot: c.slot, kind: c.kind, level: 0, cd: 0, rally: w.path.nearest(pos), soldierIds: [], respawn: [], spent: cost };
      if (c.kind === 'barracks') { for (let i = 0; i < BARRACKS.soldiers; i++) { t.soldierIds.push(null); t.respawn.push(0); } }
      w.towers.push(t); w.events.push({ type: 'build', x: pos.x, y: pos.y, id: t.id, kind: c.kind }); return;
    }
    case 'upgrade': {
      const t = w.towers.find((q) => q.id === c.tower); if (!t || t.level >= maxLevel(t.kind)) return;
      const cost = towerCost(t.kind, t.level + 1); if (w.gold < cost) return;
      w.gold -= cost; t.spent += cost; t.level++;
      if (t.kind === 'barracks') for (const sid of t.soldierIds) { const s = soldierById(w, sid); if (s) { const lv = BARRACKS.levels[t.level]; const r = s.hp / s.maxHp; s.maxHp = lv.hp; s.hp = lv.hp * r; s.dmg = lv.dmg; s.armor = lv.armor; } }
      const pos = w.map.slots[t.slot]; w.events.push({ type: 'upgrade', x: pos.x, y: pos.y, id: t.id }); return;
    }
    case 'sell': {
      const i = w.towers.findIndex((q) => q.id === c.tower); if (i < 0) return; const t = w.towers[i];
      w.gold += Math.floor(t.spent * SELL_REFUND);
      for (const sid of t.soldierIds) { const s = soldierById(w, sid); if (s) killSoldier(w, s, false); }
      const pos = w.map.slots[t.slot]; w.events.push({ type: 'sell', x: pos.x, y: pos.y, id: t.id }); w.towers.splice(i, 1); return;
    }
    case 'rally': {
      const t = w.towers.find((q) => q.id === c.tower); if (!t || t.kind !== 'barracks') return;
      const pos = w.map.slots[t.slot]; const dx = c.x - pos.x, dy = c.y - pos.y; const d = Math.hypot(dx, dy) || 1;
      const k = d > BARRACKS.rallyRange ? BARRACKS.rallyRange / d : 1; t.rally = { x: pos.x + dx * k, y: pos.y + dy * k };
      t.soldierIds.forEach((sid, i) => { const s = soldierById(w, sid); if (s) { s.rx = t.rally.x + FORMATION[i % 3].x; s.ry = t.rally.y + FORMATION[i % 3].y; s.target = null; } }); return;
    }
    case 'callWave': {
      if (w.waveIndex >= w.map.waves.length || w.waveTimer <= 0) return;
      const bonus = Math.ceil(w.waveTimer); w.gold += bonus; w.reinforceCd = Math.max(0, w.reinforceCd - w.waveTimer); w.waveTimer = 0; return;
    }
    case 'reinforce': {
      if (w.reinforceCd > 0) return; w.reinforceCd = REINFORCE.cooldown; const p = { x: c.x, y: c.y };
      for (let i = 0; i < REINFORCE.count; i++) spawnSoldier(w, null, i, p, p, REINFORCE.life);
      w.events.push({ type: 'spell', x: c.x, y: c.y, kind: 'reinforce' }); return;
    }
  }
}

function killSoldier(w: World, s: Soldier, report = true): void {
  s.alive = false; for (const e of w.enemies) if (e.blockedBy === s.id) e.blockedBy = null;
  if (s.tower != null) { const t = w.towers.find((q) => q.id === s.tower); if (t) { t.soldierIds[s.idx] = null; t.respawn[s.idx] = BARRACKS.respawn; } }
  if (report) w.events.push({ type: 'soldierDown', x: s.x, y: s.y, id: s.id });
}

function spawnWave(w: World): void {
  const wave = w.map.waves[w.waveIndex]; w.events.push({ type: 'wave', id: w.waveIndex });
  for (const g of wave.groups) for (let i = 0; i < g.count; i++) w.spawnQueue.push({ at: w.time + g.delay + i * g.interval, type: g.type });
  w.spawnQueue.sort((a, b) => a.at - b.at); w.gold += wave.income; w.waveIndex++;
  w.waveTimer = w.waveIndex < w.map.waves.length ? wave.nextIn : Infinity;
}

export function addEnemy(w: World, type: EnemyId, hp?: number, d = 0): Enemy {
  const def = ENEMIES[type]; const p = w.path.at(d); const h = hp ?? def.hp;
  const e: Enemy = { id: w.nextId++, def: type, hp: h, maxHp: h, d, x: p.x, y: p.y, px: p.x, py: p.y, blockedBy: null, atkCd: 0, alive: true };
  w.enemies.push(e); w.enemyIdx.set(e.id, e); return e;
}

export function step(w: World, cmds: Command[] = []): void {
  if (w.status !== 'playing') return;
  w.events.length = 0;
  for (const c of cmds) applyCommand(w, c);
  // waves
  if (w.waveTimer !== Infinity) { w.waveTimer -= DT; if (w.waveTimer <= 0 && w.waveIndex < w.map.waves.length) spawnWave(w); }
  while (w.spawnQueue.length && w.spawnQueue[0].at <= w.time) addEnemy(w, w.spawnQueue.shift()!.type);
  w.reinforceCd = Math.max(0, w.reinforceCd - DT);
  for (const e of w.enemies) { e.px = e.x; e.py = e.y; }
  for (const s of w.soldiers) { s.px = s.x; s.py = s.y; }
  for (const p of w.projectiles) { p.px = p.x; p.py = p.y; }
  // towers
  for (const t of w.towers) {
    const pos = w.map.slots[t.slot];
    if (t.kind === 'barracks') {
      for (let i = 0; i < t.soldierIds.length; i++) {
        if (t.soldierIds[i] == null && !soldierById(w, t.soldierIds[i])) {
          t.respawn[i] -= DT; if (t.respawn[i] <= 0) t.soldierIds[i] = spawnSoldier(w, t, i, pos, t.rally, null).id;
        }
      }
    } else {
      t.cd -= DT; if (t.cd > 0) continue;
      const sh = SHOOTERS[t.kind], lv = sh.levels[t.level]; let best: Enemy | null = null;
      for (const e of w.enemies) if (e.alive && dist(e, pos) <= lv.range && (!best || e.d > best.d)) best = e;
      if (best) { t.cd = lv.cooldown; w.projectiles.push({ id: w.nextId++, x: pos.x, y: pos.y - 30, px: pos.x, py: pos.y - 30, target: best.id, dmg: roll(w, lv.dmg), magic: sh.magic, speed: sh.projSpeed, alive: true }); }
    }
  }
  // soldiers
  for (const s of w.soldiers) {
    if (!s.alive) continue;
    if (s.life != null) { s.life -= DT; if (s.life <= 0) { killSoldier(w, s, false); continue; } }
    let t = enemyById(w, s.target);
    if (!t) {
      s.target = null; let best: Enemy | null = null, bestBlocked = true, bd = Infinity;
      for (const e of w.enemies) {
        if (!e.alive) continue; const d = Math.hypot(e.x - s.rx, e.y - s.ry); if (d > ENGAGE_RADIUS) continue;
        const free = e.blockedBy == null || !soldierById(w, e.blockedBy);
        if ((free && bestBlocked) || (free === !bestBlocked && d < bd)) { best = e; bestBlocked = !free; bd = d; }
      }
      if (best) { t = best; s.target = best.id; if (bestBlocked === false) best.blockedBy = s.id; }
    } else if (t.blockedBy !== s.id && Math.hypot(t.x - s.rx, t.y - s.ry) > LEASH_RADIUS) { s.target = null; t = undefined; }
    if (t && (t.blockedBy == null || !soldierById(w, t.blockedBy))) t.blockedBy = s.id; // any engaged soldier re-blocks if the previous blocker fell
    const gx = t ? t.x - 15 : s.rx, gy = t ? t.y : s.ry; const dx = gx - s.x, dy = gy - s.y; const d = Math.hypot(dx, dy);
    if (t && Math.hypot(t.x - s.x, t.y - s.y) <= REACH) {
      s.atkCd -= DT; if (s.atkCd <= 0) { s.atkCd = s.atkEvery; const e = t; e.hp -= roll(w, s.dmg) * (1 - ENEMIES[e.def].armor); w.events.push({ type: 'hit', x: e.x, y: e.y }); if (e.hp <= 0) killEnemy(w, e); }
    } else if (d > 1) { const m = Math.min(d, SOLDIER_SPEED * DT); s.x += (dx / d) * m; s.y += (dy / d) * m; }
  }
  // enemies
  for (const e of w.enemies) {
    if (!e.alive) continue; const def = ENEMIES[e.def]; const b = soldierById(w, e.blockedBy);
    if (b) {
      if (Math.hypot(b.x - e.x, b.y - e.y) <= REACH + def.radius * 0.5) {
        e.atkCd -= DT; if (e.atkCd <= 0) { e.atkCd = def.atkEvery; b.hp -= roll(w, def.dmg) * (1 - b.armor); if (b.hp <= 0) killSoldier(w, b); }
      }
      continue;
    }
    e.blockedBy = null; e.d += def.speed * DT; const p = w.path.at(e.d); e.x = p.x; e.y = p.y;
    if (e.d >= w.path.total) { e.alive = false; w.lives -= def.lives; w.leaked += def.lives; w.events.push({ type: 'leak', x: e.x, y: e.y, id: e.id }); }
  }
  // projectiles
  for (const p of w.projectiles) {
    const t = enemyById(w, p.target); if (!t) { p.alive = false; continue; }
    const dx = t.x - p.x, dy = t.y - p.y, d = Math.hypot(dx, dy), m = p.speed * DT;
    if (d <= m + 4) {
      p.alive = false; t.hp -= p.dmg * (1 - (p.magic ? ENEMIES[t.def].resist : ENEMIES[t.def].armor)); w.events.push({ type: 'hit', x: t.x, y: t.y });
      if (t.hp <= 0) killEnemy(w, t);
    } else { p.x += (dx / d) * m; p.y += (dy / d) * m; }
  }
  // cleanup
  compact(w.enemies, (e) => { if (!e.alive) w.enemyIdx.delete(e.id); return e.alive; }); compact(w.soldiers, (q) => { if (!q.alive) w.soldierIdx.delete(q.id); return q.alive; }); compact(w.projectiles, (p) => p.alive);
  w.tick++; w.time += DT;
  if (w.lives <= 0) { w.lives = 0; w.status = 'lost'; w.events.push({ type: 'lost' }); }
  else if (w.waveIndex >= w.map.waves.length && w.spawnQueue.length === 0 && w.enemies.length === 0) { w.status = 'won'; w.events.push({ type: 'won' }); }
}

/** In-place filter (no per-tick array allocation). */
function compact<T>(a: T[], keep: (x: T) => boolean): void { let j = 0; for (let i = 0; i < a.length; i++) { const x = a[i]; if (keep(x)) a[j++] = x; } a.length = j; }

function killEnemy(w: World, e: Enemy): void {
  if (!e.alive) return; e.alive = false; w.gold += ENEMIES[e.def].bounty; w.kills++; w.events.push({ type: 'death', x: e.x, y: e.y, id: e.id });
}

/** Stable 32-bit hash of the full simulation state (for replay/determinism tests). */
export function hashWorld(w: World): number {
  let h = 2166136261 >>> 0; const mix = (n: number) => { h ^= Math.round(n * 1000) | 0; h = Math.imul(h, 16777619) >>> 0; };
  mix(w.tick); mix(w.gold); mix(w.lives); mix(w.waveIndex); mix(w.waveTimer === Infinity ? -1 : w.waveTimer); mix(w.rng.s);
  for (const e of w.enemies) { mix(e.id); mix(e.hp); mix(e.d); }
  for (const s of w.soldiers) { mix(s.id); mix(s.hp); mix(s.x); mix(s.y); }
  for (const t of w.towers) { mix(t.id); mix(t.level); mix(t.cd); }
  for (const p of w.projectiles) { mix(p.id); mix(p.x); mix(p.y); }
  return h >>> 0;
}

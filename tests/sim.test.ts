import { describe, expect, it } from 'vitest';
import { createWorld, step, hashWorld, addEnemy, DT, type Command } from '../src/sim/world';
import { ENEMIES, BARRACKS } from '../src/sim/data';
import { DEFAULT_PLAN, playBot } from '../src/sim/bot';

const run = (w: ReturnType<typeof createWorld>, seconds: number, cmds: Command[] = []) => { for (let i = 0; i < seconds / DT; i++) step(w, i === 0 ? cmds : []); };

describe('economy & commands', () => {
  it('builds, upgrades and sells with correct gold flow', () => {
    const w = createWorld(1); const g0 = w.gold;
    step(w, [{ type: 'build', slot: 0, kind: 'archer' }]); expect(w.gold).toBe(g0 - 70); expect(w.towers.length).toBe(1);
    step(w, [{ type: 'build', slot: 0, kind: 'archer' }]); expect(w.towers.length).toBe(1); // slot occupied
    step(w, [{ type: 'upgrade', tower: w.towers[0].id }]); expect(w.gold).toBe(g0 - 70 - 110);
    step(w, [{ type: 'sell', tower: w.towers[0].id }]); expect(w.gold).toBe(g0 - 180 + Math.floor(180 * 0.8)); expect(w.towers.length).toBe(0);
  });
  it('rejects purchases without enough gold', () => {
    const w = createWorld(1); w.gold = 50; step(w, [{ type: 'build', slot: 0, kind: 'archer' }]); expect(w.towers.length).toBe(0); expect(w.gold).toBe(50);
  });
  it('early wave call pays gold equal to seconds skipped and recharges spells', () => {
    const w = createWorld(1); w.reinforceCd = 8; const t = w.waveTimer; const g = w.gold;
    step(w, [{ type: 'callWave' }]); expect(w.gold).toBeGreaterThanOrEqual(g + Math.ceil(t) - 1); expect(w.reinforceCd).toBe(Math.max(0, 8 - t));
    expect(w.waveIndex).toBe(1);
  });
});

describe('blocking', () => {
  it('a soldier stops an enemy; enemy resumes only after the soldier dies', () => {
    const w = createWorld(3); step(w, [{ type: 'build', slot: 1, kind: 'barracks' }]);
    run(w, 14); // soldiers spawned & at rally
    expect(w.soldiers.length).toBe(BARRACKS.soldiers);
    const t = w.towers[0]; const rp = t.rally;
    // put a lone strong orc on the rally point
    const orc = addEnemy(w, 'orc', 9999);
    const d0 = w.path.nearest(rp); void d0;
    orc.d = (() => { let best = 0, bd = Infinity; for (let d = 0; d < w.path.total; d += 1) { const p = w.path.at(d); const dd = Math.hypot(p.x - rp.x, p.y - rp.y); if (dd < bd) { bd = dd; best = d; } } return best; })();
    run(w, 1.0);
    expect(orc.blockedBy).not.toBeNull(); const dWhile = orc.d; run(w, 2); expect(orc.d).toBe(dWhile); // not moving while engaged
    for (const s of w.soldiers) s.hp = 0.0001;
    let last = orc.d, movedWhileGuarded = false, resumed = false;
    for (let i = 0; i < 10 / DT; i++) {
      const guarded = w.soldiers.length > 0; step(w);
      if (guarded && orc.blockedBy !== null && orc.d !== last) movedWhileGuarded = true;
      if (!guarded && orc.d > last) resumed = true; last = orc.d;
    }
    expect(movedWhileGuarded).toBe(false); // never walks past a living blocker (re-blocking works)
    expect(resumed).toBe(true); // walks on once every soldier is dead
    expect(ENEMIES.orc.speed).toBeGreaterThan(0);
  });
  it('barracks soldiers respawn after the respawn delay', () => {
    const w = createWorld(3); step(w, [{ type: 'build', slot: 1, kind: 'barracks' }]); run(w, 12);
    const s = w.soldiers[0]; s.hp = 0;
    // kill via damage path
    s.alive = false; w.towers[0].soldierIds[s.idx] = null; w.towers[0].respawn[s.idx] = BARRACKS.respawn; w.soldiers = w.soldiers.filter((q) => q.alive); w.soldierIdx.delete(s.id);
    run(w, BARRACKS.respawn + 1); expect(w.soldiers.length).toBe(BARRACKS.soldiers);
  });
});

describe('determinism', () => {
  it('same seed + same commands => identical state hash; different seed differs', () => {
    expect(playBot(7, DEFAULT_PLAN).hash).toBe(playBot(7, DEFAULT_PLAN).hash);
    expect(playBot(7, DEFAULT_PLAN).hash).not.toBe(playBot(8, DEFAULT_PLAN).hash);
  });
  it('state hash changes every tick while playing', () => {
    const w = createWorld(1); const a = hashWorld(w); step(w); expect(hashWorld(w)).not.toBe(a);
  });
});

describe('balance gates (bot)', () => {
  const win = (plan: Parameters<typeof playBot>[1], n = 12) => Array.from({ length: n }, (_, i) => playBot(i + 1, plan));
  it('doing nothing loses', () => { expect(playBot(1, null).status).toBe('lost'); });
  it('thin defenses lose (build choices matter)', () => {
    const thin = { builds: DEFAULT_PLAN.builds.slice(0, 3), callEarly: false };
    expect(win(thin, 6).every((r) => r.status === 'lost')).toBe(true);
    expect(win({ builds: [[1, 'archer'], [2, 'archer']], callEarly: false }, 6).every((r) => r.status === 'lost')).toBe(true);
    expect(win({ builds: [[1, 'barracks'], [4, 'barracks'], [0, 'barracks'], [6, 'barracks']], callEarly: false }, 6).every((r) => r.status === 'lost')).toBe(true);
  });
  it('a full greedy defense wins every seed but is not a free win', () => {
    const rs = win(DEFAULT_PLAN); expect(rs.every((r) => r.status === 'won'), JSON.stringify(rs.map((r) => r.lives))).toBe(true);
    const avg = rs.reduce((a, r) => a + r.lives, 0) / rs.length; expect(avg).toBeLessThan(15); expect(avg).toBeGreaterThan(2);
  });
  it('no single tower type is a free win', () => {
    const only = (kind: 'archer' | 'mage') => ({ builds: [[1, kind], [2, kind], [3, kind], [4, kind], [0, kind], [6, kind]] as [number, 'archer' | 'mage'][], callEarly: false });
    for (const k of ['archer', 'mage'] as const) { const rs = win(only(k)); const avg = rs.reduce((a, r) => a + r.lives, 0) / rs.length; expect(avg, k).toBeLessThan(15); }
  });
});

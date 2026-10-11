// Original game data (placeholder numbers; to be tuned by the balance bot). World space: 1280x720.
export interface Vec { x: number; y: number }
export type Dmg = [number, number];
export type EnemyId = 'goblin' | 'orc' | 'wolf';
export type TowerKind = 'archer' | 'barracks' | 'mage';

export interface EnemyDef { id: EnemyId; hp: number; speed: number; armor: number; resist: number; dmg: Dmg; atkEvery: number; bounty: number; lives: number; radius: number }
export const ENEMIES: Record<EnemyId, EnemyDef> = {
  goblin: { id: 'goblin', hp: 20, speed: 58, armor: 0, resist: 0, dmg: [1, 4], atkEvery: 1.0, bounty: 3, lives: 1, radius: 10 },
  orc: { id: 'orc', hp: 100, speed: 40, armor: 0.4, resist: 0, dmg: [4, 8], atkEvery: 1.1, bounty: 10, lives: 2, radius: 14 },
  wolf: { id: 'wolf', hp: 32, speed: 100, armor: 0, resist: 0.4, dmg: [2, 5], atkEvery: 0.9, bounty: 5, lives: 1, radius: 11 },
};

export interface ShooterLevel { cost: number; dmg: Dmg; cooldown: number; range: number }
export interface BarracksLevel { cost: number; hp: number; dmg: Dmg; armor: number; atkEvery: number }
export const SHOOTERS: Record<'archer' | 'mage', { magic: boolean; projSpeed: number; levels: ShooterLevel[] }> = {
  archer: { magic: false, projSpeed: 520, levels: [
    { cost: 70, dmg: [4, 6], cooldown: 0.8, range: 150 }, { cost: 110, dmg: [7, 11], cooldown: 0.6, range: 170 }, { cost: 160, dmg: [10, 16], cooldown: 0.5, range: 190 }] },
  mage: { magic: true, projSpeed: 380, levels: [
    { cost: 120, dmg: [12, 21], cooldown: 1.6, range: 150 }, { cost: 190, dmg: [30, 51], cooldown: 1.6, range: 165 }, { cost: 280, dmg: [54, 93], cooldown: 1.6, range: 180 }] },
};
export const BARRACKS: { levels: BarracksLevel[]; soldiers: number; respawn: number; rallyRange: number } = {
  levels: [
    { cost: 70, hp: 50, dmg: [1, 3], armor: 0, atkEvery: 1.0 }, { cost: 110, hp: 110, dmg: [3, 5], armor: 0.15, atkEvery: 1.0 }, { cost: 160, hp: 180, dmg: [6, 10], armor: 0.3, atkEvery: 1.0 }],
  soldiers: 3, respawn: 10, rallyRange: 130,
};
export const REINFORCE = { cooldown: 10, count: 2, life: 20, hp: 40, dmg: [1, 3] as Dmg, armor: 0, atkEvery: 1.0 };
export const SELL_REFUND = 0.8;
export const SOLDIER_SPEED = 95;
export const ENGAGE_RADIUS = 70;
export const LEASH_RADIUS = 110;
export const REACH = 16;

export interface WaveGroup { type: EnemyId; count: number; interval: number; delay: number }
export interface WaveDef { groups: WaveGroup[]; income: number; nextIn: number }
export interface MapDef { id: string; width: number; height: number; path: Vec[]; slots: Vec[]; startGold: number; startLives: number; waves: WaveDef[]; firstWaveIn: number }

export const MAP_FARMLANDS: MapDef = {
  id: 'farmlands', width: 1280, height: 720, startGold: 260, startLives: 20, firstWaveIn: 20,
  path: [{ x: -40, y: 540 }, { x: 210, y: 540 }, { x: 210, y: 300 }, { x: 540, y: 300 }, { x: 540, y: 570 }, { x: 880, y: 570 }, { x: 880, y: 230 }, { x: 1320, y: 230 }],
  slots: [{ x: 130, y: 440 }, { x: 300, y: 430 }, { x: 330, y: 210 }, { x: 440, y: 400 }, { x: 640, y: 440 }, { x: 710, y: 650 }, { x: 790, y: 400 }, { x: 980, y: 330 }, { x: 1040, y: 140 }],
  waves: [
    { income: 20, nextIn: 22, groups: [{ type: 'goblin', count: 8, interval: 1.3, delay: 0 }] },
    { income: 30, nextIn: 24, groups: [{ type: 'goblin', count: 12, interval: 1.0, delay: 0 }] },
    { income: 40, nextIn: 26, groups: [{ type: 'goblin', count: 8, interval: 1.0, delay: 0 }, { type: 'wolf', count: 5, interval: 0.9, delay: 4 }] },
    { income: 60, nextIn: 28, groups: [{ type: 'orc', count: 5, interval: 2.2, delay: 0 }, { type: 'goblin', count: 10, interval: 0.9, delay: 3 }] },
    { income: 70, nextIn: 28, groups: [{ type: 'wolf', count: 11, interval: 0.7, delay: 0 }, { type: 'goblin', count: 6, interval: 0.8, delay: 4 }] },
    { income: 90, nextIn: 30, groups: [{ type: 'orc', count: 8, interval: 1.8, delay: 0 }, { type: 'goblin', count: 14, interval: 0.7, delay: 5 }, { type: 'wolf', count: 5, interval: 0.8, delay: 12 }] },
    { income: 0, nextIn: 0, groups: [{ type: 'orc', count: 10, interval: 1.6, delay: 0 }, { type: 'wolf', count: 11, interval: 0.6, delay: 3 }, { type: 'goblin', count: 18, interval: 0.6, delay: 8 }] },
  ],
};

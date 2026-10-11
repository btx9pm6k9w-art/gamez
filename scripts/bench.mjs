// Runs the in-game 15 s stress benchmark in headless Chromium. NUMBERS HERE ARE SOFTWARE-GL (meaningless for Macs);
// this verifies the benchmark works. On your Mac: open the game and press B instead.
import { chromium } from 'playwright-core';
import { spawn } from 'node:child_process';
import { readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
const base = process.env.PW_BROWSERS_PATH || '/opt/pw-browsers'; const dir = readdirSync(base).filter((d) => /^chromium-\d+$/.test(d)).sort().pop();
const exe = [join(base, dir, 'chrome-linux', 'chrome'), join(base, dir, 'chrome-linux64', 'chrome')].find(existsSync);
const srv = spawn('npx', ['vite', 'preview', '--port', '4175', '--strictPort'], { stdio: 'ignore' }); await new Promise((r) => setTimeout(r, 2500));
const b = await chromium.launch({ executablePath: exe, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'] });
const p = await b.newPage({ viewport: { width: 1280, height: 720 } }); const errs = []; p.on('pageerror', (e) => errs.push(e.message));
await p.goto(`http://localhost:4175/?renderer=${process.env.RENDERER || 'webgl'}`); await p.waitForSelector('html[data-ready="1"]', { timeout: 60000 });
await p.keyboard.press('b'); await p.waitForFunction(() => window.__benchResult, null, { timeout: 60000 });
console.log(JSON.stringify(await p.evaluate(() => window.__benchResult), null, 1)); console.log('page errors:', errs.length ? errs.join('; ') : 'none');
await b.close(); srv.kill();

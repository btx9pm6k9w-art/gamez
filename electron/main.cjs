// Minimal Electron shell (macOS-first). Loads the Vite build (or the dev server when GAME_DEV_URL is set).
const { app, BrowserWindow } = require('electron');
const path = require('node:path');
app.commandLine.appendSwitch('ignore-gpu-blocklist');
app.whenReady().then(() => {
  const win = new BrowserWindow({ width: 1280, height: 720, backgroundColor: '#14182a', title: 'Gamez', webPreferences: { backgroundThrottling: false, contextIsolation: true } });
  if (process.env.GAME_DEV_URL) win.loadURL(process.env.GAME_DEV_URL); else win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
});
app.on('window-all-closed', () => app.quit());

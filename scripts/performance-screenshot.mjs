import { spawn, spawnSync } from 'node:child_process';
import { access, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// This opens only the standalone HTML report. It never launches Flutter Web.
const args = process.argv.slice(2);
const options = { report: 'build/performance/report.html', output: 'build/performance/report-preview.png' };
while (args.length) {
  const key = args.shift();
  if (!['--report', '--output'].includes(key) || !args.length) {
    throw new Error('Usage: node scripts/performance-screenshot.mjs [--report report.html] [--output image.png]');
  }
  options[key.slice(2)] = args.shift();
}
await access(options.report);
const browser = process.env.PERF_BROWSER ?? ['google-chrome', 'chromium', 'chromium-browser']
  .map((name) => spawnSync('which', [name], { encoding: 'utf8' }))
  .find((result) => result.status === 0)?.stdout.trim();
if (!browser) throw new Error('Chrome/Chromium required for the report image; set PERF_BROWSER to its executable path.');
const profile = await mkdtemp(resolve(tmpdir(), 'vanta-report-chrome-'));
const child = spawn(browser, [
  '--headless', '--no-sandbox', '--disable-gpu', '--no-first-run',
  '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });
let socket;
try {
  const endpoint = await new Promise((accept, reject) => {
    const timer = setTimeout(() => reject(new Error('Chrome startup timed out')), 20000);
    let stderr = '';
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
      const match = stderr.match(/DevTools listening on (ws:\/\/[^\s]+)/);
      if (match) { clearTimeout(timer); accept(match[1]); }
    });
    child.once('error', (error) => { clearTimeout(timer); reject(error); });
    child.once('exit', (code) => { clearTimeout(timer); reject(new Error(`Chrome exited ${code}: ${stderr}`)); });
  });
  socket = new WebSocket(endpoint);
  await new Promise((accept, reject) => {
    socket.addEventListener('open', accept, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  let serial = 0;
  const pending = new Map();
  socket.addEventListener('message', ({ data }) => {
    const message = JSON.parse(data);
    const request = pending.get(message.id);
    if (!request) return;
    pending.delete(message.id);
    clearTimeout(request.timer);
    if (message.error) request.reject(new Error(JSON.stringify(message.error)));
    else request.accept(message.result);
  });
  const send = (method, params = {}, sessionId) => new Promise((accept, reject) => {
    const id = ++serial;
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`Chrome command timed out: ${method}`));
    }, 20000);
    pending.set(id, { accept, reject, timer });
    socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  });
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  const page = (method, params) => send(method, params, sessionId);
  await page('Page.enable');
  await page('Emulation.setDeviceMetricsOverride', { width: 1440, height: 1100, deviceScaleFactor: 1, mobile: false });
  await page('Page.navigate', { url: pathToFileURL(resolve(options.report)).href });
  let ready = false;
  for (let attempt = 0; attempt < 100; attempt++) {
    const response = await page('Runtime.evaluate', {
      expression: 'document.readyState === "complete" && document.querySelectorAll("#summary tr").length > 1 && !!document.querySelector("#trend svg")',
      returnByValue: true,
    });
    if (response.result.value) { ready = true; break; }
    await new Promise((accept) => setTimeout(accept, 100));
  }
  if (!ready) throw new Error('Report did not render its table and charts');
  await page('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
  const { cssContentSize } = await page('Page.getLayoutMetrics');
  const width = Math.ceil(cssContentSize.width);
  const height = Math.ceil(cssContentSize.height);
  const { data } = await page('Page.captureScreenshot', {
    format: 'png', captureBeyondViewport: true,
    clip: { x: 0, y: 0, width, height, scale: 1 },
  });
  await mkdir(dirname(resolve(options.output)), { recursive: true });
  await writeFile(options.output, Buffer.from(data, 'base64'));
  console.log(`Full report image: ${options.output} (${width} × ${height}, includes table and charts)`);
} finally {
  socket?.close();
  const exited = new Promise((accept) => child.once('exit', accept));
  child.kill();
  await Promise.race([exited, new Promise((accept) => setTimeout(accept, 3000))]);
  try {
    await rm(profile, {
      recursive: true,
      force: true,
      maxRetries: 8,
      retryDelay: 100,
    });
  } catch (error) {
    // The report image is valid even if a late Chrome helper briefly keeps a
    // profile file open. The OS temporary directory remains the only residue.
    console.warn(`Could not remove temporary Chrome profile ${profile}: ${error.message}`);
  }
}

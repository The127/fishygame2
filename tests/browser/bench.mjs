// Browser bench: serves the Web export, loads it in headless Chromium with ?debug=1 and reports
// frame rate, draw calls and render objects per map with 20 fish, plus load timings.
// Software GL, so only compare runs on the same machine.
//
//   just export-web && cd tests/browser && npm ci && npx playwright install chromium && npm run bench
//
// Env: WEB_DIR, OUT_DIR, CHROMIUM_PATH, STEP_TIMEOUT_MS as in smoke.mjs; MAPS (comma list), SAMPLE_MS.
// Server and helpers below are copied from smoke.mjs.
import { chromium } from "playwright";
import { createServer } from "node:http";
import { readFile, mkdir } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = fileURLToPath(new URL(".", import.meta.url));
const webDir = resolve(process.env.WEB_DIR ?? join(here, "../../build/web"));
const outDir = resolve(process.env.OUT_DIR ?? join(here, "results"));
const stepTimeout = Number(process.env.STEP_TIMEOUT_MS ?? 90000);

const MIME = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
};

function serve() {
  const server = createServer(async (req, res) => {
    const path = new URL(req.url, "http://x").pathname;
    const file = normalize(join(webDir, path === "/" ? "index.html" : path));
    if (!file.startsWith(webDir)) {
      res.writeHead(403).end();
      return;
    }
    try {
      const body = await readFile(file);
      res.writeHead(200, { "content-type": MIME[extname(file)] ?? "application/octet-stream" });
      res.end(body);
    } catch {
      res.writeHead(404).end();
    }
  });
  return new Promise((ok) => server.listen(0, "127.0.0.1", () => ok(server)));
}

const problems = [];
const fail = (msg) => {
  problems.push(msg);
  console.error(`FAIL: ${msg}`);
};
const log = (msg) => console.log(`[bench] ${msg}`);

function watch(page) {
  page.on("console", (m) => {
    if (m.type() === "error") fail(`console error: ${m.text()}`);
    else if (m.type() === "warning") console.log(`[warn] ${m.text()}`);
  });
  page.on("pageerror", (e) => fail(`uncaught exception: ${e.message}`));
  page.on("requestfailed", (r) => fail(`request failed: ${r.url()} ${r.failure()?.errorText}`));
  page.on("response", (r) => {
    if (r.status() >= 400) fail(`HTTP ${r.status()} for ${r.url()}`);
  });
}

const state = (page) =>
  page.evaluate(() => (window.fishyTest?.state ? JSON.parse(window.fishyTest.state) : null));
const act = (page, ...args) => page.evaluate((a) => window.fishyTest.act(...a), args);

async function waitState(page, what, predicate, timeout = stepTimeout) {
  const deadline = Date.now() + timeout;
  let last = null;
  while (Date.now() < deadline) {
    last = await state(page);
    if (last && predicate(last)) return last;
    await page.waitForTimeout(100);
  }
  throw new Error(`timed out waiting for ${what}; last state: ${JSON.stringify(last)}`);
}

// Home screen -> race scene. Enter presses the focused "Open lobby" button.
async function openLobby(page, url) {
  await page.goto(url);
  await page.waitForSelector("canvas", { timeout: stepTimeout });
  // The canvas shows up before the engine is running, so keep pressing Enter until the
  // race scene (and with it the test bridge) is there.
  const deadline = Date.now() + stepTimeout;
  while (Date.now() < deadline) {
    await page.waitForTimeout(1000);
    await page.keyboard.press("Enter");
    const s = await state(page);
    if (s?.flow === "LOBBY") return s;
  }
  throw new Error("timed out waiting for lobby after Open lobby");
}

async function shot(page, name) {
  await page.screenshot({ path: join(outDir, `${name}.png`) });
}


const median = (a) => (a.length ? [...a].sort((x, y) => x - y)[Math.floor(a.length / 2)] : 0);
const SAMPLE_MS = Number(process.env.SAMPLE_MS ?? 10000);

async function sample(page, ms) {
  const rows = [];
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const s = await state(page);
    if (s?.perf) rows.push({ fps: s.fps, ...s.perf });
    await page.waitForTimeout(250);
  }
  const m = (k) => Number(median(rows.map((r) => r[k])).toFixed(2));
  return {
    fps: m("fps"),
    process_ms: m("process_ms"),
    physics_ms: m("physics_ms"),
    draw_calls: m("draw_calls"),
    objects: m("objects"),
    nodes: m("nodes"),
  };
}

async function main() {
  await mkdir(outDir, { recursive: true });
  const server = await serve();
  const url = `http://127.0.0.1:${server.address().port}/?debug=1`;
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || undefined,
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
  });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  await context.addInitScript(() => localStorage.setItem("fishygame2.onboarding_done", "1"));
  const page = await context.newPage();
  watch(page);
  const results = {};
  try {
    const t0 = Date.now();
    await page.goto(url);
    await page.waitForSelector("canvas", { timeout: stepTimeout });
    results.canvas_ms = Date.now() - t0;
    // Home screen: no test bridge there, so read frames from requestAnimationFrame.
    await page.waitForTimeout(8000);
    results.home_raf_fps = await page.evaluate(
      () => new Promise((ok) => { let n = 0; const t = performance.now();
        const f = () => { n++; if (performance.now() - t < 5000) requestAnimationFrame(f); else ok(n / 5); };
        requestAnimationFrame(f); }));
    await openLobby(page, url);
    results.lobby_ready_ms = Date.now() - t0;
    await act(page, "players", 20);
    await waitState(page, "20 players", (s) => s.players >= 20);
    const maps = (process.env.MAPS ?? "zigzag,pachinko,wreck,whirlpool,jelly,abyss,vents,coral,kraken,gravity,tide,fork,city,washer,whale,flush,switchback").split(",");
    results.maps = {};
    for (const map of maps) {
      log(`map ${map}`);
      await act(page, "map", map);
      await page.waitForTimeout(1500);
      await shot(page, `map-${map}`);
      await act(page, "start");
      await waitState(page, "racing", (s) => s.flow === "RACING");
      await page.waitForTimeout(2000);
      results.maps[map] = await sample(page, SAMPLE_MS);
      await shot(page, `race-${map}`);
      log(JSON.stringify(results.maps[map]));
      await act(page, "stop");
      await waitState(page, "idle", (s) => s.flow === "IDLE");
      await act(page, "open");
      await waitState(page, "lobby", (s) => s.flow === "LOBBY");
      await act(page, "players", 20);
      await waitState(page, "20 players", (s) => s.players >= 20);
    }
  } catch (e) {
    fail(String(e.message ?? e));
    await shot(page, "bench-error").catch(() => {});
  } finally {
    await browser.close();
    server.close();
  }
  console.log("BENCH " + JSON.stringify(results));
  if (problems.length) process.exit(1);
}

await main();

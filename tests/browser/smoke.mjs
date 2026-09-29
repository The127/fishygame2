// Browser smoke test: serves the Web export, loads it in headless Chromium with ?debug=1,
// plays a whole round and checks that points survive a page reload.
//
//   just export-web && cd tests/browser && npm ci && npx playwright install chromium && npm run smoke
//
// Set STRICT_RELOAD=1 to reload the moment the podium shows instead of waiting for the save
// to reach IndexedDB. That currently loses the payout (known issue), so CI leaves it off.
//
// Env: WEB_DIR (default ../../build/web), OUT_DIR (default ./results), CHROMIUM_PATH (use an
// already installed Chromium instead of the one Playwright downloaded), STEP_TIMEOUT_MS.
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
const log = (msg) => console.log(`[smoke] ${msg}`);

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
  await page.waitForTimeout(1500);
  await page.keyboard.press("Enter");
  return waitState(page, "lobby after Open lobby", (s) => s.flow === "LOBBY");
}

// Contents of the saved points file as Godot's IDBFS holds it, or null.
const savedPoints = (page) =>
  page.evaluate(
    () =>
      new Promise((done) => {
        const open = indexedDB.open("/userfs");
        open.onerror = () => done(null);
        open.onsuccess = () => {
          const db = open.result;
          if (!db.objectStoreNames.contains("FILE_DATA")) return done(null);
          const cursor = db.transaction("FILE_DATA").objectStore("FILE_DATA").openCursor();
          cursor.onsuccess = () => {
            const c = cursor.result;
            if (!c) return done(null);
            if (String(c.key).endsWith("/points.json") && c.value.contents) {
              return done(new TextDecoder().decode(c.value.contents));
            }
            c.continue();
          };
          cursor.onerror = () => done(null);
        };
      }),
  );

async function waitForSavedBalance(page, user, balance) {
  const deadline = Date.now() + stepTimeout;
  let last = null;
  while (Date.now() < deadline) {
    last = await savedPoints(page);
    try {
      const saved = JSON.parse(last);
      if (saved.balances[user] === balance && Object.keys(saved.stakes).length === 0) return;
    } catch {}
    await page.waitForTimeout(250);
  }
  throw new Error(`${user}=${balance} never reached IndexedDB; last saved: ${last}`);
}

async function shot(page, name) {
  await page.screenshot({ path: join(outDir, `${name}.png`) });
}

async function main() {
  await mkdir(outDir, { recursive: true });
  const server = await serve();
  const url = `http://127.0.0.1:${server.address().port}/?debug=1`;
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || undefined,
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
  });
  // One persistent context so IndexedDB (user://) survives the reload like it does for a streamer.
  const context = await browser.newContext({ viewport: { width: 1920, height: 1080 } });
  const page = await context.newPage();
  watch(page);

  try {
    log("home screen -> lobby");
    await shot(page, "00-home-pending").catch(() => {});
    await openLobby(page, url);
    await shot(page, "01-lobby");

    log("filling the lobby (3 debug players + alice + bob)");
    await act(page, "players", 3);
    await act(page, "chat", "alice", "#join");
    await act(page, "chat", "bob", "#join");
    await waitState(page, "5 players", (s) => s.players === 5);

    log("alice bets 100 on bob");
    await act(page, "chat", "alice", "#bet bob 100");
    const afterBet = await waitState(page, "bet taken", (s) => s.balances.alice === 900);
    if (afterBet.bet_rejections.length) fail(`bet rejected: ${afterBet.bet_rejections}`);

    log("start race");
    await act(page, "start");
    await waitState(page, "racing", (s) => s.flow === "RACING" || s.flow === "COUNTDOWN");
    await page.waitForTimeout(3000);
    await shot(page, "02-race");
    const podium = await waitState(page, "podium", (s) => s.podiums >= 1);
    await page.waitForTimeout(500);
    await shot(page, "03-podium");
    if (podium.podium.length < 1) fail("podium was empty");
    log(`podium: ${podium.podium.join(", ")}`);
    const settled = podium.balances.alice;
    if (settled === 1000 || (settled !== 900 && settled !== 1400)) {
      fail(`unexpected settled balance for alice: ${settled} (expected 900 or 1400)`);
    }

    if (process.env.STRICT_RELOAD) {
      log("STRICT_RELOAD: reloading right away");
    } else {
      // Godot writes IndexedDB asynchronously, so give it time. Reloading right away loses
      // the payout (see STRICT_RELOAD in the header comment).
      await waitForSavedBalance(page, "alice", settled);
    }
    log(`reload with alice at ${settled}`);
    await openLobby(page, url);
    await act(page, "chat", "alice", "#points");
    const reloaded = await waitState(page, "alice balance after reload", (s) => "alice" in s.balances);
    if (reloaded.balances.alice !== settled) {
      fail(`points lost across reload: alice had ${settled}, now ${reloaded.balances.alice}`);
    }
    await shot(page, "04-after-reload");
  } catch (e) {
    fail(String(e.message ?? e));
    await shot(page, "error").catch(() => {});
  } finally {
    await browser.close();
    server.close();
  }

  if (problems.length) {
    console.error(`\n${problems.length} problem(s)`);
    process.exit(1);
  }
  log("ok");
}

await main();

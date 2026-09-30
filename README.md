# FishyMarbleRun 2

A Twitch-integrated marble race with fish, built in Godot 4 for the browser (OBS browser source).
It replaces fishygame 1 (a React/Express overlay) with a real physics marble race.

## Requirements

- [Godot 4.7.x](https://godotengine.org/download) (standard build, GDScript only)
- Web export templates for the same version (Editor > Manage Export Templates)

## Open

Import `project.godot` from the Godot project manager, or run `godot --editor` in the repo root.

## Run

Press F5 in the editor, or from the command line:

```sh
godot            # runs the main scene (scenes/main.tscn)
```

The project uses a 1920x1080 viewport with `canvas_items` stretch and a transparent
background, so it can sit over a stream.

## Export (Web)

The `Web` preset in `export_presets.cfg` builds without threads, so no COOP/COEP headers
are needed. Output goes to `build/web/index.html`.

```sh
just export-web   # or: godot --headless --export-release Web build/web/index.html
```

Exporting needs the Godot 4.7.x Web export templates (Editor > Manage Export Templates,
or unpack the matching `.tpz` into `~/.local/share/godot/export_templates/4.7.x.stable/`),
otherwise it fails with "No export template found".

The preset injects a small style (`html/head_include`) that makes the page background
transparent, so only what the game draws shows up in OBS. To check, add the browser source
over a colorful scene: empty areas should show the scene underneath, not black.

Serve `build/web/` with any static file server and add the URL as an OBS browser source
(1920x1080). Serving over HTTP is required; opening the file directly will not work.

## Hosted build (GitHub Pages)

Every push to `main` that passes CI is deployed to GitHub Pages by the `deploy-pages` job in
`.github/workflows/ci.yml`:

**<https://the127.github.io/fishygame2/>**

Add that URL as an OBS browser source (1920x1080), then follow "Twitch login" below. The game is
served from the `/fishygame2/` subpath; all asset paths are relative and the Twitch login redirect is
built from the page's own origin and path, so nothing needs configuring for the subpath.

One-time repo setup (owner): **Settings > Pages > Build and deployment > Source: GitHub Actions**.
Without it the deploy job fails with "Pages not enabled". Forks get their own URL,
`https://<owner>.github.io/<repo>/`.

## Browser smoke test

CI loads the Web export in headless Chromium (Playwright), plays a whole round with fake players and a
bet, and reloads the page to check that points persist. It drives the game through `window.fishyTest`,
which only exists in the web build with `?debug=1` (`scripts/debug/web_test_bridge.gd`). Screenshots
are uploaded as the `browser-smoke-screenshots` artifact.

```sh
just export-web
cd tests/browser && npm ci && npx playwright install chromium   # once
just smoke                                                       # or: npm run smoke
```

`CHROMIUM_PATH` uses an installed Chromium instead of Playwright's. The test reloads right after
the podium, so it also checks that points survive a quick reload.

## Streamer powers

During a race the streamer has three powers of their own, free but rationed: a fishing rod that
yanks the nearest fish back up the track, a net that holds fish in an area for a moment, and a
bubble blast that shoves nearby fish away. Press 1, 2 or 3 (or the panel buttons) to arm one, then
left click the spot; right click or the same key cancels. A shared cooldown and a cap per race
apply, and everything is in the settings (Streamer powers tab). Using a power shows an overlay
notice and a chat line. Races where the streamer used a power can't be replayed from their seed;
seed-only races (the debug race and the CI seed sweeps) never use powers.

## Sound

`Sound` (autoload) plays an ambient music loop and effects for join, countdown, race start,
boost, curse, finish and podium. Each map also has a quiet ambience bed (creaking timbers,
geyser rumble, sonar pings and so on) and its own win jingle at the podium. The control panel
(the top tab or F1 toggles it) has Master, Music, Ambience and Effects sliders and a mute switch;
they are saved in `user://audio.cfg` (browser storage in the web build). All audio is generated
by `tools/generate_audio.py`, see `assets/audio/README.md`.

Browsers block audio until the first click or key press; the game resumes it on that input, so
clicking "Open lobby" on the home screen is enough. OBS browser sources normally allow autoplay;
if there is no sound, tick "Control audio via OBS" on the source and check it is not muted in
the OBS audio mixer.

## Twitch login (streamer setup)

On first launch the game shows a short setup guide (Twitch app, login, OBS, safe areas, debug
mode). Skipping or finishing it is remembered per browser source; reopen it from Settings >
Setup guide. The steps below are the same information in full.

The game reads chat over Twitch EventSub and posts replies through the Twitch API, so it needs a
token for the streamer's account. There is no backend: the browser logs in with the OAuth
implicit grant and keeps the token in its own `localStorage`.

One-time setup, done by whoever hosts the game (once, not per streamer):

1. Register an app at <https://dev.twitch.tv/console/apps>.
2. Add an **OAuth Redirect URL** that is exactly the address the game is opened at, without query
   or fragment. For the hosted build that is `https://the127.github.io/fishygame2/` (keep the
   trailing slash). For your own host or testing, e.g. `https://fish.example.com/` or `http://localhost:8000/`;
   if you open `.../index.html`, register that). It must match what the browser shows, or Twitch
   refuses the login.
3. Category: Game Integration, client type: Public. Copy the **Client ID** (it is not a secret;
   never put a client secret anywhere in this project).

Each streamer, once (and again whenever the login expires):

1. Add the game URL as an OBS browser source, right-click it and choose **Interact**.
2. On the home screen paste the client id, press **Log in with Twitch**, and approve the scopes
   `user:read:chat` and `user:write:chat`. The screen then shows "Logged in as <name>".
3. Press **Open lobby**. The login survives reloads of the browser source.

Notes:

- The token is stored only in that browser source's `localStorage`, next to the game. Anyone who
  can open the OBS browser source's Interact window or its profile can use it; **Log out** on the
  home screen revokes it at Twitch and deletes it. Do not screen-share that window while logged in.
- On GitHub Pages the origin is `the127.github.io`, shared by every Pages site of that account, so
  they can read the same `localStorage`. Only host code you trust there.
- Implicit tokens expire (Twitch decides when, typically hours) and cannot be refreshed. When it
  runs out, or Twitch rejects it, the home screen says so and the streamer logs in again.
- Login uses the account's own channel: the token owner is the broadcaster and the chat sender.
- Login always asks Twitch to show the account chooser, so check you approve the right account.
- The older way still works and takes precedence over a stored login when the page loads: pass `client_id`, `token`,
  `broadcaster_id` (and optionally `user_id`) as URL query parameters, or use `user://twitch.cfg`
  on desktop. The Twitch login button only works in the web build.

## Debug mode

The +1/+5 fake player buttons and the fake chat fallback only exist in debug mode, so they never
show up on stream. On the web build add `?debug=1` to the URL. Desktop editor and debug builds
have it on automatically.

## Development commands

Install the dev tools once: `pip install -r requirements-dev.txt` (gdtoolkit, pinned) and
[just](https://github.com/casey/just). Every recipe uses `godot` from `PATH`; override with
`GODOT=/path/to/godot just <recipe>`. CI runs these same recipes' commands.

| Command           | What it does                                                        |
| ----------------- | ------------------------------------------------------------------- |
| `just test`       | Headless import, then the [GUT](https://github.com/bitwes/Gut) suite in `tests/` |
| `just lint`       | `gdformat --check` and `gdlint` over `scripts/` and `tests/`        |
| `just format`     | `gdformat` over `scripts/` and `tests/`                             |
| `just export-web` | Web export to `build/web/`                                          |

Tests live in `tests/` as `test_*.gd` files extending `GutTest` (config: `.gutconfig.json`).
`addons/` (including the vendored GUT 9.7.1) is excluded from lint and format. `gdlint` allows lines up to 240 columns (gdformat wraps code at 100) so long literals such as recorded JSON do not need suppression; prefer JSON fixture files under `tests/` when data is large.

Maps live in `scenes/tracks/` and are registered in `scripts/tracks/track_catalog.gd`. The
control panel's Map picker chooses one for the next race (default Random, never the same map
twice in a row). To check a map for jams, run full races headless over many seeds:

```sh
tests/run_race_seeds.sh godot 1 100                  # every map, 10 marbles, seeds 1..100
MARBLES=20 tests/run_race_seeds.sh godot 1 100 pachinko
```

Every map has a hazard (`scripts/tracks/hazard.gd`): a current on Zigzag, an eel on Pachinko and
collapsing planks on Shipwreck, a cross current on Volcanic Vents, a surge that spins up the vortex on
Whirlpool and a tide that sloshes the flip gates on Coral Maze. The Jellyfish
Field map also has a permanent gimmick: glowing jellyfish drift on paths drawn from the race seed
and kick marbles away like very bouncy bumpers. Their tentacles briefly catch and drag along any fish that
touches them (then let go, and ignore that fish for a few seconds). The hazard is a surge that speeds them up.
Abyss has an unstable portal that throws fish back and two big anglerfish that lunge at fish in
reach, swallow them and spit them out again at an earlier ramp a moment later (a fish is eaten at
most once per race). Events are planned from the race seed, so a seed replays the same
ones, and the seed runs above have them on (frequency 3). Pass `--hazards=0` to
`scenes/debug/race_debug.tscn` to run without them. Streamers turn them off or change how often
they strike in Settings > Race.

Volcanic Vents also has timed geysers (`scripts/tracks/geyser.gd`) that throw marbles upward and
sideways. They belong to the map, so they erupt whatever the hazard setting is. Each vent's phase and
period come from the race seed, so a seed replays the same eruptions.

Coral Maze's gimmick is the flip gate (`scripts/tracks/flip_gate.gd`): a tilting paddle under a
ledge that flips every time a fish rolls off it, so the order fish arrive in decides which of the
four routes each one takes. Gates start in the same state every race, so a seed replays the same
routes.

Basic sanity checks:

```sh
godot --headless --import   # (re)import assets; must finish without errors
godot --headless --quit     # loads the project and exits; must be clean
```

## CI

`.github/workflows/ci.yml` runs on pushes to `main` and on all pull requests: lint/format,
headless GUT tests, a Web export uploaded as the `web-build` artifact, and the browser smoke test.
On `main`, the export is then deployed to GitHub Pages. The Godot version
is set once in the `GODOT_VERSION` env var at the top of the workflow.

## Layout

| Folder     | Contents                     |
| ---------- | ---------------------------- |
| `scenes/`  | `.tscn` scenes               |
| `scripts/` | GDScript files               |
| `assets/`  | Art, audio, fonts            |
| `tests/`   | Tests                        |
| `addons/`  | Third-party editor plugins   |

See [CLAUDE.md](CLAUDE.md) for coding conventions.

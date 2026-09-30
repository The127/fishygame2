# FishyMarbleRun 2

A Twitch-integrated marble race with fish, built in Godot 4 for the browser (OBS browser source).
It replaces fishygame 1 (a React/Express overlay) with a real physics marble race.

**Streaming with it?** See the [streamer guide](docs/STREAMER_GUIDE.md).

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

## Treasures

Each race scatters 2 to 4 glowing treasures on the map: a coin (15 points), a pearl (25) or a chest
(50). The first fish to touch one takes it, with a sparkle and the amount floating up, and its
viewer is paid when the race ends normally (a stopped round pays nothing). Finders show in the chat
result line and count in `#stats`. Purely visual: a treasure never pushes a fish. Where they lie is
a function of the race seed. A map lists its spots as `Marker2D` children of a `TreasureSpots` node,
ordered along the route fish really take; maps without one use the centerline. Turn them off in the
settings (Race tab).

## Sound

`Sound` (autoload) plays an ambient music loop and effects for join, countdown, race start,
boost, curse, finish and podium. Each map also has a quiet ambience bed (creaking timbers,
geyser rumble, sonar pings and so on) and its own win jingle at the podium. The control panel
(the top tab or F1 toggles it) has Master, Music, Ambience and Effects sliders and a mute switch;
they are saved in `user://audio.cfg` (browser storage in the web build). All audio is generated
by `tools/generate_audio.py`, see `assets/audio/README.md`.

Browsers block audio until the first click or key press; the game resumes it on that input, so
clicking "Open lobby" on the home screen is enough. Until then a small "Click anywhere to enable
sound" note shows at the bottom of the screen, and it disappears after the first click.

The web export must keep `audio/general/default_playback_type.web=0` (stream playback) in
`project.godot`. Godot's default for the web, sample playback, plays nothing with the Music,
Ambience and SFX buses used here.

OBS browser source (streamer):

- Audio is captured per browser source. In the source's properties tick **Control audio via OBS**;
  the source then gets its own track in the Audio Mixer, where you set its volume and make sure it
  is not muted. Without that option the sound goes to the desktop audio instead (or nowhere).
- OBS's browser (CEF) normally lets pages autoplay, so no click is needed. If the hint note shows
  in OBS, right-click the source, choose **Interact** and click once inside the window.
- After changing the audio options, reload the source (Refresh cache of current page).

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
EVENT=low_gravity tests/run_race_seeds.sh godot 1 20 zigzag  # under a random event
```

Random events (Settings, Betting & Chaos tab, off by default): a wheel spins during the countdown of every
race and lands mostly on nothing, sometimes on a modifier (low gravity, double hazards, lights out,
bouncy, Thanos snap: half the fish turn to dust mid-race and are DNF). Modifiers change rules without drawing from the race seed (`scripts/game/race_event.gd`);
`--event=<id>` on the debug race scene replays one.

Every map has a hazard (`scripts/tracks/hazard.gd`): a current on Zigzag, an eel on Pachinko (a tall machine with three peg levels: a dense field, a sparse one with pulsing bumpers and one of spinners) and
collapsing planks on Shipwreck, a cross current on Volcanic Vents and Gravity Flip, a surge that spins up the vortex on
Whirlpool, a tide that sloshes the flip gates on Coral Maze, tentacle swats on Kraken's Lair, a rip current on Ebb Tide, ruined towers that come down when the fish arrive on Sunken City and a flush on Toilet Flush. The Jellyfish

Whirlpool, a tide that sloshes the flip gates on Coral Maze, tentacle swats on Kraken's Lair, a rip current on Ebb Tide and a spin cycle on Washing Machine and a burp jet on Inside the Whale. The Jellyfish
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

Kraken's Lair has three switchback ramps under the gaze of a huge kraken eye. Its hazard
(`scripts/tracks/kraken_hazard.gd`) is a swat: a dashed arc and the eye snapping open warn that
one to three of the four tentacles rooted below the frame are about to sweep across the ramps and fling
every fish they touch sideways, forwards or back. The sweeps are a force field rather than a solid
body, so a fish is thrown along instead of being crushed. The kraken strikes often (about five times
in a typical race) and is never still in between: the eye follows the leading fish
(`scripts/tracks/kraken_eye.gd`) and dim idle tentacles curl and probe in the deep
(`scripts/tracks/kraken_lurkers.gd`, drawn from a clock the finish replay records).
Gravity Flip turns the whole room every 3 to 4 seconds (`scripts/tracks/gravity_flipper.gd`): an Area2D
that points gravity at the floor, the ceiling, the wall toward the finish or (rarely, and weaker) the wall
behind the start, so walls become floors and the ceiling becomes the floor. The course is three
partitions with one-way valve doors (fish pass toward the finish, never back), each room split into an
upper and a lower lane by a tilted shelf. A door is in the top or the bottom of its partition (the last one has both), so a fish
has to change lane in most rooms, and only some pulls carry it there: a shelf that funnels fish to the
gap under one pull is a hill under the other. Pulls toward the finish lean up or down by seed. There is
no countdown or arrow: for the last 1.2 seconds gravity thins out to a weightless beat, the debris
hangs still and the wall that is about to become the floor charges with light. Flip times, sides and
leans come from the race seed. The finish spans the whole height, so every orientation reaches it.
The flipper joins the finish replay (the side, the charge, the wave and the debris are replayed).

Ebb Tide is a race against the map: the water starts above everything and drains from the top
down (`scripts/tracks/water_level.gd`). A fish that lies above the waterline for two seconds is
stranded: it flops, fades away and is DNF, like a fish caught by the Thanos snap. The drain is tuned
so that a few of the slowest fish are caught in a normal field and takes a little longer for bigger
fields. If the tide strands everyone, the race ends as a normal "nobody finished". Its hazard is a
rip current that only ever flows with the lane. The debug race prints `stranded=N` and the
seed sweeps do not count stranded fish as a jam, so check a map change with the drain turned off
(set `drain_seconds` very high) to be sure no fish really gets stuck. The finish replay shows the
waterline, the rip current and stranded fish (hop and fade) as they were; the rocking of a flopping
fish and its gasp flashes are not replayed.

Fork Reef has three separate starts (`SpawnOrigin` and the markers under `Starts` in
`scenes/tracks/fork_track.tscn`). Each race deals the fish out evenly between them by seed
(`Track.plan_starts`), and each start has its own route: a short steep one with bumpers and geysers,
a middle one with two ledges and a long safe one. The routes merge into a funnel above a shared
finish run. Progress on a multi-start map is measured along one `Feeders` path per start for the
first `merge_progress` of the scale and along `Centerline` (merge point to finish) for the rest.
The debug race prints each marble's start (`starts=`) so a seed sweep can report results per start.

Sunken City is a drowned ruin where the towers come down as the fish arrive (`scripts/tracks/ruin_hazard.gd`).
There is no event timer: every ruin has an invisible trigger zone (an `Area2D` named `Trigger`) on the
lane just upstream of it, and the first fish to enter it sets the ruin off. The tower shakes and
lets dust fall, then topples and crashes, shoving any fish in its sweep (an `Area2D` named `Sweep`)
up and forward, and throwing the fish near its tip when it lands. Ruins run on their own, so several
can be coming down at once. The crash changes the floor until the race ends. On the first two ruins
a cap stone in lane A crumbles away and leaves a gap: a shortcut to the lane below. The next two
start with an open gap in lane B and a slab hanging above it, and the crash drops the slab into the
gap and seals it. The last five ruins have no gap: the tower shatters on the lane (two on the long
upper lanes, three on the bottom lane) and leaves a heap of rubble that is scenery only, because a
fish at rest cannot climb any step on these gentle lanes and nothing may block it. The race seed
decides which ruins are live in a race (more of them at higher hazard levels, all of them at the top
level) and how long each hesitates after its trigger; where the fish are decides the rest. With hazards
off nothing moves, so every state has to stay passable. A ruin is a child of the hazard with a
`Tower` (scenery, never collides), a `Slab` (the `AnimatableBody2D` that moves), a `Trigger`, a
`Sweep` and metadata for `mode` (`open`, `close` or `topple`), `lie_degrees` and `height`. The finish
replay shows the shaking and falling towers, the slabs, the rubble and the dust of the crash.

Washing Machine is circles inside circles: the fish start in the middle of three nested steel rings
(`scripts/tracks/wash_drum.gd`, one `WashDrum` node per ring under the spin cycle hazard). Every ring
tumbles like a real washer: it swings about 250 to 300 degrees, slows and swings back, over and over,
so the load never rides the wall for long. Neighbouring rings swing opposite ways at their own pace
(3.5, 5 and 7 seconds a swing), each with a door gap in the rim. A fish drops through a door when it
sweeps past the bottom, into the channel of the next ring out, and out of the last door onto two
drain lanes that lead to the finish. There are deliberately no baffles inside: a pocket carries its
fish round with the door and they never meet, which trapped fish for minutes in testing. Each ring
waits a seeded moment before it starts and never jumps, so a rim can not hit a fish. The hazard is a
spin cycle (`scripts/tracks/spin_cycle_hazard.gd`): the rings whirl through one or two whole laps
(each by its own whole multiple, sometimes counterclockwise), then drop back into their tumble
exactly where they were. The rings keep tumbling when hazards are off. The race centerline starts on
the left of the first lane so fish dropping onto it never read as nearly finished (the follow cam
chases the leader by progress along that line).

Inside the Whale swallows the fish at the start: a throat slide drops into a stomach whose
pink muscle lobes swell and relax (`scripts/tracks/pulsing_bumper.gd`, the pulse starts at a point
drawn from the race seed) and whose digestive pools slow any fish that wades through them
(`digestive_pool.gd`, a drag and a little buoyancy, never a stop). A gut in the last intestine
squeezes fish along all the time (`peristalsis.gd`). The hazard is a burp jet that shoves fish
along one of the three lanes at a seeded moment. At the finish a blowhole (`blowhole.gd`) throws
every fish that has crossed the line up into the air, and leaves the ones still racing alone.

Toilet Flush starts with a slide into a porcelain bowl (`scripts/tracks/flush_bowl.gd`, a `Whirlpool`
with one drain at the bottom and a shorter dwell). Its hazard is the flush: the lever on the cistern
swings down and the vortex spins up. The drain leads into a sewer pipe: a rubber duck
(`scripts/tracks/duck_bumper.gd`) bobs in a chamber above the first lane, a propeller turns in the
second, and a second hazard, a surge, pushes the pack along one of the two lanes (always forward).
The duck's starting point comes from the race seed and both the duck and the lever are replayed in
the finish replay. The finish zone starts on the last stretch of the second lane and covers the pit
at the end, so a pile of finished fish does not hold back the ones still to arrive.

### Finish replay and moving map parts

The finish replay (`scripts/race/finish_replay.gd`) plays back a short recorded clip around the
winner's crossing. Besides the fish it replays everything on the map that moves, so a new map
must make its moving parts replayable or they will stand wherever they ended up during playback.
Hazards (anything extending `Hazard`) are replayable already: the event clock and phase are
recorded for free, and a hazard that draws more than that overrides `_replay_extra()` and
`_apply_replay_extra()` (see `scripts/tracks/whirlpool.gd` for a small example).

Any other moving node opts in with the hook in `scripts/race/replayable.gd`:

```gdscript
func _ready() -> void:
	Replayable.join(self)

## Everything that decides how the node looks right now, as a fixed number of floats.
func replay_state() -> PackedFloat32Array:
	return PackedFloat32Array([position.x, position.y, _phase])

## Show the state `weight` (0 to 1) of the way from recorded state `from` to the next one, `to`.
func replay_apply(from: PackedFloat32Array, to: PackedFloat32Array, weight: float) -> void:
	position = Replayable.mix_vector(from, to, weight, 0)
	_phase = Replayable.step(from, to, weight, 2)  # `step` for flags and indices, `mix` for smooth values
```

Put the state on the node that owns it (a hazard records its jellyfish, lures and so on itself).
A node that draws something to the fish (the jellyfish crackle to a caught fish) records the fish's
id in its state, and gets the replayed fish (id to `Marble`) through an optional
`replay_fish(fish: Dictionary)` method to look up where to draw.
While a replay plays, the node's `_process` and `_physics_process` are switched off and `AnimatableBody2D`s stop
syncing to physics, so nothing moves on its own; afterwards the node gets back the state it had
before. Keep the state small (a few dozen floats): it is stored about 30 times a second. Fish
that vanish during the clip (swallowed by an anglerfish, Thanos snap) are replayed too. Particle
bursts are not, unless they are recorded as a `ReplayRecorder.Kind` event: the anglerfish and
portals and trapdoor planks do that by emitting `burst_played`, which `Track` forwards and `Race` records
as a `BURST`.

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

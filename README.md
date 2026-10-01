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
Whirlpool, a tremor that shakes the flip gates on Crystal Cave, tentacle swats on Kraken's Lair, a rip current on Ebb Tide, ruined towers that come down when the fish arrive on Sunken City and a flush on Toilet Flush, a backwash that tips a ramp on Switchback, overgrowth on Coral Garden and a tilt on Pinball Reef (somebody bumps the cabinet and every fish is shoved back and forth sideways, `scripts/tracks/tilt_hazard.gd`) and an aftershock on Earthquake Fault (the floor shudders and hops every fish, `scripts/tracks/aftershock_hazard.gd`) and a restless ghost that stirs up an eddy on Riptide Rounds. The Jellyfish

Whirlpool, a tremor that shakes the flip gates on Crystal Cave, tentacle swats on Kraken's Lair, a rip current on Ebb Tide and a spin cycle on Washing Machine and a burp jet on Inside the Whale. The Jellyfish
Field map also has a permanent gimmick: glowing jellyfish drift on paths drawn from the race seed
and kick marbles away like very bouncy bumpers. Their tentacles briefly catch and drag along any fish that
touches them (then let go, and ignore that fish for a few seconds). The hazard is a surge that speeds them up.
The field is four stacked sections, about 2800 px tall (the camera follows the pack down; the overview
zooms out to fit it), joined by drops: a gap in the middle, one against the left wall, one against the right
wall, then the finish funnel. A map taller than one screen sets `view_bounds` to its real size and
`TrackStyle` repeats the parallax layers, extends the sky and lowers the foreground floor shapes to match.
Keep the floors at roughly 10 degrees or steeper (fish stall on shallower ones) and the jellyfish well clear of the floors.
Abyss has an unstable portal that throws fish back and two big anglerfish that lunge at fish in
reach, swallow them and spit them out again at an earlier ramp a moment later (a fish is eaten at
most once per race). Events are planned from the race seed, so a seed replays the same
ones, and the seed runs above have them on (frequency 3). Pass `--hazards=0` to
`scenes/debug/race_debug.tscn` to run without them. Streamers turn them off or change how often
they strike in Settings > Race.

Shipwreck's ship sinks while the fish race (`scripts/tracks/ship_sinking.gd`). Four trigger zones
along the route (the `Zones` under `Sinking` in `scenes/tracks/wreck_track.tscn`) start the stages:
the first fish into a zone brings the next stage, and a fish that skips a zone brings every stage up
to its own. Each stage leans gravity a little further over (toward a side the race seed picks; the
hull behind the decks leans with it, exaggerated) and raises the floodwater, which damps every fish
under it. Stages are never undone, so the lean and the water only grow. The water hurts whoever
gets down there first, which gives the pack a chance to catch up. The finish replay records the
lean, the waterline and the stage, and ignores the replayed fish crossing the zones.

Volcanic Vents also has timed geysers (`scripts/tracks/geyser.gd`) that throw marbles upward and
sideways. They belong to the map, so they erupt whatever the hazard setting is. Each vent's phase and
period come from the race seed, so a seed replays the same eruptions.

Crystal Cave's gimmick is the flip gate (`scripts/tracks/flip_gate.gd`): a tilting paddle under a
ledge that flips every time a fish rolls off it, so the order fish arrive in decides which of the
four routes each one takes. Gates start in the same state every race, so a seed replays the same
routes.

Coral Garden is about living coral (`scripts/tracks/coral_hazard.gd`, one `scripts/tracks/coral_bed.gd`
per opening). The lanes have openings in them that drop fish to the lane below, and the first fish
into the trigger zone on the lane just above an opening wakes the coral there: the polyps glow,
then the coral grows across the opening over a few seconds and stays until the race is over. So
the way the leader took closes behind it, and the fish further back drop through the openings that
are still free or ride the lane to its end, which is never closed. The growth belongs to the map and
runs whatever the hazard setting is (like geysers). The hazard is overgrowth: now and then a bed that still sleeps wakes and
grows shut without any fish. The plugs are thin and slide in along the lane (`AnimatableBody2D`), so a fish is brushed
on, never crushed. Seeds decide how long each bed hesitates and when overgrowth strikes; the finish
replay shows the beds mid growth.

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

Switchback is three long ramps that pivot about their middle (`scripts/tracks/switchback_ramp.gd`).
Somewhere along each ramp, at a spot drawn from the race seed, sits an invisible trigger zone: the
first fish to reach it makes the slab shudder and glow for half a second, then the slab swings to the
opposite slope and everything on it rolls back the way it came. After a short hold it swings back.
Nothing on screen counts down, the shudder is the warning. A ramp flips at most twice per race, each
hold is bounded, and nothing flips after 45 seconds, so a flip can cost fish time but never trap them.
The hazard (`scripts/tracks/switchback_hazard.gd`) is a backwash that tips one ramp without a fish
touching its trigger, and the same node plans the triggers of every ramp from the race seed. The
finish replay shows the ramps tipping as recorded.

Ebb Tide is a race against the map: the water starts above everything and drains from the top
down (`scripts/tracks/water_level.gd`). A fish that lies above the waterline for two seconds is
stranded: it flops, fades away and is DNF, like a fish caught by the Thanos snap. The drain is tuned
so that a few of the slowest fish are caught in a normal field and takes a little longer for bigger
fields. If the tide strands everyone, the race ends as a normal "nobody finished". Invisible
`TideTrigger` zones (`scripts/tracks/tide_trigger.gd`) are spread along the course: the first fish
through one is the furthest along, and the water crashes down to that trigger's `level_y` and holds
there until the steady drain catches up. A trigger fires once per race and only ever lowers the
water, so a long lead shortens everyone else's time. Levels are tuned to sit just above the tail
of the pack (20 fish strand 0 to 4 per race), so set them from seed sweeps, not by eye. Its hazard
is a rip current that only ever flows with the lane. The debug race prints `stranded=N` and the
seed sweeps do not count stranded fish as a jam, so check a map change with the drain turned off
(set `drain_seconds` very high and every trigger's `level_y` very negative) to be sure no fish really gets stuck. The finish replay shows the
waterline (and the surface flare while it crashes down), the rip current and stranded fish (hop and fade) as they were; the rocking of a flopping
fish and its gasp flashes are not replayed.

Fork Reef has three separate starts (`SpawnOrigin` and the markers under `Starts` in
`scenes/tracks/fork_track.tscn`). Each race deals the fish out evenly between them by seed
(`Track.plan_starts`), and each start has its own route: a short steep one with bumpers and geysers,
a middle one with two ledges and a long safe one. The routes merge into a funnel, and under the funnel
gap a switch (a `FlipGate`, directly under the map) sends the fish alternately down the Rapids on the
left (a long steep ramp with geysers, short but bumpy) or along the Long Road on the right (the
gentle tail). Each route has a trapdoor (`scripts/tracks/trap_door.gd`): a hinged floor plate that
glows, swings open for a moment and drops the fish above it onto the floor below, skipping the
rest of that route. Door phases come from the race seed (`reseed`, like the geysers) and a door
that was never armed stays shut. The finish is two shapes: the box at the end of the Long Road and a
band under the end of the Rapids, placed so a fish registers before it can touch the pile of fish
that already finished. Progress on a multi-start map is measured along one `Feeders` path per start for the
first `merge_progress` of the scale and along `Centerline` (merge point to finish) for the rest.
A map can split again after the merge: every `Path2D` under a `Branches` node is another route from the
merge point to the finish, and a fish is measured along whichever route it is nearest to (Fork Reef's
`Rapids`). The debug race prints each marble's start (`starts=`) so a seed sweep can report results
per start.

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
The city also has two permanent set pieces: three bronze bells hung above the lanes (`PulsingBumper`,
seeded like the stomach lobes of Inside the Whale) that swell and shove nearby fish, and a flooded
plaza on the first lane (`scripts/tracks/drift_zone.gd`) whose slow current only ever pushes along
the lane. Neither can block a fish: the bells hang clear of the lanes and the current never pushes back.

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

Two acid pits (`scripts/tracks/acid_pit.gd`) cut through the stomach floor and the start of the
intestine. A stone hatch covers each pit and sinks into the acid for about a second every seven or
eight seconds, glowing green just before (the seed picks where in its cycle it starts). A fish that
touches the acid is dissolved at once: `Marble.dissolve()` fizzes it away, it is out of the race
for good (`Marble.is_out()`, a DNF like a snapped or stranded fish, ranked behind every other DNF),
`Race.fish_dissolved` and a stream notice announce it, and the pit draws its skeleton, which sinks
into the liquid. The acid takes every fish that touches it, so nothing can get stuck in a pit. A
pit keeps its newest six skeletons. Pit and skeletons run on the pit's own race clock and are part
of the finish replay (`replay_state()` holds the clock, the cycle shift and the skeleton slots). A
typical 10-fish race loses two or three fish to the pits; `race_debug` prints `dissolved=N` in its
`RESULT` line.

The whale is alive. A huge mouth (`whale_mouth.gd`, in a slow parallax layer behind the map) gapes
above the throat, with daylight beyond its teeth: the jaws breathe open and closed, the tongue sways,
and a hazard can make it yawn by setting `WhaleMouth.yawn`. The two long stretches of stomach floor
(`wiggling_floor.gd`) ripple with a muscle wave that runs with the fish. The wave is smaller than the
slope it lies on, so the floor never turns uphill and no dip can trap a fish, and it fades to nothing
at both ends so it joins the acid pit hatches and the rest of the floor. The floor builds its colliders
from a top line (`surface`), so a new rippling stretch is one `WigglingFloor` node with a `Visual`
Polygon2D. Mouth and floor run on the physics clock, the wave is seeded and both are part of the finish
replay.

The whale also gulps (`gulp_hazard.gd`, the `gulp` event). The telegraph is the mouth in the
background yawning wide (the hazard emits `yawn_changed`, the scene connects it to the mouth); then a
rush of water drags sea junk (`gulp_debris.gd`: barrels, crates, planks) in through the top of the map
and it tumbles down the throat as real bodies that bump the fish. The junk is a small pool created once,
so a gulp never allocates in a race. Junk that lands in an acid pit dissolves, anything else fizzles
out after ten seconds, so it can never clog the map. The pool is part of the finish replay.

Toilet Flush starts with a slide into a porcelain bowl (`scripts/tracks/flush_bowl.gd`, a `Whirlpool`
with one drain at the bottom and a shorter dwell). Its hazard is the flush: the lever on the cistern
swings down and the vortex spins up. The drain leads into a sewer pipe: a rubber duck
(`scripts/tracks/duck_bumper.gd`) bobs in a chamber above the first lane, a propeller turns in the
second, and a second hazard, a surge, pushes the pack along one of the two lanes (always forward).
The duck's starting point comes from the race seed and both the duck and the lever are replayed in
the finish replay. The finish zone starts on the last stretch of the second lane and covers the pit
at the end, so a pile of finished fish does not hold back the ones still to arrive.

Pinball Reef is the map chat plays. A plunger shoots the pack up the lane on the right, a current at
the top carries it out over the table, and the fish work down through ten bumpers that pop them away
and three banks of flippers (`scripts/tracks/pinball_table.gd`, `pinball_flipper.gd`) to the drain,
which is the finish. Any viewer, joined or not, types `#left` or `#right` to fire that side's
flippers, which fling every fish lying on the blades up and toward the middle (`FlipperCommands`
turns the chat line into a request, `Game` passes it to the map, which owns the cooldowns). A side
can fire once every 0.6 s, every press counts on a small tally in the top left, and when chat has
been quiet for a few seconds the flippers fire by themselves on a schedule drawn from the race seed.
With no chat input a seed replays the same race, so the seed sweeps and CI run on auto-fire only.
The finish replay records the blade angles, the plunger and the bumper glow through the generic
replay hook; the tally and the fish names on it are not replayed. Fish sometimes get flung back up a
bank, so races take 10 to 45 seconds with auto-fire only.

Earthquake Fault is the other map chat plays. The fish zigzag down three rock shelves with four
cracks in them (`scripts/tracks/fault_crack.gd`), each shut with a plug of rock until a quake splits
it. Two are shortcuts, holes right through a shelf that drop the fish onto the shelf below. Two are
pits, hollows full of rubble that slow the fish and push them on out the far side, so none is ever
trapped. Viewers type `#shake` (`ShakeCommands` turns the chat line into a request, `Game` passes it
to the fault, `scripts/tracks/quake_fault.gd`). When enough of them have shaken inside 8 seconds,
the ground rumbles for a moment and then a crack opens, the view jolts and every fish is thrown
about. The presses needed are 40% of the joined viewers (at least 3, at most 12), one viewer counts
for at most two, a meter in the top left shows how close it is, and a quake has a 12 second cooldown.
Which crack opens is a seeded order, taking the first one the pack has not passed yet. If chat stays
quiet, one quake still happens at a time drawn from the race seed (6 to 11 s), so the seed sweeps
and CI run on that automatic quake only. `race_debug.tscn --shake` has made-up viewers spam `#shake`
for a manual check. The cracks and the fault use the generic replay hook, so the finish replay shows
the plugs falling away (the meter and the view shake are not replayed). The map's random event is an
aftershock, which hops the fish but never opens a crack. Races take 20 to 50 seconds.
Floor parts that are not direct children of the track join the stone look through the group
`track_stone`.

Riptide Rounds is a looping map and the one round race (`scripts/race/race_rounds.gd`). The fish are carried round a
stadium-shaped channel by a current, with no gravity and no slopes (`scripts/tracks/ring_channel.gd` builds the loop and the
walls, `scripts/tracks/ring_current.gd` is the water: fastest down the middle, with slow crests that travel against it and a small
seeded knack for each fish). A race is `laps` laps (three here). When the lap line has been crossed by everyone but the
slowest third of the fish still racing (a third, rounded down, never the last two fish) after lap 1 and after lap 2, the rest
are cut. The last lap is a plain finish. A cut fish is out of the race for good: it counts as unfinished (ranked by how far
it got), so results, the 100/50/25 payouts and stats treat it like a stranded fish. It is drained into the still lagoon at the
middle of the ring and waits there as a ghost (`scripts/tracks/eddy_ring.gd`). Its viewer types `#eddy` (`scripts/game/haunt.gd`,
free, a cooldown per viewer, at most three eddies at a time) and the ghost flies out and spins for five seconds as an eddy
(a small whirlpool, tangential drag and a pull to the middle) on the lane a little ahead of the leader, shoving and slowing
the fish that swim through it. The ghosts are the cut fish themselves (frozen `Marble`s that the map moves), so the finish
replay shows them; the swirls record their own state through `Replayable`. The finish is the lap line, so fish that finish
are taken out of the physics and wait in the lagoon too, instead of circling among the others. Nothing on this map is a timer:
the cut is the lap line itself. The camera keeps the whole ring in view (`Track.follow_camera`). To make another map a round
race give its `Track` a closed `Centerline` and `laps`. It has no timed hazard: the eddies are its hazard. The debug race
(and so the seed sweeps) has a cut fish send an eddy every two seconds, standing in for chat; `--eddies=0` turns that off.

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

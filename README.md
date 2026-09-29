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

## Docker

The image exports the Web build with a checksum-verified headless Godot and serves it with nginx.

```sh
docker build -t fishygame2 .
docker run --rm -p 8080:80 fishygame2
```

Open <http://localhost:8080>, or use that URL as an OBS browser source (1920x1080).
CI builds the image on every PR and pushes it to `ghcr.io/the127/fishygame2` (`latest` and the
commit SHA) on pushes to `main`:

```sh
docker run --rm -p 8080:80 ghcr.io/the127/fishygame2:latest
```

The Godot version and checksums in the `Dockerfile` must match `.github/workflows/ci.yml`.

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

Basic sanity checks:

```sh
godot --headless --import   # (re)import assets; must finish without errors
godot --headless --quit     # loads the project and exits; must be clean
```

## CI

`.github/workflows/ci.yml` runs on pushes to `main` and on all pull requests: lint/format,
headless GUT tests, and a Web export uploaded as the `web-build` artifact. The Godot version
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

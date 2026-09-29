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
mkdir -p build/web
godot --headless --export-release Web build/web/index.html
```

Exporting needs the Godot 4.7.x Web export templates (Editor > Manage Export Templates,
or unpack the matching `.tpz` into `~/.local/share/godot/export_templates/4.7.x.stable/`),
otherwise it fails with "No export template found".

The preset injects a small style (`html/head_include`) that makes the page background
transparent, so only what the game draws shows up in OBS. To check, add the browser source
over a colorful scene: empty areas should show the scene underneath, not black.

Serve `build/web/` with any static file server and add the URL as an OBS browser source
(1920x1080). Serving over HTTP is required; opening the file directly will not work.

## Checks

```sh
godot --headless --import   # (re)import assets; must finish without errors
godot --headless --quit     # loads the project and exits; must be clean
```

## Layout

| Folder     | Contents                     |
| ---------- | ---------------------------- |
| `scenes/`  | `.tscn` scenes               |
| `scripts/` | GDScript files               |
| `assets/`  | Art, audio, fonts            |
| `tests/`   | Tests                        |
| `addons/`  | Third-party editor plugins   |

See [CLAUDE.md](CLAUDE.md) for coding conventions.

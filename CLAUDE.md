# Project conventions

Godot 4.7.x, GDScript only. Runs in the browser (Web export, no threads) as an OBS browser source.

## GDScript

- Static typing everywhere: typed variables, parameters and return types (`var speed: float = 1.0`, `func foo(x: int) -> void`).
- Files are `snake_case.gd`; scenes are `snake_case.tscn`.
- One class per file, declared with `class_name` in PascalCase matching the file name (`marble_racer.gd` -> `MarbleRacer`).
- Use signals to communicate across systems; do not reach into other systems with direct node references or `get_node` paths. Parents may call down to their own children.
- Autoloads only for true singletons (global services with exactly one instance). Prefer scene-local nodes otherwise.

## Layout

- `scenes/`, `scripts/`, `assets/`, `tests/`, `addons/`. Main scene: `scenes/main.tscn`.
- Commit `*.import` files; do not commit `.godot/` or `build/`.

## Checks before committing

```sh
godot --headless --import
godot --headless --quit
```

Both must run with no errors.

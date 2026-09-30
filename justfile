# Same commands CI runs. Override the engine binary with: GODOT=/path/to/godot just test
godot := env_var_or_default("GODOT", "godot")

default:
    @just --list

# Import the project, then run the GUT test suite headless (fails on any test failure).
test:
    {{godot}} --headless --import
    GODOT={{godot}} tools/run_tests.sh

# gdformat --check and gdlint over scripts/ and tests/.
lint:
    gdformat --check scripts tests
    gdlint scripts tests

# Auto-format scripts/ and tests/.
format:
    gdformat scripts tests

# Export the Web build to build/web/.
export-web:
    mkdir -p build/web
    {{godot}} --headless --import
    {{godot}} --headless --export-release Web build/web/index.html

# Play a round in headless Chromium against build/web (run `just export-web` first).
# Needs Node and, once, `cd tests/browser && npm ci && npx playwright install chromium`.
smoke:
    cd tests/browser && npm run smoke

# Frame rate, draw calls and render objects per map with 20 fish in headless Chromium against build/web.
# Numbers are relative only (software GL). MAPS=zigzag,cave limits the maps, SAMPLE_MS the sample length.
bench:
    cd tests/browser && npm run bench

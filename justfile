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

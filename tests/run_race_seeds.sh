#!/bin/sh
# Headless race check: runs a full 10-marble race per seed and fails if any marble times out.
# Usage: tests/run_race_seeds.sh [godot-binary] [first-seed] [last-seed]
GODOT="${1:-godot}"
FIRST="${2:-1}"
LAST="${3:-10}"
status=0
OUT="$(mktemp)"
for seed in $(seq "$FIRST" "$LAST"); do
	"$GODOT" --headless --fixed-fps 60 res://scenes/debug/race_debug.tscn -- --autorun --seed="$seed" > "$OUT" 2>&1 || status=1; grep RESULT "$OUT"
done
exit $status

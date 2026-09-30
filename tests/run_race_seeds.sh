#!/bin/sh
# Headless race check: runs a full race per seed and map, and fails if any marble times out.
# Usage: tests/run_race_seeds.sh [godot-binary] [first-seed] [last-seed] [maps]
# MARBLES (env, default 10) sets the field size. EVENT (env, default none) runs every race under that random event. `maps` is a space-separated list of map ids (default: every map in TrackCatalog, listed by tools/print_map_ids.gd).
GODOT="${1:-godot}"
FIRST="${2:-1}"
LAST="${3:-10}"
MAPS="${4:-$("$GODOT" --headless -s tools/print_map_ids.gd 2>/dev/null | tail -n 1)}"
[ -n "$MAPS" ] || { echo "could not list maps from TrackCatalog"; exit 1; }
MARBLES="${MARBLES:-10}"
EVENT="${EVENT:-}"
status=0
OUT="$(mktemp)"
for map in $MAPS; do
	for seed in $(seq "$FIRST" "$LAST"); do
		"$GODOT" --headless --fixed-fps 60 res://scenes/debug/race_debug.tscn -- --autorun --seed="$seed" --map="$map" --count="$MARBLES" ${EVENT:+--event="$EVENT"} > "$OUT" 2>&1 || status=1
		grep -E "RESULT|ERROR" "$OUT" || { echo "no result for map=$map seed=$seed"; status=1; }
		! grep -q "ERROR" "$OUT" || status=1
	done
done
rm -f "$OUT"
exit $status

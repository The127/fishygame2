#!/usr/bin/env bash
# Runs the GUT suite headless. GUT skips test scripts that fail to parse
# without failing the run, so treat any script error as a failure too.
#
# SHARD (1-based) and SHARDS split the test scripts round-robin so CI can run
# them in parallel jobs. Without them the whole suite runs.
set -uo pipefail
GODOT="${GODOT:-godot}"
SHARD="${SHARD:-1}"
SHARDS="${SHARDS:-1}"
log="$(mktemp)"
args=()
if [ "$SHARDS" -gt 1 ]; then
	config="$(mktemp)"
	tests="$(find tests -name 'test_*.gd' | sort | awk -v s="$SHARD" -v n="$SHARDS" '(NR - 1) % n == s - 1 { print "res://" $0 }')"
	jq -n --arg tests "$tests" '{dirs: [], tests: ($tests | split("\n")), should_exit: true, should_exit_on_success: true, log_level: 1}' > "$config"
	echo "Shard $SHARD of $SHARDS: $(echo "$tests" | wc -l) test scripts"
	args+=("-gconfig=$config")
fi
"$GODOT" --headless -s addons/gut/gut_cmdln.gd ${args[@]+"${args[@]}"} 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Ignoring script" "$log"; then
	echo "Test run had script errors (see above)." >&2
	status=1
fi
rm -f "$log" "${config:-}"
exit "$status"

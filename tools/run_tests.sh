#!/usr/bin/env bash
# Runs the GUT suite headless. GUT skips test scripts that fail to parse
# without failing the run, so treat any script error as a failure too.
set -uo pipefail
GODOT="${GODOT:-godot}"
log="$(mktemp)"
"$GODOT" --headless -s addons/gut/gut_cmdln.gd 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Ignoring script" "$log"; then
	echo "Test run had script errors (see above)." >&2
	status=1
fi
rm -f "$log"
exit "$status"

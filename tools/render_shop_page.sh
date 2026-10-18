#!/usr/bin/env bash
# Renders the static shop page (shop.html and shop/*.webp) into a web build folder.
# Usage: tools/render_shop_page.sh [out-dir]   (default build/web; run after the import)
# Needs Xvfb: the previews are drawn by the real renderer, which --headless doesn't have.
# A hung renderer is stopped after 5 minutes rather than holding the CI job.
set -uo pipefail
GODOT="${GODOT:-godot}"
out="${1:-build/web}"
log="$(mktemp)"
timeout 300 xvfb-run -a -s "-screen 0 640x480x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 10 \
	--script tools/render_shop_page.gd -- --out="$out" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
# A GDScript error doesn't change Godot's exit code, so treat any as a failure.
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$log"; then
	echo "render_shop_page.sh: the render had script errors (see above)." >&2
	status=1
fi
grep -q "^Shop page: " "$log" || status=1
rm -f "$log"
exit "$status"

#!/usr/bin/env bash
# Writes the commit and UTC build time into scripts/game/build_info.gd, for the release export.
# Usage: tools/stamp_build.sh <full-commit-sha>
# GNU sed (CI runner); it edits the tracked file, so do not commit the result.
set -euo pipefail
sha="${1:?usage: stamp_build.sh <commit-sha>}"
file="$(dirname "$0")/../scripts/game/build_info.gd"
[[ "$sha" =~ ^[0-9a-f]{7,40}$ ]] || { echo "stamp_build.sh: not a commit sha: $sha" >&2; exit 1; }
short="${sha:0:7}"
built="$(date -u '+%Y-%m-%d %H:%M UTC')"
sed -i \
  -e "s|^const COMMIT: String = \".*\"|const COMMIT: String = \"${short}\"|" \
  -e "s|^const BUILT_AT: String = \".*\"|const BUILT_AT: String = \"${built}\"|" \
  "$file"
grep -q "\"${short}\"" "$file" && grep -q "\"${built}\"" "$file" || { echo "stamp_build.sh: could not stamp $file" >&2; exit 1; }

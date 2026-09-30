#!/usr/bin/env bash
# Writes the commit and UTC build time into scripts/game/build_info.gd, for the release export.
# Usage: tools/stamp_build.sh <full-commit-sha>
set -euo pipefail
sha="${1:?usage: stamp_build.sh <commit-sha>}"
file="$(dirname "$0")/../scripts/game/build_info.gd"
short="${sha:0:7}"
built="$(date -u '+%Y-%m-%d %H:%M UTC')"
sed -i \
  -e "s|^const COMMIT: String = \".*\"|const COMMIT: String = \"${short}\"|" \
  -e "s|^const BUILT_AT: String = \".*\"|const BUILT_AT: String = \"${built}\"|" \
  "$file"
grep -q "\"${short}\"" "$file" && grep -q "\"${built}\"" "$file"

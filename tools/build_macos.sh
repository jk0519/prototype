#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN=${GODOT:-godot}
mkdir -p builds
touch builds/.gdignore
"$GODOT_BIN" --headless --path . --editor --import --quit
"$GODOT_BIN" --headless --path . --script res://tools/write_engine_notices.gd
"$GODOT_BIN" --headless --path . --export-release macOS
# The exporter may attach Finder icon metadata to the bundle directory.
# Remove that cosmetic attribute so Apple's strict signature check passes.
if xattr -p com.apple.FinderInfo builds/SIDEOUT.app >/dev/null 2>&1; then
    xattr -d com.apple.FinderInfo builds/SIDEOUT.app
fi
codesign --verify --deep --strict builds/SIDEOUT.app
ditto -c -k --sequesterRsrc --keepParent builds/SIDEOUT.app builds/SIDEOUT-Mac.zip

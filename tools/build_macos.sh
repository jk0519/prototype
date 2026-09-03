#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN=${GODOT:-godot}
mkdir -p builds
touch builds/.gdignore
"$GODOT_BIN" --headless --path . --editor --import --quit
"$GODOT_BIN" --headless --path . --script res://tools/write_engine_notices.gd
"$GODOT_BIN" --headless --path . --export-release macOS
# A cloud-backed workspace may attach empty Finder icon metadata faster than it
# can be verified. Stage outside that workspace, remove that cosmetic attribute,
# verify the exact signed app, and omit external metadata from the release zip.
STAGE_DIR=$(mktemp -d /private/tmp/sideout-sign.XXXXXX)
mv builds/SIDEOUT.app "$STAGE_DIR/SIDEOUT.app"
if xattr -p com.apple.FinderInfo "$STAGE_DIR/SIDEOUT.app" >/dev/null 2>&1; then
    xattr -d com.apple.FinderInfo "$STAGE_DIR/SIDEOUT.app"
fi
codesign --verify --deep --strict "$STAGE_DIR/SIDEOUT.app"
ditto -c -k --norsrc --keepParent "$STAGE_DIR/SIDEOUT.app" builds/SIDEOUT-Mac.zip
mv "$STAGE_DIR/SIDEOUT.app" builds/SIDEOUT.app
rmdir "$STAGE_DIR"

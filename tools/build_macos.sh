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
# File Provider may attach FinderInfo or provenance to nested bundle files.
# Neither is part of the signed application, so clear all extended metadata.
xattr -cr "$STAGE_DIR/SIDEOUT.app"
codesign --verify --deep --strict "$STAGE_DIR/SIDEOUT.app"
ditto -c -k --norsrc --keepParent "$STAGE_DIR/SIDEOUT.app" builds/SIDEOUT-Mac.zip
# Verify the downloadable artifact after extraction. This is the exact bundle a
# user receives, without File Provider metadata from the workspace directory.
VERIFY_DIR=$(mktemp -d /private/tmp/sideout-verify.XXXXXX)
ditto -x -k builds/SIDEOUT-Mac.zip "$VERIFY_DIR"
codesign --verify --deep --strict "$VERIFY_DIR/SIDEOUT.app"
rm -rf "$VERIFY_DIR"
mv "$STAGE_DIR/SIDEOUT.app" builds/SIDEOUT.app
rmdir "$STAGE_DIR"
# Moving the verified app back into a File Provider folder can immediately add
# an empty FinderInfo attribute. Remove that cosmetic metadata once more so the
# app stored in builds/ passes the same strict verification as the release zip.
xattr -cr builds/SIDEOUT.app

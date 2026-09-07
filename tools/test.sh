#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN=${GODOT:-godot}
"$GODOT_BIN" --headless --path . --editor --import --quit
"$GODOT_BIN" --headless --path . --script res://tests/simulation_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/integration_test.gd -- --mute
"$GODOT_BIN" --headless --path . --script res://tests/audio_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/contact_regression.gd
"$GODOT_BIN" --headless --path . --script res://tests/pose_regression.gd

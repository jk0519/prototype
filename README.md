# SIDEOUT — first playable

A Mac-first, 2D volleyball prototype inspired by the basic play of The Spike: six athletes, one human wing spiker, and five AI players. Built in **Godot 4.7.2**, with original placeholder characters, a moving camera, and synthesized sound.

## Play on Mac

Unzip the Mac build and open **SIDEOUT.app**, then choose **Play match**. Godot does not need to be installed to play the exported app. The universal app includes Apple Silicon and Intel executables.

The exported engine requires macOS 13 or later on Apple Silicon, or macOS 11 or later on Intel. The build is ad-hoc signed and has not been notarized by Apple.

You are the blue **#7 wing spiker**, marked **YOU**. Your setter (#2) and middle blocker (#11) play automatically. The orange team is controlled by AI. Win one set to **15 points, with a two-point lead**.

| Input | Action |
| --- | --- |
| A / D or left / right arrows | Move |
| Z | Jump; press again in the air to swing |
| Z, then Z again | Toss/jump and hit your serve |
| Hold Space | Receive and pass |
| Hold X | Jump to block |
| C | Slide/dive in your movement direction |
| Esc | Pause/resume |
| F11 | Toggle fullscreen (some Mac keyboards require Fn) |

The first serve is yours. Press **Z**, then press **Z again during the jump**, while the ball is near your hand. After serving, move into the court. For an attack, approach the net on your side, jump as your setter's ball rises, then press Z again when the ball reaches your hand. Moving toward the net as you hit aims the spike shorter; moving away aims deeper. Hold Space before a low ball arrives to pass it to the setter.

Keyboard bindings, sound, impact effects, and the optional landing guide are available under **Controls & settings** and are saved between sessions. Pause also provides restart and main-menu buttons; a completed match offers a rematch.

## What is implemented

- Two teams of three, each with a wing spiker, setter, and middle blocker.
- Human control of the left wing spiker; five AI players use the same movement and contact mechanics.
- AI receiving, setting, attacking, blocking, serving, diving, and a fallback setter when the normal setter takes the first touch.
- Running, jumping, timed air swings, ground receives, blocks, and dives.
- Ball gravity, contact areas, a solid net, floor/out detection, three-touch and double-touch faults, and block touches that keep the ball live.
- Role-based passing and set arcs, with actual contact timing determining whether a hit succeeds.
- A full serve/rally/point/match-result loop, rotating servers on side-out, score display, and win-by-two scoring.
- Smooth camera movement and zoom, player/action indicators, ball trail, simple character action poses, sound effects, and menus.

This is an arcade baseline. Roles stay in fixed formations; it does not implement regulation six-player rotations, back-row restrictions, or every official fault. AI difficulty and jump/spike timing need human playtesting. Teammates use simple ball/role rules; there is no call-for-set input. Online play, touch controls, player switching, progression, and finished art are outside this version.

## Open the project

1. Install [Godot 4.7.2 Standard](https://godotengine.org/download/archive/4.7.2-stable/) for macOS. The .NET edition is unnecessary.
2. Import `project.godot` into Godot, then press **F6** on the main scene or **F5** to run the project.
3. To export a Mac app, install the matching export templates through Godot's **Manage Export Templates** dialog, then use the **macOS** export preset.

The repository contains the complete editable project. It has no package-manager dependencies or external art downloads. Godot's generated `.godot` cache and application builds are excluded from version control.

## Development and verification

With the Godot executable on your path:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/simulation_test.gd
godot --headless --path . --script res://tests/integration_test.gd
godot --headless --path . --export-release macOS
```

`GODOT=/path/to/Godot tools/build_macos.sh` builds and zips the Mac app. `tools/test.sh` runs both test suites using the same `GODOT` override. See [QA.md](QA.md) for the checks and current validation limits, and [ARCHITECTURE.md](ARCHITECTURE.md) for the code layout.

The optional **Web QA** preset runs the same scene for browser-based visual/input checks. It is not the primary delivery target. Windows, Android, and iOS exports can reuse the simulation and player model, but are not configured or tested yet.

## Engine notices

Godot and its bundled third-party dependencies retain their respective licenses. The generated `assets/engine_notices.txt` contains the notices reported by this engine version. All court graphics and character shapes in this project are drawn by its own code.

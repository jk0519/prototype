# SIDEOUT — arcade impact prototype

A Mac-first, 2D volleyball prototype inspired by the basic play of The Spike: six athletes, one human wing spiker, and five AI players. Built in **Godot 4.7.2**, with small faceless athletes, deliberately extreme arcade motion, a reactive camera, and recorded court audio.

## Play on Mac

Unzip the Mac build and open **SIDEOUT.app**, then choose **Play match**. Godot does not need to be installed to play the exported app. The universal app includes Apple Silicon and Intel executables.

The exported engine requires macOS 13 or later on Apple Silicon, or macOS 11 or later on Intel. The build is ad-hoc signed and has not been notarized by Apple.

You are the blue **#7 wing spiker**, marked **YOU**. Your setter (#2) and middle blocker (#11) play automatically. The orange team is controlled by AI. Win one set to **15 points, with a two-point lead**.

| Input | Action |
| --- | --- |
| A / D or left / right arrows | Move |
| Z | Jump; press again in the air to swing |
| Hold X before your serve | Charge toss distance; release X to throw the ball |
| W / S or up / down arrows while charging | Higher / lower toss |
| Hold Space | Receive and pass |
| Hold X | Jump to block |
| C | Slide/dive in your movement direction |
| Esc | Pause/resume |
| F11 | Toggle fullscreen (some Mac keyboards require Fn) |

The first serve is yours. Move freely behind the baseline with **A/D**. **Hold X** to charge a longer forward toss, adjust its height with **W/S** or the up/down arrows, then **release X** to throw it. Movement stays active while X is held and during the throwing motion, so you can build a run-up before the ball leaves your hand. Press **Z** to plant and jump as the ball starts descending, then press **Z again** when it reaches your striking hand. Tossing does not jump automatically. An untouched toss loses the point; the serve must be hit in the air. After serving, move into the court. For an attack, approach the net on your side, jump as your setter's ball rises, then press Z again when the ball reaches your hand. Moving toward the net as you hit aims the spike shorter; moving away aims deeper. Hold Space before a low ball arrives to pass it to the setter.

Spike and serve results depend on contact. The strongest hit comes from pressing Z so the hand reaches the ball during the torso snap and lining up the ball horizontally with the palm. Contact quality changes the real launch speed, hit audio, short flash, directional streak, camera kick, slight pullback, and impact hold. The HUD keeps your best hit speed for the match.

Keyboard bindings, separate court/crowd volume sliders, sound, impact effects, and the optional landing guide are available under **Controls & settings** and are saved between sessions. Pause also provides restart and main-menu buttons; a completed match offers a rematch.

## What is implemented

- Two teams of three, each with a wing spiker, setter, and middle blocker.
- Human control of the left wing spiker; five AI players use the same movement and contact mechanics.
- AI receiving, ground and jump setting, attacking, blocking, serving, earlier emergency dives, and a fallback setter when the normal setter takes the first touch.
- Adjustable jump serves with a displayed parabola, hand-led toss motion, movable charge and windup, approach, foot plant, takeoff, timed contact, follow-through, and landing compression. AI servers use the same mechanics.
- Hold duration controls forward toss distance while W/S controls vertical height. A/D remains horizontal movement through every serve phase; the live charge and height meters show the resulting arc.
- Near-instant acceleration, very high jumps, rapid plants and recoveries, running strides tied to distance, timed air swings, ground receives, blocks, and fast horizontal dives.
- Exaggerated ball gravity, severe serve and spike topspin, generous action contact areas, a solid net, floor/out detection, three-touch and double-touch faults, and block touches that keep the ball live. Clean jump serves launch at extreme speed before dropping violently into the back court.
- Role-based passing and oversized set arcs, including airborne setter contacts, with actual contact timing determining whether a hit succeeds.
- A full serve/rally/point/match-result loop, rotating servers on side-out, score display, and win-by-two scoring. Ordinary points stay on the live court and flow into the next serve after a compact score tick.
- Six small, faceless 2D athletes use a 32-frame action atlas. Normal 1280-pixel-wide play targets a roughly 45–65-pixel visible athlete height while separate run, spike, jump-serve, receive, jump-set, block, dive, and recovery sequences make the silhouettes readable in motion.
- Skill-graded spike and serve contact based on swing-frame timing and palm alignment. Contact quality changes actual ball speed and every feedback layer; the match records your best speed.
- Ball smears, directional speed lines, restrained player afterimages, pose squash and stretch, swing arcs, landing shock lines, short contact bursts, a brief impact wash, hit-stop, camera pullback/roll, velocity look-ahead, and fast camera tracking. Blocks accelerate the incoming spike back down at the attacker.
- Multiple contacts cut from a real CC0 indoor volleyball game supply distinct spikes, serves, blocks, passes, sets, floor hits, and landings with their natural gym reflections intact. Each action randomly selects a related take and plays one clean contact. A quiet real-gym room bed, selective shoe squeaks, slides, a restrained swing whoosh, and a wordless serve crowd keep the court alive without masking the ball. Pause and mute stop ongoing audio.

This is an arcade baseline. Roles stay in fixed formations; it does not implement regulation six-player rotations, back-row restrictions, or every official fault. AI difficulty and jump/spike timing need human playtesting. Teammates use simple ball/role rules; there is no call-for-set input. Online play, touch controls, player switching, progression, and a varied character roster are outside this version.

## Open the project

1. Install [Godot 4.7.2 Standard](https://godotengine.org/download/archive/4.7.2-stable/) for macOS. The .NET edition is unnecessary.
2. Import `project.godot` into Godot, then press **F6** on the main scene or **F5** to run the project.
3. To export a Mac app, install the matching export templates through Godot's **Manage Export Templates** dialog, then use the **macOS** export preset.

The repository contains the complete editable project. It has no runtime package-manager dependencies or external art downloads. Godot's generated `.godot` cache and application builds are excluded from version control. Editable athlete source studies live under `assets/art/animation/source`; the prepared north/south atlases are runtime assets. The simulation keeps a separate collision skeleton so the visible hand remains aligned with a legal ball contact.

## Development and verification

With the Godot executable on your path:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/simulation_test.gd
godot --headless --path . --script res://tests/integration_test.gd -- --mute
godot --headless --path . --script res://tests/audio_test.gd
godot --headless --path . --export-release macOS
```

`GODOT=/path/to/Godot tools/build_macos.sh` builds and zips the Mac app. `tools/test.sh` runs the simulation, scene integration, and audio lifecycle suites using the same `GODOT` override. See [GAMEPLAY_REFERENCE.md](GAMEPLAY_REFERENCE.md) for the measured gameplay target, [QA.md](QA.md) for the checks and current validation limits, and [ARCHITECTURE.md](ARCHITECTURE.md) for the code layout.

The optional **Web QA** preset runs the same scene for browser-based visual/input checks. It is not the primary delivery target. Windows, Android, and iOS exports can reuse the simulation and player model, but are not configured or tested yet.

## Engine notices

Godot and its bundled third-party dependencies retain their respective licenses. The generated `assets/engine_notices.txt` contains the notices reported by this engine version. The court graphics and athlete illustrations are original project assets.

## Audio sources

The bundled foley and wordless crowd recordings are CC0. See [audio credits](assets/audio/CREDITS.md) for creators, source links, and edits. `tools/prepare_audio.py` reproduces the prepared samples using Python with numpy/scipy and ffmpeg. No assets were extracted from The Spike. Running or building the game needs no audio downloads or Python packages.

For silent visual checks, launch with `-- --mute`. `tests/visual_capture.gd` captures native screenshots of the toss, plant, jump, contact, follow-through, dive, jump-set, block, point flow, next serve, and settings; use `--audio-driver Dummy` and `-- --visual-output=/absolute/output/folder --mute`. Godot Movie Maker mode can record a fixed-frame gameplay pass for transition review.

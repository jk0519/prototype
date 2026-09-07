# SIDEOUT — side-view volleyball prototype

A Mac-first, 2D volleyball prototype inspired by the basic play of The Spike: six athletes, one human wing spiker, and five AI players. Built in **Godot 4.7.2**, with compact side-view athletes, exaggerated arcade motion, a reactive camera, and recorded court audio. **0.14.0** separates spike and block motion, keeps servers behind the line until contact, restores backward movement around the service area, and reports actual shot speed and contact height for every player.

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

The first serve is yours. Move behind the baseline with **A/D**. **Hold X** to charge a longer forward toss while carrying the ball low, adjust its height with **W/S** or the up/down arrows, then **release X** to start the throwing motion. The palm lifts for 0.22 seconds before releasing the ball. Movement and running feet remain active through charge and throw. Press **Z** to plant and jump as the ball starts descending, then press **Z again** when it reaches your striking hand. Tossing does not jump automatically; an untouched toss loses the point.

The server stays behind the baseline until the ball is hit, including while airborne. You can reverse direction throughout the serve and keep moving backward after contact. Tosses and hits remain live from the full service area; the old offscreen rule no longer ends them immediately at its rear edge. A long toss needs a longer approach: the charge prompt displays **STEP BACK** when the projected contact is too far beyond the available service area. Once you hit, you can enter the court.

For an attack, approach the net on your side, jump as your setter's ball rises, then press Z again when the ball reaches your hand. Moving toward the net as you hit aims the spike shorter; moving away aims deeper. Hold Space before a low ball arrives to pass it to the setter.

Spike and serve results depend on swing timing and horizontal palm alignment. Contact quality changes the real launch speed and impact feedback. With default attributes, the serve profile spans **80–120 km/h** and the spike profile **70–125 km/h**; hard limits of **125** and **130 km/h** also apply to boosted attributes. These are game tuning choices. The existing exaggerated jumps and high set arcs remain.

Every valid serve, receive, dive, set, spike, block, and free ball shows its outgoing speed and **contact height**. The HUD retains the three most recent shots with team, role, and jersey number, including teammates and opponents. Height is the ball's height above the floor when struck, not the player's jump height or the ball's later apex. Measurements use one court scale: **18 metres across 1,640 world units**. The readout follows the physical ball velocity; it does not hide a faster shot behind a display cap.

Keyboard bindings, separate court/crowd volume sliders, sound, impact effects, and the optional landing guide are available under **Controls & settings** and are saved between sessions. Pause also provides restart and main-menu buttons; a completed match offers a rematch.

## What is implemented

- Two teams of three, each with a wing spiker, setter, and middle blocker.
- Human control of the left wing spiker; five AI players use the same movement and contact mechanics.
- AI receiving, ground and jump setting, attacking, blocking, serving, earlier emergency dives, and a fallback setter when the normal setter takes the first touch.
- Adjustable jump serves with a low carry, continuous palm lift, hand-attached release, displayed parabola, movable charge and windup, approach, foot plant, takeoff, timed contact, follow-through, and landing compression. Human and AI servers share the same behind-line boundary through contact, including jumps and missed landings. The surrounding service area remains accessible after the hit, avoiding a phase-change position jump.
- Hold duration controls forward toss distance while W/S controls vertical height. A/D remains horizontal movement through every serve phase; the live charge and height meters show the resulting arc.
- Near-instant acceleration, very high jumps, rapid plants and recoveries, running strides tied to distance, timed air swings, ground receives, blocks, and fast horizontal dives.
- Exaggerated ball gravity, curved topspin serves and spikes, generous action contact areas, a lowered solid net, floor/out detection, three-touch and double-touch faults, and block touches that keep the ball live. Attack trajectories solve for a bounded outgoing speed; weaker long shots reduce topspin when needed to remain reachable.
- Role-based passing and oversized set arcs, including airborne setter contacts, with actual contact timing determining whether a hit succeeds.
- A full serve/rally/point/match-result loop, rotating servers on side-out, score display, and win-by-two scoring. Ordinary points stay on the live court and flow into the next serve after a compact score tick.
- Six compact, faceless athletes use original side-profile body parts: a narrow torso, profile head, distinct near/far limbs, and a modest torso turn during attacks. The spike loads its elbow behind the head, leads with the elbow, extends to contact, and follows through across the body. The block uses an upright two-hand reach and a neutral descent instead of returning to an attacking windup. Continuous poses keep limbs clear of the head and preserve running feet during carry and throw. Athlete scale is 92 world units, or 98 for the middle blocker; visible screen height changes with the camera.
- Drawing and legal contact centers use the same joint positions. Ball contact no longer relocates the whole athlete or skips the swing forward. Per-player contact debounce lets a different player block or save a ball immediately after a hit. Jump and dive taps during impact holds are retained for the next simulation step.
- Skill-graded spike and serve contact based on swing timing and palm alignment, with court-calibrated speed and contact-height measurements for every valid human and AI shot. Measurements persist through point transitions and clear on a new match.
- Ball smears, directional speed lines, swing arcs, landing shock lines, compact contact bursts, a brief impact wash, hit-stop, camera pullback/roll, velocity look-ahead, and fast camera tracking. Smaller flashes expose the athlete at contact. Blocks use a distinct two-hand stop effect and drive the rebound down toward the attacker; their contact area is centered on the displayed palms.
- Multiple contacts cut from a real CC0 indoor volleyball game supply distinct spikes, serves, blocks, passes, sets, floor hits, and landings with their natural gym reflections intact. Each action randomly selects a related take and plays one clean contact. A quiet real-gym room bed, selective shoe squeaks, slides, a restrained swing whoosh, and a wordless serve crowd keep the court alive without masking the ball. Pause and mute stop ongoing audio.

This is an arcade prototype, not a verified reproduction of The Spike's physics or a finished commercial game. Motion quality, visual consistency, sound balance, AI difficulty, and jump/spike timing still need human playtesting and iteration. Roles stay in fixed formations; it does not implement regulation six-player rotations, back-row restrictions, or every official fault. Teammates use simple ball/role rules; there is no call-for-set input. Online play, touch controls, player switching, progression, and a varied character roster are outside this version.

## Open the project

1. Install [Godot 4.7.2 Standard](https://godotengine.org/download/archive/4.7.2-stable/) for macOS. The .NET edition is unnecessary.
2. Import `project.godot` into Godot, then press **F6** on the main scene or **F5** to run the project.
3. To export a Mac app, install the matching export templates through Godot's **Manage Export Templates** dialog, then use the **macOS** export preset.

The repository contains the complete editable project. It has no runtime package-manager dependencies or external art downloads. Godot's generated `.godot` cache and application builds are excluded from version control. Current body-part artwork and its provenance live under `assets/art/side_rig`; action poses are editable in `scripts/athlete_pose.gd`. Older atlas studies remain in the repository as superseded source material and are not used by the athlete renderer.

## Development and verification

With the Godot executable on your path:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/simulation_test.gd
godot --headless --path . --script res://tests/integration_test.gd -- --mute
godot --headless --path . --script res://tests/contact_regression.gd
godot --headless --path . --script res://tests/pose_regression.gd
godot --headless --path . --script res://tests/serve_control_regression.gd -- --mute
godot --headless --path . --script res://tests/shot_regression.gd
godot --headless --path . --script res://tests/audio_test.gd
godot --headless --path . --export-release macOS
```

`GODOT=/path/to/Godot tools/test.sh` runs the complete automated suite. `GODOT=/path/to/Godot tools/build_macos.sh` builds and zips the Mac app. Coverage includes simulation, keyboard integration, service boundaries, shot measurements and physical speed limits, contact regressions, pose continuity, and audio lifecycle. See [GAMEPLAY_REFERENCE.md](GAMEPLAY_REFERENCE.md) for the gameplay target, [QA.md](QA.md) for validation status and limits, and [ARCHITECTURE.md](ARCHITECTURE.md) for the code layout.

The optional **Web QA** preset runs the same scene for browser-based visual/input checks. It is not the primary delivery target. Windows, Android, and iOS exports can reuse the simulation and player model, but are not configured or tested yet.

## Engine notices

Godot and its bundled third-party dependencies retain their respective licenses. The generated `assets/engine_notices.txt` contains the notices reported by this engine version. The court graphics and athlete illustrations are original project assets.

## Audio sources

The bundled foley and wordless crowd recordings are CC0. See [audio credits](assets/audio/CREDITS.md) for creators, source links, and edits. `tools/prepare_audio.py` reproduces the prepared samples using Python with numpy/scipy and ffmpeg. No assets were extracted from The Spike. Running or building the game needs no audio downloads or Python packages.

For silent visual checks, launch with `-- --mute`. `tests/visual_capture.gd` captures native screenshots of the toss, plant, jump, contact, follow-through, dive, jump-set, block, point flow, next serve, and settings; use `--audio-driver Dummy` and `-- --visual-output=/absolute/output/folder --mute`. `tests/motion_capture.gd` records a 15-second keyboard-serve and AI-rally pass with Movie Maker (`--write-movie /absolute/clip.avi --fixed-fps 60`). `tests/pose_capture.gd` renders an enlarged contact sheet for joint-overlap inspection.

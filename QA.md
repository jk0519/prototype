# SIDEOUT 0.14.0 validation

Engine: Godot **4.7.2.stable.official.ed1daf0bf**. Development host: Apple Silicon Mac.

This release changes attack/block motion, service boundaries, backward movement, physical attack speeds, and per-contact measurements. Passing numerical checks does not establish animation quality or gameplay parity with The Spike. Visual acceptance must use complete action sequences at normal court scale.

## Automated coverage

| Suite | What it checks |
| --- | --- |
| `tests/simulation_test.gd` | Serve flow, toss options, role behavior, ball trajectories, scoring/faults, contact quality, AI rallies, and continuous point-to-next-serve flow |
| `tests/integration_test.gd` | Actual main-scene keyboard controls, serving, contact feedback, pause/resume, rally flow, result/rematch, and input during impact holds |
| `tests/contact_regression.gd` | Service boundaries through an unstruck jump/landing, immediate opposing contacts despite hitter debounce, block rebounds landing in court, and setter recovery after a dive |
| `tests/pose_regression.gd` | Fixed limb lengths, planted-foot stability in both directions, moving carry/throw, distinct attack/block poses, head clearance, utility actions, floor recovery, and continuous takeoff/release/landing/contact transitions |
| `tests/serve_control_regression.gd` | Real-scene serving controls, reversing in each serve phase, shoes behind both service lines through contact, backward movement after the hit, real tosses/hits from both rear apron endpoints, and floor/runaway rules |
| `tests/shot_regression.gd` | All seven actions and six player identities, court unit conversion, actual outgoing speed and contact height, physical serve/spike speed limits, live AI coverage, fixed historical measurements, reset, and fault exclusion |
| `tests/audio_test.gd` | Recorded sample loading, serve crowd/room lifecycle, action cues, and stopping sustained audio on pause/mute |

The pose suite samples all three roles and exercises carry, aim, windup, and released-arm motion while running. Contact tests use the palm-centered action regions; a block has 42-unit radii on both axes, including the ball. These are assisted contact regions, not exact image outlines. The shot suite varies timing, contact elevation, position, role, and boosted power. It checks physical velocity independently of the HUD and accounts for gravity during the remaining ball substeps after a contact.

## Current release results

The complete `tools/test.sh` run passed all seven suites with no script errors: **4,958 pose samples**, **42 player/action combinations**, **1,728 physical attack velocity cases**, live AI telemetry, physical keyboard input, rear-apron service regressions, and three complete seeded AI matches. The shot checks also verify that a later deflection cannot change an earlier contact effect's direction.

| Match seed | Final score | Simulation seconds | Longest rally contacts | Blocks |
| --- | --- | --- | --- | --- |
| 7 | 8–15 | 158.7 | 13 | 8 |
| 21 | 15–10 | 178.3 | 36 | 7 |
| 83 | 15–9 | 160.7 | 11 | 4 |

Native rendering review used a **901-frame, 60 fps** motion capture, with frame sequences sampled at 6 fps inspected across the 15-second recording, plus enlarged attack/block sequences and real-scene serve, contact, follow-through, and utility-action stills. The recording contains two serves, four receives, four sets, three spikes and a continuous point transition; blocks are covered by the separate pose sequence and native fixture. It does not establish exact timing parity with the reference game.

The universal Mac release exported successfully. The exact release ZIP was extracted and passed strict, deep signature verification; bundle version is **0.14.0**. Its executable ran a silent native autoplay smoke check, reached a rally, saved a rendered screenshot successfully, and exited with code 0 without script errors. Cloud-folder Finder metadata was cleared from the local extracted copy before strict verification.

Capture scripts keep audio silent. The checks establish implemented mechanics and rendering paths; they do not certify the game's appeal or exact reference-game parity.

Run the checks from the repository with Godot on your path, or set `GODOT` for the project scripts. All automated launches should use dummy/headless audio or `--mute` to avoid unexpected playback.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/simulation_test.gd
godot --headless --path . --script res://tests/integration_test.gd -- --mute
godot --headless --path . --script res://tests/contact_regression.gd
godot --headless --path . --script res://tests/pose_regression.gd
godot --headless --path . --script res://tests/serve_control_regression.gd -- --mute
godot --headless --path . --script res://tests/shot_regression.gd
godot --headless --path . --script res://tests/audio_test.gd
```

## Native visual acceptance

Review the actual rendered court in motion, at its normal camera scale, for:

- A narrow profile torso and head, consistent near/far limb overlap, and a limited intentional torso turn while attacking.
- Alternating running feet while holding and throwing the serve, with each stance foot contacting the floor instead of sliding with the body.
- A low hand-held ball during charge, a visible palm lift before release, and no detached ball or backward position jump at the phase change.
- Direction reversal during charge, throw, flight, and after the hit; both shoes remain behind the line until contact, including during a moving jump. Check a long toss from near the line produces readable step-back guidance.
- A readable plant, takeoff, arm load, overhead contact, follow-through, fall, and landing through complete sequences.
- A hitting elbow loaded behind the head, a separate guiding arm, and a quick extension/follow-through that clears the head. A block keeps its torso upright and both hands overhead, then descends without adopting an attacking windup when the button is released.
- Hands near the ball at serve, spike, set, and block contact, without moving the entire athlete to make a screenshot align.
- Compact contact flashes that reveal the athlete, distinct block/attack feedback, and readable speed/height labels for both teams. Recent-shot rows must identify the correct player and remain stable while the ball continues its arc.
- Dive extension and floor recovery without instantaneous knee reversal or premature jumping out of recovery.
- Continuous ordinary-point flow, camera framing of high tosses and sets, and readable six-player scale.

Still captures help inspect silhouette and contact alignment. A consecutive-frame capture or live play session is required to inspect transitions, timing, and foot motion. The original game references guide visual comparison, but no numerical test here establishes exact reproduction of its gameplay.

## Practical limits

This is a playable development prototype with one shared athlete design and two team palettes. It still needs human review and tuning of animation rhythm, contact timing, movement, curved attack trajectories, set height, impact hold, camera behavior, sound balance, and AI decisions. The shared pose aligns displayed artwork with contact positions; it does not replace animation direction or broad player testing. Shot units follow one 18-metre court scale, while the existing vertical gameplay and character proportions remain exaggerated.

Recorded court audio and its source files are unchanged in this release. Sound quality remains an open playtesting concern. The wordless crowd is a generic anticipation/reaction recording. See `assets/audio/CREDITS.md` for source details.

The Mac build is ad-hoc signed and not Apple-notarized. Intel Mac, Windows, and mobile have not been run on target hardware. The shared simulation has no macOS-only logic, but each target still needs export, performance, display, and input checks. Online play, touch controls, player switching, progression, and a varied roster are not implemented.

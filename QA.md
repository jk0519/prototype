# SIDEOUT 0.13.0 validation

Engine: Godot **4.7.2.stable.official.ed1daf0bf**. Development host: Apple Silicon Mac.

This release replaces the whole-character atlas with a shared articulated side-view pose. The earlier 0.12.0 visual sign-off is superseded: its static-pose checks did not establish that the feet moved correctly during serves or that the character construction matched the intended side viewpoint. Passing numerical pose checks is necessary, but does not establish animation quality or gameplay parity with The Spike.

## Automated coverage

| Suite | What it checks |
| --- | --- |
| `tests/simulation_test.gd` | Serve flow, toss options, role behavior, ball trajectories, scoring/faults, contact quality, AI rallies, and continuous point-to-next-serve flow |
| `tests/integration_test.gd` | Actual main-scene keyboard controls, serving, contact feedback, pause/resume, rally flow, result/rematch, and input during impact holds |
| `tests/contact_regression.gd` | Consistent grounded serve boundaries and immediate contacts by another athlete despite the previous hitter's debounce |
| `tests/pose_regression.gd` | Fixed limb lengths, both feet taking stance phases, planted-foot stability in either movement direction, moving carry/charge/throw, continuous throwing and striking hands, utility actions, floor recovery, and no pose jump on hit confirmation |
| `tests/audio_test.gd` | Recorded sample loading, serve crowd/room lifecycle, action cues, and stopping sustained audio on pause/mute |

The side-view pose suite samples all three roles. It exercises carry, aim, windup, and released-arm motion while running, rather than inspecting only stationary screenshots. Contact tests use the palm-centered action regions; a block has 42-unit radii on both axes, including the ball. These are assisted contact regions, not exact image outlines.

## Current release results

Verified on September 6, 2026:

- `tools/test.sh` passed: simulation, real-scene keyboard integration, audio, contact regressions, and **4,398** pose samples.
- Three seeded AI matches finished: seed 7 at **9–15** (19-contact longest rally, 15 blocks), seed 21 at **15–7** (17 contacts, 7 blocks), and seed 83 at **15–13** (16 contacts, 7 blocks).
- Contact regressions cover both serving boundaries, taps during hit-stop, human receive followed by a recovering AI setter, and eight representative block trajectories that land in the opposing court.
- Native captures covered the toss, plant, jump, contact, follow-through, dive, jump-set, block, point transition, and settings. Enlarged renderings were reviewed for seams and overlap. A **901-frame, 60 fps** recording captured manual movement during serve preparation followed by AI rallies; frame sequences sampled at six frames per second were reviewed. It includes two serves, five sets, four spikes, and two blocks.
- The universal Mac export completed. The build script verified the ad-hoc signed app and the exact ZIP after extraction outside the cloud-backed workspace. The packaged **0.13.0** app then launched, rendered a rally screenshot successfully, and exited without runtime errors.

The capture scripts keep audio silent. These checks establish the implemented mechanics and rendering paths; they do not certify the game’s appeal or exact reference-game parity.

Run the checks from the repository with Godot on your path, or set `GODOT` for the project scripts. All automated launches should use dummy/headless audio or `--mute` to avoid unexpected playback.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/simulation_test.gd
godot --headless --path . --script res://tests/integration_test.gd -- --mute
godot --headless --path . --script res://tests/contact_regression.gd
godot --headless --path . --script res://tests/pose_regression.gd
godot --headless --path . --script res://tests/audio_test.gd
```

## Native visual acceptance

Review the actual rendered court in motion, at its normal camera scale, for:

- A narrow profile torso and head, consistent near/far limb overlap, and a limited intentional torso turn while attacking.
- Alternating running feet while holding and throwing the serve, with each stance foot contacting the floor instead of sliding with the body.
- A low hand-held ball during charge, a visible palm lift before release, and no detached ball or backward position jump at the phase change.
- A readable plant, takeoff, arm load, overhead contact, follow-through, fall, and landing through complete sequences.
- Hands near the ball at serve, spike, set, and block contact, without moving the entire athlete to make a screenshot align.
- Dive extension and floor recovery without instantaneous knee reversal or premature jumping out of recovery.
- Continuous ordinary-point flow, camera framing of high tosses and sets, and readable six-player scale.

Still captures help inspect silhouette and contact alignment. A consecutive-frame capture or live play session is required to inspect transitions, timing, and foot motion. The original game references guide visual comparison, but no numerical test here establishes exact reproduction of its gameplay.

## Practical limits

This is a playable development prototype with one shared athlete design and two team palettes. It still needs human review and tuning of animation rhythm, contact timing, movement, extreme topspin, set height, impact hold, camera behavior, sound balance, and AI decisions. The shared pose removes the previous split between displayed artwork and a separate collision skeleton; it does not replace professional animation direction or broad player testing.

Recorded court audio remains from the existing CC0 sources. This release does not introduce new volleyball recordings or claim to resolve the user's concerns about sound by changing the character art. The wordless crowd is a generic anticipation/reaction recording. See `assets/audio/CREDITS.md` for source details.

The Mac build is ad-hoc signed and not Apple-notarized. Intel Mac, Windows, and mobile have not been run on target hardware. The shared simulation has no macOS-only logic, but each target still needs export, performance, display, and input checks. Online play, touch controls, player switching, progression, and a varied roster are not implemented.

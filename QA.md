# Impact and pace update validation

Engine: Godot **4.7.2.stable.official.ed1daf0bf**. Build: **SIDEOUT 0.4.0**. Development host: Apple Silicon Mac.

## Passed

- Godot imports and compiles the project, recorded WAV assets, and all three automated test suites.
- A human serve waits for input. Holding X starts aim; A/D changes forward distance; W/S changes height; releasing X plays the throw. The toss follows the displayed parabola and does not automatically jump.
- Low, medium, and high tosses work for every server role on both teams. The AI approaches, plants behind the baseline, becomes airborne, and contacts the serve through the same athlete mechanics as the human. An untouched toss is a missed serve.
- Run footsteps follow distance instead of key-repeat time. The plant precedes takeoff; the air swing has a delayed contact window; follow-through cannot contact twice.
- Ball-down and out scoring, duplicate-point protection, win-by-two scoring, fast net collision, fallback setter selection, and the four-touch fault pass deterministic rule checks.
- Three seeded AI matches finish at the faster movement settings with receives, sets, spikes, blocks, free balls, dives, net contacts, and multi-contact rallies. Results: 12–15 (29-contact longest rally), 15–6 (47), and 9–15 (37).
- Deterministic impact checks require a spike to leave the hand above 1,850 px/s and a block to reverse a 1,200 px/s attack above 1,150 px/s with a steep downward rebound.
- The real main scene passes keyboard integration: title, six players, toss aim and release, approach/jump/air-swing serve, movement, impact hold/burst, Escape pause/resume with frozen match time, human receive followed by AI set, result screen, and rematch.
- The audio lifecycle suite confirms the aim starts the crowd swell, toss is silent, a swing triggers its air cue, serve contact triggers its two-layer ball hit and crowd release, and pause/mute stop sustained audio. All prepared court samples load as recorded WAV files.
- Native 1280x800 captures cover title, toss aim, throwing windup, foot plant, jump, ball-hand contact, follow-through, block impact, horizontal dive, and both ends of the scrolling settings panel. The high toss remains framed, control prompts are readable, hands meet the ball at strike and block contact, and all controls and both volume sliders remain accessible.
- The new player renderer was checked at ready, aim, plant, jump, contact, follow-through, and dive poses. Each athlete has an outlined body, fitted team uniform, face, distinct hair/palette, articulated hands and legs, and layered court shoes. Fast movement and hits show directional streaks, swing arcs, and contact bursts.
- macOS universal export succeeds, contains arm64 and x86_64 binaries, and passes the strict Apple code-signature check.
- The exported app launches silently in an automated smoke run and reaches the gameplay scene.

The test command is `GODOT=/path/to/Godot tools/test.sh`. All automated launches use headless audio or `--mute`, so they do not play unexpected sound through the computer.

## Practical limits

This is still an arcade prototype with procedural art rather than authored sprite sheets. A human playtest is needed to tune movement, impact hold, camera acceleration, serve timing window, relative sound levels, and AI difficulty by feel. The wordless crowd recording is a generic anticipation/reaction sound, not audio copied from The Spike or a recording of a specific Japanese chant.

The Mac build is ad-hoc signed and not Apple-notarized. Intel Mac, Windows, and mobile have not been run on their target hardware. The shared game simulation has no macOS-only logic, but those targets still need their own export and input checks.

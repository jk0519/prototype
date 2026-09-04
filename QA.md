# Body mechanics and contact update validation

Engine: Godot **4.7.2.stable.official.ed1daf0bf**. Build: **SIDEOUT 0.6.0**. Development host: Apple Silicon Mac.

## Passed

- Godot imports and compiles the project, recorded WAV assets, and all three automated test suites.
- A human serve waits for input. Holding X starts aim; A/D changes forward distance; W/S or up/down changes vertical height; releasing X plays the throw. The two axes change independently, cover their full ranges quickly, and show live percentages plus a vertical meter. The toss follows the displayed parabola and does not automatically jump.
- Low, medium, and high tosses work for every server role on both teams. The AI approaches, plants behind the baseline, becomes airborne, and contacts the serve through the same athlete mechanics as the human. An untouched toss is a missed serve.
- Run footsteps follow distance instead of key-repeat time. The plant precedes takeoff; the air swing has a delayed contact window; follow-through cannot contact twice.
- Ball-down and out scoring, duplicate-point protection, win-by-two scoring, fast net collision, fallback setter selection, and the four-touch fault pass deterministic rule checks.
- The serve windup, spike coil, contact, follow-through, and falling recovery use continuously blended full-body joints. Deterministic pose checks require the shoulders to load behind the hips, then cross more than 34 pixels through the hips while the head flexes more than 42 pixels through contact.
- Centered contact in the torso-snap window must earn a perfect grade and launch above 2,200 px/s. A 1,900 px/s incoming attack must produce a forceful high-grade block rebound. Human serve/spike speed is stored as the match best.
- Three seeded AI matches finish with receives, sets, spikes, blocks, free balls, dives, net contacts, and multi-contact rallies. Results: 12–15 (38-contact longest rally), 15–7 (16), and 15–13 (24).
- The real main scene passes keyboard integration: title, six players, vertical toss aim and release, approach/jump/air-swing serve, reported contact grade and speed, movement, graded impact hold/burst, Escape pause/resume with frozen match time, human receive followed by AI set, result screen, and rematch.
- The audio lifecycle suite confirms the aim starts the crowd swell and real-gym room, toss is silent, a swing triggers its air cue, serve contact triggers one clean volleyball hit and the crowd release, and pause/mute stop sustained audio. All prepared court samples load as recorded WAV files.
- Native 1280x800 captures cover title, toss aim and vertical meter, throwing windup, foot plant, jump, sideways torso contact, follow-through, block impact, horizontal dive, and both ends of the scrolling settings panel. The high toss remains framed, control prompts and contact grades are readable, hands meet the ball at strike and block contact, and all controls and both volume sliders remain accessible.
- The player renderer was checked at ready, aim, plant, jump, contact, follow-through, block, and dive poses. Each athlete now has tapered limbs without circular toy joints, separate limb anchors, sleeves, knee pads, a connected neck, a smaller oval head, and a neutral face. Fast movement and hits still show directional streaks, swing arcs, and contact bursts.
- macOS universal export succeeds, contains arm64 and x86_64 binaries, and passes the strict Apple code-signature check.
- The exported app launches silently in an automated smoke run and reaches the gameplay scene.

The test command is `GODOT=/path/to/Godot tools/test.sh`. All automated launches use headless audio or `--mute`, so they do not play unexpected sound through the computer.

## Practical limits

This is still an arcade prototype with procedural joint animation rather than authored frame-by-frame sprite sheets. A human playtest is needed to tune the contact-grade thresholds, body flex, movement, impact hold, camera acceleration, serve timing window, relative sound levels, and AI difficulty by feel. The wordless crowd recording is a generic anticipation/reaction sound, not audio copied from The Spike or a recording of a specific Japanese chant.

The Mac build is ad-hoc signed and not Apple-notarized. Intel Mac, Windows, and mobile have not been run on their target hardware. The shared game simulation has no macOS-only logic, but those targets still need their own export and input checks.

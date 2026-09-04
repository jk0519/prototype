# Arcade impact prototype validation

Engine: Godot **4.7.2.stable.official.ed1daf0bf**. Build: **SIDEOUT 0.12.0**. Development host: Apple Silicon Mac.

## Passed

- Godot imports and compiles the project, recorded WAV assets, and all three automated test suites.
- A human serve waits for input. A/D remains movement before and throughout the held X charge and throwing windup. The ball is anchored to the low displayed hand in ready and the opening raise beat, then to the visible open palm through windup; only release starts free flight. Hold duration changes forward toss distance; W/S or up/down changes vertical height. The toss follows the displayed parabola and does not automatically jump.
- Low, medium, and high tosses work for every server role on both teams. The AI approaches, plants behind the baseline, becomes airborne, and contacts the serve through the same athlete mechanics as the human. An untouched toss is a missed serve.
- Run footsteps follow distance instead of key-repeat time. The plant precedes takeoff; the air swing has a delayed contact window; follow-through cannot contact twice.
- Ball-down and out scoring, duplicate-point protection, win-by-two scoring, the lowered 172-unit net and matching fast collision, fallback setter selection, and the four-touch fault pass deterministic rule checks. A normal point accepts player movement and returns to serve setup after a 0.52-second score tick without leaving the court.
- The invisible gameplay skeleton still verifies the serve windup, spike coil, contact, follow-through, and falling recovery. Deterministic pose checks require the shoulders to load behind the hips, then cross more than 34 pixels through the hips while the head flexes more than 42 pixels through contact.
- Centered contact in the torso-snap window must earn a perfect grade and launch above 2,200 px/s. A 1,900 px/s incoming attack must produce a forceful high-grade block rebound. Human serve/spike speed is stored as the match best.
- A perfect jump serve launches above 3,500 px/s with more than 2,500 px/s² of added topspin acceleration. The test advances the ball to confirm that the serve dives rapidly after its initial launch. Sets reach at least 659 pixels and remove attacking spin.
- High passes trigger a physical AI jump-set intention. Dive input launches at the configured dive speed, while AI receivers now commit to emergency saves earlier.
- Three seeded AI matches finish with receives, oversized sets, high attacks, occasional blocks, emergency dives, and multi-contact rallies. Results: 9–15 (22-contact longest rally), 16–14 (13), and 17–19 (16).
- The real main scene passes keyboard integration: title, six players, movement during serve charge, vertical toss adjustment and release, approach/jump/air-swing serve, reported contact quality and speed, movement, impact hold/burst, Escape pause/resume with frozen match time, human receive followed by AI set, ordinary-point continuity, final result screen, and rematch.
- The audio lifecycle suite confirms the aim starts the crowd swell and real-gym room, toss is silent, a swing triggers its air cue, serve contact triggers one clean volleyball hit and the crowd release, and pause/mute stop sustained audio. All prepared court samples load as recorded WAV files.
- Native 1280x800 captures cover title, toss charge and vertical meter, throwing windup, foot plant, jump, contact, follow-through, block impact, horizontal dive, airborne jump set, live point tick, next serve, and both ends of the scrolling settings panel. The high toss remains framed, hands meet the ball at strike, set, and block contact, and all controls and both volume sliders remain accessible.
- The player renderer was checked at ready, aim, plant, jump, contact, follow-through, block, jump-set, and dive poses. The grounded visible height is roughly 45–65 pixels at normal 1280-pixel-wide play, matching the measured reference range. Team color, silhouette, and pose carry the play.
- A fixed-step 60 FPS gameplay capture covers 841 consecutive rendered frames. A focused 481-frame serve capture additionally confirms the continuous low-hand carry, palm raise, attached windup, palm-origin release, rapid approach, compressed plant, high takeoff, distinct airborne swing poses, and hand-to-ball contact without a detached pre-serve ball.
- macOS universal export succeeds, contains arm64 and x86_64 binaries, and passes the strict Apple code-signature check.
- The exported app launches silently in an automated smoke run and reaches the gameplay scene.

The test command is `GODOT=/path/to/Godot tools/test.sh`. All automated launches use headless audio or `--mute`, so they do not play unexpected sound through the computer.

## Practical limits

This is still an arcade prototype with one shared athlete design and an initial authored action atlas. A human playtest is needed to tune pose timing, contact-grade thresholds, movement, extreme topspin, set height, impact hold, camera acceleration, serve timing window, relative sound levels, and AI difficulty by feel. The wordless crowd recording is a generic anticipation/reaction sound and does not reproduce a recording from another game.

The Mac build is ad-hoc signed and not Apple-notarized. Intel Mac, Windows, and mobile have not been run on their target hardware. The shared game simulation has no macOS-only logic, but those targets still need their own export and input checks.

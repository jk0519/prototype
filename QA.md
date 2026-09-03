# First-playable validation

Engine: Godot **4.7.2.stable.official.ed1daf0bf**. Build: **SIDEOUT 0.1.0**. Development host: Apple Silicon Mac.

## Passed

- Godot imports and compiles the project, including both test scripts.
- A human serve waits for input. The AI does not move the human athlete. A two-tap serve contacts the ball, including second taps at 0.15, 0.30, and 0.50 seconds after the jump.
- The human can move into position before an opponent's serve.
- Ball-down and out scoring, duplicate-point protection, win-by-two scoring, fast net collision, fallback setter selection, and the four-touch fault pass the deterministic rule checks.
- Three seeded AI matches reach a winner, with actual receives, sets, spikes, blocks, and dives on the court.
- The real main scene passes input integration checks: title, six players, two-tap serve, movement, Escape pause/resume with frozen match time, human receive followed by an AI set, result screen, and rematch reset.
- The human/AI test includes a setter already diving when the human receives. The pass provides time for the setter to recover and make the second contact.
- Browser inspection of the same Godot scene verifies title/menu layout, a six-player court, keyboard jump and two-tap serve, pause/settings, key rebinding, persistence across reload, and restoring default keys.
- macOS universal export succeeds. The app includes arm64 and x86_64 binaries. Apple's `codesign --verify --deep --strict` check passes.
- The exported Mac application starts and runs the game scene in headless autoplay mode, then exits successfully.

| Seed | Final score | Simulated duration | Longest rally |
| --- | --- | --- | --- |
| 7 | 15–13 | 448.9 s | 94 contacts |
| 21 | 15–12 | 410.6 s | 61 contacts |
| 83 | 15–7 | 404.3 s | 103 contacts |

The match test runs both sides under AI to test sustained rallies and match completion. The separate integration suite checks the human path through the real scene.

## Validation limits

The execution environment cannot initialize a native macOS application window. The windowed Mac launch therefore remains a manual check; browser rendering of the same scene and the exported app's headless launch are the available verification. Audible output and Mac fullscreen behavior have not been personally verified. Intel Mac, Windows, and mobile have not been tested.

This build uses a valid ad-hoc signature and is not Apple-notarized. It is a development build, not an App Store release. No Apple developer credentials are required for the local prototype.

The sandbox logs a macOS certificate-store access error during engine startup. The game performs no network requests, and the tests and exported headless runtime continue successfully. The graphical launch restriction is separate from this message.

## First manual playtest

Open the Mac app, start a match, serve with Z then Z again, and move toward the net. Try receiving with Space, attacking your setter's ball with a two-tap jump/spike, blocking with X, and diving with C. Check whether camera framing, jump timing, and ball visibility feel comfortable on your display. A complete human match is the next useful tuning step; unusually long AI rallies and serve consistency are known balancing areas.

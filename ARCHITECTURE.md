# Project layout

The game separates keyboard/UI input, player actions, match rules, and drawing. This keeps the desktop prototype straightforward while allowing another controlled role or touch controls later.

| File | Responsibility |
| --- | --- |
| `scenes/main.tscn` / `scripts/main.gd` | Scene setup, keyboard bindings, camera, menus, preferences, and connecting simulation events to feedback |
| `scripts/match_model.gd` | Ball state, serve/rally/point/result phases, legal contacts, scoring, role-based ball trajectories, and match statistics |
| `scripts/athlete.gd` | A single player's movement, plant/takeoff/swing/follow-through/landing state, joint poses, and contact positions |
| `scripts/player_config.gd` | Shared configurable movement, jump, reach, and spike attributes, with small role variations |
| `scripts/ai_controller.gd` | Ball prediction and role rules producing the same action dictionaries as human input |
| `scripts/court_view.gd` | Arena, outlined anime-style athlete renderer, ball/player streaks, and contact effects |
| `scripts/hud.gd` | Score, match prompts, role marker, and control hints |
| `scripts/audio_feedback.gd` | Recorded CC0 samples, positional court voices, footfall variation, serve crowd envelope, volume and mute lifecycle |

## Simulation

The court uses x across the screen and y above the floor. Drawing flips the y axis. Godot advances the simulation at 120 physics ticks per second; the ball uses four integration substeps and swept contact tests within each tick. This makes fast spikes and net collisions independent of display frame rate.

An action dictionary describes movement and jump, swing, receive, block, dive, set, toss-hold, or toss-height intent. All six athletes use the same `Athlete.step` and contact system. The AI cannot teleport or hit outside those contact regions. Controlled-player input replaces exactly one AI intention entry. The default controlled player is index 0, the blue wing spiker.

The AI predicts descending ball intersections. One bot approaches an incoming ball; the setter takes the second contact; the wing approaches for the third. The middle blocks the opposing set. A middle can set when the setter made the pass. Position and jump-timing variations allow real misses; points are not assigned randomly. An already-diving setter gets a higher pass to allow physical recovery.

Serve, pass, set, and spike velocities are calculated arcs with arcade assistance. Net and player contacts still happen in space. Spike and serve launch speed is graded from the swing frame and horizontal palm alignment; presentation consumes the same quality value, so a stronger flash always represents a physically faster hit. A short contact lock prevents a single overlap from producing several touches. This is intentionally a small simulation, not Godot RigidBody2D volleyball.

## Next extensions

- Supporting another human position means adapting the role HUD and input interpretation, including an explicit set action. The shared athlete actions and `human_id` already separate ownership from physics; player switching is not a finished feature.
- Mobile can replace keyboard input with touch buttons, using the same intention dictionary. Camera, UI layout, performance, and signing still need device testing.
- A Windows build should use the Windows export templates and get its own launch/input test. No Windows-only or macOS-only game logic is used.
- Adjust movement and jump attributes in `player_config.gd`; adjust ball/net constants and attack/pass arcs in `match_model.gd`. Keep AI assumptions about contact height in sync if changing player scale.

## Jump serving and feedback

Serve phases are `serve_ready → serve_aim → serve_windup → serve_toss → rally`. Hold X to aim, adjust the toss using A/D and W/S, release X for the throwing animation, approach, then use separate jump and swing inputs. The preview and released ball use the same launch velocity and gravity. A grounded server plants behind the baseline; an airborne server can travel over it. Missing the toss awards the point.

The athlete skeleton supplies rendered joints and the striking-hand contact center. A swing continuously blends through neutral flight, backward coil, lateral hip-and-shoulder snap, leg scissor, contact, folded follow-through, and a falling recovery pose. The ground serve loads and releases the torso before the same airborne swing. Contact captures the palm pose at the ball and cannot cause a second contact. Run stride/footfall events track distance travelled; jump, cut, slide, and landing events drive their respective recorded sounds. Cosmetic motion events never reroll AI errors or increment ball-contact metrics.

Player art is procedural and original. A tapered torso, angular shorts, outlined articulated limbs, three mirrored hair silhouettes, individual palettes, face details, and layered shoes are assembled around each athlete's simulation joints. The horizontal dive is another skeleton pose rather than a disconnected drawing. This keeps the visuals aligned with contacts and makes every action available to any controlled role.

Fast attacks add long ball streaks, player motion lines, swing arcs, radial contact bursts, camera velocity look-ahead, punch zoom, and a brief impact hold. Contact quality drives ball speed, audio gain and pitch, flash size, ray count, shake, zoom, and hold duration. A transient grade and km/h readout explain the result, while the HUD retains the human player's best serve or spike speed for the match. Blocks preserve most incoming horizontal speed while reversing it and driving the ball down. Turning off impact effects also turns off the hold, shake, and punch zoom. Match rules and ball physics remain deterministic.

`audio_feedback.gd` owns a bounded pool of positional court voices and separate crowd streams. One clean recorded volleyball spike is filtered into a consistent family for spikes, serves, blocks, passes, sets, floor hits, and landings. High-impact contacts use two dry layers; the attack windup has its own short recorded whoosh. Routine AI steps are suppressed, while occasional human shoe squeaks, plants, slides, and landings preserve court motion without masking the ball. The looping anticipation vowel fades in while aiming, builds through the toss, and gives way to a quiet reaction on real serve contact. The crowd is briefly ducked under the hit. Pause/menu/mute stop active audio. Separate court and crowd gains are saved with controls. `--mute` is a runtime override that does not change the user's saved preference.

Audio source URLs, licensing and processing notes are in `assets/audio/CREDITS.md`. The preparation script is optional development tooling; playable builds contain all necessary WAV resources.

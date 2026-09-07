# Project layout

The game separates keyboard/UI input, player actions, match rules, and drawing. This keeps the desktop prototype straightforward while allowing another controlled role or touch controls later.

| File | Responsibility |
| --- | --- |
| `scenes/main.tscn` / `scripts/main.gd` | Scene setup, keyboard bindings, camera, menus, preferences, and connecting simulation events to feedback |
| `scripts/match_model.gd` | Ball state, serve/rally/point/result phases, legal contacts, scoring, role-based ball trajectories, and match statistics |
| `scripts/athlete.gd` | A single player's movement, action timelines, distance clock, and contact positions sampled from the shared pose |
| `scripts/athlete_pose.gd` | Continuous side-view joint poses, fixed-length limb solving, planted-foot gait, and action transitions |
| `scripts/athlete_renderer.gd` | Body-part textures attached to those joints, near/far layering, profile/turned torso selection, and team palette |
| `scripts/player_config.gd` | Shared configurable movement, jump, reach, and spike attributes, with small role variations |
| `scripts/ai_controller.gd` | Ball prediction and role rules producing the same action dictionaries as human input |
| `scripts/court_view.gd` | Arena, athlete-renderer placement, ball/player streaks, and contact effects |
| `scripts/hud.gd` | Score, match prompts, role marker, and control hints |
| `scripts/audio_feedback.gd` | Recorded CC0 samples, positional court voices, footfall variation, serve crowd envelope, volume and mute lifecycle |

## Simulation

The court uses x across the screen and y above the floor. Drawing flips the y axis. Godot advances the simulation at 120 physics ticks per second; the ball uses four integration substeps and swept contact tests within each tick. This makes fast spikes and net collisions independent of display frame rate.

An action dictionary describes movement and jump, swing, receive, block, dive, set, toss-hold, or toss-height intent. All six athletes use the same `Athlete.step` and contact system. The AI cannot teleport or hit outside those contact regions. Controlled-player input replaces exactly one AI intention entry. The default controlled player is index 0, the blue wing spiker.

The AI predicts descending ball intersections. One bot approaches an incoming ball; the setter takes the second contact; the wing approaches for the third. The middle blocks the opposing set. A middle can set when the setter made the pass. Position and jump-timing variations allow real misses; points are not assigned randomly. An already-diving setter gets a higher pass to allow physical recovery.

Serve, pass, set, and spike velocities are calculated arcs with heavy arcade assistance. Net and player contacts still happen in space. Serves and spikes add extreme downward acceleration; passes and oversized sets remove it, and prediction uses the active gravity value. Spike and serve launch speed is graded from swing timing and horizontal palm alignment; presentation consumes the same quality value, so a stronger flash represents a faster hit. Blocks use a palm-centered swept contact test with 42-unit horizontal and vertical radii, including ball size, and accelerate the return downward. Each athlete has a short contact debounce to prevent repeated touches from one overlap. It does not exclude another athlete from contacting the ball during that interval. This is a stylized simulation rather than Godot RigidBody2D volleyball; its constants are not measurements of The Spike's private implementation.

## Next extensions

- Supporting another human position means adapting the role HUD and input interpretation, including an explicit set action. The shared athlete actions and `human_id` already separate ownership from physics; player switching is not a finished feature.
- Mobile can replace keyboard input with touch buttons, using the same intention dictionary. Camera, UI layout, performance, and signing still need device testing.
- A Windows build should use the Windows export templates and get its own launch/input test. No Windows-only or macOS-only game logic is used.
- Adjust movement and jump attributes in `player_config.gd`; adjust ball/net constants and attack/pass arcs in `match_model.gd`. Keep AI assumptions about contact height in sync if changing player scale.

## Jump serving and feedback

Serve phases are `serve_ready → serve_aim → serve_windup → serve_toss → rally`. Hold X to charge forward toss distance, use W/S to adjust height and A/D to move, then release X for a 0.22-second palm lift. The ball remains attached to the displayed palm until the lift finishes. The preview samples the same release pose, launch velocity, and gravity as the free ball. Approach, jump, and swing are separate player actions. Ready, aim, windup, and the grounded toss share a behind-baseline boundary; an airborne server can travel over it. Missing the toss awards the point.

`athlete_pose.gd` produces one set of local, right-facing, y-up joints. It combines distance-driven leg motion with timed upper-body actions, then solves fixed-length arms and legs. The serve carry and throwing arm therefore do not replace the running feet with a static whole-body picture. A stance foot moves backward in local space at the athlete's forward world speed, keeping that foot planted on the court during its stance interval. Signed distance also supports backward movement. The pose contains distinct near/far shoulders, elbows, hands, hips, knees, and feet, plus a limited torso turn and head angle. Height is 92 world units by default and 98 for the middle blocker.

`athlete_renderer.gd` attaches the original side-profile cutouts to those joints and orders the far limbs behind the body. The narrow resting torso changes to a modestly turned variant during an attack; this preserves the side viewpoint without locking the whole athlete into rigid profile. `athlete.gd` mirrors the same joints for facing and derives contact centers from them. Registering a hit neither moves the body to the ball nor skips ahead in the action timeline. Contact regions remain forgiving gameplay envelopes, not pixel-perfect texture masks. Input ownership remains separate from pose and contact, so the same actions work for AI and the human athlete.

Current source artwork, prepared transparent parts, team palettes, and generation provenance are under `assets/art/side_rig`. The previous whole-character atlases and their preparation tools are superseded. This rig uses generated cutout artwork with authored joint motion; it is not a frame-for-frame recreation of another game's animation. Continuous numeric poses and fixed bone lengths prevent several classes of popping and stretching, but do not by themselves prove that motion feels good in play.

Jump and dive press edges are captured before an impact hold and consumed once the simulation resumes. Run distance, plants, slides, and landings generate motion events for audio. Cosmetic events never reroll AI errors or increment ball-contact metrics.

Fast attacks add stretched ball smears, long trails, player afterimages, full-court speed lines, swing arcs, radial bursts, camera velocity look-ahead, punch zoom, a screen wash, and a pronounced impact hold. Contact quality drives ball speed, audio gain and pitch, flash size, ray count, shake, zoom, and hold duration. A transient grade explains the result, while the HUD retains the human player's best serve or spike speed for the match. Blocks accelerate the incoming horizontal speed while reversing it and driving the ball down. Turning off impact effects also turns off the hold, shake, and punch zoom. Match rules and ball physics remain deterministic.

`audio_feedback.gd` owns a bounded pool of positional court voices plus real-gym room and crowd streams. Separate contacts cut from a CC0 indoor volleyball game supply randomized spikes, serves, blocks, passes, sets, floor hits, and landings while retaining their natural reflection. Each action plays one contact with a narrow pitch range; the attack windup has a restrained recorded whoosh. Routine AI steps are suppressed, while occasional human shoe squeaks, plants, slides, and landings preserve court motion without masking the ball. The looping anticipation vowel fades in while aiming, builds through the toss, and gives way to a quiet reaction on real serve contact. The room and crowd duck under the hit. Pause/menu/mute stop active audio. Separate court and crowd gains are saved with controls. `--mute` is a runtime override that does not change the user's saved preference.

Audio source URLs, licensing and processing notes are in `assets/audio/CREDITS.md`. The preparation script is optional development tooling; playable builds contain all necessary WAV resources.

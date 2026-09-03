# Project layout

The game separates keyboard/UI input, player actions, match rules, and drawing. This keeps the desktop prototype straightforward while allowing another controlled role or touch controls later.

| File | Responsibility |
| --- | --- |
| `scenes/main.tscn` / `scripts/main.gd` | Scene setup, keyboard bindings, camera, menus, preferences, and connecting simulation events to feedback |
| `scripts/match_model.gd` | Ball state, serve/rally/point/result phases, legal contacts, scoring, role-based ball trajectories, and match statistics |
| `scripts/athlete.gd` | A single player's movement, jump/swing/dive state, cooldowns, and contact positions |
| `scripts/player_config.gd` | Shared configurable movement, jump, reach, and spike attributes, with small role variations |
| `scripts/ai_controller.gd` | Ball prediction and role rules producing the same action dictionaries as human input |
| `scripts/court_view.gd` | Arena, player poses, ball/trail, and contact effects |
| `scripts/hud.gd` | Score, match prompts, role marker, and control hints |
| `scripts/audio_feedback.gd` | Small generated sounds; no audio files or external libraries |

## Simulation

The court uses x across the screen and y above the floor. Drawing flips the y axis. Godot advances the simulation at 120 physics ticks per second; the ball uses four integration substeps and swept contact tests within each tick. This makes fast spikes and net collisions independent of display frame rate.

An action dictionary describes movement and jump, swing, receive, block, dive, or set intent. All six athletes use the same `Athlete.step` and contact system. The AI cannot teleport or hit outside those contact regions. Controlled-player input replaces exactly one AI intention entry. The default controlled player is index 0, the blue wing spiker.

The AI predicts descending ball intersections. One bot approaches an incoming ball; the setter takes the second contact; the wing approaches for the third. The middle blocks the opposing set. A middle can set when the setter made the pass. Position and jump-timing variations allow real misses; points are not assigned randomly. An already-diving setter gets a higher pass to allow physical recovery.

Serve, pass, set, and spike velocities are calculated arcs with arcade assistance. Net and player contacts still happen in space. A short contact lock prevents a single overlap from producing several touches. This is intentionally a small simulation, not Godot RigidBody2D volleyball.

## Next extensions

- Supporting another human position means adapting the role HUD and input interpretation, including an explicit set action. The shared athlete actions and `human_id` already separate ownership from physics; player switching is not a finished feature.
- Mobile can replace keyboard input with touch buttons, using the same intention dictionary. Camera, UI layout, performance, and signing still need device testing.
- A Windows build should use the Windows export templates and get its own launch/input test. No Windows-only or macOS-only game logic is used.
- Adjust movement and jump attributes in `player_config.gd`; adjust ball/net constants and attack/pass arcs in `match_model.gd`. Keep AI assumptions about contact height in sync if changing player scale.

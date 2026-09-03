extends SceneTree
## Runs the real scene and InputMap through Godot's physics frames.
var failures: Array = []
var main

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)

func escape() -> void:
	var event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event.pressed = false
	Input.parse_input_event(event)

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(2)
	expect(main.mode == "title", "Launch opens title screen")
	expect(main.game.players.size() == 6, "Real scene contains six athletes")
	main.start_match()
	await frames(42)
	await tap("jump")
	await frames(15)
	await tap("jump")
	expect(main.game.metrics.serve == 1, "Two jump inputs serve through the scene InputMap")
	var x = main.game.players[0].pos.x
	Input.action_press("right")
	await frames(30)
	Input.action_release("right")
	expect(main.game.players[0].pos.x > x + 35, "Movement input reaches the controlled player")
	await escape()
	expect(main.mode == "paused", "Escape pauses the match")
	var frozen_time = main.game.time
	await frames(12)
	expect(main.game.time == frozen_time, "Pause freezes the simulation")
	await escape()
	expect(main.mode == "playing", "Escape resumes the match")
	main.start_match()
	var game = main.game
	game.phase = "rally"
	game.last_team = 1
	game.last_player = 3
	game.last_action = "spike"
	game.touches = 3
	game.players[0].reset(415)
	game.ball = Vector2(440, 105)
	game.previous_ball = game.ball
	game.ball_velocity = Vector2(0, -200)
	Input.action_press("receive")
	await frames(8)
	Input.action_release("receive")
	expect(game.last_player == 0 and game.metrics.receive == 1, "Human receive makes a real contact")
	await frames(270)
	expect(game.metrics.set >= 1, "AI setter follows up the human's receive")
	game.phase = "rally"
	game.score = [14, 3]
	game.award_point(0, "BALL DOWN")
	await frames(2)
	expect(main.mode == "result", "Winning point opens the result screen")
	main.start_match()
	expect(main.mode == "playing" and game.score == [0, 0] and game.phase == "serve_ready", "Rematch resets the score and serving state")
	if failures.is_empty():
		print("PASS: scene launch, input, serve, movement, pause, human receive + AI set, result and rematch")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

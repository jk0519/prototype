extends SceneTree
## Service boundaries, reversible movement and actual keyboard input regressions.
const MatchModel = preload("res://scripts/match_model.gd")
const DT = 1.0 / 120.0
var failures: Array = []
var main

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func service_game(side: int):
	var game = MatchModel.new(4)
	game.serving_team = side
	game.serve_order[side] = 0
	game.human_id = side * 3
	game.prepare_serve()
	return game

func keep_toss_high(game) -> void:
	game.ball = Vector2(1000, 2200)
	game.previous_ball = game.ball
	game.ball_velocity = Vector2.ZERO
	game.phase_time = 0

func check_service_controls(side: int) -> void:
	var game = service_game(side)
	var server = game.players[game.server_id]
	var facing: float = server.facing
	var start: float = server.pos.x
	for i in range(70): game.step(DT, {"move": -facing})
	expect((start - server.pos.x) * facing > 360, "Side %d has a usable backward approach in ready" % side)
	var rear: float = server.pos.x
	for i in range(70): game.step(DT, {"move": facing, "toss": true})
	expect(game.phase == "serve_aim" and (server.pos.x - rear) * facing > 350, "Side %d can reverse forward while charging" % side)
	var aiming: float = server.pos.x
	for i in range(18): game.step(DT, {"move": -facing, "toss": true})
	expect((aiming - server.pos.x) * facing > 55, "Side %d can reverse backward while charging" % side)
	game.step(DT, {"move": facing})
	var lifting: float = server.pos.x
	for i in range(12): game.step(DT, {"move": facing})
	expect(game.phase == "serve_windup" and (server.pos.x - lifting) * facing > 25, "Side %d can move forward during the toss lift" % side)
	var reverse_lift: float = server.pos.x
	for i in range(15): game.step(DT, {"move": -facing})
	expect(game.phase == "serve_toss" and (reverse_lift - server.pos.x) * facing > 20, "Side %d can reverse backward through release" % side)
	var release: float = server.pos.x
	for i in range(12):
		keep_toss_high(game)
		game.step(DT, {"move": -facing})
	expect((release - server.pos.x) * facing > 65, "Side %d keeps backward control after release" % side)
	for i in range(180):
		keep_toss_high(game)
		game.step(DT, {"move": facing})
	var line: float = server.pos.x
	var limit: float = game.grounded_serve_bounds(side).y if side == 0 else game.grounded_serve_bounds(side).x
	expect(absf(line - limit) < 0.01 and absf(server.velocity.x) < 0.01, "Side %d stops with both shoes behind the line" % side)
	game.step(DT, {"move": facing, "jump": true})
	var airborne = false
	var landed = false
	var max_forward_foot: float = -INF
	var largest_step: float = 0
	for i in range(132):
		keep_toss_high(game)
		var before: float = server.pos.x
		game.step(DT, {"move": facing})
		airborne = airborne or server.pos.y > 1
		landed = landed or (airborne and server.pos.y <= 0.01)
		largest_step = maxf(largest_step, absf(server.pos.x - before))
		var pose: Dictionary = server.skeleton()
		for foot in [pose.front_foot, pose.back_foot]:
			max_forward_foot = maxf(max_forward_foot, (server.pos.x + foot.x) * facing + 9)
	expect(airborne and landed, "Side %d can jump and land while waiting to hit" % side)
	expect(absf(server.pos.x - line) < 0.01, "Side %d airborne movement never unlocks the service line" % side)
	expect(max_forward_foot < (game.COURT_LEFT if side == 0 else -game.COURT_RIGHT), "Side %d visible shoes remain behind the line in motion" % side)
	expect(largest_step <= server.config.run_speed * DT + 0.01, "Side %d service landing never teleports the player" % side)
	for i in range(15):
		keep_toss_high(game)
		game.step(DT, {"move": -facing})
	expect((line - server.pos.x) * facing > 65, "Side %d can reverse immediately away from the line" % side)
	# Contact is the only event that unlocks forward entry. Check the real hit
	# path, and ensure the expanded rear apron remains available afterwards.
	server.pos.y = 185
	server.swing_elapsed = 0.108
	game.ball = server.contact_center("serve")
	game.previous_ball = game.ball
	game.serve(server)
	expect(game.phase == "rally", "Side %d serve contact starts the rally" % side)
	for i in range(60):
		game.ball = Vector2(1000, 2200)
		game.previous_ball = game.ball
		game.ball_velocity = Vector2.ZERO
		game.step(DT, {"move": facing})
	expect((server.pos.x - line) * facing > 150, "Side %d can enter the court after the hit" % side)
	var after_hit: float = server.pos.x
	for i in range(110):
		game.ball = Vector2(1000, 2200)
		game.previous_ball = game.ball
		game.ball_velocity = Vector2.ZERO
		game.step(DT, {"move": -facing})
	expect((after_hit - server.pos.x) * facing > 550, "Side %d retains the full backward apron during the rally" % side)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func check_rear_apron_toss(side: int) -> void:
	var game = service_game(side)
	var server = game.players[game.server_id]
	for i in range(90): game.step(DT, {"move": -server.facing})
	var rear_limit: float = server.movement_bounds.x if side == 0 else server.movement_bounds.y
	expect(absf(server.pos.x - rear_limit) < 0.01, "Side %d can reach the rear apron before tossing" % side)
	for i in range(30): game.step(DT, {"toss": true})
	for i in range(30): game.step(DT)
	expect(game.phase == "serve_toss" and game.score == [0, 0], "Side %d can release a real toss from the rear apron without an instant out" % side)
	expect(game.ball.y > game.BALL_RADIUS and (game.ball.x < -400 if side == 0 else game.ball.x > 2400), "Side %d rear toss flies inside the expanded apron beyond the old runaway bound" % side)
	for i in range(10): game.step(DT)
	expect(game.phase == "serve_toss" and game.ball_velocity.y > 0, "Side %d rear toss remains live on its ascent" % side)
	# Follow the actual released toss into a physical approach/jump/swing. The
	# resulting serve contact is still outside the old early-out rectangle.
	for i in range(420):
		var intent: Dictionary = game.ai.intentions(game, true)[server.id]
		game.step(DT, intent)
		if game.metrics.serve > 0 or game.phase == "point": break
	expect(game.metrics.serve == 1 and game.phase == "rally", "Side %d can strike the actual rear-apron toss without immediate out" % side)
	expect(game.ball.x < -400 if side == 0 else game.ball.x > 2400, "Side %d rear-apron serve really contacts beyond the previous limit" % side)
	for i in range(6): game.step(DT)
	expect(game.phase == "rally" and game.score == [0, 0], "Side %d outgoing serve stays live while leaving the rear apron" % side)
	# Extending the safety guard does not change where a ball touching the floor
	# is out, or allow an escaped ball to keep a rally running indefinitely.
	game.ball = Vector2(-500 if side == 0 else 2500, game.BALL_RADIUS + 1)
	game.ball_velocity = Vector2(0, -200)
	game.step_ball(DT)
	expect(game.phase == "point" and game.point_reason == "OUT", "Side %d ball on the apron floor still scores out" % side)
	game = service_game(side)
	game.phase = "rally"
	game.last_team = side
	game.ball = Vector2(game.Athlete.APRON_LEFT - 201 if side == 0 else game.Athlete.APRON_RIGHT + 201, 300)
	game.ball_velocity = Vector2.ZERO
	game.step_ball(DT)
	expect(game.phase == "point" and game.point_reason == "OUT", "Side %d runaway guard still ends an escaped ball" % side)

func key_action(action: String, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = main.keys[action]
	event.physical_keycode = main.keys[action]
	event.pressed = pressed
	Input.parse_input_event(event)

func check_keyboard_controls() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(2)
	main.sound.enabled = false
	main.start_match()
	await frames(42)
	var server = main.game.players[0]
	key_action("block", true)
	key_action("left", true)
	await frames(34)
	key_action("left", false)
	expect(main.game.phase == "serve_aim" and server.pos.x < -280, "Actual A input moves backward while X charges the toss")
	var rear: float = server.pos.x
	key_action("right", true)
	await frames(28)
	key_action("right", false)
	expect(server.pos.x > rear + 100, "Actual D input reverses the moving charged serve")
	key_action("block", false)
	key_action("left", true)
	await frames(18)
	expect(main.game.phase == "serve_windup" and server.velocity.x < -100, "Actual A input remains active throughout the throwing motion")
	await frames(18)
	key_action("left", false)
	expect(main.game.phase == "serve_toss" and server.velocity.x < -100, "Actual A input stays active after the ball leaves the hand")
	keep_toss_high(main.game)
	key_action("right", true)
	key_action("jump", true)
	await frames(11)
	key_action("jump", false)
	expect(server.pos.y > 0 and server.velocity.x > 100, "Actual D/Z input allows a forward serve takeoff")
	var airborne_x: float = server.pos.x
	key_action("right", false)
	key_action("left", true)
	await frames(17)
	key_action("left", false)
	expect(server.pos.y > 0 and server.pos.x < airborne_x - 35, "Actual A input reverses the airborne server")
	key_action("right", true)
	for i in range(130):
		keep_toss_high(main.game)
		await frames(1)
	key_action("right", false)
	expect(server.pos.y == 0 and server.pos.x <= main.game.COURT_LEFT - main.game.SERVICE_FOOT_CLEARANCE, "Held D remains behind the service line through takeoff and landing")
	var stopped_x: float = server.pos.x
	key_action("left", true)
	await frames(18)
	key_action("left", false)
	expect(server.pos.x < stopped_x - 65, "Actual A input reverses away from the service line after landing")
	for action in ["left", "right", "block", "jump"]: key_action(action, false)
	main.queue_free()
	await process_frame

func run() -> void:
	for side in range(2):
		check_service_controls(side)
		check_rear_apron_toss(side)
	var model_only: bool = OS.get_cmdline_user_args().has("--model-only")
	if not model_only:
		await check_keyboard_controls()
	if failures.is_empty():
		print("PASS: bilateral serve reversals, visible baseline clearance, takeoff/landing bounds, post-contact entry and rear-apron toss/hit/floor/runaway rules" + ("" if model_only else ", plus actual A/D/X controls"))
	else:
		for failure in failures: printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## Regression scenarios for motion boundaries and immediate contested contacts.
const MatchModel = preload("res://scripts/match_model.gd")
const DT = 1.0 / 120.0
var failures: Array = []

func _initialize() -> void:
	check_serve_runup()
	check_immediate_block()
	check_block_lands_in_court()
	check_setter_after_dive()
	if failures.is_empty():
		print("PASS: serve movement, immediate blocks, in-court block rebounds and setter recovery after a dive")
	else:
		for failure in failures: printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func check_serve_runup() -> void:
	for side in range(2):
		var game = MatchModel.new(4)
		game.serving_team = side
		game.serve_order[side] = 0
		game.human_id = side * 3
		game.prepare_serve()
		var server = game.players[game.server_id]
		var start = server.pos.x
		for i in range(42): game.step(DT)
		for i in range(240): game.step(DT, {"toss": true, "move": server.facing})
		expect((server.pos.x - start) * server.facing > 200, "Side %d can move through the full serve run-up" % side)
		var release_x = server.pos.x
		var largest_step = 0.0
		for i in range(40):
			var before = server.pos.x
			game.step(DT, {"move": server.facing})
			largest_step = maxf(largest_step, absf(server.pos.x - before))
		expect(game.phase == "serve_toss", "Side %d toss releases after long moving charge" % side)
		expect(largest_step <= server.config.run_speed * DT + 0.01, "Side %d release never teleports the server" % side)
		expect(absf(server.pos.x - release_x) < 0.01, "Side %d stays at the same approach boundary after release" % side)
		# Keep a missed toss in flight beyond landing: once the athlete takes off,
		# landing inside the court must not reinstate the behind-baseline clamp.
		game.ball = Vector2(1000, 2200)
		game.previous_ball = game.ball
		game.ball_velocity = Vector2.ZERO
		game.phase_time = 0
		game.step(DT, {"move": server.facing, "jump": true})
		var airborne = false
		var landed = false
		for i in range(128):
			var before = server.pos.x
			game.step(DT, {"move": server.facing})
			largest_step = maxf(largest_step, absf(server.pos.x - before))
			airborne = airborne or server.pos.y > 1
			landed = landed or (airborne and server.pos.y <= 0.01)
		expect(airborne and landed, "Side %d completes a serve approach jump and landing" % side)
		expect(largest_step <= server.config.run_speed * DT + 0.01, "Side %d landing never snaps back behind the service line" % side)
		expect((server.pos.x - release_x) * server.facing > 200, "Side %d can land forward inside the court" % side)

func check_immediate_block() -> void:
	var game = MatchModel.new(5)
	game.phase = "rally"
	game.last_team = 0
	game.last_player = 1
	game.last_action = "set"
	game.touches = 2
	var attacker = game.players[0]
	attacker.reset(840)
	attacker.pos.y = 220
	attacker.swing_elapsed = 0.082
	game.ball = attacker.contact_center("spike")
	game.previous_ball = game.ball
	game.contact(attacker, "spike")
	var blocker = game.players[5]
	blocker.reset(1053)
	blocker.pos.y = 200
	blocker.blocking = true
	# Put the raised hands on the imminent ball path, outside its initial
	# contact ellipse. Let the actual struck ball sweep into them.
	blocker.pos += game.ball + Vector2(130, -12) - blocker.contact_center("block")
	var elapsed = 0.0
	while game.metrics.block == 0 and elapsed < 0.08:
		game.step_ball(DT / 4.0)
		elapsed += DT / 4.0
	expect(game.metrics.block == 1 and game.last_player == blocker.id, "A correctly placed blocker touches a spike within the hitter's cooldown")
	expect(game.ball_velocity.x < 0 and game.touches == 0, "Immediate block reflects the ball and leaves three team touches")
	# Repeated collision sweeps through the same still-active block should not
	# count more contacts; nor may the previous hitter recontact in that overlap.
	var contacts = game.rally_contacts
	for i in range(8):
		game.ball = blocker.contact_center("block")
		game.previous_ball = game.ball
		game.check_contacts()
	expect(game.rally_contacts == contacts and game.phase == "rally", "An active block overlapping the ball cannot produce duplicate contacts")
	attacker.swing_timer = 0.001
	game.ball = attacker.contact_center("spike")
	game.previous_ball = game.ball
	game.check_contacts()
	expect(game.rally_contacts == contacts, "A block does not clear the original hitter's overlap debounce")

func check_block_lands_in_court() -> void:
	for side in range(2):
		for incoming_speed in [1500.0, 4500.0]:
			for jump_height in [150.0, 275.0]:
				var game = MatchModel.new(9)
				game.phase = "rally"
				game.last_team = 1 - side
				game.last_player = (1 - side) * 3
				game.last_action = "spike"
				var blocker = game.players[side * 3 + 2]
				blocker.reset(947 if side == 0 else 1053)
				blocker.pos.y = jump_height
				blocker.blocking = true
				blocker.block_elapsed = 0.20
				game.ball = blocker.contact_center("block")
				game.previous_ball = game.ball
				game.ball_velocity = Vector2(-blocker.facing * incoming_speed, -400)
				game.check_contacts()
				expect(game.metrics.block == 1, "Side %d raised palms physically contact a %.0f-speed spike" % [side, incoming_speed])
				var descent_time = game.time_to_height(game.BALL_RADIUS)
				var landing_x = game.ball.x + game.ball_velocity.x * descent_time
				expect(descent_time < 0.4 and game.ball_velocity.y < -900, "A firm block drives the ball sharply downward")
				expect(landing_x > game.COURT_LEFT and landing_x < game.COURT_RIGHT and (landing_x - game.NET_X) * blocker.facing > 0, "A centered block predicts a landing inside the attacking court")
				for tick in range(240):
					game.step_ball(DT / 2)
					if game.phase == "point": break
				expect(game.point_reason == "BALL DOWN" and game.point_winner == side, "The actual blocked flight crosses the net and lands in the opposing court")

func check_setter_after_dive() -> void:
	for side in range(2):
		var game = MatchModel.new(7)
		game.human_id = side * 3
		game.phase = "rally"
		game.last_team = 1 - side
		game.last_player = (1 - side) * 3
		game.last_action = "spike"
		game.touches = 3
		game.players[game.human_id].reset(415 if side == 0 else 1585)
		game.ball = Vector2(440 if side == 0 else 1560, 105)
		game.previous_ball = game.ball
		game.ball_velocity = Vector2(0, -200)
		var setter_dived = false
		var setter_recovered = false
		for tick in range(278):
			game.step(DT, {"receive": tick < 8})
			var setter = game.players[side * 3 + 1]
			setter_dived = setter_dived or setter.dive_timer > 0
			setter_recovered = setter_recovered or setter.dive_recovery > 0
			if game.metrics.set > 0: break
		expect(setter_dived and setter_recovered, "Side %d setter completes both slide and hand-planted recovery" % side)
		expect(game.metrics.receive == 1 and game.metrics.set >= 1 and game.phase == "rally", "Side %d setter returns from the failed dive to set the human's pass" % side)

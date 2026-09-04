extends SceneTree
const MatchModel = preload("res://scripts/match_model.gd")
var failures: Array = []

func _initialize() -> void:
	check_human_control()
	check_rules()
	for seed_value in [7, 21, 83]:
		check_match(seed_value)
	if failures.is_empty():
		print("PASS: simulation, input, scoring, collisions and complete 3v3 matches")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)

func expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func check_human_control() -> void:
	var game = MatchModel.new(2)
	var x = game.players[0].pos.x
	for i in range(240): game.step(1.0 / 120.0)
	expect(game.phase == "serve_ready", "Human serve waits for toss input")
	expect(game.players[0].pos.x == x, "AI must not move the human")
	for i in range(60): game.step(1.0 / 120.0, {"toss": true, "aim_height": 1.0, "move": 1.0})
	expect(game.phase == "serve_aim" and game.toss_height > 650 and game.toss_forward > 270, "Aim keys adjust toss height and distance")
	expect(game.players[0].pos.x == x, "Aiming adjusts the arc without sliding the player")
	game.step(1.0 / 120.0)
	expect(game.phase == "serve_windup", "Releasing toss starts the throwing motion")
	for i in range(33): game.step(1.0 / 120.0)
	expect(game.phase == "serve_toss" and game.ball_velocity.y > 0, "Ball releases upward after the windup")
	expect(game.players[0].pos.y == 0, "Tossing does not automatically jump")
	for i in range(500):
		game.step(1.0 / 120.0)
		if game.phase == "point": break
	expect(game.metrics.serve == 0 and game.point_reason == "MISSED SERVE", "An untouched toss loses the serve")
	game.reset()
	game.serving_team = 1
	game.prepare_serve()
	x = game.players[0].pos.x
	for i in range(24): game.step(1.0 / 120.0, {"move": 1.0})
	expect(game.phase == "serve_ready" and game.players[0].pos.x > x + 20, "Human can reposition before an opponent serve")
	# Every role uses the same physical toss, approach, plant, jump and contact.
	for server in range(6):
		for arc in [Vector2(390, 70), Vector2(560, 210), Vector2(820, 370)]:
			game = MatchModel.new(11)
			game.serving_team = server / 3
			game.serve_order[game.serving_team] = server % 3
			game.prepare_serve()
			game.toss_height = arc.x
			game.toss_forward = arc.y
			var was_airborne = false
			var max_height = 0.0
			for i in range(720):
				game.step(1.0 / 120.0, {}, true)
				max_height = maxf(max_height, game.ball.y)
				was_airborne = was_airborne or game.players[server].pos.y > 35
				if game.metrics.serve > 0 or game.phase == "point": break
			expect(game.metrics.serve == 1 and was_airborne, "Role %d completes physical jump serve with arc %s" % [server, arc])
			expect(absf(max_height - arc.x) < 4, "Toss follows the displayed parabolic height")
	# Walking makes foley; standing and airborne travel do not make footsteps.
	var athlete = game.players[0]
	athlete.reset(400)
	var steps = 0
	for i in range(120):
		athlete.step(1.0 / 120.0, {"move": 1.0})
		steps += athlete.motion_events.count("step")
	expect(steps >= 6 and steps <= 8, "Footsteps follow distance travelled")
	athlete.step(1.0 / 120.0, {"jump": true})
	expect(athlete.jump_prepare > 0 and athlete.pos.y == 0, "Jump begins with a grounded foot plant")
	for i in range(20): athlete.step(1.0 / 120.0, {})
	expect(athlete.pos.y > 0, "Plant transitions to takeoff")
	athlete.begin_swing()
	expect(athlete.swing_timer == 0, "Windup has no instant ball contact")
	for i in range(9): athlete.step(1.0 / 120.0, {})
	expect(athlete.swing_timer > 0, "Swing has a timed contact window")
	athlete.confirm_hit()
	for i in range(8): athlete.step(1.0 / 120.0, {})
	expect(athlete.swing_elapsed > 0.12 and athlete.swing_timer == 0, "Follow-through cannot hit the ball twice")

func check_rules() -> void:
	var game = MatchModel.new()
	game.phase = "rally"
	game.last_team = 0
	game.ball = Vector2(1500, 12)
	game.ball_velocity = Vector2(0, -200)
	game.step_ball(0.02)
	expect(game.score == [1, 0], "Floor on opponent court awards one point")
	game.award_point(0, "BALL DOWN")
	expect(game.score == [1, 0], "A point may not be counted twice")
	game.prepare_serve()
	game.phase = "rally"
	game.last_team = 0
	game.ball = Vector2(1900, 12)
	game.ball_velocity = Vector2(0, -200)
	game.step_ball(0.02)
	expect(game.score == [1, 1], "Out is charged to the last team to touch")
	game.phase = "rally"
	game.score = [14, 14]
	game.award_point(0, "BALL DOWN")
	expect(game.phase == "point", "15-14 is not a win")
	game.phase = "rally"
	game.award_point(0, "BALL DOWN")
	expect(game.phase == "finished", "16-14 wins the set")
	game.prepare_serve()
	game.phase = "rally"
	game.last_team = 0
	game.ball = Vector2(982, 100)
	game.ball_velocity = Vector2(1300, 0)
	game.step(1.0 / 120.0, {}, true)
	game.step(1.0 / 120.0, {}, true)
	expect(game.ball.x < 1000 and game.ball_velocity.x < 0, "Fast ball bounces off the net")
	game.prepare_serve()
	game.phase = "rally"
	game.last_team = 0
	game.last_player = 1
	game.last_action = "receive"
	game.touches = 1
	expect(game.setter_for(0) == 2, "Middle sets if the setter receives")
	game.contact(game.players[2], "set")
	expect(game.touches == 2, "Set counts as second team touch")
	game.contact(game.players[0], "spike")
	game.contact_lock = 0
	game.contact(game.players[1], "receive")
	expect(game.point_reason == "FOUR TOUCHES", "Fourth team touch is a fault")
	var impact_game = MatchModel.new(5)
	impact_game.phase = "rally"
	impact_game.last_team = 0
	impact_game.last_player = 1
	impact_game.last_action = "set"
	impact_game.touches = 2
	impact_game.players[0].pos.y = 190
	impact_game.ball = Vector2(790, 315)
	impact_game.contact(impact_game.players[0], "spike")
	expect(impact_game.ball_velocity.x > 1800 and impact_game.ball_velocity.length() > 1850, "Spike leaves the hand at decisive attack speed")
	impact_game = MatchModel.new(5)
	impact_game.phase = "rally"
	impact_game.last_team = 1
	impact_game.last_player = 3
	impact_game.last_action = "spike"
	impact_game.touches = 3
	impact_game.ball_velocity = Vector2(-1200, -180)
	impact_game.contact(impact_game.players[2], "block")
	expect(impact_game.ball_velocity.x > 1150 and impact_game.ball_velocity.y <= -370, "Block sharply redirects the incoming spike")

func check_match(seed_value: int) -> void:
	var game = MatchModel.new(seed_value)
	for step in range(120 * 1200):
		game.step(1.0 / 120.0, {}, true)
		if not is_finite(game.ball.x) or not is_finite(game.ball.y):
			failures.append("Non-finite ball position")
			break
		if game.phase == "finished":
			break
	print("MATCH ", seed_value, " ", game.score, " time=", snappedf(game.time, 0.1), " longest=", game.longest_rally, " actions=", game.metrics)
	print("RALLIES ", game.history.slice(0, 8))
	expect(game.phase == "finished", "AI match %d must reach a result" % seed_value)
	expect(game.metrics.receive > 8, "Both teams must receive during a match")
	expect(game.metrics.set > 6, "Setters must set during a match")
	expect(game.metrics.spike > 5, "Spikers must attack during a match")
	expect(game.longest_rally >= 7, "AI must sustain a rally across the net")

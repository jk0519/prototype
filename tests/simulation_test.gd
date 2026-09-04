extends SceneTree
const MatchModel = preload("res://scripts/match_model.gd")
var failures: Array = []

func _initialize() -> void:
	check_human_control()
	check_rules()
	check_arcade_mechanics()
	for seed_value in [7, 21, 83]:
		check_match(seed_value)
	if failures.is_empty():
		print("PASS: simulation, input, continuous action animation, scoring, collisions and complete 3v3 matches")
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
	expect(game.ball.distance_to(game.players[0].pos + Vector2(25, 48)) < 0.01, "Ready server visibly holds the ball at the hip")
	for i in range(240): game.step(1.0 / 120.0)
	expect(game.phase == "serve_ready", "Human serve waits for toss input")
	expect(game.players[0].pos.x == x, "AI must not move the human")
	for i in range(8): game.step(1.0 / 120.0, {"toss": true})
	expect(game.phase == "serve_aim" and game.serve_charge == 0, "Serve begins with a deliberate ball-raise beat before charging")
	expect(game.ball.distance_to(game.players[0].pos + Vector2(25, 48)) < 0.01, "Ball stays in the low hand during the opening raise beat")
	for i in range(120): game.step(1.0 / 120.0, {"toss": true, "aim_height": 1.0, "move": 1.0})
	expect(game.phase == "serve_aim" and game.toss_height > 820 and game.toss_forward > 290, "Hold time charges toss distance while vertical input raises its height")
	expect(game.players[0].pos.x > x + 300, "Human can move throughout the serve setup")
	expect(game.ball.distance_to(game.players[0].pos + Vector2(32, 108)) < 0.01, "Charged serve keeps the ball attached to the visible tossing palm")
	var high_toss = game.toss_height
	var forward_toss = game.toss_forward
	var aimed_x = game.players[0].pos.x
	for i in range(24): game.step(1.0 / 120.0, {"toss": true, "aim_height": -1.0})
	expect(game.toss_height < high_toss - 75 and game.toss_forward > forward_toss, "Vertical input lowers height while continued hold increases toss distance")
	expect(absf(game.players[0].pos.x - aimed_x) < 35, "Releasing movement stops the server independently of toss charge")
	game.step(1.0 / 120.0)
	expect(game.phase == "serve_windup", "Releasing toss starts the throwing motion")
	expect(game.ball.distance_to(game.players[0].pos + Vector2(32, 108)) < 0.01, "Windup does not detach or float the ball before release")
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
				if game.metrics.serve > 0 or game.phase == "point": break
				max_height = maxf(max_height, game.ball.y)
				was_airborne = was_airborne or game.players[server].pos.y > 35
			expect(game.metrics.serve == 1 and was_airborne, "Role %d completes physical jump serve with arc %s" % [server, arc])
			expect(absf(max_height - arc.x) < 12, "Toss follows the displayed parabolic height")
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
	athlete.reset(400)
	athlete.step(1.0 / 120.0, {"move": 1.0, "dive": true})
	expect(athlete.dive_timer > 0.27 and athlete.velocity.x >= athlete.config.dive_speed, "Dive input launches a full-body floor save")
	var dive_launch = athlete.skeleton()
	for i in range(16): athlete.step(1.0 / 120.0, {})
	var dive_extension = athlete.skeleton()
	expect(dive_extension.hand.distance_to(dive_launch.hand) > 18, "Dive extends through intermediate airborne motion")
	for i in range(35): athlete.step(1.0 / 120.0, {})
	expect(athlete.dive_timer == 0 and athlete.dive_recovery > 0, "Dive transitions through a hand-planted recovery")
	var pose_player = MatchModel.new().players[0]
	pose_player.serve_pose = "windup"
	pose_player.serve_pose_time = 0.22
	var serve_pose = pose_player.skeleton()
	expect(serve_pose.shoulder.x - serve_pose.hip.x < -18, "Serve windup loads the torso sideways")
	pose_player.pos.y = 150
	pose_player.swing_elapsed = 0.035
	var coil_pose = pose_player.skeleton()
	pose_player.swing_elapsed = 0.118
	var strike_pose = pose_player.skeleton()
	expect(coil_pose.shoulder.x - coil_pose.hip.x < -25, "Spike begins with a backward whole-body coil")
	expect(strike_pose.shoulder.x - strike_pose.hip.x > 34 and strike_pose.head.x - strike_pose.hip.x > 42, "Spike snaps the torso and head sideways through contact")
	pose_player.swing_elapsed = 0.05
	var early_snap = pose_player.skeleton()
	pose_player.swing_elapsed = 0.08
	var mid_snap = pose_player.skeleton()
	pose_player.swing_elapsed = 0.105
	var late_snap = pose_player.skeleton()
	expect(early_snap.hand.x < mid_snap.hand.x and mid_snap.hand.x < late_snap.hand.x, "Spike arm whips through multiple ordered in-between frames")
	pose_player.reset(500)
	var set_start = pose_player.skeleton()
	for i in range(22): pose_player.step(1.0 / 120.0, {"set": true})
	var set_ready = pose_player.skeleton()
	expect(set_ready.hand.y > set_start.hand.y + 50 and set_ready.other_hand.y > set_start.other_hand.y + 50, "Set raises both hands through a timed preparation")

func check_rules() -> void:
	var game = MatchModel.new()
	expect(game.NET_HEIGHT == 172.0, "Net collision height matches the lowered visual net")
	game.phase = "rally"
	game.last_team = 0
	game.ball = Vector2(1500, 12)
	game.ball_velocity = Vector2(0, -200)
	game.step_ball(0.02)
	expect(game.score == [1, 0], "Floor on opponent court awards one point")
	game.award_point(0, "BALL DOWN")
	expect(game.score == [1, 0], "A point may not be counted twice")
	var point_x = game.players[0].pos.x
	for i in range(24): game.step(1.0 / 120.0, {"move": 1.0})
	expect(game.phase == "point" and game.players[0].pos.x > point_x + 20, "A scored rally keeps player movement live")
	for i in range(48): game.step(1.0 / 120.0)
	expect(game.phase == "serve_ready" and game.score == [1, 0], "A point flows directly into the next serve without ending the match")
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
	impact_game.players[0].swing_elapsed = 0.082
	impact_game.ball = impact_game.players[0].contact_center("spike")
	impact_game.previous_ball = impact_game.ball
	impact_game.contact(impact_game.players[0], "spike")
	expect(impact_game.events[-1].quality >= 0.86 and impact_game.ball_velocity.x > 2200, "Centered contact in the snap window earns a perfect high-speed spike")
	expect(impact_game.best_hit_speed == impact_game.events[-1].speed, "Human contact stores a personal best speed for the match")
	impact_game = MatchModel.new(5)
	impact_game.phase = "rally"
	impact_game.last_team = 1
	impact_game.last_player = 3
	impact_game.last_action = "spike"
	impact_game.touches = 3
	impact_game.ball_velocity = Vector2(-1900, -300)
	impact_game.contact(impact_game.players[2], "block")
	expect(impact_game.events[-1].quality > 0.75 and impact_game.ball_velocity.x > 1850 and impact_game.ball_velocity.y < -425, "Fast spike produces a forceful high-grade block rebound")

func check_arcade_mechanics() -> void:
	var game = MatchModel.new(13)
	var server = game.players[0]
	game.phase = "serve_toss"
	server.pos.y = 185
	server.swing_elapsed = 0.082
	game.ball = server.contact_center("serve")
	game.previous_ball = game.ball
	game.serve(server)
	expect(game.ball_topspin > 2500 and game.ball_velocity.length() > 3500, "Perfect jump serve launches at extreme arcade speed with severe topspin")
	var initial_vertical = game.ball_velocity.y
	game.contact_lock = 2
	game.step_ball(0.2)
	expect(game.ball_velocity.y < initial_vertical - 500, "Topspin visibly accelerates the serve downward")

	game = MatchModel.new(14)
	game.ball = Vector2(620, 155)
	game.set_ball(0)
	var set_apex = game.ball.y + game.ball_velocity.y * game.ball_velocity.y / (2.0 * game.BALL_GRAVITY)
	expect(set_apex >= 659 and game.ball_topspin == 0, "Set rises into an oversized clean attack arc")

	game.phase = "rally"
	game.last_team = 0
	game.last_player = 0
	game.last_action = "receive"
	game.touches = 1
	var setter = game.players[1]
	setter.reset(setter.home_x)
	game.ball = Vector2(setter.pos.x, 600)
	game.ball_velocity = Vector2(0, -500)
	var intentions = game.ai.intentions(game, true)
	expect(intentions[setter.id].get("set", false) and intentions[setter.id].get("jump", false), "AI setter jumps to take a high pass")

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

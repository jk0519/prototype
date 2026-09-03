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
	for i in range(240):
		game.step(1.0 / 120.0)
	expect(game.phase == "serve_ready", "Human serve must wait for input")
	expect(game.players[0].pos.x == x, "AI must not move the human")
	game.step(1.0 / 120.0, {"jump": true})
	expect(game.phase == "serve_toss", "Jump input starts the human serve")
	for i in range(18):
		game.step(1.0 / 120.0)
	game.step(1.0 / 120.0, {"jump": true})
	for i in range(20):
		game.step(1.0 / 120.0, {"move": 1.0})
	expect(game.metrics.serve == 1, "Second tap strikes a real serve contact")
	expect(game.players[0].pos.x > x + 15, "Keyboard intent moves the human")
	for delay in [36, 60]:
		game.reset()
		for i in range(42):
			game.step(1.0 / 120.0)
		game.step(1.0 / 120.0, {"jump": true})
		for i in range(delay):
			game.step(1.0 / 120.0)
		game.step(1.0 / 120.0, {"jump": true})
		expect(game.metrics.serve == 1, "Serve remains hittable after a %d-frame pause" % delay)
	game.serving_team = 1
	game.prepare_serve()
	x = game.players[0].pos.x
	for i in range(24):
		game.step(1.0 / 120.0, {"move": 1.0})
	expect(game.phase == "serve_ready" and game.players[0].pos.x > x + 20, "Human may reposition before an opponent serve")

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

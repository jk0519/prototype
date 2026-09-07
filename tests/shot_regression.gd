extends SceneTree
## Shot measurements must describe the simulation, including every AI contact.
const MatchModel = preload("res://scripts/match_model.gd")
const ShotTracker = preload("res://scripts/shot_tracker.gd")
const ACTIONS = ["serve", "receive", "dive", "set", "spike", "block", "free"]
const DT = 1.0 / 120.0
const METRES_PER_UNIT = 18.0 / 1640.0
var failures: Array = []
var attack_samples: int = 0

func _initialize() -> void:
	check_units()
	check_all_players_and_actions()
	check_attack_speed_limits()
	check_faults_are_not_shots()
	check_live_ai_measurements()
	if failures.is_empty():
		print("PASS: shot units, all 42 player/action combinations, ", attack_samples, " physical attack velocities, immutable measurements, faults and live AI telemetry")
	else:
		for failure in failures: printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func check_units() -> void:
	var tracker = ShotTracker.new()
	expect(is_equal_approx(tracker.height_metres(1640), 18.0), "Both court boundaries define exactly eighteen metres")
	expect(is_equal_approx(tracker.speed_kmh(Vector2(3, 4) * (1640.0 / 18.0)), 18.0), "Speed measures both velocity axes in kilometres per hour")
	expect(is_equal_approx(tracker.height_metres(250), 250 * METRES_PER_UNIT), "Contact height uses the same distance conversion as speed")
	for kmh in [0.0, 30.0, 80.0, 120.0, 130.0]:
		expect(absf(tracker.speed_kmh(Vector2(tracker.world_speed(kmh), 0)) - kmh) < 0.0001, "Speed conversion round trips %.0f km/h" % kmh)
	expect(tracker.recent().is_empty(), "An empty shot history has no recent measurements")

func setup_contact(player_id: int, action: String):
	var game = MatchModel.new(13 + player_id)
	var player = game.players[player_id]
	player.reset(800 if player.team == 0 else 1200)
	player.serve_pose = ""
	game.phase = "rally"
	game.last_team = player.team
	game.last_player = player.team * 3 + (player.id + 1) % 3
	game.last_action = "receive"
	game.touches = 1
	game.time = 12.5
	if action == "serve":
		game.phase = "serve_toss"
		game.server_id = player_id
		game.serving_team = player.team
		player.pos.x = 100 if player.team == 0 else 1900
		player.pos.y = 200
		player.swing_elapsed = 0.108
	elif action == "spike":
		game.touches = 2
		game.last_action = "set"
		player.pos.y = 200
		player.swing_elapsed = 0.108
	elif action == "block":
		game.last_team = 1 - player.team
		game.last_player = (1 - player.team) * 3
		game.last_action = "spike"
		player.pos.y = 180
		player.blocking = true
		player.block_elapsed = 0.2
	elif action in ["receive", "dive"]:
		game.last_team = 1 - player.team
		game.last_player = (1 - player.team) * 3
		game.last_action = "serve"
	elif action == "free":
		game.touches = 2
	game.ball = player.contact_center(action)
	game.previous_ball = game.ball
	game.ball_velocity = Vector2(-player.facing * 1800, -400)
	game.events.clear()
	return game

func perform_contact(game, action: String, player_id: int) -> void:
	if action == "serve": game.serve(game.players[player_id])
	else: game.contact(game.players[player_id], action)

func check_all_players_and_actions() -> void:
	var court = preload("res://scripts/court_view.gd").new()
	for player_id in range(6):
		for action in ACTIONS:
			var label = "Player %d %s" % [player_id, action]
			var game = setup_contact(player_id, action)
			perform_contact(game, action, player_id)
			expect(game.shots.history.size() == 1, label + " records exactly one measurement")
			if game.shots.history.is_empty(): continue
			var shot: Dictionary = game.shots.history[0]
			var event: Dictionary = game.events[-1]
			expect(shot.action == action and shot.player == player_id and shot.team == player_id / 3, label + " retains its actual action and player identity")
			expect(shot.role == game.players[player_id].role and shot.number == game.players[player_id].number, label + " carries its jersey and role")
			expect(shot.velocity.is_equal_approx(game.ball_velocity), label + " records the outgoing rather than incoming velocity")
			expect(absf(shot.speed_kmh - game.ball_velocity.length() * METRES_PER_UNIT * 3.6) < 0.001, label + " displays the physical outgoing speed")
			expect(absf(shot.contact_height_m - game.ball.y * METRES_PER_UNIT) < 0.0001, label + " displays height at contact rather than apex or root height")
			expect(shot.contact_position.is_equal_approx(game.ball) and shot.time == 12.5 and shot.shot_id == 1, label + " snapshots the contact and match time")
			expect(event.shot_id == shot.shot_id and event.speed_kmh == shot.speed_kmh and event.contact_height_m == shot.contact_height_m, label + " exposes the same measurement in the event")
			var snapshot: Dictionary = shot.duplicate(true)
			game.ball += Vector2(37, 90)
			game.ball_velocity = Vector2(70, -900)
			court.game = game
			court.add_event(event)
			expect(court.effects[-1].ball_velocity == snapshot.velocity, label + " preserves impact direction after a later ball deflection")
			game.step_ball(DT)
			game.award_point(0, "BALL DOWN")
			game.prepare_serve()
			expect(game.shots.history[0] == snapshot, label + " remains unchanged after flight, point and next serve setup")
			game.reset()
			expect(game.shots.history.is_empty() and game.shots.recent().is_empty(), label + " clears when a new match starts")
	court.free()

func check_attack_speed_limits() -> void:
	for player_id in range(6):
		for action in ["serve", "spike"]:
			for elapsed in [0.07, 0.08, 0.09, 0.10, 0.108, 0.12, 0.13, 0.14]:
				for elevation in [60.0, 185.0, 300.0]:
					for forward in [-180.0, 0.0, 120.0]:
						for power in [2700.0, 9000.0]:
							var game = setup_contact(player_id, action)
							var player = game.players[player_id]
							player.pos.x += player.facing * forward
							player.pos.y = elevation
							player.swing_elapsed = elapsed
							player.config.spike_speed = power
							game.ball = player.contact_center(action)
							game.previous_ball = game.ball
							var quality: float = game.strike_quality(player, action)
							var expected_kmh: float = clampf(lerpf(80, 120, quality) * power / 2700.0, 65, 125) if action == "serve" else clampf(lerpf(70, 125, quality) * power / 2700.0, 60, 130)
							perform_contact(game, action, player_id)
							var measured: float = game.ball_velocity.length() * METRES_PER_UNIT * 3.6
							var cap: float = 125 if action == "serve" else 130
							var label = "%s player %d t=%.3f y=%.0f x=%.0f power=%.0f" % [action, player_id, elapsed, elevation, forward, power]
							expect(is_finite(measured) and measured <= cap + 0.01, label + " limits the actual physical vector")
							expect(absf(measured - expected_kmh) < 0.01, label + " delivers the speed earned by contact quality")
							expect(game.shots.history.size() == 1 and absf(game.shots.history[0].speed_kmh - measured) < 0.001, label + " never hides a faster ball with a display clamp")
							attack_samples += 1

func check_faults_are_not_shots() -> void:
	for fault in ["DOUBLE TOUCH", "FOUR TOUCHES"]:
		var game = setup_contact(0, "receive")
		game.last_team = 0
		game.last_player = 0 if fault == "DOUBLE TOUCH" else 1
		game.last_action = "receive"
		game.touches = 1 if fault == "DOUBLE TOUCH" else 3
		game.contact(game.players[0], "receive")
		expect(game.point_reason == fault and game.phase == "point", fault + " is still called")
		expect(game.shots.history.is_empty(), fault + " cannot create a valid shot measurement")
		game.award_point(1, fault)
		game.emit_event("net", Vector2(1000, 100))
		expect(game.shots.history.is_empty(), "Point and net events cannot invent a player shot")

func check_live_ai_measurements() -> void:
	var game = MatchModel.new(21)
	var shot_events: int = 0
	var ai_contact_seen: bool = false
	var opponent_contact_seen: bool = false
	for frame in range(120 * 60):
		game.step(DT, {}, true)
		var last_shot: Dictionary = {}
		var net_contact: bool = false
		for event in game.events:
			net_contact = net_contact or event.kind == "net"
			if event.kind not in ACTIONS: continue
			shot_events += 1
			ai_contact_seen = ai_contact_seen or event.player != game.human_id
			opponent_contact_seen = opponent_contact_seen or event.player >= 3
			expect(event.shot_id == shot_events, "Live AI contacts have contiguous shot IDs without gaps or double recording")
			last_shot = event
			expect(event.velocity.is_equal_approx(game.shots.history[event.shot_id - 1].velocity), "Live AI event and history preserve the same contact-time velocity")
		# A contact can occur in any of four swept intervals. By frame end the
		# outgoing ball may have accumulated up to three more gravity steps.
		if not last_shot.is_empty() and game.phase == "rally" and not net_contact:
			expect(absf(game.ball_velocity.x - last_shot.velocity.x) < 0.01, "Live AI shot preserves its measured horizontal launch velocity")
			var gravity_change: float = last_shot.velocity.y - game.ball_velocity.y
			expect(gravity_change >= -0.01 and gravity_change <= game.ball_gravity() * DT * 0.75 + 0.01, "Live AI shot differs from its measured vertical launch velocity only by remaining substep gravity")
		expect(game.shots.history.size() == shot_events, "Every live player-contact event creates exactly one shot record")
		if game.phase == "finished": break
	var contact_metrics: int = 0
	for action in ACTIONS: contact_metrics += game.metrics[action]
	expect(ai_contact_seen and opponent_contact_seen and shot_events > 15, "Natural rallies include both teammate and opponent AI shots")
	expect(contact_metrics == shot_events and game.shots.history.size() == shot_events, "All live contact metrics are represented in shot history")
	var recent: Array = game.shots.recent(3)
	expect(recent.size() == mini(3, shot_events), "Recent shots returns the requested history tail")
	for index in range(recent.size()):
		expect(recent[index].shot_id == shot_events - index, "Recent shots are newest first")

extends RefCounted
## The authoritative match simulation. Coordinates are x across the court and
## y above the floor. Rendering and keyboard handling never change the rules.
const Athlete = preload("res://scripts/athlete.gd")
const AI = preload("res://scripts/ai_controller.gd")
const BALL_RADIUS: float = 11.0
const BALL_GRAVITY: float = 1500.0
const NET_X: float = 1000.0
const NET_HEIGHT: float = 207.0
const COURT_LEFT: float = 180.0
const COURT_RIGHT: float = 1820.0
const TOSS_MIN_HEIGHT: float = 340.0
const TOSS_MAX_HEIGHT: float = 940.0
const TOSS_MIN_FORWARD: float = 55.0
const TOSS_MAX_FORWARD: float = 440.0

var players: Array = []
var ai = AI.new()
var rng = RandomNumberGenerator.new()
var human_id: int = 0
var ball = Vector2(160, 135)
var previous_ball = ball
var ball_velocity = Vector2.ZERO
var score: Array = [0, 0]
var target_score: int = 15
var phase: String = "serve_ready"
var phase_time: float = 0.0
var toss_height: float = 560.0
var toss_forward: float = 210.0
var serve_charge: float = 0.0
var time: float = 0.0
var serving_team: int = 0
var serve_order: Array = [0, -1]
var server_id: int = 0
var last_team: int = -1
var last_player: int = -1
var last_action: String = ""
var touches: int = 0
var contact_lock: float = 0.0
var net_lock: float = 0.0
var point_winner: int = -1
var point_reason: String = ""
var rally_contacts: int = 0
var rally_time: float = 0.0
var longest_rally: int = 0
var best_hit_speed: float = 0.0
var events: Array = []
var history: Array = []
var metrics: Dictionary = {}
var ai_error_x: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var ai_jump_error: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var ai_block_attempt: Array = [true, true]

func _init(seed_value: int = 7):
	rng.seed = seed_value
	var roles = ["WS", "SET", "MB"]
	var homes = [415.0, 630.0, 840.0, 1585.0, 1370.0, 1160.0]
	for i in range(6):
		players.append(Athlete.new(i, i / 3, roles[i % 3], homes[i]))
	reset()

func reset() -> void:
	score = [0, 0]
	toss_height = 560
	toss_forward = 210
	serving_team = 0
	serve_order = [0, -1]
	server_id = 0
	time = 0
	longest_rally = 0
	best_hit_speed = 0
	history.clear()
	metrics = {"serve": 0, "receive": 0, "set": 0, "spike": 0, "block": 0, "free": 0, "dive": 0, "net": 0, "points": 0}
	prepare_serve()

func prepare_serve() -> void:
	phase = "serve_ready"
	phase_time = 0
	rally_time = 0
	rally_contacts = 0
	touches = 0
	last_team = -1
	last_player = -1
	last_action = ""
	contact_lock = 0
	net_lock = 0
	for p in players:
		p.movement_bounds = Vector2(65, 962) if p.team == 0 else Vector2(1038, 1935)
		p.reset(p.home_x)
	server_id = serving_team * 3 + maxi(serve_order[serving_team], 0)
	var server = players[server_id]
	server.movement_bounds = Vector2(-260, 962) if serving_team == 0 else Vector2(1038, 2260)
	server.reset(-125.0 if serving_team == 0 else 2125.0)
	server.serve_pose = "ready"
	serve_charge = 0
	ball = server.pos + server.skeleton().other_hand + Vector2(0, BALL_RADIUS)
	previous_ball = ball
	ball_velocity = Vector2.ZERO
	refresh_ai_accuracy()

func refresh_ai_accuracy() -> void:
	# Small physical positioning / jump errors create beatable opponents.
	# Outcomes are always resolved by actual ball contacts, never random points.
	for i in range(6):
		ai_error_x[i] = rng.randf_range(-118, 118)
		ai_jump_error[i] = rng.randf_range(-0.12, 0.10)
	ai_block_attempt = [rng.randf() < 0.63, rng.randf() < 0.63]

func attack_x(side: int) -> float:
	return 830.0 if side == 0 else 1170.0

func setter_for(side: int) -> int:
	var setter = side * 3 + 1
	if last_player == setter:
		return side * 3 + 2
	return setter

func time_to_height(height: float) -> float:
	# The descending intersection, shared by all AI roles.
	var discriminant = ball_velocity.y * ball_velocity.y + 2 * BALL_GRAVITY * (ball.y - height)
	if discriminant < 0:
		return 0.0
	return maxf(0, (ball_velocity.y + sqrt(discriminant)) / BALL_GRAVITY)

func toss_origin() -> Vector2:
	var server = players[server_id]
	return server.pos + Vector2(server.facing * 28, 129)

func toss_velocity() -> Vector2:
	var vy = sqrt(2 * BALL_GRAVITY * (toss_height - toss_origin().y))
	var flight = vy / BALL_GRAVITY + sqrt(2 * (toss_height - 300) / BALL_GRAVITY)
	return Vector2(players[server_id].facing * toss_forward / flight, vy)

func toss_preview() -> Array:
	var points: Array = []
	var origin = toss_origin()
	var velocity = toss_velocity()
	for i in range(45):
		var t = i * 0.045
		var point = origin + velocity * t - Vector2(0, 0.5 * BALL_GRAVITY * t * t)
		if point.y < BALL_RADIUS: break
		points.append(point)
	return points

func step_athletes(dt: float, intents: Array) -> void:
	for p in players:
		p.step(dt, intents[p.id])
		for kind in p.motion_events:
			events.append({"kind": kind, "position": p.pos, "player": p.id})

func step(dt: float, human_intent: Dictionary = {}, all_ai: bool = false) -> void:
	events.clear()
	if phase == "finished": return
	time += dt
	phase_time += dt
	contact_lock = maxf(0, contact_lock - dt)
	net_lock = maxf(0, net_lock - dt)
	if phase == "point":
		step_athletes(dt, [{}, {}, {}, {}, {}, {}])
		if phase_time >= 0.95: prepare_serve()
		return
	var intents = ai.intentions(self, all_ai)
	if not all_ai: intents[human_id] = human_intent
	var server = players[server_id]
	if phase in ["serve_ready", "serve_aim", "serve_windup"]:
		var input = intents[server_id]
		if phase == "serve_ready" and phase_time > 0.3 and input.get("toss", false):
			phase = "serve_aim"
			phase_time = 0
		if phase == "serve_aim":
			toss_forward = clampf(toss_forward + input.get("move", 0.0) * server.facing * dt * 220, TOSS_MIN_FORWARD, TOSS_MAX_FORWARD)
			toss_height = clampf(toss_height + input.get("aim_height", 0.0) * dt * 420, TOSS_MIN_HEIGHT, TOSS_MAX_HEIGHT)
			serve_charge = minf(1, serve_charge + dt * 0.65)
			if phase_time > 0.1 and not input.get("toss", false):
				phase = "serve_windup"
				phase_time = 0
		server.serve_pose = {"serve_ready": "ready", "serve_aim": "aim", "serve_windup": "windup"}[phase]
		server.serve_pose_time = phase_time
		intents[server_id] = {}
		step_athletes(dt, intents)
		ball = server.pos + server.skeleton().other_hand + Vector2(0, BALL_RADIUS)
		previous_ball = ball
		if phase == "serve_windup" and phase_time >= 0.26:
			ball = toss_origin()
			previous_ball = ball
			ball_velocity = toss_velocity()
			phase = "serve_toss"
			phase_time = 0
			server.serve_pose = "released"
			events.append({"kind": "toss", "position": ball, "player": server_id})
		return
	server.serve_pose_time = phase_time
	if phase == "serve_toss" and server.pos.y <= 0.01:
		server.movement_bounds = Vector2(-260, COURT_LEFT - 16) if server.team == 0 else Vector2(COURT_RIGHT + 16, 2260)
	else:
		server.movement_bounds = Vector2(-260, 962) if server.team == 0 else Vector2(1038, 2260)
	step_athletes(dt, intents)
	# Four swept intervals prevent fast spikes tunnelling through the net or floor.
	for substep in range(4):
		if phase not in ["rally", "serve_toss"]: break
		step_ball(dt / 4.0)
	if phase == "rally": rally_time += dt
	elif phase == "serve_toss" and phase_time > 4.0:
		award_point(1 - serving_team, "MISSED SERVE")

func step_ball(dt: float) -> void:
	previous_ball = ball
	ball_velocity.y -= BALL_GRAVITY * dt
	ball += ball_velocity * dt
	if contact_lock <= 0:
		check_contacts()
	if phase not in ["rally", "serve_toss"]:
		return
	# A solid net with a small, damped bounce. A ball that brushes the net stays live.
	if absf(ball.x - NET_X) < 5 + BALL_RADIUS and ball.y < NET_HEIGHT + BALL_RADIUS:
		if previous_ball.y >= NET_HEIGHT + BALL_RADIUS and ball_velocity.y < 0:
			ball.y = NET_HEIGHT + BALL_RADIUS
			ball_velocity.y = maxf(95, absf(ball_velocity.y) * 0.22)
			if absf(ball_velocity.x) < 45:
				ball_velocity.x = -65 if previous_ball.x < NET_X else 65
		else:
			var side = -1.0 if previous_ball.x < NET_X else 1.0
			ball.x = NET_X + side * (5 + BALL_RADIUS)
			ball_velocity.x = side * maxf(45, absf(ball_velocity.x) * 0.25)
			ball_velocity.y *= 0.75
		if net_lock <= 0:
			emit_event("net", ball)
			net_lock = 0.3
	if ball.y <= BALL_RADIUS:
		ball.y = BALL_RADIUS
		events.append({"kind": "floor", "position": ball, "player": -1})
		if phase == "serve_toss":
			award_point(1 - serving_team, "MISSED SERVE")
		elif ball.x < COURT_LEFT - BALL_RADIUS or ball.x > COURT_RIGHT + BALL_RADIUS:
			award_point(1 - last_team if last_team >= 0 else 1 - serving_team, "OUT")
		else:
			var landed_on = 0 if ball.x < NET_X else 1
			award_point(1 - landed_on, "BALL DOWN")
	elif ball.x < -400 or ball.x > 2400:
		award_point(1 - last_team if last_team >= 0 else 1 - serving_team, "OUT")

func within_contact(p, action: String, radius: Vector2) -> bool:
	return contact_alignment(p, action, radius) > 0

func contact_alignment(p, action: String, radius: Vector2) -> float:
	var center = p.contact_center(action)
	# Test the segment, not just the last position. Contact radii include the ball.
	var a = (previous_ball - center) / radius
	var b = (ball - center) / radius
	var segment = b - a
	var u = clampf(-a.dot(segment) / maxf(segment.length_squared(), 0.0001), 0, 1)
	return 1.0 - clampf((a + segment * u).length(), 0, 1)

func strike_quality(p, action: String) -> float:
	var radius = Vector2(42, 38) if action == "serve" else Vector2(46, 42)
	var center = p.contact_center(action)
	var horizontal = 1.0 - clampf(absf(ball.x - center.x) / radius.x, 0, 1)
	var timing = 0.55
	if p.swing_elapsed >= 0:
		timing = 1.0 - clampf(absf(p.swing_elapsed - 0.082) / 0.052, 0, 1)
	# The ball first crosses the outside of the swept contact ellipse, so grade
	# horizontal hand placement separately from the swing-frame timing.
	return clampf(0.18 + 0.82 * (timing * 0.72 + horizontal * 0.28), 0.18, 1.0)

func check_contacts() -> void:
	if phase == "serve_toss":
		var server = players[server_id]
		if server.pos.y > 35 and server.swing_timer > 0 and within_contact(server, "serve", Vector2(42, 38)):
			serve(server)
		return
	# Block contacts take priority at the net. They do not consume a team touch.
	for p in players:
		if p.blocking and p.pos.y > 35 and p.team != last_team and last_action != "serve":
			if within_contact(p, "block", Vector2(35, 54)):
				contact(p, "block")
				return
	for p in players:
		if p.swing_timer > 0 and p.pos.y > 35:
			if within_contact(p, "spike", Vector2(46, 42)):
				contact(p, "spike")
				return
	if ball_velocity.y > 75:
		return
	for p in players:
		if p.setting and p.team == last_team and touches == 1:
			if within_contact(p, "set", Vector2(65, 48)):
				contact(p, "set")
				return
	for p in players:
		if not p.receiving or p.pos.y > 30:
			continue
		var action = "dive" if p.dive_timer > 0 else "receive"
		var radius = Vector2(84, 35) if action == "dive" else Vector2(66, 47)
		if within_contact(p, action, radius):
			contact(p, action)
			return

func serve(p) -> void:
	var quality = strike_quality(p, "serve")
	phase = "rally"
	phase_time = 0
	last_team = p.team
	last_player = p.id
	last_action = "serve"
	touches = 1
	contact_lock = 0.24
	p.confirm_hit(ball - Vector2(p.facing * BALL_RADIUS, 0))
	p.serve_pose = ""
	ball = p.contact_center("serve") + Vector2(p.facing * BALL_RADIUS, 0)
	var target = 1580.0 + rng.randf_range(-120, 120) if p.team == 0 else 420.0 + rng.randf_range(-120, 120)
	var height_power = clampf((ball.y - 205) / 135.0, 0, 1)
	var strike_speed = p.config.spike_speed * lerpf(0.78, 1.18, quality) * lerpf(0.92, 1.05, height_power)
	var flight = maxf(0.48, absf(target - ball.x) / strike_speed)
	ball_velocity = arc_to(Vector2(target, 75), flight)
	if p.id == human_id:
		best_hit_speed = maxf(best_hit_speed, ball_velocity.length())
	rally_contacts += 1
	emit_event("serve", ball, p.id, {"quality": quality, "speed": ball_velocity.length()})

func contact(p, action: String) -> void:
	if action != "block" and p.id == last_player and last_action != "block":
		award_point(1 - p.team, "DOUBLE TOUCH")
		return
	if action == "block":
		touches = 0
	elif p.team != last_team:
		touches = 1
	else:
		touches += 1
	if touches > 3:
		award_point(1 - p.team, "FOUR TOUCHES")
		return
	last_team = p.team
	last_player = p.id
	contact_lock = 0.13
	p.contact_flash = 0.18
	p.swing_timer = 0
	var quality = 0.62
	match action:
		"block":
			var incoming = ball_velocity.length()
			quality = clampf((incoming - 700.0) / 1500.0, 0.25, 1.0)
			ball_velocity = Vector2(p.facing * maxf(950, absf(ball_velocity.x) * lerpf(0.84, 1.05, quality)), -lerpf(270, 480, quality))
		"spike":
			quality = strike_quality(p, "spike")
			p.confirm_hit(ball - Vector2(p.facing * BALL_RADIUS, 0))
			ball = p.contact_center("spike") + Vector2(p.facing * BALL_RADIUS, 0)
			var depth = rng.randf_range(430, 740)
			if p.id == human_id:
				depth = 605.0 - p.last_move * p.facing * 125.0
			var target = NET_X + p.facing * depth
			var strike_speed = p.config.spike_speed * lerpf(0.78, 1.22, quality)
			var flight = maxf(0.28, absf(target - ball.x) / strike_speed)
			ball_velocity = arc_to(Vector2(target, BALL_RADIUS), flight)
		"set":
			set_ball(p.team)
		_:
			if touches == 1:
				var setter = players[setter_for(p.team)]
				var target = Vector2(clampf(setter.pos.x, 360, 790) if p.team == 0 else clampf(setter.pos.x, 1210, 1640), setter.config.height + 15)
				# A teammate may already be sliding when the human makes the pass.
				# Give the pass enough height for that real movement to finish.
				var recovery_x = setter.pos.x + setter.velocity.x * setter.dive_timer
				var recovery_time = setter.dive_timer + absf(target.x - recovery_x) / setter.config.run_speed + 0.2
				if setter.dive_timer > 0:
					recovery_time += 2.0 * absf(setter.velocity.x) / setter.config.acceleration
				var flight = maxf(0.62, maxf(recovery_time, absf(target.x - ball.x) / 650.0))
				ball_velocity = arc_to(target, flight)
			elif touches == 2:
				set_ball(p.team)
				action = "set"
			else:
				var target = Vector2(1510 if p.team == 0 else 490, 70)
				ball_velocity = arc_to(target, maxf(0.82, absf(target.x - ball.x) / 1050.0))
				action = "free"
	last_action = action
	rally_contacts += 1
	var details = {}
	if action in ["spike", "block"]:
		details = {"quality": quality, "speed": ball_velocity.length()}
	if action == "spike" and p.id == human_id:
		best_hit_speed = maxf(best_hit_speed, ball_velocity.length())
	emit_event(action, ball, p.id, details)

func set_ball(side: int) -> void:
	var apex = maxf(370.0, ball.y + 60)
	var vy = sqrt(2 * BALL_GRAVITY * (apex - ball.y))
	var flight = vy / BALL_GRAVITY + sqrt(2 * (apex - 300.0) / BALL_GRAVITY)
	ball_velocity = Vector2((attack_x(side) - ball.x) / flight, vy)

func arc_to(target: Vector2, flight: float) -> Vector2:
	return Vector2((target.x - ball.x) / flight, (target.y - ball.y + 0.5 * BALL_GRAVITY * flight * flight) / flight)

func emit_event(kind: String, position: Vector2, player_id: int = -1, details: Dictionary = {}) -> void:
	if kind in ["serve", "receive", "set", "spike", "block", "dive", "free"]:
		refresh_ai_accuracy()
	metrics[kind] = metrics.get(kind, 0) + 1
	var event = {"kind": kind, "position": position, "player": player_id}
	event.merge(details, true)
	events.append(event)

func award_point(winner: int, reason: String) -> void:
	if phase in ["point", "finished"]:
		return
	point_winner = winner
	point_reason = reason
	score[winner] += 1
	longest_rally = maxi(longest_rally, rally_contacts)
	metrics["points"] += 1
	history.append({"winner": winner, "reason": reason, "contacts": rally_contacts, "seconds": snappedf(rally_time, 0.01)})
	if winner != serving_team:
		serve_order[winner] = (serve_order[winner] + 1) % 3
	serving_team = winner
	ball_velocity = Vector2.ZERO
	phase_time = 0
	if score[winner] >= target_score and score[winner] - score[1 - winner] >= 2:
		phase = "finished"
	else:
		phase = "point"
	events.append({"kind": "point", "position": ball, "player": -1})

extends RefCounted
const Config = preload("res://scripts/player_config.gd")
const SWING_WINDUP = 0.055
const SWING_END = 0.46
const DIVE_DURATION = 0.40
const DIVE_RECOVERY = 0.34

var id: int
var team: int
var role: String
var number: int
var config: Resource
var pos: Vector2
var previous_pos: Vector2
var velocity = Vector2.ZERO
var home_x: float
var facing: float
var swing_timer: float = 0.0
var swing_cooldown: float = 0.0
var swing_elapsed: float = -1.0
var swing_connected: bool = false
var impact_hand = Vector2(43, 127)
var dive_timer: float = 0.0
var dive_elapsed: float = -1.0
var dive_recovery: float = 0.0
var dive_cooldown: float = 0.0
var jump_cooldown: float = 0.0
var jump_prepare: float = 0.0
var landing_timer: float = 0.0
var contact_flash: float = 0.0
var receiving: bool = false
var setting: bool = false
var blocking: bool = false
var last_move: float = 0.0
var run_clock: float = 0.0
var animation_clock: float = 0.0
var set_elapsed: float = -1.0
var block_elapsed: float = -1.0
var receive_elapsed: float = -1.0
var step_distance: float = 0.0
var skid_cooldown: float = 0.0
var serve_pose: String = ""
var serve_pose_time: float = 0.0
var movement_bounds = Vector2(65, 962)
var motion_events: Array = []

func _init(player_id: int, player_team: int, player_role: String, x: float):
	id = player_id
	team = player_team
	role = player_role
	number = [7, 2, 11, 9, 4, 6][id]
	config = Config.for_role(role)
	home_x = x
	facing = 1.0 if team == 0 else -1.0
	movement_bounds = Vector2(65, 962) if team == 0 else Vector2(1038, 1935)
	reset(x)

func reset(x: float) -> void:
	pos = Vector2(x, 0)
	previous_pos = pos
	velocity = Vector2.ZERO
	swing_timer = 0
	swing_cooldown = 0
	swing_elapsed = -1
	swing_connected = false
	dive_timer = 0
	dive_elapsed = -1
	dive_recovery = 0
	dive_cooldown = 0
	jump_cooldown = 0
	jump_prepare = 0
	landing_timer = 0
	contact_flash = 0
	receiving = false
	setting = false
	blocking = false
	serve_pose = ""
	serve_pose_time = 0
	step_distance = 0
	run_clock = 0
	animation_clock = id * 0.37
	set_elapsed = -1
	block_elapsed = -1
	receive_elapsed = -1
	skid_cooldown = 0
	motion_events.clear()

func jump() -> void:
	if pos.y <= 0.01 and jump_cooldown <= 0 and dive_timer <= 0 and jump_prepare <= 0:
		jump_prepare = 0.085
		jump_cooldown = 0.22
		motion_events.append("plant")

func begin_swing() -> void:
	if pos.y > 25 and swing_cooldown <= 0 and not blocking:
		swing_elapsed = 0
		swing_cooldown = SWING_END + 0.04
		swing_connected = false
		motion_events.append("swing")

func confirm_hit(contact_position: Vector2 = Vector2.INF) -> void:
	impact_hand = Vector2(43, config.reach)
	if contact_position.is_finite():
		impact_hand = contact_position - pos
		impact_hand.x *= facing
		impact_hand.y = minf(impact_hand.y, config.reach + 20)
	swing_connected = true
	swing_timer = 0
	swing_elapsed = 0.12
	contact_flash = 0.14

func step(dt: float, intent: Dictionary) -> void:
	motion_events.clear()
	animation_clock += dt
	previous_pos = pos
	swing_cooldown = maxf(0, swing_cooldown - dt)
	if swing_elapsed >= 0:
		swing_elapsed += dt
		if swing_elapsed >= SWING_END: swing_elapsed = -1
	swing_timer = 0.001 if swing_elapsed >= SWING_WINDUP and swing_elapsed < 0.17 and not swing_connected else 0.0
	var was_diving = dive_timer > 0
	dive_timer = maxf(0, dive_timer - dt)
	if dive_timer > 0:
		dive_elapsed += dt
	elif was_diving:
		dive_elapsed = -1
		dive_recovery = DIVE_RECOVERY
	dive_recovery = maxf(0, dive_recovery - dt)
	dive_cooldown = maxf(0, dive_cooldown - dt)
	jump_cooldown = maxf(0, jump_cooldown - dt)
	landing_timer = maxf(0, landing_timer - dt)
	contact_flash = maxf(0, contact_flash - dt)
	skid_cooldown = maxf(0, skid_cooldown - dt)
	receiving = intent.get("receive", false)
	setting = intent.get("set", false)
	blocking = intent.get("block", false)
	set_elapsed = set_elapsed + dt if setting and set_elapsed >= 0 else (0.0 if setting else -1.0)
	block_elapsed = block_elapsed + dt if blocking and block_elapsed >= 0 else (0.0 if blocking else -1.0)
	receive_elapsed = receive_elapsed + dt if receiving and receive_elapsed >= 0 else (0.0 if receiving else -1.0)
	var move = clampf(intent.get("move", 0.0), -1, 1)
	last_move = move
	if intent.get("dive", false) and pos.y <= 0.01 and dive_cooldown <= 0 and jump_prepare <= 0:
		dive_timer = DIVE_DURATION
		dive_elapsed = 0.0
		dive_recovery = 0.0
		dive_cooldown = 1.0
		velocity.x = (move if absf(move) > 0.1 else facing) * config.dive_speed
		motion_events.append("slide")
	if intent.get("jump", false):
		if pos.y <= 0.01: jump()
		elif dive_timer <= 0: begin_swing()
	if intent.get("swing", false): begin_swing()
	if blocking and pos.y <= 0.01: jump()
	if pos.y <= 0.01 and absf(velocity.x) > 180 and move * velocity.x < -60 and skid_cooldown <= 0:
		motion_events.append("skid")
		skid_cooldown = 0.3
	if dive_timer <= 0:
		velocity.x = move_toward(velocity.x, move * config.run_speed, config.acceleration * dt)
	else:
		receiving = true
	pos.x = clampf(pos.x + velocity.x * dt, movement_bounds.x, movement_bounds.y)
	if jump_prepare > 0:
		jump_prepare = maxf(0, jump_prepare - dt)
		if jump_prepare == 0:
			velocity.y = config.jump_speed
			motion_events.append("takeoff")
	if pos.y > 0 or velocity.y > 0:
		velocity.y -= config.gravity * dt
		pos.y += velocity.y * dt
		if pos.y <= 0:
			pos.y = 0
			velocity.y = 0
			blocking = false
			landing_timer = 0.16
			motion_events.append("land")
	if pos.y < 1 and dive_timer <= 0:
		var distance = absf(pos.x - previous_pos.x)
		run_clock += distance * PI / 72.0
		step_distance += distance
		if step_distance >= 72:
			step_distance = fmod(step_distance, 72)
			motion_events.append("step")

func skeleton() -> Dictionary:
	# This pose supplies both rendered joints and the actual striking hand.
	# Local coordinates use y-up, then mirror for the other team.
	var h = config.height / 104.0
	var running = absf(velocity.x) > 20 and pos.y < 1
	var stride_wave = sin(run_clock) if running else 0.0
	var stride = stride_wave * 22
	var lean = clampf(velocity.x * facing / 65, -6, 6)
	# Even the idle silhouette keeps a slight ready stance; receives compress it
	# further. This avoids the rigid mannequin pose between contacts.
	var crouch = (12.0 if receiving else 4.0) if pos.y < 1 else 0.0
	if jump_prepare > 0: crouch += 17 * sin((1 - jump_prepare / 0.085) * PI * 0.75)
	crouch += 12 * (landing_timer / 0.16)
	var bounce = absf(cos(run_clock)) * 2.7 if running else 0.0
	var back_lift = maxf(0, stride_wave) * 7.0
	var front_lift = maxf(0, -stride_wave) * 7.0
	var breathe = sin(animation_clock * 2.2) * 0.8 if not running and pos.y < 1 else 0.0
	var follow = clampf((swing_elapsed - 0.12) / 0.22, 0, 1) if swing_elapsed >= 0 else 0.0
	var joints = {
		"hip": Vector2(0, 40 * h - crouch + bounce),
		"shoulder": Vector2(lean, 79 * h - crouch + bounce + breathe),
		"head": Vector2(lean + 2, 101 * h - crouch + bounce + breathe * 1.25),
		"back_knee": Vector2(-9 - stride * 0.35, 21 - crouch * 0.35 + back_lift * 0.55),
		"back_foot": Vector2(-13 - stride, 3 + back_lift),
		"front_knee": Vector2(10 + stride * 0.35, 21 - crouch * 0.35 + front_lift * 0.55),
		"front_foot": Vector2(14 + stride, 3 + front_lift),
		"elbow": Vector2(17 + stride * 0.33, 59 - stride * 0.46),
		"hand": Vector2(15 + stride * 0.77, 45 - stride * 0.28),
		"other_elbow": Vector2(-18 - stride * 0.30, 57 + stride * 0.46),
		"other_hand": Vector2(-14 - stride * 0.73, 44 + stride * 0.27)
	}
	# A jump starts with a deep arm swing behind the hips. The feet leave only
	# after that plant finishes, so takeoff reads as force rather than levitation.
	if jump_prepare > 0:
		var plant = smoothstep(0.0, 1.0, 1.0 - jump_prepare / 0.085)
		joints.hip.x += lerpf(0, -7, plant)
		joints.shoulder.x += lerpf(0, 8, plant)
		joints.head.x += lerpf(0, 10, plant)
		joints.elbow = joints.elbow.lerp(Vector2(-16, 48), plant)
		joints.hand = joints.hand.lerp(Vector2(-31, 31), plant)
		joints.other_elbow = joints.other_elbow.lerp(Vector2(-22, 47), plant)
		joints.other_hand = joints.other_hand.lerp(Vector2(-38, 35), plant)
	if pos.y > 1:
		var ascent = clampf(1.0 - maxf(velocity.y, 0) / config.jump_speed, 0, 1)
		var falling = clampf(-velocity.y / config.jump_speed, 0, 1)
		var load = smoothstep(0.0, 0.72, ascent)
		joints.back_knee = Vector2(-13, 25).lerp(Vector2(-21, 28), ascent)
		joints.back_foot = Vector2(-20, 8).lerp(Vector2(-34 + follow * 15, 12), ascent)
		joints.front_knee = Vector2(14, 22).lerp(Vector2(19 + follow * 5, 20), ascent)
		joints.front_foot = Vector2(17, 4).lerp(Vector2(8 + follow * 11, 1), ascent)
		joints.elbow = Vector2(-14, 49).lerp(Vector2(-30, 102 * h), load).lerp(Vector2(13, 71), falling)
		joints.hand = Vector2(-29, 32).lerp(Vector2(-37, config.reach - 7), load).lerp(Vector2(5, 48), falling)
		joints.other_elbow = Vector2(-21, 48).lerp(Vector2(24, 102 * h), load).lerp(Vector2(-16, 69), falling)
		joints.other_hand = Vector2(-37, 34).lerp(Vector2(36, config.reach - 3), load).lerp(Vector2(-20, 48), falling)
		joints.shoulder.x -= lerpf(0, 7, load) - follow * 4
		joints.head.x -= lerpf(0, 6, load) - follow * 3
	if serve_pose in ["ready", "aim", "windup"]:
		var lift = smoothstep(0.03, 0.26, serve_pose_time) if serve_pose == "windup" else 0.0
		# Load the torso away from the court as the tossing shoulder rises. The
		# hip/shoulder separation makes the serve a whole-body throw.
		var load = 0.24 if serve_pose == "aim" else lift
		joints.hip.x = 6 * load
		joints.shoulder.x = -17 * load
		joints.shoulder.y += 3 * load
		joints.head.x = -21 * load
		joints.head.y += 2 * load
		joints.back_knee.x -= 7 * load
		joints.front_knee.x += 5 * load
		joints.other_elbow = Vector2(15, lerpf(57, 94, lift))
		joints.other_hand = Vector2(28, lerpf(78, 118, lift))
		joints.elbow = Vector2(-20, 56)
		joints.hand = Vector2(-29, 67)
	elif serve_pose == "released" and serve_pose_time < 0.38 and pos.y < 1:
		var release = smoothstep(0.0, 0.18, serve_pose_time)
		joints.hip.x = lerpf(5, -6, release)
		joints.shoulder.x = lerpf(-15, 18, release)
		joints.head.x = lerpf(-19, 23, release)
		joints.other_elbow = Vector2(20, 99)
		joints.other_hand = Vector2(29, 125)
	if swing_elapsed >= 0:
		if swing_elapsed < 0.12:
			# Coil back, then snap the shoulder past the hips. This creates the
			# sideways bow seen in a real jump serve and spike instead of moving
			# only the striking arm.
			var windup = smoothstep(0.0, 0.045, swing_elapsed)
			var strike = smoothstep(0.045, 0.108, swing_elapsed)
			joints.hip = Vector2(0, 40 * h).lerp(Vector2(8, 42 * h), windup).lerp(Vector2(-10, 38 * h), strike)
			joints.shoulder = Vector2(-4, 79 * h).lerp(Vector2(-21, 84 * h), windup).lerp(Vector2(27, 76 * h), strike)
			joints.head = Vector2(-1, 101 * h).lerp(Vector2(-25, 108 * h), windup).lerp(Vector2(35, 96 * h), strike)
			joints.back_knee = Vector2(-18, 26).lerp(Vector2(-22, 27), windup).lerp(Vector2(-28, 21), strike)
			joints.back_foot = Vector2(-31, 10).lerp(Vector2(-36, 12), windup).lerp(Vector2(-43, 7), strike)
			joints.front_knee = Vector2(17, 20).lerp(Vector2(18, 19), windup).lerp(Vector2(24, 26), strike)
			joints.front_foot = Vector2(9, 0).lerp(Vector2(11, 0), windup).lerp(Vector2(22, 8), strike)
			joints.elbow = Vector2(-25, 102 * h).lerp(Vector2(-31, 101 * h), windup).lerp(Vector2(20, config.reach - 14), strike)
			joints.hand = Vector2(-18, config.reach - 5).lerp(Vector2(-36, config.reach - 8), windup).lerp(Vector2(52, config.reach + 3), strike)
			joints.other_elbow = Vector2(17, 100 * h).lerp(Vector2(25, 103 * h), windup).lerp(Vector2(-7, 78 * h), strike)
			joints.other_hand = Vector2(28, 119 * h).lerp(Vector2(36, config.reach - 3), windup).lerp(Vector2(-29, 57 * h), strike)
		else:
			# Hold the contact silhouette briefly, whip the arm across the body, then
			# unwind. The asymmetric legs preserve rotation through the landing.
			var whip = smoothstep(0.12, 0.24, swing_elapsed)
			var recover = smoothstep(0.24, SWING_END, swing_elapsed)
			var contact_hand = impact_hand if swing_connected else Vector2(52, config.reach + 3)
			joints.hip = Vector2(-10, 38 * h).lerp(Vector2(-4, 35 * h), whip).lerp(Vector2(1, 40 * h), recover)
			joints.shoulder = Vector2(27, 76 * h).lerp(Vector2(14, 67 * h), whip).lerp(Vector2(-3, 79 * h), recover)
			joints.head = Vector2(35, 96 * h).lerp(Vector2(25, 88 * h), whip).lerp(Vector2(0, 101 * h), recover)
			joints.back_knee = Vector2(-28, 21).lerp(Vector2(-17, 31), whip).lerp(Vector2(-15, 27), recover)
			joints.back_foot = Vector2(-43, 7).lerp(Vector2(-31, 16), whip).lerp(Vector2(-18, 5), recover)
			joints.front_knee = Vector2(24, 26).lerp(Vector2(31, 18), whip).lerp(Vector2(13, 19), recover)
			joints.front_foot = Vector2(22, 8).lerp(Vector2(36, 2), whip).lerp(Vector2(7, 0), recover)
			joints.elbow = Vector2(20, config.reach - 14).lerp(Vector2(26, 54), whip).lerp(Vector2(20, 69), recover)
			joints.hand = contact_hand.lerp(Vector2(-5, 42), whip).lerp(Vector2(7, 45), recover)
			joints.other_elbow = Vector2(-7, 78 * h).lerp(Vector2(-23, 63), whip).lerp(Vector2(-18, 67), recover)
			joints.other_hand = Vector2(-29, 57 * h).lerp(Vector2(-10, 42), whip).lerp(Vector2(-20, 46), recover)
	elif blocking:
		var block_raise = smoothstep(0.0, 0.13, maxf(block_elapsed, 0))
		var block_recoil = sin(clampf((0.18 - contact_flash) / 0.18, 0, 1) * PI) if contact_flash > 0 else 0.0
		joints.elbow = joints.elbow.lerp(Vector2(20, 107 * h - block_recoil * 7), block_raise)
		joints.hand = joints.hand.lerp(Vector2(33, config.reach + 7 - block_recoil * 10), block_raise)
		joints.other_elbow = joints.other_elbow.lerp(Vector2(-14, 108 * h - block_recoil * 7), block_raise)
		joints.other_hand = joints.other_hand.lerp(Vector2(15, config.reach + 7 - block_recoil * 10), block_raise)
	elif setting:
		var air_lift = minf(pos.y * 0.025, 6.0)
		var set_raise = smoothstep(0.0, 0.16, maxf(set_elapsed, 0))
		var set_release = sin(clampf((0.18 - contact_flash) / 0.18, 0, 1) * PI) if contact_flash > 0 else 0.0
		joints.shoulder.y += air_lift + set_release * 2
		joints.elbow = joints.elbow.lerp(Vector2(23, 99 * h + air_lift - set_release * 4), set_raise)
		joints.hand = joints.hand.lerp(Vector2(7, config.height + 15 - set_release * 7), set_raise)
		joints.other_elbow = joints.other_elbow.lerp(Vector2(-23, 99 * h + air_lift - set_release * 4), set_raise)
		joints.other_hand = joints.other_hand.lerp(Vector2(-7, config.height + 15 - set_release * 7), set_raise)
	elif receiving:
		var receive_ready = smoothstep(0.0, 0.14, maxf(receive_elapsed, 0))
		var receive_bump = sin(clampf((0.18 - contact_flash) / 0.18, 0, 1) * PI) if contact_flash > 0 else 0.0
		joints.shoulder.x += receive_bump * 4
		joints.elbow = joints.elbow.lerp(Vector2(13, 65 + receive_bump * 5), receive_ready)
		joints.hand = joints.hand.lerp(Vector2(35, 77 + receive_bump * 7), receive_ready)
		joints.other_elbow = joints.other_elbow.lerp(Vector2(10, 64 + receive_bump * 5), receive_ready)
		joints.other_hand = joints.other_hand.lerp(Vector2(28, 77 + receive_bump * 7), receive_ready)
	if dive_timer > 0:
		var d = signf(velocity.x) * facing
		if d == 0: d = 1
		var dive_out = smoothstep(0.0, 0.11, maxf(dive_elapsed, 0))
		var dive_tuck = smoothstep(0.25, DIVE_DURATION, maxf(dive_elapsed, 0))
		joints.hip = joints.hip.lerp(Vector2(-d * 4, 25), dive_out).lerp(Vector2(-d * 9, 19), dive_tuck)
		joints.shoulder = joints.shoulder.lerp(Vector2(d * 31, 35), dive_out).lerp(Vector2(d * 23, 27), dive_tuck)
		joints.head = joints.head.lerp(Vector2(d * 53, 41), dive_out).lerp(Vector2(d * 42, 30), dive_tuck)
		joints.back_knee = joints.back_knee.lerp(Vector2(-d * 16, 18), dive_out).lerp(Vector2(-d * 7, 15), dive_tuck)
		joints.back_foot = joints.back_foot.lerp(Vector2(-d * 44, 9), dive_out).lerp(Vector2(-d * 29, 5), dive_tuck)
		joints.front_knee = joints.front_knee.lerp(Vector2(-d * 3, 17), dive_out).lerp(Vector2(d * 2, 13), dive_tuck)
		joints.front_foot = joints.front_foot.lerp(Vector2(-d * 31, 3), dive_out).lerp(Vector2(-d * 21, 3), dive_tuck)
		joints.elbow = joints.elbow.lerp(Vector2(d * 53, 33), dive_out).lerp(Vector2(d * 39, 21), dive_tuck)
		joints.hand = joints.hand.lerp(Vector2(d * 76, 28), dive_out).lerp(Vector2(d * 57, 12), dive_tuck)
		joints.other_elbow = joints.other_elbow.lerp(Vector2(d * 47, 25), dive_out).lerp(Vector2(d * 27, 18), dive_tuck)
		joints.other_hand = joints.other_hand.lerp(Vector2(d * 70, 22), dive_out).lerp(Vector2(d * 46, 9), dive_tuck)
	elif dive_recovery > 0:
		# One hand plants, then the hips rise through a crouch. This prevents the
		# full dive silhouette from snapping directly back to standing.
		var recover = smoothstep(0.0, 1.0, 1.0 - dive_recovery / DIVE_RECOVERY)
		var d = signf(velocity.x) * facing
		if d == 0: d = 1
		joints.hip = Vector2(-d * 9, 19).lerp(Vector2(0, 28), recover)
		joints.shoulder = Vector2(d * 23, 27).lerp(Vector2(d * 5, 62), recover)
		joints.head = Vector2(d * 42, 30).lerp(Vector2(d * 7, 85), recover)
		joints.back_knee = Vector2(-d * 7, 15).lerp(Vector2(-12, 15), recover)
		joints.back_foot = Vector2(-d * 29, 5).lerp(Vector2(-20, 3), recover)
		joints.front_knee = Vector2(d * 2, 13).lerp(Vector2(13, 16), recover)
		joints.front_foot = Vector2(-d * 21, 3).lerp(Vector2(20, 3), recover)
		joints.elbow = Vector2(d * 39, 21).lerp(Vector2(20, 49), recover)
		joints.hand = Vector2(d * 57, 12).lerp(Vector2(25, 38), recover)
		joints.other_elbow = Vector2(d * 27, 18).lerp(Vector2(-16, 45), recover)
		joints.other_hand = Vector2(d * 46, 9).lerp(Vector2(-15, 34), recover)
	for key in joints: joints[key].x *= facing
	return joints

func contact_center(action: String) -> Vector2:
	match action:
		"spike", "serve": return pos + skeleton().hand
		"block": return pos + Vector2(facing * 24, config.reach + 7)
		"set": return pos + Vector2(0, config.height + 15)
		"dive": return pos + Vector2(signf(velocity.x) * 50, 26)
	return pos + Vector2(facing * 25, 77)

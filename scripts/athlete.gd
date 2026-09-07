extends RefCounted
const Pose = preload("res://scripts/athlete_pose.gd")
const Config = preload("res://scripts/player_config.gd")
const SWING_WINDUP = 0.070
const SWING_END = 0.34
const DIVE_DURATION = 0.32
const DIVE_RECOVERY = 0.22
const APRON_LEFT = -620.0
const APRON_RIGHT = 2620.0

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
var dive_direction: float = 1.0
var jump_cooldown: float = 0.0
var jump_prepare: float = 0.0
var landing_timer: float = 0.0
var contact_flash: float = 0.0
var receiving: bool = false
var setting: bool = false
var blocking: bool = false
var last_move: float = 0.0
var run_clock: float = 0.0
var gait_stop_remaining: float = 0.0
var gait_stop_pose: Dictionary = {}
var gait_start_remaining: float = 0.0
var gait_start_pose: Dictionary = {}
var transition_pose: Dictionary = {}
var transition_remaining: float = 0.0
var transition_duration: float = 0.0
var animation_clock: float = 0.0
var set_elapsed: float = -1.0
var block_elapsed: float = -1.0
var block_start_pose: Dictionary = {}
var receive_elapsed: float = -1.0
var step_distance: float = 0.0
var skid_cooldown: float = 0.0
var serve_pose: String = ""
var serve_pose_time: float = 0.0
var movement_bounds = Vector2(APRON_LEFT, 962)
var motion_events: Array = []

func _init(player_id: int, player_team: int, player_role: String, x: float):
	id = player_id
	team = player_team
	role = player_role
	number = [7, 2, 11, 9, 4, 6][id]
	config = Config.for_role(role)
	home_x = x
	facing = 1.0 if team == 0 else -1.0
	movement_bounds = rally_bounds(team)
	reset(x)

static func rally_bounds(side: int) -> Vector2:
	return Vector2(APRON_LEFT, 962) if side == 0 else Vector2(1038, APRON_RIGHT)

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
	dive_direction = facing
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
	gait_stop_remaining = 0.0
	gait_stop_pose.clear()
	gait_start_remaining = 0.0
	gait_start_pose.clear()
	transition_pose.clear()
	transition_remaining = 0.0
	transition_duration = 0.0
	animation_clock = id * 0.37
	set_elapsed = -1
	block_elapsed = -1
	block_start_pose.clear()
	receive_elapsed = -1
	skid_cooldown = 0
	motion_events.clear()

func jump() -> void:
	if pos.y <= 0.01 and jump_cooldown <= 0 and dive_timer <= 0 and dive_recovery <= 0 and jump_prepare <= 0:
		if not blocking: block_start_pose.clear()
		jump_prepare = 0.060
		jump_cooldown = 0.16
		motion_events.append("plant")

func begin_swing() -> void:
	if pos.y > 25 and swing_cooldown <= 0 and not blocking:
		swing_elapsed = 0
		swing_cooldown = SWING_END + 0.02
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
	# Contact never relocates the visible skeleton or rewinds the swing.
	contact_flash = 0.14

func step(dt: float, intent: Dictionary) -> void:
	# Capture the final moving pose before deceleration reaches zero. The pose
	# sampler then completes two short settling steps instead of snapping feet.
	var stopping_pose: Dictionary = {}
	var starting_pose: Dictionary = {}
	if pos.y < 1.0 and dive_timer <= 0 and dive_recovery <= 0 and absf(velocity.x) <= 12.0 and absf(intent.get("move", 0.0)) > 0.01:
		starting_pose = Pose.sample(self)
	if pos.y < 1.0 and dive_timer <= 0 and dive_recovery <= 0 and absf(velocity.x) > 12.0:
		var braking: bool = absf(intent.get("move", 0.0)) < 0.01 and absf(velocity.x) <= config.acceleration * dt + 12.0
		var near_boundary: bool = minf(pos.x - movement_bounds.x, movement_bounds.y - pos.x) <= maxf(absf(velocity.x), config.run_speed) * dt
		if braking or near_boundary: stopping_pose = Pose.sample(self)
	gait_stop_remaining = maxf(0.0, gait_stop_remaining - dt)
	gait_start_remaining = maxf(0.0, gait_start_remaining - dt)
	transition_remaining = maxf(0.0, transition_remaining - dt)
	if blocking and not intent.get("block", false):
		start_pose_transition(Pose.sample(self), 0.12)
	motion_events.clear()
	animation_clock += dt
	previous_pos = pos
	swing_cooldown = maxf(0, swing_cooldown - dt)
	if swing_elapsed >= 0:
		swing_elapsed += dt
		if swing_elapsed >= SWING_END: swing_elapsed = -1
	swing_timer = 0.001 if swing_elapsed >= SWING_WINDUP and swing_elapsed < 0.14 and not swing_connected else 0.0
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
	if intent.get("block", false) and not blocking:
		block_start_pose = Pose.sample(self)
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
		dive_cooldown = 0.70
		dive_direction = signf(move if absf(move) > 0.1 else facing)
		velocity.x = dive_direction * config.dive_speed
		motion_events.append("slide")
	if intent.get("jump", false):
		if pos.y <= 0.01: jump()
		elif dive_timer <= 0: begin_swing()
	if intent.get("swing", false): begin_swing()
	if blocking and pos.y <= 0.01: jump()
	if pos.y <= 0.01 and absf(velocity.x) > 180 and move * velocity.x < -60 and skid_cooldown <= 0:
		motion_events.append("skid")
		skid_cooldown = 0.3
	if dive_recovery > 0:
		velocity.x = move_toward(velocity.x, 0, config.acceleration * dt)
	elif dive_timer <= 0:
		velocity.x = move_toward(velocity.x, move * config.run_speed, config.acceleration * dt)
	else:
		receiving = true
	var intended_x: float = pos.x + velocity.x * dt
	var actual_x: float = clampf(intended_x, movement_bounds.x, movement_bounds.y)
	if not is_equal_approx(actual_x, intended_x):
		# Animation follows achieved movement, including blocked movement. Keeping
		# commanded speed here freezes a running pose against the court boundary.
		velocity.x = (actual_x - pos.x) / dt if dt > 0 else 0.0
	pos.x = actual_x
	if jump_prepare > 0:
		var takeoff_pose: Dictionary = Pose.sample(self) if jump_prepare <= dt else {}
		jump_prepare = maxf(0, jump_prepare - dt)
		if jump_prepare == 0:
			start_pose_transition(takeoff_pose, 0.065)
			velocity.y = config.jump_speed
			motion_events.append("takeoff")
	if pos.y > 0 or velocity.y > 0:
		var landing_pose: Dictionary = Pose.sample(self) if pos.y > 0 and pos.y + (velocity.y - config.gravity * dt) * dt <= 0 else {}
		velocity.y -= config.gravity * dt
		pos.y += velocity.y * dt
		if pos.y <= 0:
			start_pose_transition(landing_pose, 0.10)
			pos.y = 0
			velocity.y = 0
			blocking = false
			landing_timer = 0.12
			motion_events.append("land")
	if pos.y < 1 and dive_timer <= 0:
		var distance = absf(pos.x - previous_pos.x)
		run_clock += (pos.x - previous_pos.x) * facing * TAU / (Pose.STRIDE_LENGTH * config.height / 92.0)
		step_distance += distance
		if step_distance >= 88:
			step_distance = fmod(step_distance, 88)
			motion_events.append("step")
	if not stopping_pose.is_empty() and absf(velocity.x) <= 12.0:
		gait_stop_pose = stopping_pose
		gait_stop_remaining = 0.20
	elif absf(velocity.x) > 12.0 or pos.y >= 1.0 or dive_timer > 0:
		gait_stop_remaining = 0.0
	if not starting_pose.is_empty() and absf(velocity.x) > 12.0:
		gait_start_pose = starting_pose
		gait_start_remaining = 0.10
	elif absf(velocity.x) <= 12.0 or pos.y >= 1.0 or dive_timer > 0:
		gait_start_remaining = 0.0

func start_pose_transition(from_pose: Dictionary, duration: float) -> void:
	if from_pose.is_empty(): return
	transition_pose = from_pose
	transition_duration = duration
	transition_remaining = duration

func visual_pose() -> Dictionary:
	return Pose.sample(self)

func skeleton() -> Dictionary:
	var joints = visual_pose()
	for key in joints:
		if joints[key] is Vector2: joints[key].x *= facing
	return joints

func contact_center(action: String) -> Vector2:
	var joints = skeleton()
	match action:
		"spike", "serve", "carry": return pos + joints.hand
		"block", "set": return pos + (joints.hand + joints.other_hand) * 0.5
		"receive": return pos + (joints.hand + joints.elbow) * 0.5
		"dive": return pos + (joints.hand + joints.other_hand) * 0.5
	return pos + joints.hand

extends RefCounted
const Config = preload("res://scripts/player_config.gd")

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
var dive_timer: float = 0.0
var dive_cooldown: float = 0.0
var jump_cooldown: float = 0.0
var contact_flash: float = 0.0
var receiving: bool = false
var setting: bool = false
var blocking: bool = false
var last_move: float = 0.0
var run_clock: float = 0.0

func _init(player_id: int, player_team: int, player_role: String, x: float):
	id = player_id
	team = player_team
	role = player_role
	number = [7, 2, 11, 9, 4, 6][id]
	config = Config.for_role(role)
	home_x = x
	facing = 1.0 if team == 0 else -1.0
	reset(x)

func reset(x: float) -> void:
	pos = Vector2(x, 0)
	previous_pos = pos
	velocity = Vector2.ZERO
	swing_timer = 0
	swing_cooldown = 0
	dive_timer = 0
	dive_cooldown = 0
	jump_cooldown = 0
	receiving = false
	setting = false
	blocking = false

func jump() -> void:
	if pos.y <= 0.01 and jump_cooldown <= 0 and dive_timer <= 0:
		velocity.y = config.jump_speed
		jump_cooldown = 0.16

func step(dt: float, intent: Dictionary) -> void:
	previous_pos = pos
	swing_timer = maxf(0, swing_timer - dt)
	swing_cooldown = maxf(0, swing_cooldown - dt)
	dive_timer = maxf(0, dive_timer - dt)
	dive_cooldown = maxf(0, dive_cooldown - dt)
	jump_cooldown = maxf(0, jump_cooldown - dt)
	contact_flash = maxf(0, contact_flash - dt)
	receiving = intent.get("receive", false)
	setting = intent.get("set", false)
	blocking = intent.get("block", false)
	var move = clampf(intent.get("move", 0.0), -1, 1)
	last_move = move
	if intent.get("dive", false) and pos.y <= 0.01 and dive_cooldown <= 0:
		dive_timer = 0.40
		dive_cooldown = 1.0
		velocity.x = (move if absf(move) > 0.1 else facing) * config.dive_speed
	if intent.get("jump", false):
		if pos.y <= 0.01:
			jump()
		elif not blocking and dive_timer <= 0 and swing_cooldown <= 0:
			swing_timer = 0.19
			swing_cooldown = 0.26
	if intent.get("swing", false) and pos.y > 25 and swing_cooldown <= 0:
		swing_timer = 0.19
		swing_cooldown = 0.26
	if blocking and pos.y <= 0.01:
		jump()
	if dive_timer <= 0:
		velocity.x = move_toward(velocity.x, move * config.run_speed, config.acceleration * dt)
	else:
		receiving = true
	pos.x += velocity.x * dt
	pos.x = clampf(pos.x, 65 if team == 0 else 1038, 962 if team == 0 else 1935)
	if pos.y > 0 or velocity.y > 0:
		velocity.y -= config.gravity * dt
		pos.y += velocity.y * dt
		if pos.y <= 0:
			pos.y = 0
			velocity.y = 0
			blocking = false
	if absf(velocity.x) > 10:
		run_clock += dt * absf(velocity.x) / 33.0

func contact_center(action: String) -> Vector2:
	match action:
		"spike", "serve": return pos + Vector2(facing * 40, config.reach - 1)
		"block": return pos + Vector2(facing * 24, config.reach + 7)
		"set": return pos + Vector2(0, config.height + 15)
		"dive": return pos + Vector2(signf(velocity.x) * 50, 26)
	return pos + Vector2(facing * 25, 77)

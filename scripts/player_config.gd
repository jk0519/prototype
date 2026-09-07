extends Resource
## All six players use these same attributes, regardless of input source.
@export var run_speed: float = 760.0
@export var acceleration: float = 18000.0
@export var jump_speed: float = 1480.0
@export var gravity: float = 3600.0
@export var dive_speed: float = 1450.0
@export var spike_speed: float = 2700.0
@export var height: float = 92.0
@export var reach: float = 110.0

static func for_role(role: String) -> Resource:
	var result = load("res://scripts/player_config.gd").new()
	if role == "SET":
		result.run_speed = 790.0
		result.jump_speed = 1390.0
	elif role == "MB":
		result.height = 98.0
		result.reach = 117.0
		result.jump_speed = 1510.0
		result.run_speed = 720.0
	return result

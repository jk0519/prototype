extends Resource
## All six players use these same attributes, regardless of input source.
@export var run_speed: float = 570.0
@export var acceleration: float = 9000.0
@export var jump_speed: float = 1080.0
@export var gravity: float = 3000.0
@export var dive_speed: float = 1000.0
@export var spike_speed: float = 1900.0
@export var height: float = 104.0
@export var reach: float = 127.0

static func for_role(role: String) -> Resource:
	var result = load("res://scripts/player_config.gd").new()
	if role == "SET":
		result.run_speed = 600.0
		result.jump_speed = 1010.0
	elif role == "MB":
		result.height = 111.0
		result.reach = 137.0
		result.jump_speed = 1050.0
		result.run_speed = 540.0
	return result

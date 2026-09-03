extends Resource
## All six players use these same attributes, regardless of input source.
@export var run_speed: float = 365.0
@export var acceleration: float = 2600.0
@export var jump_speed: float = 825.0
@export var gravity: float = 1800.0
@export var dive_speed: float = 660.0
@export var spike_speed: float = 1080.0
@export var height: float = 104.0
@export var reach: float = 127.0

static func for_role(role: String) -> Resource:
	var result = load("res://scripts/player_config.gd").new()
	if role == "SET":
		result.run_speed = 385.0
		result.jump_speed = 780.0
	elif role == "MB":
		result.height = 111.0
		result.reach = 137.0
		result.jump_speed = 810.0
		result.run_speed = 350.0
	return result

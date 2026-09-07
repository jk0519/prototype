extends RefCounted
## Immutable measurements sampled after every valid player contact.
## One distance scale covers both axes: the playable court is 18 metres long.
var units_per_metre: float
var history: Array = []

func _init(court_world_width: float = 1640.0) -> void:
	units_per_metre = court_world_width / 18.0

func reset() -> void:
	history.clear()

func speed_kmh(velocity: Vector2) -> float:
	return velocity.length() / units_per_metre * 3.6

func world_speed(kmh: float) -> float:
	return kmh / 3.6 * units_per_metre

func height_metres(world_height: float) -> float:
	return maxf(0, world_height) / units_per_metre

func record(action: String, player, velocity: Vector2, contact: Vector2, match_time: float) -> Dictionary:
	var shot = {
		"shot_id": history.size() + 1,
		"action": action,
		"player": player.id,
		"team": player.team,
		"number": player.number,
		"role": player.role,
		"velocity": velocity,
		"speed": velocity.length(),
		"speed_kmh": speed_kmh(velocity),
		"contact_height_m": height_metres(contact.y),
		"contact_position": contact,
		"time": match_time,
	}
	history.append(shot)
	return shot

func recent(count: int = 3) -> Array:
	var result: Array = []
	for index in range(history.size() - 1, maxi(-1, history.size() - count - 1), -1):
		result.append(history[index])
	return result

extends Control
var game
var mode: String = "title"
var key_names: Dictionary = {}
var autoplay: bool = false
var font = ThemeDB.fallback_font
const WHITE = Color("eef5ee")
const MUTED = Color("97b1bf")
const BLUE = Color("70c7fa")
const ORANGE = Color("ffb063")

func text_at(pos: Vector2, value: String, size_px: int, color: Color, centered: bool = false) -> void:
	if centered:
		pos.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / 2
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func box(rect: Rect2, color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	draw_style_box(style, rect)

func _draw() -> void:
	if game == null:
		return
	var w = size.x
	var h = size.y
	text_at(Vector2(30, 47), "SIDEOUT", 24, WHITE)
	text_at(Vector2(31, 67), "3 v 3  /  VOLLEYBALL", 10, MUTED)
	if mode == "title":
		return
	box(Rect2(w / 2 - 210, 23, 420, 71), Color("101e30"), 14, Color("2c4357"))
	text_at(Vector2(w / 2 - 133, 50), "NORTH", 14, BLUE, true)
	text_at(Vector2(w / 2 - 133, 71), "YOUR TEAM", 9, MUTED, true)
	text_at(Vector2(w / 2 - 45, 70), str(game.score[0]).pad_zeros(2), 35, WHITE, true)
	text_at(Vector2(w / 2, 61), ":", 22, MUTED, true)
	text_at(Vector2(w / 2 + 45, 70), str(game.score[1]).pad_zeros(2), 35, WHITE, true)
	text_at(Vector2(w / 2 + 133, 50), "SOUTH", 14, ORANGE, true)
	text_at(Vector2(w / 2 + 133, 71), "OPPONENT", 9, MUTED, true)
	text_at(Vector2(w / 2, 113), "FIRST TO 15  ·  WIN BY 2", 10, MUTED, true)
	var serve_x = w / 2 - 182 if game.serving_team == 0 else w / 2 + 182
	draw_circle(Vector2(serve_x, 59), 3.5, BLUE if game.serving_team == 0 else ORANGE)
	box(Rect2(26, 99, 135, 32), Color(0.05, 0.10, 0.17, 0.78), 8)
	text_at(Vector2(39, 120), "YOU  /  WING SPIKER", 10, BLUE)
	draw_shot_readouts()
	if autoplay:
		text_at(Vector2(32, 348), "AUTOPLAY TEST", 10, ORANGE)
	if game.phase.begins_with("serve_"):
		var own_serve = game.server_id == game.human_id and not autoplay
		var prompt = "YOUR JUMP SERVE" if own_serve else ("TEAMMATE SERVING" if game.serving_team == 0 else "OPPONENT SERVING")
		var hint = "Get into position for the next ball"
		if own_serve:
			match game.phase:
				"serve_ready": hint = "%s / %s to move  ·  hold %s to charge the toss" % [key_names.get("left", "A"), key_names.get("right", "D"), key_names.get("block", "X")]
				"serve_aim":
					prompt = "%s / %s  MOVE    %s / %s  TOSS HEIGHT" % [key_names.get("left", "A"), key_names.get("right", "D"), key_names.get("toss_raise", "W"), key_names.get("toss_lower", "S")]
					var vertical = roundi(inverse_lerp(game.TOSS_MIN_HEIGHT, game.TOSS_MAX_HEIGHT, game.toss_height) * 100)
					var forward = roundi(inverse_lerp(game.TOSS_MIN_FORWARD, game.TOSS_MAX_FORWARD, game.toss_forward) * 100)
					hint = "HEIGHT %d%%  ·  CHARGE %d%%  ·  RELEASE %s" % [vertical, forward, key_names.get("block", "X")]
					if game.serve_needs_more_room(): hint = "HEIGHT %d%%  ·  CHARGE %d%%  ·  STEP BACK" % [vertical, forward]
				"serve_windup": hint = "Move either way  ·  stay behind the serving line"
				"serve_toss": hint = "Stay behind the line  ·  %s jump, then %s hit" % [key_names.get("jump", "Z"), key_names.get("jump", "Z")]
		box(Rect2(w / 2 - 218, 138, 436, 63), Color(0.055, 0.10, 0.17, 0.92), 12, Color("334d60"))
		text_at(Vector2(w / 2, 162), prompt, 13, WHITE, true)
		text_at(Vector2(w / 2, 185), hint, 12, MUTED, true)
	elif game.phase == "point":
		var color = BLUE if game.point_winner == 0 else ORANGE
		# A scored rally only ticks the scoreboard; it never becomes a modal screen.
		box(Rect2(w / 2 - 116, 108, 232, 34), Color(0.055, 0.10, 0.17, 0.84), 9, Color(color, 0.35))
		text_at(Vector2(w / 2, 130), ("NORTH +1" if game.point_winner == 0 else "SOUTH +1") + "  ·  " + game.point_reason, 11, color, true)
	elif game.phase == "rally":
		var touch_text = "TOUCH %d / 3" % game.touches if game.touches else "BLOCK · BALL LIVE"
		text_at(Vector2(w - 33, 116) - Vector2(font.get_string_size(touch_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, 0), touch_text, 11, MUTED)
	# A compact, always-visible keyboard strip.
	box(Rect2(24, h - 75, w - 48, 53), Color("101e30"), 12, Color("2a4155"))
	var controls = [["left", "MOVE"], ["jump", "JUMP / SPIKE"], ["receive", "RECEIVE"], ["block", "BLOCK / TOSS"], ["dive", "DIVE"]]
	var cell = (w - 80) / 5.0
	for i in range(controls.size()):
		var x = 40 + i * cell
		var action = controls[i][0]
		var key = key_names.get(action, "?")
		if action == "left":
			key += " / " + key_names.get("right", "D")
		var key_w = maxf(29, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 15)
		box(Rect2(x, h - 63, key_w, 28), Color("233c51"), 6)
		text_at(Vector2(x + key_w / 2, h - 44), key, 12, WHITE, true)
		text_at(Vector2(x + key_w + 9, h - 45), controls[i][1], 9, MUTED)

func draw_shot_readouts() -> void:
	var recent = game.shots.recent(3)
	if recent.is_empty(): return
	box(Rect2(26, 146, 252, 27 + recent.size() * 52), Color(0.045,0.085,0.14,0.90), 9, Color("2c4357"))
	text_at(Vector2(39,164), "RECENT SHOTS  ·  CONTACT HEIGHT", 10, MUTED)
	for index in range(recent.size()):
		var shot: Dictionary = recent[index]
		var y = 184.0 + index * 52
		var color = BLUE if shot.team == 0 else ORANGE
		var label = "%s  %s #%d  ·  %s" % ["NORTH" if shot.team == 0 else "SOUTH", shot.role, shot.number, shot.action.to_upper()]
		text_at(Vector2(39,y), label, 10, color)
		text_at(Vector2(39,y+21), "%d km/h   ·   %.2f m" % [roundi(shot.speed_kmh), shot.contact_height_m], 17 if index == 0 else 15, WHITE if index == 0 else MUTED)

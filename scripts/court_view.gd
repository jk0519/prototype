extends Node2D
## Small, quiet athlete silhouettes. Speed, pose timing, and impact carry the action.
var game
var effects: Array = []
var trail: Array = []
var clock: float = 0
var landing_guide: bool = true
var font = ThemeDB.fallback_font
const INK = Color("15283d")
const CREAM = Color("f0f6ec")
const BLUE = Color("4ecbff")
const ORANGE = Color("ff9b42")
const AthleteRenderer = preload("res://scripts/athlete_renderer.gd")

func advance(dt: float) -> void:
	clock += dt
	for effect in effects:
		effect.age += dt
	effects = effects.filter(func(e): return e.age < e.lifetime)
	trail.append({"position": game.ball, "age": 0.0})
	for item in trail:
		item.age += dt
	trail = trail.filter(func(item): return item.age < 0.18)
	queue_redraw()

func add_event(event: Dictionary) -> void:
	if event.kind in ["serve", "receive", "set", "spike", "block", "dive", "free", "net", "plant", "takeoff", "land", "skid", "slide", "floor"]:
		var kind: String = event.kind
		var effect = {
			"position": event.position,
			"kind": kind,
			"age": 0.0,
			"lifetime": 0.52 if kind in ["serve", "spike", "block"] else 0.30,
			"quality": float(event.get("quality", 0.62)),
			"speed": float(event.get("speed", 0.0)),
			"ball_velocity": game.ball_velocity,
		}
		var player_id = int(event.get("player", -1))
		if player_id >= 0 and player_id < game.players.size():
			var p = game.players[player_id]
			effect["player_position"] = p.pos
			effect["player_pose"] = p.visual_pose()
			effect["player_facing"] = p.facing
			effect["player_team"] = p.team
		effects.append(effect)

func ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(32):
		var a = i * TAU / 32
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)

func caption(where: Vector2, text: String, size: int, color: Color, centered: bool = false) -> void:
	if centered:
		where.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	draw_string(font, where, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if game == null:
		return
	draw_arena()
	if game.phase == "serve_windup" or (game.phase == "serve_aim" and game.phase_time >= game.SERVE_RAISE_DURATION):
		draw_toss_guide()
	if landing_guide and game.phase == "rally":
		var t = game.time_to_height(game.BALL_RADIUS)
		var x = game.ball.x + game.ball_velocity.x * t
		if x > 180 and x < 1820:
			var color = Color(BLUE, 0.48) if x < 1000 else Color(ORANGE, 0.48)
			ellipse(Vector2(x, 6), Vector2(27, 7), color)
			draw_line(Vector2(x - 36, 6), Vector2(x - 18, 6), CREAM, 2)
			draw_line(Vector2(x + 18, 6), Vector2(x + 36, 6), CREAM, 2)
	for p in game.players:
		var spread = 1.0 - clampf(p.pos.y / 1100.0, 0, 0.5)
		ellipse(Vector2(p.pos.x, 8), Vector2(15 * spread, 4 * spread), Color(0.03, 0.10, 0.14, 0.3))
		if p.id == game.human_id:
			ellipse(Vector2(p.pos.x, 8), Vector2(20, 5), Color(BLUE, 0.42))
	draw_net()
	draw_impact_afterimages()
	for p in game.players:
		draw_player(p)
	if game.phase not in ["point", "finished", "serve_ready", "serve_aim", "serve_windup"]:
		for item in trail:
			var alpha = (1 - item.age / 0.18) * 0.40
			var at = Vector2(item.position.x, -item.position.y)
			draw_circle(at, 3 + 6 * (1 - item.age / 0.18), Color(CREAM, alpha))
	var ball_screen = Vector2(game.ball.x, -game.ball.y)
	var screen_velocity = Vector2(game.ball_velocity.x, -game.ball_velocity.y)
	if screen_velocity.length() > 560 and game.phase == "rally":
		var back = -screen_velocity.normalized()
		var length = clampf(screen_velocity.length() * 0.10, 70, 240)
		for i in range(7):
			var offset = back.orthogonal() * (i - 3) * 3.5
			draw_line(ball_screen + back * 13 + offset, ball_screen + back * (length - abs(i - 3) * 15) + offset, Color(CREAM, 0.44 - abs(i - 3) * 0.045), 2.5, true)
	if screen_velocity.length() > 1100 and game.phase == "rally":
		var stretch = clampf(screen_velocity.length() / 1250.0, 1.0, 2.7)
		draw_set_transform(ball_screen, screen_velocity.angle(), Vector2.ONE)
		ellipse(Vector2(-5 * stretch, 0), Vector2(11 * stretch, 8.5), Color(CREAM, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var spin_direction = -signf(game.ball_velocity.x) if absf(game.ball_velocity.x) > 1 else 1.0
	draw_ball(Vector2(game.ball.x, -game.ball.y), game.time * (5.0 + game.ball_topspin * 0.012) * spin_direction)
	for effect in effects:
		var pos = Vector2(effect.position.x, -effect.position.y)
		var alpha = clampf(1 - effect.age / effect.lifetime, 0, 1)
		var quality: float = effect.quality
		var perfect = quality >= 0.86 and effect.kind in ["serve", "spike", "block"]
		var color = Color("ffe46b") if perfect else (ORANGE if effect.kind in ["spike", "block"] else BLUE)
		var radius = 12 + effect.age * lerpf(150, 280, quality)
		if effect.kind in ["serve", "spike", "block", "set", "receive", "net"]:
			draw_arc(pos, radius, 0, TAU, 32, Color(color, alpha * 0.82), 3.2, true)
		if effect.kind in ["serve", "spike", "block"]:
			var flash = clampf(1 - effect.age / 0.16, 0, 1)
			draw_circle(pos, lerpf(22, 48, quality) * flash, Color(CREAM, flash * lerpf(0.24, 0.52, quality)))
			var ray_count = 5 + roundi(quality * 4)
			for i in range(ray_count):
				var ray = Vector2.from_angle(i * TAU / ray_count + 0.16) * (42 + effect.age * lerpf(170, 300, quality))
				draw_line(pos + ray * 0.42, pos + ray, Color(CREAM, alpha * 0.78), 2.0 + quality, true)
			draw_attack_speed_lines(effect, pos, color)
			var slash = Vector2(36, -72) * Vector2(signf(effect.ball_velocity.x), 1)
			draw_line(pos - slash, pos + slash, Color(CREAM, flash * 0.9), 7.0, true)
			draw_line(pos - slash * 0.65, pos + slash * 0.65, Color(color, flash), 2.5, true)
		if effect.kind == "set":
			caption(pos + Vector2(0, -35 - effect.age * 55), "SET", 15, Color(CREAM, alpha), true)
		elif effect.kind in ["land", "skid", "slide", "floor"]:
			var floor_pos = Vector2(pos.x, 2)
			var spread = 22 + effect.age * (210 if effect.kind == "floor" else 125)
			draw_line(floor_pos - Vector2(spread, 0), floor_pos + Vector2(spread, 0), Color(CREAM, alpha * 0.48), 3.0, true)
			for i in range(5):
				var side = -1.0 if i % 2 == 0 else 1.0
				var dust = floor_pos + Vector2(side * (10 + i * 6 + effect.age * 85), -3 - i * 2)
				draw_circle(dust, 3 + (4 - i) * 0.8, Color(CREAM, alpha * 0.26))
	var wash = impact_wash_alpha()
	if wash > 0:
		draw_rect(Rect2(-2000, -2200, 6000, 3500), Color(CREAM, wash))

func impact_wash_alpha() -> float:
	var result = 0.0
	for effect in effects:
		if effect.kind in ["serve", "spike", "block"]:
			result = maxf(result, clampf(1.0 - effect.age / 0.045, 0, 1) * lerpf(0.018, 0.060, effect.quality))
	return result

func draw_attack_speed_lines(effect: Dictionary, pos: Vector2, color: Color) -> void:
	if effect.age > 0.19:
		return
	var life = 1.0 - effect.age / 0.19
	var direction = signf(effect.ball_velocity.x)
	if direction == 0: direction = 1.0
	for i in range(7):
		var lane = float(i - 3)
		var start = pos + Vector2(-direction * (45 + absf(lane) * 12), lane * 38)
		var length = (155 + absf(lane) * 27) * lerpf(0.72, 1.25, effect.quality)
		draw_line(start, start - Vector2(direction * length, lane * 4), Color(color, life * (0.22 + effect.quality * 0.24)), 2.0 + effect.quality, true)

func draw_impact_afterimages() -> void:
	for effect in effects:
		if effect.kind not in ["serve", "spike", "block"] or effect.age > 0.15 or not effect.has("player_pose"):
			continue
		var origin = Vector2(effect.player_position.x, -effect.player_position.y) - Vector2(effect.player_facing * 14, 0)
		AthleteRenderer.draw_pose(self, effect.player_pose, origin, effect.player_facing, effect.player_team, 0.16 * (1.0 - effect.age / 0.15))

func draw_arena() -> void:
	draw_rect(Rect2(-2000, -2200, 6000, 3500), Color("0c1625"))
	draw_rect(Rect2(-700, -760, 3400, 760), Color("14243a"))
	for i in range(12):
		var x = -350 + i * 260
		draw_rect(Rect2(x, -760, 3, 590), Color("1e344b"))
		draw_rect(Rect2(x + 10, -740, 235, 7), Color("263e54"))
	# Lighting strips and quiet seating give the court depth without busy artwork.
	draw_line(Vector2(-700, -530), Vector2(2700, -530), Color("29465d"), 3)
	draw_line(Vector2(-700, -526), Vector2(2700, -526), Color("21364e"), 5)
	caption(Vector2(190, -380), "SIDEOUT", 76, Color("385568"))
	caption(Vector2(193, -345), "V O L L E Y B A L L   C L U B", 17, Color("587281"))
	caption(Vector2(1780, -345), "01", 105, Color("385568"), true)
	for row in range(3):
		var y = -259 + row * 37
		draw_rect(Rect2(-700, y + 12, 3400, 8), Color("1a3047"))
		for col in range(57):
			var x = -650 + col * 61
			var shade = Color("263e53") if (col + row) % 3 else Color("2d4b5d")
			draw_style_box(seat_style(shade), Rect2(x, y - 13, 41, 27))
			if (col * 3 + row) % 5 < 3:
				var center = Vector2(x + 20, y - 8)
				var spectator = Color("466273") if col % 3 else Color("60777e")
				draw_line(center + Vector2(0, 5), center + Vector2(0, 17), spectator, 12, true)
				draw_circle(center, 5, spectator.lightened(0.08))
				if game.phase in ["serve_toss", "serve_windup"]:
					var lift = sin(clock * 3 + col * 0.7) * 2
					draw_line(center + Vector2(-4, 8), center + Vector2(-10, -4 + lift), spectator, 3, true)
					draw_line(center + Vector2(4, 8), center + Vector2(10, -4 - lift), spectator, 3, true)
	draw_rect(Rect2(-700, -112, 3400, 45), Color("203b50"))
	draw_rect(Rect2(-700, -68, 3400, 6), Color("88adbb"))
	draw_rect(Rect2(-700, -61, 3400, 62), Color("182e43"))
	caption(Vector2(430, -24), "N O R T H", 18, Color("7295a8"), true)
	caption(Vector2(1570, -24), "S O U T H", 18, Color("7295a8"), true)
	# The floor has shallow visual depth; athletes retain a side-on action plane.
	draw_rect(Rect2(-1600, -48, 5200, 1400), Color("173749"))
	var corners = PackedVector2Array([Vector2(220,-60), Vector2(1780,-60), Vector2(1900,120), Vector2(100,120)])
	draw_colored_polygon(corners, Color("609f94"))
	draw_polyline(PackedVector2Array([corners[0],corners[1],corners[2],corners[3],corners[0]]), CREAM, 6, true)
	for x in [600,1000,1400]:
		var shift = (x - 1000) * 0.10
		draw_line(Vector2(x - shift / 3.0, -60), Vector2(x + shift, 120), Color(CREAM,0.8), 3, true)
	caption(Vector2(235, 157), "COURT 01     /     3 vs 3", 18, Color("638899"))
	caption(Vector2(1770, 157), "PLAY THE NEXT BALL", 18, Color("638899"), true)

var seat_cache: Dictionary = {}
func seat_style(color: Color) -> StyleBoxFlat:
	if not seat_cache.has(color):
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(5)
		seat_cache[color] = style
	return seat_cache[color]

func draw_net() -> void:
	var top = -game.NET_HEIGHT
	# Slight offset shows the mesh in a side-on game.
	var mesh = PackedVector2Array([Vector2(997, top), Vector2(1024, top - 13), Vector2(1024, -65), Vector2(997, -51)])
	draw_colored_polygon(mesh, Color(0.70, 0.85, 0.85, 0.16))
	for y in range(int(top) + 8, -50, 14):
		draw_line(Vector2(997, y), Vector2(1024, y - 13), Color(0.85, 0.95, 0.92, 0.45), 1)
	for x in range(997, 1025, 7):
		draw_line(Vector2(x, top - (x - 997) * 0.48), Vector2(x, -52 - (x - 997) * 0.48), Color(0.85, 0.95, 0.92, 0.3), 1)
	draw_line(Vector2(1000, top), Vector2(1027, top - 13), CREAM, 6)
	draw_line(Vector2(1000, top - 7), Vector2(1000, 20), Color("68b5e4"), 10)
	draw_line(Vector2(1000, -95), Vector2(1000, 20), Color("2679a8"), 16)
	draw_line(Vector2(997, -90), Vector2(997, 15), Color("4398bd"), 3)
	draw_line(Vector2(1000, top - 7), Vector2(1000, top - 48), CREAM, 3)

func draw_motion_streaks(p, origin: Vector2, team_color: Color) -> void:
	var speed = absf(p.velocity.x)
	var carrying_serve_ball = p.id == game.server_id and game.phase in ["serve_ready", "serve_aim", "serve_windup"]
	if speed > 260 and not carrying_serve_ball:
		var back = -signf(p.velocity.x)
		var strength = clampf((speed - 260) / 430.0, 0.12, 0.9)
		for i in range(6):
			var y = -8.0 - i * 11.0
			var start = origin + Vector2(back * (17 + i * 4), y)
			draw_line(start, start + Vector2(back * (26 + speed * 0.10), i - 3), Color(team_color, strength * (0.38 - i * 0.04)), 2.0, true)
	if p.jump_prepare > 0:
		var pulse = 1.0 - p.jump_prepare / 0.060
		draw_arc(origin + Vector2(0, 4), 14 + pulse * 30, PI, TAU, 18, Color(team_color, 0.75 * (1 - pulse)), 3, true)
	if p.pos.y > 30 and p.velocity.y > 280:
		var rise = clampf(p.velocity.y / p.config.jump_speed, 0.0, 1.0)
		for i in range(4):
			var x = (i - 1.5) * 11
			draw_line(origin + Vector2(x, 10), origin + Vector2(x * 1.4, 44 + rise * 35), Color(team_color, rise * 0.28), 2.0, true)
	if p.swing_elapsed >= 0 and p.pos.y > 25:
		var sweep = clampf(p.swing_elapsed / 0.13, 0, 1)
		var from = -2.6 if p.facing > 0 else -0.55
		var to = -0.2 if p.facing > 0 else -2.95
		draw_arc(origin + Vector2(0, -58), 54, from, lerpf(from, to, sweep), 20, Color(team_color, 0.22 + 0.42 * (1 - sweep)), 6, true)

func draw_player(p) -> void:
	var origin = Vector2(p.pos.x, -p.pos.y)
	draw_motion_streaks(p, origin, BLUE if p.team == 0 else ORANGE)
	AthleteRenderer.draw_pose(self, p.visual_pose(), origin, p.facing, p.team)
	if p.id == game.human_id and p.swing_elapsed < 0:
		var head = p.skeleton().head
		var marker = origin + Vector2(head.x, -head.y - 18)
		draw_colored_polygon(PackedVector2Array([marker + Vector2(-6, -4), marker + Vector2(6, -4), marker + Vector2(0, 4)]), BLUE)

func draw_ball(pos: Vector2, rotation_angle: float) -> void:
	draw_circle(pos + Vector2(1, 2), 13, Color(INK, 0.3))
	draw_circle(pos, 11, CREAM)
	for i in range(3):
		var angle = rotation_angle + TAU * i / 3
		var offset = Vector2(cos(angle), sin(angle)) * 3
		draw_arc(pos + offset, 8, angle, angle + 1.7, 12, ORANGE if i == 0 else Color("45667a"), 2.7, true)
	draw_arc(pos, 11, 0, TAU, 30, Color("d3ddd0"), 1.1, true)

func draw_toss_guide() -> void:
	var points = game.toss_preview()
	for i in range(points.size()):
		var at = Vector2(points[i].x, -points[i].y)
		var alpha = 0.75 if i % 2 == 0 else 0.4
		draw_circle(at, 3 if i % 2 == 0 else 2, Color(CREAM, alpha))
	var apex_at = game.toss_origin() + game.toss_velocity() * (game.toss_velocity().y / game.BALL_GRAVITY)
	apex_at.y = -game.toss_height
	draw_line(apex_at - Vector2(15, 0), apex_at + Vector2(15, 0), BLUE, 2)
	var vertical = roundi(inverse_lerp(game.TOSS_MIN_HEIGHT, game.TOSS_MAX_HEIGHT, game.toss_height) * 100)
	caption(apex_at + Vector2(0, -17), "VERTICAL %d%%" % vertical, 13, CREAM, true)
	var meter_x = game.toss_origin().x - game.players[game.server_id].facing * 48
	var meter_top = -game.TOSS_MAX_HEIGHT
	var meter_bottom = -game.TOSS_MIN_HEIGHT
	draw_line(Vector2(meter_x, meter_top), Vector2(meter_x, meter_bottom), Color(BLUE, 0.24), 2)
	draw_line(Vector2(meter_x - 8, apex_at.y), Vector2(meter_x + 8, apex_at.y), BLUE, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(meter_x, meter_top - 9), Vector2(meter_x - 5, meter_top), Vector2(meter_x + 5, meter_top)]), Color(BLUE, 0.8))
	draw_colored_polygon(PackedVector2Array([Vector2(meter_x, meter_bottom + 9), Vector2(meter_x - 5, meter_bottom), Vector2(meter_x + 5, meter_bottom)]), Color(BLUE, 0.8))

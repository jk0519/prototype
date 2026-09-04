extends Node2D
## Original procedural anime-style athletes built around simulation contact joints.
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

func advance(dt: float) -> void:
	clock += dt
	for effect in effects:
		effect.age += dt
	effects = effects.filter(func(e): return e.age < 0.42)
	trail.append({"position": game.ball, "age": 0.0})
	for item in trail:
		item.age += dt
	trail = trail.filter(func(item): return item.age < 0.20)
	queue_redraw()

func add_event(event: Dictionary) -> void:
	if event.kind in ["serve", "receive", "set", "spike", "block", "dive", "free", "net"]:
		effects.append({"position": event.position, "kind": event.kind, "age": 0.0, "quality": float(event.get("quality", 0.62)), "speed": float(event.get("speed", 0.0))})

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
	if game.phase in ["serve_aim", "serve_windup"]: draw_toss_guide()
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
		ellipse(Vector2(p.pos.x, 8), Vector2(29 * spread, 7 * spread), Color(0.03, 0.10, 0.14, 0.3))
		if p.id == game.human_id:
			ellipse(Vector2(p.pos.x, 8), Vector2(35, 9), Color(BLUE, 0.42))
	draw_net()
	for p in game.players:
		draw_player(p)
	if game.phase not in ["point", "finished", "serve_ready", "serve_aim", "serve_windup"]:
		for item in trail:
			var alpha = (1 - item.age / 0.20) * 0.32
			var at = Vector2(item.position.x, -item.position.y)
			draw_circle(at, 4 + 5 * (1 - item.age / 0.20), Color(CREAM, alpha))
	var ball_screen = Vector2(game.ball.x, -game.ball.y)
	var screen_velocity = Vector2(game.ball_velocity.x, -game.ball_velocity.y)
	if screen_velocity.length() > 620 and game.phase == "rally":
		var back = -screen_velocity.normalized()
		var length = clampf(screen_velocity.length() * 0.08, 55, 150)
		for i in range(5):
			var offset = back.orthogonal() * (i - 2) * 4
			draw_line(ball_screen + back * 14 + offset, ball_screen + back * (length - abs(i - 2) * 11) + offset, Color(CREAM, 0.34 - abs(i - 2) * 0.045), 2.5, true)
	draw_ball(Vector2(game.ball.x, -game.ball.y), game.time * 5)
	for effect in effects:
		var pos = Vector2(effect.position.x, -effect.position.y)
		var alpha = clampf(1 - effect.age / 0.42, 0, 1)
		var quality: float = effect.quality
		var perfect = quality >= 0.86 and effect.kind in ["serve", "spike", "block"]
		var color = Color("ffe46b") if perfect else (ORANGE if effect.kind in ["spike", "block"] else BLUE)
		var radius = 18 + effect.age * lerpf(135, 245, quality)
		draw_arc(pos, radius, 0, TAU, 32, Color(color, alpha * 0.82), 3.2, true)
		if effect.kind in ["serve", "spike", "block"]:
			var flash = clampf(1 - effect.age / 0.13, 0, 1)
			draw_circle(pos, lerpf(17, 32, quality) * flash, Color(CREAM, flash * lerpf(0.18, 0.38, quality)))
			var ray_count = 8 + roundi(quality * 8)
			for i in range(ray_count):
				var ray = Vector2.from_angle(i * TAU / ray_count + 0.16) * (42 + effect.age * lerpf(145, 245, quality))
				draw_line(pos + ray * 0.38, pos + ray, Color(CREAM, alpha * 0.8), 3.0, true)
		if effect.kind in ["serve", "spike", "block"]:
			var grade = "PERFECT" if quality >= 0.86 else ("SOLID" if quality >= 0.60 else "GLANCE")
			caption(pos + Vector2(0, -66 - effect.age * 45), "%s %s" % [grade, effect.kind.to_upper()], 18, Color(color, alpha), true)
			if effect.speed > 0:
				caption(pos + Vector2(0, -47 - effect.age * 45), "%d km/h" % roundi(effect.speed * 0.058), 13, Color(CREAM, alpha * 0.88), true)
		elif effect.kind == "set":
			caption(pos + Vector2(0, -35 - effect.age * 45), "SET", 17, Color(CREAM, alpha), true)

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
	# Ground plane; the near painted edge is decorative, x boundaries are real.
	draw_rect(Rect2(-1600, 0, 5200, 1300), Color("173749"))
	draw_rect(Rect2(165, -3, 1670, 83), Color("d7e6d8"))
	draw_rect(Rect2(181, 1, 1638, 71), Color("5b9c91"))
	draw_rect(Rect2(181, 1, 817, 71), Color("61a89b"))
	draw_rect(Rect2(1002, 1, 817, 71), Color("66a397"))
	for x in [600, 1400]:
		draw_line(Vector2(x, 0), Vector2(x, 75), CREAM, 4)
	draw_line(Vector2(1000, 0), Vector2(1000, 76), Color(CREAM, 0.7), 3)
	draw_line(Vector2(180, 1), Vector2(180, 77), CREAM, 5)
	draw_line(Vector2(1820, 1), Vector2(1820, 77), CREAM, 5)
	draw_line(Vector2(170, 95), Vector2(1830, 95), Color("244759"), 2)
	caption(Vector2(235, 130), "COURT 01     /     3 vs 3", 18, Color("638899"))
	caption(Vector2(1770, 130), "PLAY THE NEXT BALL", 18, Color("638899"), true)

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

func outlined_poly(points: PackedVector2Array, fill: Color, outline: Color = INK, width: float = 3.0) -> void:
	draw_colored_polygon(points, fill)
	var edge = points.duplicate()
	edge.append(points[0])
	draw_polyline(edge, outline, width, true)

func outlined_line(points: Array, fill: Color, width: float) -> void:
	var path = PackedVector2Array(points)
	draw_polyline(path, INK, width + 4.0, true)
	draw_polyline(path, fill, width, true)
	for point in path:
		draw_circle(point, width * 0.5 + 2.0, INK)
		draw_circle(point, width * 0.5, fill)

func limb(a: Vector2, b: Vector2, c: Vector2, color: Color, width: float) -> void:
	outlined_line([a, b, c], color, width)

func torso_shape(shoulder: Vector2, hip: Vector2, upper: float, lower: float) -> PackedVector2Array:
	var axis = (hip - shoulder).normalized()
	var across = Vector2(-axis.y, axis.x)
	return PackedVector2Array([
		shoulder - across * upper,
		shoulder + across * upper,
		hip + across * lower,
		hip - across * lower
	])

func draw_shoe(foot: Vector2, direction: float, accent: Color, back: bool) -> void:
	var d = direction if direction != 0 else 1.0
	var shade = Color("c8d5d9") if back else CREAM
	var sole = foot + Vector2(0, 3)
	var shoe = PackedVector2Array([
		foot + Vector2(-d * 5, -4),
		foot + Vector2(d * 7, -4),
		foot + Vector2(d * 13, 0),
		sole + Vector2(d * 11, 2),
		sole - Vector2(d * 6, -2)
	])
	outlined_poly(shoe, shade, INK, 2.5)
	draw_line(foot + Vector2(d * 2, -2), foot + Vector2(d * 9, 0), accent, 2, true)

func draw_head(head: Vector2, facing: float, skin: Color, hair: Color, style: int) -> void:
	# Larger anime proportions and a sharp hair silhouette keep the player
	# readable while the camera follows a fast ball.
	draw_circle(head, 16.5, INK)
	draw_circle(head, 13.8, skin)
	var spikes: PackedVector2Array
	if style == 0:
		spikes = PackedVector2Array([
			head + Vector2(-16, -4), head + Vector2(-15, -14),
			head + Vector2(-9, -19), head + Vector2(-5, -16),
			head + Vector2(-1, -23), head + Vector2(3, -17),
			head + Vector2(9, -21), head + Vector2(15, -13),
			head + Vector2(15, -3), head + Vector2(7, -8),
			head + Vector2(2, -3), head + Vector2(-3, -9), head + Vector2(-9, -2)
		])
	elif style == 1:
		spikes = PackedVector2Array([
			head + Vector2(-16, -3), head + Vector2(-15, -15),
			head + Vector2(-8, -21), head + Vector2(-1, -18),
			head + Vector2(5, -22), head + Vector2(13, -17),
			head + Vector2(16, -8), head + Vector2(10, -3),
			head + Vector2(5, -10), head + Vector2(0, -3), head + Vector2(-6, -10), head + Vector2(-10, -2)
		])
	else:
		spikes = PackedVector2Array([
			head + Vector2(-17, -5), head + Vector2(-12, -18),
			head + Vector2(-3, -22), head + Vector2(7, -20),
			head + Vector2(16, -12), head + Vector2(17, -3),
			head + Vector2(8, -6), head + Vector2(3, -1),
			head + Vector2(-2, -8), head + Vector2(-8, -1)
		])
	# Mirror the haircut so its leading fringe follows the player.
	if facing < 0:
		for i in range(spikes.size()): spikes[i].x = head.x - (spikes[i].x - head.x)
	outlined_poly(spikes, hair, INK, 2.5)
	var eye = head + Vector2(facing * 6, 0)
	draw_line(eye + Vector2(-facing * 2, -2), eye + Vector2(facing * 3, -1), INK, 2.2, true)
	draw_circle(eye + Vector2(facing * 2, 0), 1.6, Color("eff8f4"))
	draw_circle(eye + Vector2(facing * 2.5, 0), 0.9, INK)
	draw_line(head + Vector2(facing * 8, 4), head + Vector2(facing * 11, 3), skin.darkened(0.38), 1.5, true)

func draw_motion_streaks(p, origin: Vector2, team_color: Color) -> void:
	var speed = absf(p.velocity.x)
	if speed > 245:
		var back = -signf(p.velocity.x)
		var strength = clampf((speed - 245) / 350.0, 0.12, 0.8)
		for i in range(4):
			var y = -12.0 - i * 13.0
			var start = origin + Vector2(back * (17 + i * 4), y)
			draw_line(start, start + Vector2(back * (18 + speed * 0.08), i - 2), Color(team_color, strength * (0.34 - i * 0.045)), 2.0, true)
	if p.jump_prepare > 0:
		var pulse = 1.0 - p.jump_prepare / 0.085
		draw_arc(origin + Vector2(0, 4), 18 + pulse * 18, PI, TAU, 18, Color(team_color, 0.6 * (1 - pulse)), 3, true)
	if p.swing_elapsed >= 0 and p.pos.y > 25:
		var sweep = clampf(p.swing_elapsed / 0.18, 0, 1)
		var from = -2.6 if p.facing > 0 else -0.55
		var to = -0.2 if p.facing > 0 else -2.95
		draw_arc(origin + Vector2(0, -78), 61, from, lerpf(from, to, sweep), 20, Color(team_color, 0.18 + 0.28 * (1 - sweep)), 5, true)

func draw_player(p) -> void:
	var origin = Vector2(p.pos.x, -p.pos.y)
	var f = p.facing
	var team_color = BLUE if p.team == 0 else ORANGE
	var team_dark = Color("1476a8") if p.team == 0 else Color("be5927")
	var trim = Color("dff7ff") if p.team == 0 else Color("fff0d1")
	var skins = [Color("efc9a5"), Color("d9ae88"), Color("f0d0b3"), Color("dfb98e"), Color("edc49f"), Color("c99570")]
	var hairs = [Color("182636"), Color("713b2d"), Color("27313b"), Color("a96229"), Color("22242b"), Color("6c3028")]
	var skin: Color = skins[p.id]
	var hair: Color = hairs[p.id]
	var joints = p.skeleton()
	for key in joints:
		joints[key] = origin + Vector2(joints[key].x, -joints[key].y)
	var shoulder: Vector2 = joints.shoulder
	var hip: Vector2 = joints.hip
	var head: Vector2 = joints.head
	draw_motion_streaks(p, origin, team_color)
	# Back limbs first, then the uniform mass, then the leading limbs. Dark
	# outlines keep each pose legible against court and crowd at any zoom.
	limb(hip, joints.back_knee, joints.back_foot, skin.darkened(0.13), 9)
	limb(hip, joints.front_knee, joints.front_foot, skin, 9)
	var shoe_direction = signf(p.velocity.x) if absf(p.velocity.x) > 30 else f
	draw_shoe(joints.back_foot, shoe_direction, team_color, true)
	draw_shoe(joints.front_foot, shoe_direction, team_color, false)
	limb(shoulder, joints.other_elbow, joints.other_hand, skin.darkened(0.10), 8)
	# Fitted jersey and angular shorts replace the previous rectangular body.
	outlined_poly(torso_shape(shoulder, hip, 17.5, 12.5), team_color, INK, 3.5)
	var body_axis = (hip - shoulder).normalized()
	var body_across = Vector2(-body_axis.y, body_axis.x)
	draw_line(shoulder - body_across * 13, shoulder + body_axis * 10 - body_across * 10, trim, 4, true)
	draw_line(shoulder + body_across * 13, shoulder + body_axis * 10 + body_across * 10, trim, 4, true)
	var shorts = PackedVector2Array([
		hip - body_across * 13 - body_axis * 5,
		hip + body_across * 13 - body_axis * 5,
		hip + body_across * 10 + body_axis * 11,
		hip + body_axis * 5,
		hip - body_across * 10 + body_axis * 11
	])
	outlined_poly(shorts, Color("12283a"), INK, 3)
	draw_line(shoulder + body_axis * 6, hip - body_axis * 5, Color(team_dark, 0.75), 4, true)
	# Number follows the torso rather than floating over a line segment.
	var number_at = shoulder.lerp(hip, 0.53) + Vector2(0, 5)
	caption(number_at, str(p.number), 14, trim, true)
	draw_head(head, f, skin, hair, p.id % 3)
	limb(shoulder, joints.elbow, joints.hand, skin, 8.5)
	if p.swing_connected and p.swing_elapsed >= 0.12 and p.swing_elapsed < 0.23:
		var alpha = (0.23 - p.swing_elapsed) / 0.11
		var burst = joints.hand
		for i in range(5):
			var direction = Vector2.from_angle(-1.7 + i * 0.27) * Vector2(f, 1)
			draw_line(burst - direction * 6, burst - direction * (18 + i * 3), Color(CREAM, alpha * 0.75), 2.4, true)

	var label_at = origin + Vector2(0, -p.config.height - 49)
	if p.id == game.human_id:
		# Contact grade and speed occupy this space during a swing.
		if p.swing_elapsed < 0:
			label_at.y -= 12
			caption(label_at + Vector2(0, -10), "YOU", 16, CREAM, true)
			draw_colored_polygon(PackedVector2Array([label_at + Vector2(-7, -2), label_at + Vector2(7, -2), label_at + Vector2(0, 6)]), BLUE)
	else:
		var tag = Rect2(origin.x - 18, origin.y + 24, 36, 18)
		draw_style_box(seat_style(Color(INK, 0.72)), tag)
		caption(origin + Vector2(0, 37), p.role, 11, Color(CREAM, 0.9), true)

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

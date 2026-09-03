extends Node2D
## Procedural placeholder art: the poses line up with the simulation's contacts.
var game
var effects: Array = []
var trail: Array = []
var clock: float = 0
var landing_guide: bool = true
var font = ThemeDB.fallback_font
const INK = Color("15283d")
const CREAM = Color("f0f6ec")
const BLUE = Color("70c7fa")
const ORANGE = Color("ffb063")

func advance(dt: float) -> void:
	clock += dt
	for effect in effects:
		effect.age += dt
	effects = effects.filter(func(e): return e.age < 0.55)
	trail.append({"position": game.ball, "age": 0.0})
	for item in trail:
		item.age += dt
	trail = trail.filter(func(item): return item.age < 0.14)
	queue_redraw()

func add_event(event: Dictionary) -> void:
	if event.kind in ["serve", "receive", "set", "spike", "block", "dive", "free", "net"]:
		effects.append({"position": event.position, "kind": event.kind, "age": 0.0})

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
			var alpha = (1 - item.age / 0.14) * 0.22
			draw_circle(Vector2(item.position.x, -item.position.y), 8 * (1 - item.age / 0.14), Color(CREAM, alpha))
	draw_ball(Vector2(game.ball.x, -game.ball.y), game.time * 5)
	for effect in effects:
		var pos = Vector2(effect.position.x, -effect.position.y)
		var alpha = 1 - effect.age / 0.55
		var color = ORANGE if effect.kind in ["spike", "block"] else BLUE
		draw_arc(pos, 15 + effect.age * 65, 0, TAU, 28, Color(color, alpha * 0.8), 2, true)
		if effect.kind in ["spike", "block", "set"]:
			caption(pos + Vector2(0, -32 - effect.age * 32), effect.kind.to_upper(), 16, Color(CREAM, alpha), true)

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

func limb(a: Vector2, b: Vector2, c: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, color, width, true)
	draw_line(b, c, color, width, true)
	draw_circle(b, width / 2, color)
	draw_circle(c, width / 2, color)

func draw_player(p) -> void:
	var origin = Vector2(p.pos.x, -p.pos.y)
	var f = p.facing
	var team_color = BLUE if p.team == 0 else ORANGE
	var skin = Color("e0d5be")
	var dark = Color("1d3549")
	if p.dive_timer > 0:
		var direction = signf(p.velocity.x)
		limb(origin + Vector2(-direction * 32, -13), origin + Vector2(-direction * 15, -25), origin + Vector2(direction * 2, -21), dark, 10)
		draw_line(origin + Vector2(-direction * 3, -25), origin + Vector2(direction * 29, -31), team_color, 20, true)
		draw_circle(origin + Vector2(direction * 38, -34), 11, skin)
		limb(origin + Vector2(direction * 25, -33), origin + Vector2(direction * 45, -27), origin + Vector2(direction * 70, -24), skin, 7)
	else:
		var joints = p.skeleton()
		for key in joints:
			joints[key] = origin + Vector2(joints[key].x, -joints[key].y)
		var shoulder = joints.shoulder
		var hip = joints.hip
		var head = joints.head
		limb(hip, joints.back_knee, joints.back_foot, skin.darkened(0.16), 8)
		limb(hip, joints.front_knee, joints.front_foot, skin, 8)
		for foot in [joints.back_foot, joints.front_foot]:
			draw_line(foot - Vector2(f * 5, 0), foot + Vector2(f * 8, 0), CREAM, 7, true)
		limb(shoulder, joints.other_elbow, joints.other_hand, skin.darkened(0.14), 7)
		draw_line(hip + Vector2(-8, 0), hip + Vector2(8, 0), dark, 21, true)
		draw_line(hip + Vector2(0, -7), shoulder + Vector2(0, 3), team_color, 27, true)
		draw_line(shoulder + Vector2(-11, 12), shoulder + Vector2(11, 12), Color(CREAM, 0.85), 4)
		caption(shoulder + Vector2(0, 29), str(p.number), 14, INK, true)
		draw_circle(head, 11, skin)
		draw_arc(head + Vector2(0, -2), 10, PI, TAU, 10, dark, 6, true)
		draw_circle(head + Vector2(f * 4, -1), 1.4, INK)
		limb(shoulder, joints.elbow, joints.hand, skin, 8)
		if p.swing_connected and p.swing_elapsed >= 0.12 and p.swing_elapsed < 0.23:
			var alpha = (0.23 - p.swing_elapsed) / 0.11
			draw_arc(shoulder, 53, -1.6 if f > 0 else -PI, 0.0 if f > 0 else -1.5, 16, Color(CREAM, alpha * 0.4), 3, true)

	var label_at = origin + Vector2(0, -p.config.height - 40)
	if p.id == game.human_id:
		label_at.y -= 12
		caption(label_at + Vector2(0, -10), "YOU", 17, BLUE, true)
		draw_colored_polygon(PackedVector2Array([label_at + Vector2(-7, -2), label_at + Vector2(7, -2), label_at + Vector2(0, 6)]), BLUE)
	else:
		caption(origin + Vector2(0, 33), p.role, 14, Color(CREAM, 0.78), true)

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
	caption(apex_at + Vector2(0, -17), "TOSS", 13, CREAM, true)

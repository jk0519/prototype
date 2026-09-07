extends RefCounted
## One articulated side-view athlete, with texture parts bound to gameplay joints.
const ART = "res://assets/art/side_rig/"
static var textures: Dictionary = {}

static func texture(part: String, team: int) -> Texture2D:
	if part.ends_with("_shaft"):
		var key: String = part + str(team)
		if not textures.has(key):
			var source: Texture2D = texture(part.trim_suffix("_shaft"), team)
			var region = AtlasTexture.new()
			region.atlas = source
			# The source forearms include a closed fist. Stop at the wrist and
			# articulate a single palm, rather than stacking two opposing hands.
			region.region = Rect2(0, 0, source.get_width(), source.get_height() * (0.68 if part.begins_with("far") else 0.72))
			textures[key] = region
		return textures[key]
	var path = ART + part + ("-south" if team == 1 else "") + ".png"
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

static func screen(v: Vector2) -> Vector2:
	return Vector2(v.x, -v.y)

static func piece(canvas: Node2D, part: String, team: int, a: Vector2, b: Vector2, width: float, origin: Vector2, facing: float, tint: Color) -> void:
	var delta = screen(b - a)
	var local = Transform2D(delta.angle() - PI / 2.0, screen(a))
	var world = Transform2D(Vector2(facing,0), Vector2(0,1), origin)
	canvas.draw_set_transform_matrix(world * local)
	canvas.draw_texture_rect(texture(part, team), Rect2(-width * 0.5, -1, width, delta.length() + 2), false, tint)

static func cutout(canvas: Node2D, part: String, team: int, at: Vector2, angle: float, rect: Rect2, origin: Vector2, facing: float, tint: Color) -> void:
	var world = Transform2D(Vector2(facing,0), Vector2(0,1), origin)
	canvas.draw_set_transform_matrix(world * Transform2D(angle, screen(at)))
	canvas.draw_texture_rect(texture(part, team), rect, false, tint)

static func forearm(canvas: Node2D, pose: Dictionary, side: String, team: int, origin: Vector2, facing: float, tint: Color) -> void:
	var elbow: Vector2 = pose[side + "_elbow"]
	var hand: Vector2 = pose[side + "_hand"]
	var direction: Vector2 = (hand - elbow).normalized()
	var angle: float = screen(direction).angle() + PI / 2.0
	if pose.state == "carry": angle = 0.85
	var wrist: Vector2 = hand - Vector2(sin(angle), cos(angle)) * 2.0
	piece(canvas, "far_forearm_shaft" if side == "back" else "forearm_shaft", team, elbow, wrist, 4.3 if side == "back" else 4.5, origin, facing, tint)
	cutout(canvas, "palm", team, hand, angle, Rect2(-1.9, -3.3, 3.8, 6.3), origin, facing, tint)

static func draw_pose(canvas: Node2D, pose: Dictionary, origin: Vector2, facing: float, team: int, alpha: float = 1.0) -> void:
	var tint = Color(1,1,1,alpha)
	var far_tint = Color(0.89,0.91,0.92,alpha)
	# Layer order preserves the identity of the farther limbs during overlap.
	for side in ["back", "front"]:
		var color = far_tint if side == "back" else tint
		piece(canvas,"thigh",team,pose[side+"_hip"],pose[side+"_knee"],8.0,origin,facing,color)
		piece(canvas,"shin",team,pose[side+"_knee"],pose[side+"_foot"],5.2,origin,facing,color)
		cutout(canvas,"shoe",team,pose[side+"_foot"],pose[side+"_foot_angle"],Rect2(-4,-3,12,5.5),origin,facing,color)
	piece(canvas,"far_upper_arm",team,pose.back_shoulder,pose.back_elbow,6.0,origin,facing,far_tint)
	forearm(canvas,pose,"back",team,origin,facing,far_tint)
	var down = (pose.hip - pose.shoulder).normalized()
	piece(canvas,"pelvis",team,pose.hip - down*1.5,pose.hip + down*9,14.0,origin,facing,tint)
	var turn = smoothstep(0.0, 0.48, absf(pose.torso_turn))
	var torso_width = lerpf(14.0, 16.5, turn)
	piece(canvas,"torso",team,pose.shoulder-down*4,pose.hip+down*2,torso_width,origin,facing,tint)
	piece(canvas,"torso_turn",team,pose.shoulder-down*4,pose.hip+down*2,torso_width,origin,facing,Color(1,1,1,alpha * turn))
	cutout(canvas,"head",team,pose.head,pose.head_angle,Rect2(-7.1,-9,14.2,17.8),origin,facing,tint)
	piece(canvas,"upper_arm",team,pose.front_shoulder,pose.front_elbow,6.2,origin,facing,tint)
	forearm(canvas,pose,"front",team,origin,facing,tint)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

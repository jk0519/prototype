extends RefCounted
## Authored side-view action poses. Every visible palm and collider is sampled
## from this same rig. Coordinates are local, facing right, and y-up.
## Feet are driven by distance, while body/arm actions remain independent of gait.

const STRIDE_LENGTH = 176.0
const STANCE_FRACTION = 0.30
const SERVE_LIFT_DURATION = 0.22
const UPPER_ARM = 19.0
const FOREARM = 18.0
const THIGH = 23.0
const SHIN = 23.0
const TORSO_LENGTH = 29.0

static func sample(p) -> Dictionary:
	var grounded: bool = p.pos.y < 1.0
	var running: bool = grounded and absf(p.velocity.x) > 12.0
	var travel: float = p.velocity.x * p.facing
	var phase: float = fposmod(p.run_clock / TAU, 1.0)
	var front_step: Dictionary = _step(phase)
	var back_step: Dictionary = _step(fposmod(phase + 0.5, 1.0))
	var breathe: float = sin(p.animation_clock * 2.1) * 0.35
	var hip = Vector2(0, 44.0 + breathe)
	var tilt: float = 0.12
	var turn: float = 0.0
	var front_foot = Vector2(11, 3)
	var back_foot = Vector2(-10, 3)
	var front_hand = Vector2(17, 48)
	var back_hand = Vector2(12, 50)
	var front_foot_angle: float = 0.0
	var back_foot_angle: float = 0.0
	var knee_bend: float = 1.0
	var state: String = "ready"
	var front_planted: bool = grounded
	var back_planted: bool = grounded
	if running:
		# Do not blend the foot positions by speed: that would slide the stance
		# foot. The signed distance clock makes its world x invariant.
		front_foot = front_step.position
		back_foot = back_step.position
		front_planted = front_step.planted
		back_planted = back_step.planted
		front_foot_angle = front_step.angle
		back_foot_angle = back_step.angle
		hip.y = 36.5 + sin(phase * TAU * 2.0) * 1.5
		tilt = clampf(travel / 2500.0, -0.20, 0.30)
		var arm_wave: float = sin(phase * TAU) * 18.0
		front_hand = Vector2(9.0 - arm_wave, 49.0 + maxf(0, -arm_wave) * 0.35)
		back_hand = Vector2(5.0 + arm_wave, 49.0 + maxf(0, arm_wave) * 0.35)
		state = "run"
		if p.gait_start_remaining > 0 and not p.gait_start_pose.is_empty():
			var old: Dictionary = p.gait_start_pose
			var body_scale: float = clampf(p.config.height / 92.0, 0.85, 1.15)
			var start: float = clampf(1.0 - p.gait_start_remaining / 0.10, 0, 1)
			var blend: float = smoothstep(0.0, 1.0, start)
			front_foot = (old.front_foot / body_scale).lerp(front_foot, blend)
			back_foot = (old.back_foot / body_scale).lerp(back_foot, blend)
			front_foot.y += pow(sin(start * PI), 2) * 2.0
			back_foot.y += pow(sin(start * PI), 2) * 2.0
			hip = (old.hip / body_scale).lerp(hip, blend)
			var old_torso: Vector2 = old.shoulder - old.hip
			tilt = lerpf(atan2(old_torso.x, old_torso.y), tilt, blend)
			front_hand = (old.front_hand / body_scale).lerp(front_hand, blend)
			back_hand = (old.back_hand / body_scale).lerp(back_hand, blend)
			front_foot_angle = lerpf(old.front_foot_angle, front_foot_angle, blend)
			back_foot_angle = lerpf(old.back_foot_angle, back_foot_angle, blend)
			# These are lifted transition steps, not falsely labelled stationary
			# contact feet. Exact planted stance begins when the gait takes over.
			front_planted = false
			back_planted = false
			state = "start"
	elif grounded and p.gait_stop_remaining > 0 and not p.gait_stop_pose.is_empty():
		var old: Dictionary = p.gait_stop_pose
		var body_scale: float = clampf(p.config.height / 92.0, 0.85, 1.15)
		var settle: float = clampf(1.0 - p.gait_stop_remaining / 0.20, 0, 1)
		var old_front: Vector2 = old.front_foot / body_scale
		var old_back: Vector2 = old.back_foot / body_scale
		var front_first: bool = old_front.y >= old_back.y
		var first: float = clampf(settle / 0.58, 0, 1)
		var second: float = clampf((settle - 0.42) / 0.58, 0, 1)
		front_foot = _settle_foot(old_front, front_foot, first if front_first else second)
		back_foot = _settle_foot(old_back, back_foot, second if front_first else first)
		front_planted = absf(front_foot.y - 3.0) < 0.01
		back_planted = absf(back_foot.y - 3.0) < 0.01
		hip = (old.hip / body_scale).lerp(hip, smoothstep(0.45, 1.0, settle))
		var old_torso: Vector2 = old.shoulder - old.hip
		tilt = lerpf(atan2(old_torso.x, old_torso.y), tilt, smoothstep(0.0, 1.0, settle))
		front_hand = (old.front_hand / body_scale).lerp(front_hand, smoothstep(0.0, 1.0, settle))
		back_hand = (old.back_hand / body_scale).lerp(back_hand, smoothstep(0.0, 1.0, settle))
		front_foot_angle = lerpf(old.front_foot_angle, 0, smoothstep(0.0, 1.0, settle))
		back_foot_angle = lerpf(old.back_foot_angle, 0, smoothstep(0.0, 1.0, settle))
		state = "settle"
	if p.jump_prepare > 0:
		var plant: float = smoothstep(0.0, 1.0, 1.0 - p.jump_prepare / 0.060)
		hip = hip.lerp(Vector2(-3, 30), plant)
		tilt = lerpf(tilt, 0.43, plant)
		front_hand = front_hand.lerp(Vector2(-18, 39), plant)
		back_hand = back_hand.lerp(Vector2(-23, 41), plant)
		state = "plant"
	if not grounded:
		var ascent: float = clampf(1.0 - maxf(p.velocity.y, 0.0) / p.config.jump_speed, 0, 1)
		var raise: float = smoothstep(0.0, 0.58, ascent)
		var fall: float = smoothstep(0.0, 0.7, -p.velocity.y / p.config.jump_speed)
		hip = Vector2(1, 44)
		tilt = lerpf(0.24, -0.21, raise)
		front_hand = Vector2(-17, 40).lerp(Vector2(-13, 102), raise).lerp(Vector2(13, 59), fall)
		back_hand = Vector2(-21, 42).lerp(Vector2(25, 103), raise).lerp(Vector2(9, 55), fall)
		front_foot = Vector2(10, 3).lerp(Vector2(6, 11), raise).lerp(Vector2(13, 3), fall)
		back_foot = Vector2(-19, 5).lerp(Vector2(-27, 17), raise).lerp(Vector2(-12, 3), fall)
		front_foot_angle = 0.10
		back_foot_angle = -0.55 * (1.0 - fall)
		front_planted = false
		back_planted = false
		state = "air"
	elif p.landing_timer > 0:
		var absorb: float = sin(clampf(p.landing_timer / 0.12, 0, 1) * PI)
		hip.y -= 9.0 * absorb
		tilt += 0.14 * absorb
		state = "land"

	# Upper-body actions never override grounded feet. Carrying, charging, and
	# throwing while moving therefore retain the same continuous foot cycle.
	if p.serve_pose in ["ready", "aim", "windup"]:
		var lift: float = smoothstep(0.0, SERVE_LIFT_DURATION, p.serve_pose_time) if p.serve_pose == "windup" else 0.0
		front_hand = Vector2(22, 34).lerp(Vector2(30, 99), lift)
		back_hand = Vector2(17, 35).lerp(Vector2(-12, 66), lift)
		tilt = lerpf(0.25, 0.08, lift)
		# Raise the shoulder as the tossing arm extends, without translating the
		# whole athlete or stretching either arm segment.
		if not running: hip.y = lerpf(hip.y, maxf(hip.y, 44.0), lift)
		turn = 0.06 * lift
		state = "carry" if lift == 0.0 else "toss"
	elif p.serve_pose == "released" and grounded and p.serve_pose_time < 0.22:
		var lower: float = smoothstep(0.0, 0.22, p.serve_pose_time)
		front_hand = Vector2(30, 99).lerp(front_hand, lower)
		back_hand = Vector2(-12, 66).lerp(back_hand, lower)
		tilt = lerpf(0.08, tilt, lower)
		turn = lerpf(0.06, 0.0, lower)
		if not running: hip.y = lerpf(44.0, hip.y, lower)
		state = "approach"

	if p.swing_elapsed >= 0:
		var attack: Dictionary = _attack(p.swing_elapsed, hip, tilt, front_hand, back_hand, front_foot, back_foot)
		hip = attack.hip
		tilt = attack.tilt
		turn = attack.turn
		front_hand = attack.front_hand
		back_hand = attack.back_hand
		front_foot = attack.front_foot
		back_foot = attack.back_foot
		state = "strike"
	elif p.blocking:
		var raise: float = smoothstep(0.0, 0.13, maxf(p.block_elapsed, 0))
		var recoil: float = sin(clampf((0.14 - p.contact_flash) / 0.14, 0, 1) * PI) if p.contact_flash > 0 else 0.0
		if not grounded: hip.y = lerpf(hip.y, 46.0, raise)
		tilt = lerpf(tilt, 0.08, raise)
		front_hand = front_hand.lerp(Vector2(19, 109 - recoil * 5), raise)
		back_hand = back_hand.lerp(Vector2(9, 110 - recoil * 5), raise)
		state = "block"
	elif p.setting:
		var raise: float = smoothstep(0.0, 0.13, maxf(p.set_elapsed, 0))
		var release: float = sin(clampf((0.14 - p.contact_flash) / 0.14, 0, 1) * PI) if p.contact_flash > 0 else 0.0
		tilt = lerpf(tilt, 0.04, raise)
		hip.y += release * 2.0
		front_hand = front_hand.lerp(Vector2(14, 96 + release * 9), raise)
		back_hand = back_hand.lerp(Vector2(5, 98 + release * 9), raise)
		state = "set"
	elif p.receiving:
		var ready: float = smoothstep(0.0, 0.12, maxf(p.receive_elapsed, 0))
		var bump: float = sin(clampf((0.14 - p.contact_flash) / 0.14, 0, 1) * PI) if p.contact_flash > 0 else 0.0
		hip.y = lerpf(hip.y, 33.0 + bump * 3.0, ready)
		tilt = lerpf(tilt, 0.40 - bump * 0.12, ready)
		front_hand = front_hand.lerp(Vector2(36, 52 + bump * 12), ready)
		back_hand = back_hand.lerp(Vector2(31, 53 + bump * 12), ready)
		state = "receive"

	if p.dive_timer > 0 or p.dive_recovery > 0:
		var direction: float = signf(p.velocity.x * p.facing)
		if direction == 0: direction = p.dive_direction * p.facing
		var dive: Dictionary = _dive(p, direction, hip, tilt, front_hand, back_hand, front_foot, back_foot)
		hip = dive.hip
		tilt = dive.tilt
		front_hand = dive.front_hand
		back_hand = dive.back_hand
		front_foot = dive.front_foot
		back_foot = dive.back_foot
		# Keep knees on the same anatomical side through the floor-to-standing
		# transition. Flipping the IK branch at recovery caused a visible snap.
		knee_bend = 1.0
		front_planted = false
		back_planted = false
		state = "dive" if p.dive_timer > 0 else "recover"

	var shoulder: Vector2 = hip + Vector2(sin(tilt), cos(tilt)) * TORSO_LENGTH
	var head: Vector2 = shoulder + Vector2(2, 13.5).rotated(-tilt)
	var separation: float = 1.8 + absf(turn) * 4.0
	var front_shoulder: Vector2 = shoulder + Vector2(separation, -1.0)
	var back_shoulder: Vector2 = shoulder + Vector2(-separation, 0.5)
	var front_hip: Vector2 = hip + Vector2(1.8, 0)
	var back_hip: Vector2 = hip + Vector2(-1.8, 0)
	var near_arm: Dictionary = _limb(front_shoulder, front_hand, UPPER_ARM, FOREARM, 1)
	var far_arm: Dictionary = _limb(back_shoulder, back_hand, UPPER_ARM, FOREARM, 1)
	var near_leg: Dictionary = _limb(front_hip, front_foot, THIGH, SHIN, knee_bend)
	var far_leg: Dictionary = _limb(back_hip, back_foot, THIGH, SHIN, knee_bend)
	var joints = {
		"hip": hip, "shoulder": shoulder, "head": head,
		"front_shoulder": front_shoulder, "back_shoulder": back_shoulder,
		"front_elbow": near_arm.joint, "back_elbow": far_arm.joint,
		"front_hand": near_arm.end, "back_hand": far_arm.end,
		"front_hip": front_hip, "back_hip": back_hip,
		"front_knee": near_leg.joint, "back_knee": far_leg.joint,
		"front_foot": near_leg.end, "back_foot": far_leg.end,
		"head_angle": -tilt * 0.45, "torso_turn": turn,
		"front_foot_angle": front_foot_angle, "back_foot_angle": back_foot_angle,
		"front_planted": front_planted, "back_planted": back_planted,
		"state": state
	}
	# Scale the full skeleton once, preserving every joint relationship.
	var scale_factor: float = clampf(p.config.height / 92.0, 0.85, 1.15)
	for key in joints:
		if joints[key] is Vector2: joints[key] *= scale_factor
	joints.hand = joints.front_hand
	joints.other_hand = joints.back_hand
	joints.elbow = joints.front_elbow
	joints.other_elbow = joints.back_elbow
	return joints

static func _step(phase: float) -> Dictionary:
	var half_stance: float = STRIDE_LENGTH * STANCE_FRACTION * 0.5
	if phase < STANCE_FRACTION:
		return {"position": Vector2(half_stance - phase * STRIDE_LENGTH, 3), "planted": true, "angle": 0.0}
	var t: float = (phase - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
	# Hermite tangents match the stance foot velocity at lift-off and landing.
	var slope: float = -STRIDE_LENGTH * (1.0 - STANCE_FRACTION)
	var x: float = (2*t*t*t - 3*t*t + 1) * -half_stance + (t*t*t - 2*t*t + t) * slope + (-2*t*t*t + 3*t*t) * half_stance + (t*t*t - t*t) * slope
	var y: float = 3.0 + pow(sin(t * PI), 2) * 24.0
	return {"position": Vector2(x, y), "planted": false, "angle": sin(t * TAU) * 0.45}

static func _settle_foot(from: Vector2, to: Vector2, weight: float) -> Vector2:
	var foot: Vector2 = from.lerp(to, smoothstep(0.0, 1.0, weight))
	foot.y += pow(sin(weight * PI), 2) * 7.0
	return foot

static func _limb(origin: Vector2, target: Vector2, upper: float, lower: float, bend: float) -> Dictionary:
	var delta: Vector2 = target - origin
	var distance: float = clampf(delta.length(), absf(upper - lower) + 0.01, upper + lower - 0.01)
	var direction: Vector2 = delta.normalized() if delta.length_squared() > 0.001 else Vector2.DOWN
	var along: float = (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, upper * upper - along * along))
	var normal = Vector2(-direction.y, direction.x)
	return {"joint": origin + direction * along + normal * height * bend, "end": origin + direction * distance}

static func _attack(time: float, base_hip: Vector2, base_tilt: float, base_front_hand: Vector2, base_back_hand: Vector2, base_front_foot: Vector2, base_back_foot: Vector2) -> Dictionary:
	var base = {"hip": base_hip, "tilt": base_tilt, "turn": 0.0, "front_hand": base_front_hand, "back_hand": base_back_hand, "front_foot": base_front_foot, "back_foot": base_back_foot}
	var coil = {"hip": Vector2(3, 46), "tilt": -0.38, "turn": 0.48, "front_hand": Vector2(-15, 102), "back_hand": Vector2(25, 105), "front_foot": Vector2(10, 8), "back_foot": Vector2(-24, 16)}
	var contact = {"hip": Vector2(-1, 49), "tilt": 0.32, "turn": 0.18, "front_hand": Vector2(30, 110), "back_hand": Vector2(12, 63), "front_foot": Vector2(13, 9), "back_foot": Vector2(-28, 12)}
	var through = {"hip": Vector2(0, 41), "tilt": 0.52, "turn": -0.36, "front_hand": Vector2(8, 45), "back_hand": Vector2(-13, 52), "front_foot": Vector2(21, 5), "back_foot": Vector2(-19, 10)}
	if time < 0.045: return _mix(base, coil, smoothstep(0.0, 0.045, time))
	if time < 0.108: return _mix(coil, contact, smoothstep(0.045, 0.108, time))
	if time < 0.135: return contact
	if time < 0.25: return _mix(contact, through, smoothstep(0.135, 0.25, time))
	return _mix(through, base, smoothstep(0.25, 0.34, time))

static func _dive(p, direction: float, base_hip: Vector2, base_tilt: float, base_front_hand: Vector2, base_back_hand: Vector2, base_front_foot: Vector2, base_back_foot: Vector2) -> Dictionary:
	var base = {"hip": base_hip, "tilt": base_tilt, "front_hand": base_front_hand, "back_hand": base_back_hand, "front_foot": base_front_foot, "back_foot": base_back_foot}
	var extension = {"hip": Vector2(-7 * direction, 23), "tilt": 1.16 * direction, "front_hand": Vector2(54 * direction, 27), "back_hand": Vector2(49 * direction, 24), "front_foot": Vector2(-43 * direction, 8), "back_foot": Vector2(-37 * direction, 10)}
	var floor_pose = {"hip": Vector2(-8 * direction, 22), "tilt": 1.40 * direction, "front_hand": Vector2(51 * direction, 12), "back_hand": Vector2(42 * direction, 9), "front_foot": Vector2(-44 * direction, 3), "back_foot": Vector2(-43 * direction, 10)}
	if p.dive_timer > 0:
		if p.dive_elapsed < 0.11: return _mix(base, extension, smoothstep(0.0, 0.11, p.dive_elapsed))
		return _mix(extension, floor_pose, smoothstep(0.20, 0.32, p.dive_elapsed))
	var rise: float = smoothstep(0.0, 0.22, 0.22 - p.dive_recovery)
	return _mix(floor_pose, base, rise)

static func _mix(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var result = {}
	for key in from:
		if from[key] is Vector2: result[key] = from[key].lerp(to[key], weight)
		else: result[key] = lerpf(from[key], to[key], weight)
	return result

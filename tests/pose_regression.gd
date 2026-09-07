extends SceneTree
const Pose = preload("res://scripts/athlete_pose.gd")
const Athlete = preload("res://scripts/athlete.gd")

var failures: Array[String] = []
var sampled_poses = 0

func _initialize() -> void:
	check_gait()
	check_starting()
	check_stopping()
	check_boundaries()
	check_serve()
	check_actions()
	check_contact_confirmation()
	if failures.is_empty():
		print("PASS: %d side-view poses; planted feet, moving carry, continuous toss/strike/recovery, fixed limb lengths and visible contacts" % sampled_poses)
		quit(0)
	else:
		for failure in failures: printerr("FAIL: ", failure)
		quit(1)

func expect(ok: bool, label: String) -> void:
	if not ok and not failures.has(label): failures.append(label)

func player(role: String = "WS"):
	var p = Athlete.new(0, 0, role, 300)
	p.config.height = 98.0 if role == "MB" else 92.0
	p.movement_bounds = Vector2(-10000, 10000)
	return p

func check_gait() -> void:
	for role in ["WS", "SET", "MB"]:
		for direction in [-1.0, 1.0]:
			for carry in ["", "ready", "aim", "windup", "released"]:
				var p = player(role)
				p.velocity.x = p.config.run_speed * direction
				p.serve_pose = carry
				p.serve_pose_time = 0.18
				var previous: Dictionary = Pose.sample(p)
				var previous_x: float = p.pos.x
				var front_contact_samples = 0
				var back_contact_samples = 0
				var range_min = INF
				var range_max = -INF
				for i in 96:
					p.step(1.0 / 240.0, {"move": direction})
					var pose: Dictionary = Pose.sample(p)
					validate_limbs(p, pose)
					for side in ["front", "back"]:
						if previous[side + "_planted"] and pose[side + "_planted"]:
							var old_world: float = previous_x + previous[side + "_foot"].x * p.facing
							var new_world: float = p.pos.x + pose[side + "_foot"].x * p.facing
							expect(absf(new_world - old_world) < 0.02, "%s %s %s stance foot stays fixed on court" % [role, carry, side])
							expect(absf(pose[side + "_foot"].y - 3.0 * p.config.height / 92.0) < 0.02, "%s %s stance ankle stays at floor level" % [role, carry])
							if side == "front": front_contact_samples += 1
							else: back_contact_samples += 1
					var separation: float = pose.front_foot.x - pose.back_foot.x
					range_min = minf(range_min, separation)
					range_max = maxf(range_max, separation)
					previous = pose
					previous_x = p.pos.x
				expect(front_contact_samples > 4 and back_contact_samples > 4, "%s %s both feet have stance periods" % [role, carry])
				expect(range_max - range_min > 45, "%s %s running feet alternate fully while arms perform action" % [role, carry])

func check_serve() -> void:
	for moving in [false, true]:
		var p = player()
		p.velocity.x = 760.0 if moving else 0.0
		p.run_clock = 0.17 * TAU
		p.serve_pose = "ready"
		var carry: Dictionary = Pose.sample(p)
		p.serve_pose = "aim"
		p.serve_pose_time = 1.0
		var aim: Dictionary = Pose.sample(p)
		expect(carry.front_hand.distance_to(aim.front_hand) < 0.01, "Holding toss charge keeps ball in carrying palm")
		p.serve_pose = "windup"
		p.serve_pose_time = 0.0
		var previous: Dictionary = Pose.sample(p)
		expect(previous.front_hand.distance_to(aim.front_hand) < 0.01, "Releasing charge starts toss from existing carrying palm")
		var start_y: float = previous.front_hand.y
		for i in range(1, 54):
			p.serve_pose_time = Pose.SERVE_LIFT_DURATION * i / 53.0
			var pose: Dictionary = Pose.sample(p)
			validate_limbs(p, pose)
			expect(pose.front_hand.distance_to(previous.front_hand) < 2.5, "Throwing palm moves continuously before release")
			expect(pose.front_hand.y >= previous.front_hand.y - 0.01, "Throwing palm rises consistently through toss")
			previous = pose

		expect(previous.front_hand.y - start_y > 40.0, "Toss visibly raises the carrying arm before releasing")
		p.serve_pose = "released"
		p.serve_pose_time = 0.0
		var release: Dictionary = Pose.sample(p)
		expect(release.front_hand.distance_to(previous.front_hand) < 0.01, "Released arm begins from the exact pre-release palm position")
		for i in range(1, 54):
			p.serve_pose_time = 0.22 * i / 53.0
			var pose: Dictionary = Pose.sample(p)
			validate_limbs(p, pose)
			expect(pose.front_hand.distance_to(previous.front_hand) < 2.5, "Toss arm lowers continuously into approach")
			previous = pose

func check_starting() -> void:
	for direction in [-1.0, 1.0]:
		for carry in ["", "ready", "aim"]:
			var p = player()
			p.serve_pose = carry
			var previous: Dictionary = Pose.sample(p)
			p.step(1.0 / 240.0, {"move": direction})
			var first: Dictionary = Pose.sample(p)
			expect(first.front_foot.distance_to(previous.front_foot) < 0.01 and first.back_foot.distance_to(previous.back_foot) < 0.01, "Movement starts from existing visible feet rather than an arbitrary gait frame")
			expect(first.hip.distance_to(previous.hip) < 0.01, "Movement starts without dropping the character body instantly")
			expect(not first.front_planted and not first.back_planted, "Start blend does not falsely claim physically planted gait feet")
			previous = first
			for i in 40:
				p.step(1.0 / 240.0, {"move": direction})
				var pose: Dictionary = Pose.sample(p)
				validate_limbs(p, pose)
				expect(pose.front_foot.distance_to(previous.front_foot) < 6.5 and pose.back_foot.distance_to(previous.back_foot) < 6.5, "Movement accelerates through continuous startup steps")
				previous = pose
			expect(p.gait_start_remaining == 0.0, "Startup completes and hands over to distance-driven gait")

func check_stopping() -> void:
	for starting_phase in [0.02, 0.19, 0.36, 0.57, 0.81]:
		var p = player()
		p.velocity.x = 500
		p.run_clock = starting_phase * TAU
		var previous: Dictionary = Pose.sample(p)
		var saw_settle = false
		for i in 75:
			p.step(1.0 / 240.0, {})
			var pose: Dictionary = Pose.sample(p)
			validate_limbs(p, pose)
			if p.gait_stop_remaining > 0: saw_settle = true
			for side in ["front", "back"]:
				expect(pose[side + "_foot"].distance_to(previous[side + "_foot"]) < 3.5, "Stopping finishes foot steps without snapping to idle")
			previous = pose
		expect(saw_settle and p.gait_stop_remaining == 0, "Every stopping gait completes a short settling sequence")
		expect(previous.front_planted and previous.back_planted, "Stopping finishes with both feet on the court")
func check_boundaries() -> void:
	for direction in [-1.0, 1.0]:
		var p = player()
		p.reset(500)
		p.movement_bounds = Vector2(450, 550)
		p.velocity.x = direction * p.config.run_speed
		p.serve_pose = "ready"
		for i in 120:
			p.step(1.0 / 240.0, {"move": direction})
			validate_limbs(p, Pose.sample(p))
		var pose: Dictionary = Pose.sample(p)
		expect(absf(p.velocity.x) < 0.01, "Held movement at either boundary reports zero achieved velocity")
		expect(p.gait_stop_remaining == 0 and p.gait_start_remaining == 0, "Held boundary input lets stopping animation finish")
		expect(pose.front_planted and pose.back_planted, "Both feet settle on the floor at serving boundaries")
		var stopped_front: Vector2 = pose.front_foot
		var stopped_back: Vector2 = pose.back_foot
		for i in 36: p.step(1.0 / 240.0, {"move": direction})
		pose = Pose.sample(p)
		expect(pose.front_foot.distance_to(stopped_front) < 0.01 and pose.back_foot.distance_to(stopped_back) < 0.01, "Continued pushing at wall does not restart or freeze a stride")
	var diver = player()
	diver.reset(455)
	diver.movement_bounds = Vector2(450, 550)
	diver.step(1.0 / 120.0, {"move": -1.0, "dive": true})
	for i in 17: diver.step(1.0 / 120.0, {})
	var dive: Dictionary = Pose.sample(diver)
	expect(absf(diver.velocity.x) < 0.01 and diver.dive_direction == -1.0, "Stopped dive retains its launch direction")
	expect(dive.front_hand.x < dive.hip.x and dive.head.x < dive.hip.x, "Leftward dive remains leftward after striking a boundary")
	for i in 23: diver.step(1.0 / 120.0, {})
	dive = Pose.sample(diver)
	expect(diver.dive_recovery > 0 and dive.head.x < dive.hip.x, "Boundary dive begins recovery without mirroring the body")

func check_actions() -> void:
	var p = player()
	var idle: Dictionary = Pose.sample(p)
	expect(idle.head.y + 9.0 < 103 and idle.head.y > 78, "Side-view athlete keeps compact court proportions")
	p.pos.y = 140
	p.velocity.y = 90
	var previous: Dictionary = Pose.sample(p)
	for i in 83:
		p.swing_elapsed = 0.34 * i / 82.0
		var pose: Dictionary = Pose.sample(p)
		validate_limbs(p, pose)
		expect(pose.front_hand.distance_to(previous.front_hand) < 7.0, "Full strike has continuous hand motion through coil, contact and recovery")
		expect(pose.hip.distance_to(previous.hip) < 1.5, "Strike never relocates athlete body to align the ball")
		previous = pose
	p.swing_elapsed = -1
	var after_swing: Dictionary = Pose.sample(p)
	expect(previous.front_hand.distance_to(after_swing.front_hand) < 0.01, "Strike finishes in the actual airborne recovery pose")
	for action in ["set", "receive", "block"]:
		p.reset(400)
		var start: Dictionary = Pose.sample(p)
		previous = start
		for i in 36:
			p.step(1.0 / 240.0, {action: true})
			var pose: Dictionary = Pose.sample(p)
			validate_limbs(p, pose)
			expect(pose.front_hand.distance_to(previous.front_hand) < 5.0, "%s preparation animates continuously" % action)
			previous = pose
		expect(previous.front_hand.distance_to(start.front_hand) > 16, "%s visibly changes arm configuration" % action)
	for direction in [-1.0, 1.0]:
		p.reset(400)
		p.velocity.x = direction * 600
		p.dive_timer = 0.32
		p.dive_elapsed = 0
		previous = Pose.sample(p)
		for i in range(1, 78):
			p.dive_elapsed = 0.32 * i / 77.0
			var pose: Dictionary = Pose.sample(p)
			validate_limbs(p, pose)
			expect(pose.front_hand.distance_to(previous.front_hand) < 5.0, "Dive extends continuously")
			previous = pose
		p.dive_timer = 0
		p.dive_elapsed = -1
		p.dive_recovery = 0.22
		var floor_pose: Dictionary = Pose.sample(p)
		expect(floor_pose.front_hand.distance_to(previous.front_hand) < 0.01, "Dive and recovery share the same floor pose")
		for i in range(1, 54):
			p.dive_recovery = 0.22 * (1.0 - float(i) / 53.0)
			var pose: Dictionary = Pose.sample(p)
			validate_limbs(p, pose)
			expect(pose.front_hand.distance_to(previous.front_hand) < 5.0, "Floor recovery raises hand continuously")
			expect(pose.front_knee.distance_to(previous.front_knee) < 5.0, "Floor recovery preserves knee bend without flipping IK branch")
			previous = pose

func check_contact_confirmation() -> void:
	var p = player()
	p.pos.y = 150
	p.swing_elapsed = 0.075
	var before: Dictionary = Pose.sample(p)
	p.confirm_hit(p.pos + before.front_hand)
	var after: Dictionary = Pose.sample(p)
	expect(before.front_hand.distance_to(after.front_hand) < 0.01, "Registering contact does not jump animation time or relocate the palm")

func validate_limbs(p, pose: Dictionary) -> void:
	sampled_poses += 1
	var scale_factor: float = p.config.height / 92.0
	for side in ["front", "back"]:
		var upper: float = pose[side + "_shoulder"].distance_to(pose[side + "_elbow"])
		var lower: float = pose[side + "_elbow"].distance_to(pose[side + "_hand"])
		var thigh: float = pose[side + "_hip"].distance_to(pose[side + "_knee"])
		var shin: float = pose[side + "_knee"].distance_to(pose[side + "_foot"])
		expect(absf(upper - Pose.UPPER_ARM * scale_factor) < 0.02 and absf(lower - Pose.FOREARM * scale_factor) < 0.02, "Arm proportions remain fixed through every action")
		expect(absf(thigh - Pose.THIGH * scale_factor) < 0.02 and absf(shin - Pose.SHIN * scale_factor) < 0.02, "Leg proportions remain fixed through every action")
		expect(pose[side + "_hand"].is_finite() and pose[side + "_foot"].is_finite(), "All sampled poses are finite")

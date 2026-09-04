extends Node
## Recorded CC0 court foley. Contacts, foot plants and crowd cues follow gameplay.
var enabled: bool = true:
	set(value):
		enabled = value
		if not value: stop_all()
var court_volume: float = 0.9
var crowd_volume: float = 0.22
var active: bool = false
var voices: Array = []
var samples: Dictionary = {}
var cursor: int = 0
var rng = RandomNumberGenerator.new()
var crowd = AudioStreamPlayer.new()
var reaction = AudioStreamPlayer.new()
var court_room = AudioStreamPlayer.new()
var foot_gate: float = 0
var hit_duck: float = 0

func _ready() -> void:
	rng.randomize()
	for i in range(12):
		var voice = AudioStreamPlayer2D.new()
		voice.max_distance = 2600
		voice.attenuation = 0.5
		add_child(voice)
		voices.append(voice)
	for kind in ["spike_hit", "spike_hit_1", "spike_hit_2", "serve_hit", "serve_hit_1", "block_hit", "block_hit_1", "receive_hit", "receive_hit_1", "set_hit", "set_hit_1", "floor_hit", "swing_whoosh", "squeak_0", "squeak_1", "squeak_2", "squeak_3", "land", "slide"]:
		samples[kind] = load("res://assets/audio/%s.wav" % kind)
	var room = load("res://assets/audio/court_ambience.wav").duplicate()
	room.loop_mode = AudioStreamWAV.LOOP_FORWARD
	room.loop_begin = 0
	room.loop_end = int(room.get_length() * room.mix_rate)
	court_room.stream = room
	court_room.volume_db = -60
	add_child(court_room)
	var swell = load("res://assets/audio/crowd_swell.wav").duplicate()
	swell.loop_mode = AudioStreamWAV.LOOP_FORWARD
	swell.loop_begin = 0
	swell.loop_end = int(swell.get_length() * swell.mix_rate)
	crowd.stream = swell
	crowd.volume_db = -60
	add_child(crowd)
	reaction.stream = preload("res://assets/audio/crowd_release.wav")
	add_child(reaction)

func stop_all() -> void:
	for voice in voices: voice.stop()
	court_room.stop()
	crowd.stop()
	reaction.stop()
	hit_duck = 0
	foot_gate = 0

func set_active(value: bool) -> void:
	if active == value: return
	active = value
	if not active: stop_all()

func update(game, dt: float) -> void:
	foot_gate = maxf(0, foot_gate - dt)
	hit_duck = maxf(0, hit_duck - dt)
	if not enabled or not active: return
	if court_volume > 0:
		if not court_room.playing: court_room.play()
		var room_target = -33 + linear_to_db(maxf(court_volume, 0.001)) - (5 if hit_duck > 0 else 0)
		court_room.volume_db = move_toward(court_room.volume_db, room_target, dt * 28)
	elif court_room.playing:
		court_room.stop()
	var anticipating = game.phase in ["serve_aim", "serve_windup", "serve_toss"]
	if anticipating and crowd_volume > 0:
		if not crowd.playing:
			crowd.volume_db = -42
			crowd.play()
		var build = game.serve_charge
		if game.phase == "serve_toss":
			build = clampf(0.5 + game.phase_time * 0.55, 0, 1)
		var target_db = lerpf(-34, -22, build) + linear_to_db(maxf(crowd_volume, 0.001))
		crowd.volume_db = move_toward(crowd.volume_db, target_db, dt * 25)
		crowd.pitch_scale = lerpf(0.94, 1.04, build)
	elif crowd.playing:
		crowd.volume_db = move_toward(crowd.volume_db, -60, dt * 130)
		if crowd.volume_db <= -59: crowd.stop()
	reaction.volume_db = -18 + linear_to_db(maxf(crowd_volume, 0.001)) - (9 if hit_duck > 0 else 0)
	if crowd_volume <= 0:
		crowd.stop()
		reaction.stop()

func play(event: Dictionary) -> void:
	if not enabled or not active or voices.is_empty(): return
	var kind: String = event.kind
	var pitch: float = rng.randf_range(0.97, 1.03)
	var quality: float = float(event.get("quality", 0.62))
	match kind:
		"spike":
			play_sample("spike_hit" if rng.randi_range(0, 2) == 0 else "spike_hit_%d" % rng.randi_range(1, 2), lerpf(-6.5, -0.3, quality), pitch * lerpf(0.985, 1.025, quality), event)
			hit_duck = 0.16
			return
		"serve":
			play_sample("serve_hit" if rng.randi_range(0, 1) == 0 else "serve_hit_1", lerpf(-7.0, -0.8, quality), pitch * lerpf(0.98, 1.02, quality), event)
			hit_duck = 0.16
			if crowd_volume > 0:
				crowd.stop()
				reaction.volume_db = -24 + linear_to_db(maxf(crowd_volume, 0.001))
				reaction.play()
			return
		"block":
			play_sample("block_hit" if rng.randi_range(0, 1) == 0 else "block_hit_1", lerpf(-7.5, -1.0, quality), pitch * lerpf(0.96, 1.01, quality), event)
			return
		"receive", "free", "dive": play_sample("receive_hit" if rng.randi_range(0, 1) == 0 else "receive_hit_1", -8.0, pitch, event); return
		"set": play_sample("set_hit" if rng.randi_range(0, 1) == 0 else "set_hit_1", -11.0, pitch, event); return
		"floor": play_sample("floor_hit", -4.0, pitch, event); return
		"net": play_sample("receive_hit", -20.0, pitch * 0.68, event); return
		"swing": play_sample("swing_whoosh", -13.0, pitch, event); return
		"plant", "skid": play_sample("squeak_%d" % rng.randi_range(0, 3), -18.0, pitch, event); return
		"takeoff":
			if event.player == 0: play_sample("squeak_%d" % rng.randi_range(0, 3), -26.0, pitch, event)
			return
		"land": play_sample("land", -16.0, pitch, event); return
		"slide": play_sample("slide", -20.0, pitch, event); return
		"step":
			if foot_gate > 0 or event.player != 0 or rng.randf() > 0.22: return
			foot_gate = 0.16
			play_sample("squeak_%d" % rng.randi_range(0, 3), -25.0, pitch, event)


func play_sample(sample: String, gain: float, pitch: float, event: Dictionary) -> void:
	if not samples.has(sample) or court_volume <= 0: return
	var voice = voices[cursor % voices.size()]
	cursor += 1
	voice.stream = samples[sample]
	voice.position = Vector2(event.position.x, -event.position.y)
	voice.pitch_scale = pitch
	var kind: String = event.kind
	var background = 0 if event.player == 0 or kind in ["spike", "serve", "block", "floor"] else -3
	voice.volume_db = gain + background + linear_to_db(maxf(court_volume, 0.001))
	voice.play()

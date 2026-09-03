extends SceneTree
const MatchModel = preload("res://scripts/match_model.gd")
const Audio = preload("res://scripts/audio_feedback.gd")
var failures: Array = []

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func run() -> void:
	var sound = Audio.new()
	root.add_child(sound)
	var game = MatchModel.new()
	sound.set_active(true)
	game.phase = "serve_aim"
	sound.update(game, 0.1)
	expect(sound.crowd.playing, "Aiming starts the crowd swell")
	sound.play({"kind": "toss", "position": game.ball, "player": 0})
	expect(sound.cursor == 0, "A toss does not produce a hit sound")
	game.phase = "rally"
	sound.play({"kind": "serve", "position": game.ball, "player": 0})
	expect(sound.cursor == 1 and sound.reaction.playing and not sound.crowd.playing, "Real serve contact triggers one hit and releases the crowd")
	sound.set_active(false)
	expect(not sound.reaction.playing and not sound.voices[0].playing, "Pause stops court and crowd voices")
	sound.set_active(true)
	game.phase = "serve_aim"
	sound.update(game, 0.1)
	sound.enabled = false
	expect(not sound.crowd.playing, "Disabling sound immediately stops a held crowd loop")
	sound.enabled = true
	sound.crowd_volume = 0
	sound.update(game, 0.1)
	expect(not sound.crowd.playing, "Zero crowd volume prevents the loop")
	for sample in sound.samples.values():
		expect(sample is AudioStreamWAV and sample.get_length() > 0.1, "Recorded court samples load")
	sound.stop_all()
	sound.queue_free()
	await create_timer(0.15).timeout
	for failure in failures: printerr("FAIL: ", failure)
	if failures.is_empty(): print("PASS: recorded foley, contact cues, crowd transition, pause and mute")
	quit(0 if failures.is_empty() else 1)

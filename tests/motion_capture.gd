extends SceneTree
## Deterministic real-scene movie: keyboard carry/run, throw, then full AI rallies.
## --write-movie /absolute/clip.avi --fixed-fps 60 -- --mute
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.sound.enabled = false
	main.force_mute = true
	main.set_physics_process(false)
	main.set_process(false)
	main.start_match()
	main.autoplay = false
	for frame in range(900):
		var time = frame / 60.0
		if time < 1.5:
			Input.action_release("left")
			Input.action_release("right")
			Input.action_release("block")
			if time < 0.38: Input.action_press("left")
			elif time < 1.35: Input.action_press("right")
			if time >= 0.34 and time < 1.12: Input.action_press("block")
		else:
			Input.action_release("right")
			Input.action_release("block")
			main.autoplay = true
		for tick in range(2): main._physics_process(1.0/120.0)
		main._process(1.0/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
	print("MOTION CAPTURE: ", main.game.metrics, " score=",main.game.score)
	quit()

extends SceneTree
## Silent, deterministic native visual QA of the real scene at its key poses.
var main
var destination: String

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-output="): destination = arg.trim_prefix("--visual-output=")
	run.call_deferred()

func capture(name: String) -> void:
	main.court.queue_redraw()
	main.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png(destination.path_join(name + ".png"))
	assert(result == OK)

func run() -> void:
	if destination.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(destination)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.sound.enabled = false
	main.force_mute = true
	main.set_physics_process(false)
	for i in range(5): await process_frame
	await capture("title")
	main.start_match()
	var seen = {}
	for frame in range(630):
		main.game.step(1.0 / 120.0, {}, true)
		for event in main.game.events:
			main.court.add_event(event)
		main.court.advance(1.0 / 120.0)
		main.update_camera(1.0 / 120.0)
		var p = main.game.players[0]
		var stage = ""
		if main.game.phase == "serve_aim" and main.game.phase_time > 0.4: stage = "aim"
		elif main.game.phase == "serve_windup" and main.game.phase_time > 0.18: stage = "toss"
		elif p.jump_prepare > 0 and p.jump_prepare < 0.05: stage = "plant"
		elif p.pos.y > 160 and p.swing_elapsed < 0: stage = "jump"
		elif p.swing_connected and p.swing_elapsed < 0.14: stage = "contact"
		elif p.swing_connected and p.swing_elapsed > 0.22: stage = "follow"
		if not stage.is_empty() and not seen.has(stage):
			seen[stage] = true
			await capture(stage)
	main.game.phase = "rally"
	var diver = main.game.players[0]
	diver.reset(500)
	diver.dive_timer = 0.3
	diver.velocity = Vector2(760, 0)
	await capture("dive")
	diver.reset(diver.home_x)
	var blocker = main.game.players[2]
	blocker.reset(940)
	blocker.pos.y = 150
	blocker.blocking = true
	main.game.ball = blocker.contact_center("block") + Vector2(12, 2)
	main.game.ball_velocity = Vector2(1150, -380)
	main.court.effects.clear()
	main.court.trail.clear()
	main.court.add_event({"kind": "block", "position": main.game.ball, "player": blocker.id})
	await capture("block")
	main.show_settings()
	for i in range(5): await process_frame
	await capture("settings")
	main.menu_scroll.scroll_vertical = 1000
	for i in range(3): await process_frame
	await capture("settings-bottom")
	print("VISUAL CAPTURES ", seen.keys())
	quit()

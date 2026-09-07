extends Node2D
const MatchModel = preload("res://scripts/match_model.gd")
const Court = preload("res://scripts/court_view.gd")
const HUD = preload("res://scripts/hud.gd")
const Audio = preload("res://scripts/audio_feedback.gd")
const DEFAULT_KEYS = {"left": KEY_A, "right": KEY_D, "jump": KEY_Z, "receive": KEY_SPACE, "block": KEY_X, "dive": KEY_C, "toss_raise": KEY_W, "toss_lower": KEY_S}
const ACTION_NAMES = {"left": "Move left", "right": "Move right", "jump": "Jump / air swing", "receive": "Receive / pass", "block": "Block / hold to charge toss", "dive": "Slide / dive", "toss_raise": "Raise toss arc", "toss_lower": "Lower toss arc"}

var game = MatchModel.new()
var court = Court.new()
var camera = Camera2D.new()
var hud = HUD.new()
var sound = Audio.new()
var ui: Control
var overlay: Control
var menu_panel: PanelContainer
var menu_content: VBoxContainer
var menu_scroll: ScrollContainer
var force_mute: bool = false
var pause_button: Button
var keys: Dictionary = DEFAULT_KEYS.duplicate()
var sound_on: bool = true
var effects_on: bool = true
var guide_on: bool = true
var mode: String = "title"
var settings_return: String = "title"
var rebind_action: String = ""
var rebind_buttons: Dictionary = {}
var shake: float = 0.0
var impact_hold: float = 0.0
var impact_zoom: float = 0.0
var impact_tilt: float = 0.0
var pending_jump: bool = false
var pending_dive: bool = false
var autoplay: bool = false
var capture_path: String = ""
var capture_time: float = 8.4
var capture_title: bool = false
var run_elapsed: float = 0.0
var capturing: bool = false
var quit_after_seconds: float = -1

func _ready() -> void:
	load_settings()
	install_inputs()
	court.game = game
	add_child(court)
	add_child(camera)
	camera.position = Vector2(1000, -340)
	camera.zoom = Vector2.ONE * 0.62
	add_child(sound)
	sound.enabled = sound_on
	var canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	hud.game = game
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(hud)
	pause_button = make_button("PAUSE  ·  ESC", func(): pause_match())
	pause_button.custom_minimum_size = Vector2(136, 38)
	ui.add_child(pause_button)
	build_overlay()
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay": autoplay = true
		elif arg == "--mute": force_mute = true
		elif arg == "--capture-title": capture_title = true
		elif arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-at="): capture_time = float(arg.trim_prefix("--capture-at="))
		elif arg.begins_with("--quit-after-seconds="): quit_after_seconds = float(arg.trim_prefix("--quit-after-seconds="))
	sound.enabled = sound_on and not force_mute
	hud.autoplay = autoplay
	show_title()
	if autoplay and not capture_title:
		start_match()
	get_viewport().size_changed.connect(layout_ui)
	layout_ui()
	if capture_title:
		capture_time = 0.6

func install_inputs() -> void:
	for action in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	# Arrow keys mirror horizontal movement and vertical toss aiming unless one
	# has been explicitly assigned to another action.
	var secondary = {"left": KEY_LEFT, "right": KEY_RIGHT, "toss_raise": KEY_UP, "toss_lower": KEY_DOWN}
	for action in secondary:
		var arrow = secondary[action]
		if not keys.values().has(arrow):
			var event = InputEventKey.new()
			event.physical_keycode = arrow
			InputMap.action_add_event(action, event)
	for action in keys:
		hud.key_names[action] = key_label(keys[action])

func key_label(code: int) -> String:
	return "SPACE" if code == KEY_SPACE else OS.get_keycode_string(code).to_upper()

func _physics_process(dt: float) -> void:
	if mode != "playing":
		return
	# Input edges keep arriving during impact freeze. Retain taps until the
	# first simulated frame, even when the key was released during the hold.
	pending_jump = pending_jump or Input.is_action_just_pressed("jump")
	pending_dive = pending_dive or Input.is_action_just_pressed("dive")
	if impact_hold > 0:
		impact_hold = maxf(0, impact_hold - dt)
		sound.update(game, dt)
		return
	var intent = {
		"move": Input.get_axis("left", "right"),
		"jump": pending_jump,
		"receive": Input.is_action_pressed("receive"),
		"block": Input.is_action_pressed("block"),
		"toss": Input.is_action_pressed("block"),
		"aim_height": Input.get_axis("toss_lower", "toss_raise"),
		"dive": pending_dive
	}
	pending_jump = false
	pending_dive = false
	sound.set_active(true)
	game.step(dt, intent, autoplay)
	for event in game.events:
		court.add_event(event)
		sound.play(event)
		var contact_velocity: Vector2 = event.get("velocity", game.ball_velocity)
		if event.kind in ["spike", "serve"]:
			var quality = float(event.get("quality", 0.62))
			shake = lerpf(7.0, 16.0, quality) if effects_on else 0.0
			impact_hold = lerpf(0.028, 0.068, quality) if effects_on else 0.0
			impact_zoom = lerpf(0.025, 0.070, quality) if effects_on else 0.0
			impact_tilt = -signf(contact_velocity.x) * lerpf(0.004, 0.016, quality) if effects_on else 0.0
		elif event.kind == "block":
			var quality = float(event.get("quality", 0.62))
			shake = lerpf(8.0, 18.0, quality) if effects_on else 0.0
			impact_hold = lerpf(0.032, 0.074, quality) if effects_on else 0.0
			impact_zoom = lerpf(0.030, 0.075, quality) if effects_on else 0.0
			impact_tilt = -signf(contact_velocity.x) * lerpf(0.005, 0.018, quality) if effects_on else 0.0
	sound.update(game, dt)
	if game.phase == "finished":
		show_result()

func _process(dt: float) -> void:
	run_elapsed += dt
	if mode != "playing": sound.set_active(false)
	if overlay.visible:
		menu_scroll.custom_minimum_size.y = minf(menu_content.get_combined_minimum_size().y, get_viewport_rect().size.y - 100)
	court.landing_guide = guide_on
	if mode == "playing":
		court.advance(dt)
	else:
		court.queue_redraw()
	update_camera(dt)
	hud.mode = mode
	hud.queue_redraw()
	pause_button.visible = mode == "playing"
	if not capture_path.is_empty() and not capturing and run_elapsed >= capture_time:
		capturing = true
		capture_frame()
	if quit_after_seconds > 0 and run_elapsed >= quit_after_seconds:
		get_tree().quit()

func update_camera(dt: float) -> void:
	var viewport_size = get_viewport_rect().size
	var player_x = game.players[game.human_id].pos.x
	var lo = minf(player_x, minf(game.ball.x, 850)) - 210
	var hi = maxf(player_x, maxf(game.ball.x, 1150)) + 210
	# Normal play in The Spike reads as a wide court composition. High sets and
	# serves pull wider still; impacts never enlarge the athletes.
	var span = clampf(hi - lo, 2020, 2700)
	var top = maxf(610, game.ball.y + 105)
	if game.phase in ["serve_aim", "serve_windup", "serve_toss"]: top = maxf(top, game.toss_height + 85)
	var target_zoom = clampf(minf(viewport_size.x / span, viewport_size.y * 0.74 / top), 0.40, 0.66)
	var target_x = clampf((lo + hi) * 0.5, 260, 1740)
	if mode == "playing" and game.phase == "rally":
		target_x += clampf(game.ball_velocity.x * 0.05, -95, 95)
	if mode == "title":
		target_zoom = minf(viewport_size.x / 2180, viewport_size.y / 960)
		target_x = 1000
	# A contact reveals more of the flight path for a few frames instead of
	# punching into the hitter and changing the player-to-court ratio.
	target_zoom *= 1.0 - impact_zoom
	var target_y = -viewport_size.y * 0.26 / target_zoom
	if mode == "playing" and game.phase == "rally":
		target_y -= clampf(game.ball_velocity.y * 0.035, -38, 38)
	var tracking_rate = 8.0 + clampf(game.ball_velocity.length() / 180.0, 0, 10.0) if mode == "playing" else 4.2
	var speed = 1.0 - exp(-dt * tracking_rate)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, speed)
	camera.position = camera.position.lerp(Vector2(target_x, target_y), speed)
	shake = maxf(0, shake - dt * 46)
	impact_zoom = maxf(0, impact_zoom - dt * 2.8)
	impact_tilt = move_toward(impact_tilt, 0.0, dt * 0.12)
	camera.rotation = lerpf(camera.rotation, impact_tilt, 1.0 - exp(-dt * 15.0))
	camera.offset = Vector2(sin(run_elapsed * 137), cos(run_elapsed * 111)) * shake

func _input(event: InputEvent) -> void:
	# Event capture also preserves a complete press/release between physics
	# ticks. Polling above supports programmatic actions and keyboard holds.
	if mode == "playing":
		if event.is_action_pressed("jump"): pending_jump = true
		if event.is_action_pressed("dive"): pending_dive = true
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not rebind_action.is_empty():
		if event.keycode == KEY_ESCAPE:
			rebind_action = ""
			show_settings()
		elif event.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_F11] and event.physical_keycode > 0:
			var chosen = int(event.physical_keycode)
			var old = keys[rebind_action]
			for action in keys:
				if keys[action] == chosen:
					keys[action] = old
			keys[rebind_action] = chosen
			rebind_action = ""
			install_inputs()
			save_settings()
			show_settings()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		if mode == "playing": pause_match()
		elif mode == "paused": resume_match()
		elif mode == "settings": leave_settings()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F11:
		toggle_fullscreen()

func styled_panel(color: Color, border: Color = Color("30475a")) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 27
	style.content_margin_bottom = 27
	return style

func make_button(label: String, action: Callable, primary: bool = false) -> Button:
	var button = Button.new()
	button.text = label
	button.custom_minimum_size.y = 43
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("13283b") if primary else Color("e9f4ef"))
	button.add_theme_color_override("font_hover_color", Color("13283b") if primary else Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("13283b") if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("13283b") if primary else Color.WHITE)
	var base = Color("8bcffc") if primary else Color("1b3045")
	for state in ["normal", "hover", "pressed", "focus"]:
		var style = styled_panel(base.lightened(0.09) if state == "hover" else base, Color("89cffa") if state == "focus" else Color("385469"))
		style.set_corner_radius_all(9)
		style.content_margin_left = 15
		style.content_margin_right = 15
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button

func build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var tint = ColorRect.new()
	tint.color = Color(0.025, 0.06, 0.105, 0.58)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(tint)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size.x = 510
	menu_panel.add_theme_stylebox_override("panel", styled_panel(Color(0.055, 0.10, 0.17, 0.98)))
	center.add_child(menu_panel)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu_panel.add_child(menu_scroll)
	menu_content = VBoxContainer.new()
	menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_content.add_theme_constant_override("separation", 13)
	menu_scroll.add_child(menu_content)

func clear_menu() -> void:
	for child in menu_content.get_children():
		menu_content.remove_child(child)
		child.queue_free()
	overlay.show()
	rebind_buttons.clear()

func add_label(value: String, px: int, color: Color = Color("eef5ee")) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	menu_content.add_child(label)
	return label

func add_menu_button(label: String, action: Callable, primary: bool = false) -> Button:
	var button = make_button(label, action, primary)
	menu_content.add_child(button)
	return button

func show_title() -> void:
	mode = "title"
	clear_menu()
	add_label("COURT 01  /  ATHLETE BUILD", 11, Color("91b7c9"))
	add_label("SIDEOUT", 50)
	add_label("Toss. Approach. Jump. Connect.", 17, Color("b6cbd3"))
	add_label("You play wing spiker. Your setter and blocker play\nautomatically. Beat the opposing trio to 15, win by 2.", 13, Color("8faaba"))
	var start = add_menu_button("PLAY MATCH", start_match, true)
	add_menu_button("Controls & settings", func(): settings_return = "title"; show_settings())
	add_label("%s / %s  Move     %s  Jump, then spike     %s  Receive\n%s  Block     %s  Dive     ESC  Pause" % [key_label(keys.left), key_label(keys.right), key_label(keys.jump), key_label(keys.receive), key_label(keys.block), key_label(keys.dive)], 12, Color("a3bec9"))
	add_label("Serve: move while holding %s to charge, then release. Jump and hit with %s." % [key_label(keys.block), key_label(keys.jump)], 12, Color("a3bec9"))
	add_menu_button("Quit", func(): get_tree().quit())
	start.grab_focus.call_deferred()

func start_match() -> void:
	sound.stop_all()
	pending_jump = false
	pending_dive = false
	impact_hold = 0
	impact_zoom = 0
	impact_tilt = 0
	shake = 0
	camera.rotation = 0
	game.reset()
	court.trail.clear()
	court.effects.clear()
	court.shot_labels.clear()
	mode = "playing"
	overlay.hide()

func pause_match() -> void:
	if mode != "playing": return
	pending_jump = false
	pending_dive = false
	mode = "paused"
	sound.set_active(false)
	clear_menu()
	add_label("TAKE A BREATHER", 11, Color("91b7c9"))
	add_label("Match paused", 32)
	add_label("NORTH  %d : %d  SOUTH" % game.score, 17, Color("b6cbd3"))
	var resume = add_menu_button("Resume match", resume_match, true)
	add_menu_button("Controls & settings", func(): settings_return = "paused"; show_settings())
	add_menu_button("Restart match", start_match)
	add_menu_button("Main menu", show_title)
	resume.grab_focus.call_deferred()

func resume_match() -> void:
	mode = "playing"
	overlay.hide()

func show_result() -> void:
	mode = "result"
	clear_menu()
	var won = game.score[0] > game.score[1]
	add_label("FULL TIME  /  COURT 01", 11, Color("91b7c9"))
	add_label("Your match." if won else "Next ball. Next match.", 31, Color("8bcffc") if won else Color("ffb063"))
	add_label("NORTH  %d : %d  SOUTH" % game.score, 28)
	add_label("Longest rally: %d contacts\n%d spikes  ·  %d blocks  ·  %d sets" % [game.longest_rally, game.metrics.spike, game.metrics.block, game.metrics.set], 14, Color("a3bec9"))
	var again = add_menu_button("Play again", start_match, true)
	add_menu_button("Main menu", show_title)
	again.grab_focus.call_deferred()

func show_settings() -> void:
	mode = "settings"
	clear_menu()
	add_label("MAKE YOURSELF AT HOME", 10, Color("91b7c9"))
	add_label("Controls & settings", 28)
	add_label("Click a key to change it. ESC cancels.\nJump once, then press again in the air to spike.", 12, Color("a3bec9"))
	for action in DEFAULT_KEYS:
		var row = HBoxContainer.new()
		menu_content.add_child(row)
		var label = Label.new()
		label.text = ACTION_NAMES[action]
		label.add_theme_font_size_override("font_size", 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button = make_button(key_label(keys[action]), func(): rebind_action = action; rebind_buttons[action].text = "PRESS A KEY…")
		button.custom_minimum_size = Vector2(145, 33)
		row.add_child(button)
		rebind_buttons[action] = button
	var toggles = HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 12)
	menu_content.add_child(toggles)
	for setting in ["Sound", "Impact effects", "Landing guide"]:
		var check = CheckButton.new()
		check.text = setting
		check.add_theme_font_size_override("font_size", 12)
		check.button_pressed = sound_on if setting == "Sound" else effects_on if setting == "Impact effects" else guide_on
		check.toggled.connect(func(value):
			if setting == "Sound": sound_on = value; sound.enabled = value and not force_mute
			elif setting == "Impact effects": effects_on = value
			else: guide_on = value
			save_settings())
		toggles.add_child(check)
	for audio_kind in ["Court", "Crowd"]:
		var row = HBoxContainer.new()
		menu_content.add_child(row)
		var label = Label.new()
		label.text = audio_kind + " volume"
		label.custom_minimum_size.x = 120
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = sound.court_volume if audio_kind == "Court" else sound.crowd_volume
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value):
			if audio_kind == "Court": sound.court_volume = value
			else: sound.crowd_volume = value
			save_settings())
		row.add_child(slider)
	var display_row = HBoxContainer.new()
	menu_content.add_child(display_row)
	var display_button = make_button("Window / fullscreen · F11", toggle_fullscreen)
	display_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_row.add_child(display_button)
	var defaults = make_button("Reset keys", func(): keys = DEFAULT_KEYS.duplicate(); install_inputs(); save_settings(); show_settings())
	display_row.add_child(defaults)
	var back = add_menu_button("Back", leave_settings, true)
	back.grab_focus.call_deferred()

func leave_settings() -> void:
	rebind_action = ""
	if settings_return == "paused":
		mode = "playing"
		pause_match()
	else:
		show_title()

func toggle_fullscreen() -> void:
	var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	save_settings()

func layout_ui() -> void:
	pause_button.position = Vector2(get_viewport_rect().size.x - 167, 31)

func load_settings() -> void:
	var settings = ConfigFile.new()
	if settings.load("user://settings.cfg") != OK:
		return
	for action in DEFAULT_KEYS:
		var code = settings.get_value("keys", action, DEFAULT_KEYS[action])
		if typeof(code) == TYPE_INT and code > 0:
			keys[action] = code
	var mix_version = int(settings.get_value("audio", "mix_version", 1))
	if mix_version < 2:
		# Version 2 replaces the old noisy contacts and moves the crowd behind
		# the ball. Do not carry the obsolete balance into the new mix.
		sound.court_volume = 0.9
		sound.crowd_volume = 0.22
	else:
		sound.court_volume = clampf(settings.get_value("audio", "court_volume", 0.9), 0, 1)
		sound.crowd_volume = clampf(settings.get_value("audio", "crowd_volume", 0.22), 0, 1)
	sound_on = settings.get_value("game", "sound", true)
	effects_on = settings.get_value("game", "effects", true)
	guide_on = settings.get_value("game", "guide", true)
	if settings.get_value("game", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func save_settings() -> void:
	var settings = ConfigFile.new()
	for action in keys:
		settings.set_value("keys", action, keys[action])
	settings.set_value("audio", "court_volume", sound.court_volume)
	settings.set_value("audio", "crowd_volume", sound.crowd_volume)
	settings.set_value("audio", "mix_version", 2)
	settings.set_value("game", "sound", sound_on)
	settings.set_value("game", "effects", effects_on)
	settings.set_value("game", "guide", guide_on)
	settings.set_value("game", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	settings.save("user://settings.cfg")

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var result = image.save_png(capture_path)
	print("CAPTURE ", capture_path, " result=", result, " score=", game.score, " phase=", game.phase)
	get_tree().quit(0 if result == OK else 1)

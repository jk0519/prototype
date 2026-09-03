extends Node2D
const MatchModel = preload("res://scripts/match_model.gd")
const Court = preload("res://scripts/court_view.gd")
const HUD = preload("res://scripts/hud.gd")
const Audio = preload("res://scripts/audio_feedback.gd")
const DEFAULT_KEYS = {"left": KEY_A, "right": KEY_D, "jump": KEY_Z, "receive": KEY_SPACE, "block": KEY_X, "dive": KEY_C}
const ACTION_NAMES = {"left": "Move left", "right": "Move right", "jump": "Jump / spike / serve", "receive": "Receive / pass", "block": "Block", "dive": "Slide / dive"}

var game = MatchModel.new()
var court = Court.new()
var camera = Camera2D.new()
var hud = HUD.new()
var sound = Audio.new()
var ui: Control
var overlay: Control
var menu_panel: PanelContainer
var menu_content: VBoxContainer
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
		elif arg == "--capture-title": capture_title = true
		elif arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-at="): capture_time = float(arg.trim_prefix("--capture-at="))
		elif arg.begins_with("--quit-after-seconds="): quit_after_seconds = float(arg.trim_prefix("--quit-after-seconds="))
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
	# Arrow keys are a second movement option, unless explicitly rebound elsewhere.
	for action in ["left", "right"]:
		var arrow = KEY_LEFT if action == "left" else KEY_RIGHT
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
	var intent = {
		"move": Input.get_axis("left", "right"),
		"jump": Input.is_action_just_pressed("jump"),
		"receive": Input.is_action_pressed("receive"),
		"block": Input.is_action_pressed("block"),
		"dive": Input.is_action_just_pressed("dive")
	}
	game.step(dt, intent, autoplay)
	for event in game.events:
		court.add_event(event)
		sound.play(event.kind)
		if event.kind in ["spike", "block"]:
			shake = 2.0 if effects_on else 0.0
	if game.phase == "finished":
		show_result()

func _process(dt: float) -> void:
	run_elapsed += dt
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
	var lo = minf(player_x, minf(game.ball.x, 900)) - 190
	var hi = maxf(player_x, maxf(game.ball.x, 1100)) + 190
	var span = clampf(hi - lo, 1510, 2140)
	var target_zoom = minf(viewport_size.x / span, viewport_size.y / 790.0)
	var target_x = clampf((lo + hi) * 0.5, 840, 1160)
	if mode == "title":
		target_zoom = minf(viewport_size.x / 2120, viewport_size.y / 920)
		target_x = 1000
	var target_y = -viewport_size.y * 0.29 / target_zoom - maxf(game.ball.y - 570, 0) * 0.2
	var speed = 1.0 - exp(-dt * 4.2)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, speed)
	camera.position = camera.position.lerp(Vector2(target_x, target_y), speed)
	shake = maxf(0, shake - dt * 15)
	camera.offset = Vector2(sin(run_elapsed * 105), cos(run_elapsed * 90)) * shake

func _input(event: InputEvent) -> void:
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
	menu_content = VBoxContainer.new()
	menu_content.add_theme_constant_override("separation", 13)
	menu_panel.add_child(menu_content)

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
	add_label("COURT 01  /  FIRST PLAYABLE", 11, Color("91b7c9"))
	add_label("SIDEOUT", 50)
	add_label("Find your approach. Time your spike.", 17, Color("b6cbd3"))
	add_label("You play wing spiker. Your setter and blocker play\nautomatically. Beat the opposing trio to 15, win by 2.", 13, Color("8faaba"))
	var start = add_menu_button("PLAY MATCH", start_match, true)
	add_menu_button("Controls & settings", func(): settings_return = "title"; show_settings())
	add_label("%s / %s  Move     %s  Jump, then spike     %s  Receive\n%s  Block     %s  Dive     ESC  Pause" % [key_label(keys.left), key_label(keys.right), key_label(keys.jump), key_label(keys.receive), key_label(keys.block), key_label(keys.dive)], 12, Color("a3bec9"))
	add_menu_button("Quit", func(): get_tree().quit())
	start.grab_focus.call_deferred()

func start_match() -> void:
	game.reset()
	court.trail.clear()
	court.effects.clear()
	mode = "playing"
	overlay.hide()

func pause_match() -> void:
	if mode != "playing": return
	mode = "paused"
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
			if setting == "Sound": sound_on = value; sound.enabled = value
			elif setting == "Impact effects": effects_on = value
			else: guide_on = value
			save_settings())
		toggles.add_child(check)
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
	sound_on = settings.get_value("game", "sound", true)
	effects_on = settings.get_value("game", "effects", true)
	guide_on = settings.get_value("game", "guide", true)
	if settings.get_value("game", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func save_settings() -> void:
	var settings = ConfigFile.new()
	for action in keys:
		settings.set_value("keys", action, keys[action])
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

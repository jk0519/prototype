extends RefCounted
## Small role rules. Bots move and contact the ball through the same athlete model
## as the human. They cannot teleport or hit a ball from outside its contact area.

func intentions(game, all_ai: bool) -> Array:
	var result: Array = []
	for p in game.players:
		result.append({"move": toward(p, p.home_x)})
	if game.phase in ["serve_ready", "serve_aim", "serve_windup", "serve_toss"]:
		for p in game.players: result[p.id] = {}
		var server = game.players[game.server_id]
		if game.phase == "serve_ready":
			result[server.id] = {"toss": game.phase_time > 0.55}
		elif game.phase == "serve_aim":
			result[server.id] = {"toss": game.phase_time < 0.42}
		elif game.phase == "serve_toss":
			var t = game.time_to_height(300)
			var target = game.ball.x + game.ball_velocity.x * t - server.facing * 38
			# The setter has a lower jump arc, so delaying its plant keeps its hand
			# aligned with the descending toss. Every role still serves physically.
			var jump_lead = 0.54 if server.role == "SET" else 0.59
			result[server.id] = {"move": toward(server, target), "jump": server.pos.y <= 0.01 and t < jump_lead, "swing": should_swing(game, server)}
		return result
	if game.phase != "rally":
		return result

	for side in range(2):
		var time_low = game.time_to_height(78.0)
		var landing = game.ball.x + game.ball_velocity.x * time_low
		var incoming = (landing < 1000.0) == (side == 0)
		var our_half = (game.ball.x < 1000.0) == (side == 0)
		var our_possession = game.last_team == side and game.touches > 0 and game.last_action != "serve"
		if our_possession and game.touches == 1:
			var setter_id = game.setter_for(side)
			var setter = game.players[setter_id]
			var t = game.time_to_height(setter.config.height + 15)
			var x = game.ball.x + game.ball_velocity.x * t
			result[setter_id] = {"move": toward(setter, x), "set": true}
			# Give the wing an approach while the pass travels toward the setter.
			var wing = game.players[side * 3]
			result[wing.id] = {"move": toward(wing, game.attack_x(side) - wing.facing * 100)}
		elif our_possession and game.touches == 2:
			var hitter = game.players[side * 3]
			var t = game.time_to_height(300)
			var target_x = game.ball.x + game.ball_velocity.x * t - hitter.facing * 40 + game.ai_error_x[hitter.id] * 0.48
			var intent = {"move": toward(hitter, target_x)}
			if hitter.pos.y <= 0.01 and t <= 0.57 + game.ai_jump_error[hitter.id] and game.ball.y > 220:
				intent["jump"] = true
			if should_swing(game, hitter):
				intent["swing"] = true
			# An unhittable low set is returned as a free ball.
			if game.ball.y < 155 and game.ball_velocity.y < 0:
				intent["receive"] = true
			result[hitter.id] = intent
		elif incoming and not our_possession:
			var receiver_id = -1
			var best = INF
			for p in game.players:
				if p.team != side or (p.id == game.human_id and not all_ai):
					continue
				var cost = absf(p.pos.x - landing) / p.config.run_speed
				# Prefer keeping the setter available for the second touch.
				if p.role == "SET":
					cost += 0.14
				if cost < best:
					best = cost
					receiver_id = p.id
			if receiver_id >= 0 and landing > 175 and landing < 1825:
				var receiver = game.players[receiver_id]
				var intent = {"move": toward(receiver, landing - receiver.facing * 24 + game.ai_error_x[receiver.id] * (0.45 if game.last_action == "serve" else 1.0)), "receive": true}
				if our_half and time_low < 0.18 and absf(receiver.pos.x - landing) > 75:
					intent["dive"] = true
				result[receiver_id] = intent
		# The middle follows the opposing attacker along the net and blocks.
		var middle = game.players[side * 3 + 2]
		if game.last_team == 1 - side and game.last_action == "set" and game.ai_block_attempt[side]:
			var t = game.time_to_height(300)
			var x = game.ball.x + game.ball_velocity.x * t
			if absf(x - 1000.0) < 330:
				result[middle.id] = {"move": toward(middle, 947 if side == 0 else 1053), "block": t < 0.60 + game.ai_jump_error[middle.id]}
		elif middle.pos.y > 0 and middle.blocking:
			result[middle.id]["block"] = true
	return result

func toward(player, target_x: float) -> float:
	var dx = target_x - player.pos.x
	return clampf(dx / 24.0, -1.0, 1.0) if absf(dx) > 4 else 0.0

func should_swing(game, player) -> bool:
	if player.pos.y < 55 or player.swing_cooldown > 0: return false
	var anticipation = 0.04
	var future_ball = game.ball + game.ball_velocity * anticipation - Vector2(0, 0.5 * game.BALL_GRAVITY * anticipation * anticipation)
	var future_hand = player.pos + player.velocity * anticipation + Vector2(player.facing * 28, player.config.reach - 0.5 * player.config.gravity * anticipation * anticipation)
	return future_ball.distance_to(future_hand) < 64

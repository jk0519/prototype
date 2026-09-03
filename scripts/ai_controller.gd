extends RefCounted
## Small role rules. Bots move and contact the ball through the same athlete model
## as the human. They cannot teleport or hit a ball from outside its contact area.

func intentions(game, all_ai: bool) -> Array:
	var result: Array = []
	for p in game.players:
		result.append({"move": toward(p, p.home_x)})
	if game.phase == "serve_ready":
		for p in game.players:
			result[p.id] = {}
		if game.phase_time > 0.85:
			result[game.server_id] = {"jump": true}
		return result
	if game.phase == "serve_toss":
		for p in game.players:
			result[p.id] = {}
		var server = game.players[game.server_id]
		result[server.id] = {"swing": server.pos.y > 45 and game.ball.distance_to(server.contact_center("serve")) < 95}
		return result
	if game.phase != "rally":
		return result

	for side in range(2):
		var time_low = game.time_to_height(78.0)
		var landing = game.ball.x + game.ball_velocity.x * time_low
		var incoming = (landing < 1000.0) == (side == 0)
		var our_half = (game.ball.x < 1000.0) == (side == 0)
		var our_possession = game.last_team == side and game.touches > 0
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
			if hitter.pos.y <= 0.01 and t <= 0.49 + game.ai_jump_error[hitter.id] and game.ball.y > 220:
				intent["jump"] = true
			if hitter.pos.y > 45 and game.ball.distance_to(hitter.contact_center("spike")) < 92:
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
				var intent = {"move": toward(receiver, landing - receiver.facing * 24 + game.ai_error_x[receiver.id]), "receive": true}
				if our_half and time_low < 0.18 and absf(receiver.pos.x - landing) > 75:
					intent["dive"] = true
				result[receiver_id] = intent
		# The middle follows the opposing attacker along the net and blocks.
		var middle = game.players[side * 3 + 2]
		if game.last_team == 1 - side and game.last_action == "set" and game.ai_block_attempt[side]:
			var t = game.time_to_height(300)
			var x = game.ball.x + game.ball_velocity.x * t
			if absf(x - 1000.0) < 330:
				result[middle.id] = {"move": toward(middle, 947 if side == 0 else 1053), "block": t < 0.53 + game.ai_jump_error[middle.id]}
		elif middle.pos.y > 0 and middle.blocking:
			result[middle.id]["block"] = true
	return result

func toward(player, target_x: float) -> float:
	var dx = target_x - player.pos.x
	return clampf(dx / 24.0, -1.0, 1.0) if absf(dx) > 4 else 0.0

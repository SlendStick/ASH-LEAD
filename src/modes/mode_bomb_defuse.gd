extends BaseMode
## BOMB DEFUSE -- criminals plant 2 of 3 charges in a public building while police
## are already on site. Police must find and defuse them, and civilians must not
## become collateral.

var charges: Array[Dictionary] = []


func setup_objectives() -> void:
	for a: Actor in world.call("actors_all"):
		if a.team == Db.TEAM_CRIMINAL and not a.is_civilian and not a.is_bot:
			a.gadget_charges["c4"] = 2
			break
	var centers: Array = map.points.get("bomb_sites", [])
	for i in range(mini(centers.size(), 3)):
		var o := spawn_objective(ObjectiveNode.Kind.BOMB_SITE, centers[i], "ЗАРЯД %s" % char(65 + i), Color("ff1f4b"), Db.TEAM_CRIMINAL)
		charges.append({"node": o, "pos": centers[i], "planted": false, "timer": 0.0, "defuse": 0.0, "defused": false})
	announce("РАЗМИНИРОВАНИЕ: 2 заряда решают всё", Color("ff1f4b"))
	world.call("raise_alarm", 2, "сапёры уже внутри")


func tick_mode(delta: float) -> void:
	var planted := 0
	var defused := 0
	var armed_count := 0
	for c in charges:
		var o: ObjectiveNode = c["node"]
		if bool(c["defused"]):
			defused += 1
			o.color = Color("2bff9a")
			continue
		if bool(c["planted"]):
			planted += 1
			c["timer"] = float(c["timer"]) - delta
			o.progress = 1.0 - clampf(float(c["timer"]) / 60.0, 0.0, 1.0)
			if float(c["timer"]) <= 0.0:
				win(Db.TEAM_CRIMINAL, "заряд сработал")
				return
			# defusing requires a police officer nearby holding the action
			var defuser: Actor = null
			for a: Actor in world.call("actors_all"):
				if a.team == Db.TEAM_POLICE and not a.dead and a.global_position.distance_to(o.global_position) < 80.0:
					defuser = a
					break
			if defuser != null:
				c["defuse"] = float(c["defuse"]) + delta
				if float(c["defuse"]) >= 6.0:
					c["defused"] = true
					announce("ЗАРЯД ОБЕЗВРЕЖЕН", Color("2bff9a"))
			else:
				c["defuse"] = maxf(0.0, float(c["defuse"]) - delta)
		else:
			# criminals can arm by standing close with the kit
			for a: Actor in world.call("actors_all"):
				if a.team == Db.TEAM_CRIMINAL and not a.dead and not a.is_civilian:
					if a.global_position.distance_to(o.global_position) < 74.0 and int(a.gadget_charges.get("c4", 0)) > 0:
						c["planted"] = true
						c["timer"] = 60.0
						a.gadget_charges["c4"] = int(a.gadget_charges["c4"]) - 1
						armed_count += 1
						announce("ЗАРЯД УСТАНОВЛЕН. 60 СЕКУНД.", Color("ff1f4b"))
						world.call("raise_alarm", 2, "заряд активен")
						break
	if planted - defused >= 2 and not bool(world.get("match_over")):
		var all_planted := true
		for c2 in charges:
			if not bool(c2["planted"]) and not bool(c2["defused"]):
				all_planted = false
		if armed_count == 0:
			pass
	# criminals win if 2 charges are planted and tick to zero (handled per charge)
	if defused >= 2:
		win(Db.TEAM_POLICE, "заряды обезврежены")
	# time limit: police win if no charge planted in 4 minutes
	if float(world.get("elapsed")) > 240.0:
		var any_planted := false
		for c3 in charges:
			if bool(c3["planted"]) and not bool(c3["defused"]):
				any_planted = true
		if not any_planted:
			win(Db.TEAM_POLICE, "заряды не установлены")


func on_actor_died(victim: Actor, killer: Actor, _headshot: bool) -> void:
	if victim.is_civilian and killer != null and killer.team == Db.TEAM_CRIMINAL:
		add_score(Db.TEAM_POLICE, 1)


func bot_point(actor: Actor) -> Variant:
	var best: Variant = null
	var bd := 1e9
	for c in charges:
		var o: ObjectiveNode = c["node"]
		if actor.team == Db.TEAM_POLICE and bool(c["defused"]):
			continue
		if actor.team == Db.TEAM_CRIMINAL and bool(c["planted"]):
			continue
		var d: float = o.global_position.distance_to(actor.global_position)
		if d < bd:
			bd = d
			best = o.global_position
	return best

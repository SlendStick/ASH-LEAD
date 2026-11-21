extends BaseMode
## HEIST -- PAYDAY-grade robbery.
##
## Flow:
##   1. STEALTH: criminals inside the building, guards/civilians live their lives,
##      cameras watch. Silent takeovers (knife, taser, hostage control) keep the
##      alarm down; gunfire, bodies found, broken windows raise it.
##   2. LOUD: once alarm hits 2 the police timer starts (or is cut short).
##      Criminals must crack 2-3 safes, carry bags to the van, and get out before
##      the van leaves. Police must stop the bags and wipe the crew.
##   3. EXFIL: after all bags are loaded, a 60s escape window; the van door is a
##      physical objective both teams can reach.

var vaults: Array[Dictionary] = []
var bags_total := 3
var bags_secured := 0
var van: ObjectiveNode = null
var van_timer := 0.0
var van_window := 60.0
var alarm_timer := 0.0
var drill_sound_timer := 0.0
var crew_alive := 0
var escaped := 0
var van_open := false
var van_pos := Vector2.ZERO


func setup_objectives() -> void:
	var vault_points: Array = map.points.get("vaults", [])
	if vault_points.is_empty():
		vault_points = map.points.get("bomb_sites", [])
		var i := 0
		while i < 3 and i < vault_points.size():
			i += 1
	bags_total = mini(3, maxi(2, vault_points.size()))
	for i in range(mini(bags_total, vault_points.size())):
		var o := spawn_objective(ObjectiveNode.Kind.VAULT, vault_points[i], "СЕЙФ %d" % (i + 1), Color("ffb02b"), Db.TEAM_CRIMINAL)
		o.radius = 70.0
		o.data["cracked"] = false
		o.data["progress"] = 0.0
		o.data["index"] = i
		vaults.append({"node": o, "pos": vault_points[i], "cracked": false, "progress": 0.0})
	van_pos = map.points.get("extract", map.world_size() * 0.5)
	van = spawn_objective(ObjectiveNode.Kind.VAN, van_pos, "ФУРГОН", Color("2bff9a"))
	van.data["bags"] = 0
	world.set("alarm_level", 0)
	announce("ОГРАБЛЕНИЕ. ТИХО, ПОКА МОЖНО.", Color("ffb02b"))
	Signals.objective_changed.emit("ОГРАБЛЕНИЕ", "Вскрой сейфы и донеси сумки до фургона", 0.0)


func tick_mode(delta: float) -> void:
	# stealth phase
	if int(world.get("alarm_level")) < 2:
		alarm_timer += delta
		if alarm_timer > 140.0:
			world.call("raise_alarm", 2, "охрана обходит здание")
		# drilling is loud
		for v in vaults:
			var o: ObjectiveNode = v["node"]
			if float(v["progress"]) > 0.0:
				drill_sound_timer += delta
				if drill_sound_timer > 2.5:
					drill_sound_timer = 0.0
					Sfx.play_at("drill", o.global_position, -6.0)
					Signals.noise_made.emit(o.global_position, 1100.0, "drill", Db.TEAM_CRIMINAL)
					world.call("raise_alarm", 1, "шум дрели")
	# vault cracking progress
	for v in vaults:
		var o: ObjectiveNode = v["node"]
		if bool(v["cracked"]):
			o.progress = 1.0
			continue
		var progress: float = v["progress"]
		# nearby criminals with tools advance it
		var has_drill := false
		var has_key := false
		for a in world.call("actors_all"):
			if a.dead or a.team != Db.TEAM_CRIMINAL or a.is_civilian:
				continue
			if a.global_position.distance_to(o.global_position) > 74.0:
				continue
			if bool(a.has_gadget("drill")):
				has_drill = true
			if bool(a.has_gadget("keycard")):
				has_key = true
		if has_drill:
			progress += delta / 45.0
		elif has_key:
			progress += delta / 75.0
		else:
			progress += delta / 120.0
		v["progress"] = clampf(progress, 0.0, 1.0)
		o.progress = float(v["progress"])
		if float(v["progress"]) >= 1.0:
			v["cracked"] = true
			o.data["cracked"] = true
			o.color = Color("2bff9a")
			Sfx.play_at("ui_objective", o.global_position, 0.0)
			announce("СЕЙФ ВСКРЫТ. ЗАБЕРИ СУМКУ.", Color("2bff9a"))
			Signals.objective_completed.emit(o.label, Db.TEAM_CRIMINAL)
	# van window / exfil
	if bags_secured >= bags_total and not van_open:
		van_open = true
		van_timer = van_window
		announce("ВСЁ В ФУРГОНЕ. УХОДИ, ПОКА НЕ ЗАКРЫЛАСЬ ДВЕРЬ.", Color("2bff9a"))
		raise_alarm_loud()
	if van_open:
		van_timer -= delta
		Signals.objective_changed.emit("ЭВАКУАЦИЯ", "%s" % Util.fmt_time(van_timer), 1.0 - van_timer / van_window)
		if van_timer <= 0.0:
			win(Db.TEAM_POLICE, "фургон ушёл без вас")
	# criminals escaping: standing near van with a bag
	for a in world.call("actors_all"):
		if a.dead or a.team != Db.TEAM_CRIMINAL or a.is_civilian:
			continue
		if a.bag_carried and a.global_position.distance_to(van_pos) < 92.0:
			a.bag_carried = false
			a.visual.carrying_bag = false
			bags_secured += 1
			van.data["bags"] = bags_secured
			Sfx.play_at("ui_buy", van_pos, 0.0)
			announce("СУМКА В ФУРГОНЕ (%d/%d)" % [bags_secured, bags_total], Color("2bff9a"))
			Signals.objective_changed.emit("СУМКИ", "%d из %d" % [bags_secured, bags_total], float(bags_secured) / float(bags_total))
			if a.is_local_player:
				GameFlow.add_cash(1500)
	# exfil complete
	if van_open and escaped == 0:
		var any_waiting := false
		var waiting := 0
		for a in world.call("actors_all"):
			if a.team == Db.TEAM_CRIMINAL and not a.dead and not a.is_civilian:
				if a.global_position.distance_to(van_pos) < 100.0:
					waiting += 1
				any_waiting = true
		if not any_waiting:
			win(Db.TEAM_POLICE, "экипаж уничтожен")
		elif waiting > 0 and bags_secured >= bags_total:
			# escape requires holding the van area for 8s after the last bag
			van_timer = maxf(van_timer, 8.0)


func raise_alarm_loud() -> void:
	world.call("raise_alarm", 2, "тревога ограбления")


func on_objective_interact(o: ObjectiveNode, actor: Actor) -> void:
	if o.kind == ObjectiveNode.Kind.VAULT and actor.team == Db.TEAM_CRIMINAL:
		for v in vaults:
			if v["node"] == o and bool(v["cracked"]):
				if actor.bag_carried:
					Signals.notify.emit("Уже несёшь сумку", "warning")
					return
				actor.bag_carried = true
				actor.visual.carrying_bag = true
				o.data["taken"] = true
				announce("СУМКА ВЗЯТА. НЕСИ ЕЁ В ФУРГОН.", Color("ffb02b"))


func find_interactable(actor: Actor) -> Variant:
	if actor.team != Db.TEAM_CRIMINAL:
		return null
	for v in vaults:
		var o: ObjectiveNode = v["node"]
		if bool(v["cracked"]) and not bool(o.data.get("taken", false)):
			if actor.global_position.distance_to(o.global_position) < 74.0:
				return {"node": o, "kind": "pickup_bag", "text": "Взять сумку", "time": 0.8 / Perks.interact_speed_mult(actor)}
	return null


func interaction_text(_o: ObjectiveNode, _a: Actor) -> String:
	return ""


func on_actor_died(victim: Actor, killer: Actor, _headshot: bool) -> void:
	if victim.is_civilian:
		return
	if victim.bag_carried:
		victim.bag_carried = false
		victim.visual.carrying_bag = false
		if world.has_method("drop_bag"):
			world.call("drop_bag", victim.global_position, victim.a_id)
		if int(world.get("alarm_level")) < 2:
			world.call("raise_alarm", 2, "кровь в здании")


func on_alarm(level: int) -> void:
	if level >= 2:
		var t = world.get("police_arrive_timer")
		if t != null:
			var cur := float(t)
			if cur > 150.0 or cur < 0.0:
				world.set("police_arrive_timer", 150.0)
				announce("ПОЛИЦИЯ ВЫЕХАЛА. 2:30.", Color("1d6bff"))


func bot_point(actor: Actor) -> Variant:
	if actor.team == Db.TEAM_CRIMINAL:
		if actor.bag_carried:
			return van_pos
		for v in vaults:
			var o: ObjectiveNode = v["node"]
			if bool(v["cracked"]) and not bool(o.data.get("taken", false)):
				return o.global_position
		for v2 in vaults:
			if not bool(v2["cracked"]):
				return v2["pos"]
		return van_pos
	else:
		if int(world.get("alarm_level")) >= 2:
			return van_pos
		return map.world_size() * 0.5


func retreat_point(_actor: Actor) -> Variant:
	return van_pos


func objective_progress() -> float:
	return float(bags_secured) / float(maxi(1, bags_total))

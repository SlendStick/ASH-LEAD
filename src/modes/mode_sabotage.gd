extends BaseMode
## SABOTAGE -- Counter-Strike style bomb planting.
## Criminals plant C-4 on one of three police sites, police defuse.
## One life per round, 1:45 round clock, 40s fuse, 7s defuse with a 0.5 tick.

var sites: Array[Dictionary] = []
var carrier: Actor = null
var planted := false
var bomb_pos := Vector2.ZERO
var bomb_timer := 0.0
var defuse_progress := 0.0
var defuser: Actor = null
var round_limit := 8
var planted_by: Actor = null
var plant_progress := 0.0
var planter: Actor = null


func setup_objectives() -> void:
	world.set("instant_death", true)
	var centers: Array = map.points.get("bomb_sites", [])
	var letters := ["A", "B", "C"]
	for i in range(mini(centers.size(), 3)):
		var o := spawn_objective(ObjectiveNode.Kind.BOMB_SITE, centers[i], letters[i], Color("ff1f4b"))
		sites.append({"node": o, "pos": centers[i]})
	# give the C4 to a criminal
	for a: Actor in world.call("actors_all"):
		if a.team == Db.TEAM_CRIMINAL and not a.is_civilian and not a.is_bot:
			carrier = a
			break
	if carrier == null:
		for a: Actor in world.call("actors_all"):
			if a.team == Db.TEAM_CRIMINAL and not a.is_civilian:
				carrier = a
				break
	_start_round()


func _start_round() -> void:
	round_active = true
	round_time = 0.0
	planted = false
	plant_progress = 0.0
	defuse_progress = 0.0
	world.set("round_index", round_index)
	Signals.round_state_changed.emit(0, round_index)
	announce("РАУНД %d. ЗАЛОЖИ ЗАРЯД." % round_index, Color("ff1f4b"))
	Signals.objective_changed.emit("ЗАКЛАДКА БОМБЫ", "Установи C-4 на точку A/B/C", 0.0)


func tick_mode(delta: float) -> void:
	round_time += delta
	if planted:
		bomb_timer -= delta
		var o := _bomb_objective()
		if o != null:
			o.progress = 1.0 - clampf(bomb_timer / 40.0, 0.0, 1.0)
		Signals.objective_changed.emit("БОМБА ТИКАЕТ", "%d сек до детонации" % int(ceil(bomb_timer)), 1.0 - bomb_timer / 40.0)
		if bomb_timer <= 0.0:
			win(Db.TEAM_CRIMINAL, "бомба взорвалась")
			return
		# defuse handled by interact
		if defuser != null and not defuser.dead:
			defuse_progress += delta
			if defuse_progress >= 7.0:
				win(Db.TEAM_POLICE, "заряд обезврежен")
		else:
			defuse_progress = maxf(0.0, defuse_progress - delta * 1.5)
	else:
		if round_time > 105.0:
			win(Db.TEAM_POLICE, "время вышло, заряд не заложен")
		var near_site: Dictionary = {}
		for s in sites:
			var o: ObjectiveNode = s["node"]
			o.progress = 0.0
			if carrier != null and not carrier.dead and carrier.global_position.distance_to(o.global_position) < 70.0:
				near_site = s
		if not near_site.is_empty() and carrier != null and not carrier.dead:
			plant_progress += delta
			var o2: ObjectiveNode = near_site["node"]
			o2.progress = plant_progress / 3.0
			Signals.objective_changed.emit("УСТАНОВКА ЗАРЯДА", "%d%%" % int(plant_progress / 3.0 * 100.0), plant_progress / 3.0)
			if plant_progress >= 3.0:
				_plant(near_site)
		else:
			plant_progress = maxf(0.0, plant_progress - delta * 2.0)
		Signals.police_arrival.emit(float(world.get("police_arrive_timer")))


func _plant(site: Dictionary) -> void:
	planted = true
	bomb_timer = 40.0
	planted_by = carrier
	bomb_pos = site["pos"]
	announce("ЗАРЯД УСТАНОВЛЕН! %d СЕКУНД." % 40, Color("ff1f4b"))
	Sfx.play_at("ui_objective", bomb_pos, 0.0)
	Signals.noise_made.emit(bomb_pos, 1800.0, "objective", Db.TEAM_CRIMINAL)
	world.call("raise_alarm", 2, "заложен заряд")
	Signals.objective_changed.emit("БОМБА", "Обезвредь заряд!", 0.0)


func _bomb_objective() -> ObjectiveNode:
	for s in sites:
		var o: ObjectiveNode = s["node"]
		if o.global_position.distance_to(bomb_pos) < 10.0:
			return o
	return null


func on_objective_interact(o: ObjectiveNode, actor: Actor) -> void:
	if not planted:
		if actor == carrier or (actor.team == Db.TEAM_CRIMINAL and carrier != null and carrier.dead):
			carrier = actor
		return
	if actor.team == Db.TEAM_POLICE:
		defuser = actor


func find_interactable(actor: Actor) -> Variant:
	if planted:
		if actor.team == Db.TEAM_POLICE and actor.global_position.distance_to(bomb_pos) < 80.0:
			var o := _bomb_objective()
			if o != null:
				return {"node": o, "kind": "defuse", "text": "Разминировать (7 с)", "time": 7.0 / Perks.interact_speed_mult(actor)}
		return null
	if actor.team == Db.TEAM_CRIMINAL and carrier != null and actor == carrier:
		for s in sites:
			var o2: ObjectiveNode = s["node"]
			if actor.global_position.distance_to(o2.global_position) < 74.0:
				return {"node": o2, "kind": "plant", "text": "Заложить заряд (3 с)", "time": 3.0 / Perks.interact_speed_mult(actor)}
	return null


func on_actor_died(victim: Actor, killer: Actor, _headshot: bool) -> void:
	if victim.is_civilian or not round_active:
		return
	if victim == defuser:
		defuser = null
		defuse_progress = 0.0
	# all criminals dead before plant = police win
	var crim_alive := 0
	for a: Actor in world.call("actors_all"):
		if a.team == Db.TEAM_CRIMINAL and not a.dead and not a.is_civilian:
			crim_alive += 1
	if crim_alive == 0 and not planted:
		win(Db.TEAM_POLICE, "наёмники уничтожены")
	# all police dead after plant = plant succeeds
	var pol_alive := 0
	for a: Actor in world.call("actors_all"):
		if a.team == Db.TEAM_POLICE and not a.dead:
			pol_alive += 1
	if pol_alive == 0:
		win(Db.TEAM_CRIMINAL, "полиция уничтожена")


func on_team_counts(_crim: int, _pol: int) -> void:
	pass


func bot_point(actor: Actor) -> Variant:
	if planted:
		if actor.team == Db.TEAM_POLICE:
			return bomb_pos
		return bomb_pos + (bomb_pos - (map.world_size() * 0.5)).normalized() * 220.0
	if actor.team == Db.TEAM_CRIMINAL:
		var best: Variant = null
		var best_d := 1e9
		for s in sites:
			var o: ObjectiveNode = s["node"]
			var d: float = o.global_position.distance_to(actor.global_position)
			if d < best_d:
				best_d = d
				best = o.global_position
		return best
	# police hold the sites
	var nearest: Variant = null
	var nd := 1e9
	for s in sites:
		var o2: ObjectiveNode = s["node"]
		var d2: float = o2.global_position.distance_to(actor.global_position)
		if d2 < nd:
			nd = d2
			nearest = o2.global_position
	return nearest

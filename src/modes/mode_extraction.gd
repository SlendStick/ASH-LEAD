extends BaseMode
## EXTRACTION -- criminals escort a VIP witness out of the building to a van.
## The VIP is a real civilian actor with fear AI: shots make him drop to the floor
## and refuse to move. Police can snatch him and walk him to the precinct instead.

var vip: Actor = null
var exit_node: ObjectiveNode = null
var police_exit: ObjectiveNode = null
var escort_timer := 0.0
var escort_carrier: Actor = null


func setup_objectives() -> void:
	var victims: Array = []
	for a in world.call("actors_all"):
		if a.is_civilian and a.get_meta("hostage", false) != true and a.ai != null:
			victims.append(a)
	if victims.is_empty():
		for a in world.call("actors_all"):
			if a.is_civilian:
				victims.append(a)
	if not victims.is_empty():
		vip = victims[0]
		vip.set_meta("vip", true)
		vip.a_name = "СВИДЕТЕЛЬ " + vip.a_name
		vip.max_hp = 80.0
		vip.hp = 80.0
		vip.ai.set("personality", "coward")
		Signals.hostage_state.emit(vip.a_id, "vip")
	exit_node = spawn_objective(ObjectiveNode.Kind.EXIT, map.points.get("extract", map.world_size() * 0.5), "ФУРГОН", Color("2bff9a"), Db.TEAM_CRIMINAL)
	police_exit = spawn_objective(ObjectiveNode.Kind.EXIT, map.points.get("security_room", map.world_size() * 0.3), "УЧАСТОК", Color("35c9ff"), Db.TEAM_POLICE)
	announce("ЭВАКУАЦИЯ СВИДЕТЕЛЯ", Color("ffb02b"))
	Signals.objective_changed.emit("ЭВАКУАЦИЯ", "Доведи свидетеля до фургона", 0.0)


func tick_mode(delta: float) -> void:
	if vip == null or not is_instance_valid(vip) or vip.dead:
		return
	var d_van: float = vip.global_position.distance_to(exit_node.global_position)
	if d_van < 90.0:
		win(Db.TEAM_CRIMINAL, "свидетель вывезен")
		return
	var d_prec: float = vip.global_position.distance_to(police_exit.global_position)
	if d_prec < 90.0:
		win(Db.TEAM_POLICE, "свидетель в участке")
		return
	# VIP follows the nearest escort and panics when guns fire
	var closest_crim: Actor = null
	var closest_pol: Actor = null
	var cd := 1e9
	var pd := 1e9
	for a in world.call("actors_all"):
		if a.dead or a.is_civilian:
			continue
		var d: float = a.global_position.distance_to(vip.global_position)
		if a.team == Db.TEAM_CRIMINAL and d < cd:
			cd = d
			closest_crim = a
		elif a.team == Db.TEAM_POLICE and d < pd:
			pd = d
			closest_pol = a
	var handler: Actor = closest_crim
	if closest_pol != null and pd < cd:
		handler = closest_pol
	if handler != null and handler.global_position.distance_to(vip.global_position) < 200.0:
		vip.ai.set("target_point", handler.global_position)
		vip.ai.set("state", "follow")
		if closest_crim == null and closest_pol != null:
			escort_carrier = closest_pol
		else:
			escort_carrier = closest_crim
	Signals.objective_changed.emit("ЭВАКУАЦИЯ", "Свидетель: %s" % ("под контролем наёмников" if closest_crim != null and cd < pd else "под контролем полиции"), clampf(1.0 - d_van / 1800.0, 0.0, 1.0))
	if vip.hp < vip.max_hp * 0.3:
		world.call("raise_alarm", 2, "свидетель ранен")


func on_actor_died(victim: Actor, _killer: Actor, _headshot: bool) -> void:
	if victim == vip:
		win(Db.TEAM_POLICE, "свидетель убит")


func bot_point(actor: Actor) -> Variant:
	if vip == null or vip.dead:
		return null
	if actor.team == Db.TEAM_CRIMINAL:
		if actor.global_position.distance_to(vip.global_position) > 160.0:
			return vip.global_position
		return exit_node.global_position if exit_node != null else vip.global_position
	else:
		if actor.global_position.distance_to(vip.global_position) > 160.0:
			return vip.global_position
		return police_exit.global_position if police_exit != null else vip.global_position

extends BaseMode
## DEATHMATCH -- arcade. First team to the frag limit wins. Respawn waves keep
## the pressure up; civilians are absent so the kill feed is nothing but names.

var limit := 50
var respawn_queue: Array[Dictionary] = []


func setup_objectives() -> void:
	limit = int(mode_data.get("score_limit", 50))
	world.set("friendly_fire", false)
	announce("БОЙ НАСМЕРТЬ: до %d фрагов" % limit, Color("ff2b62"))


func tick_mode(delta: float) -> void:
	# process respawns
	var keep: Array[Dictionary] = []
	for r in respawn_queue:
		r["t"] = float(r["t"]) - delta
		if float(r["t"]) <= 0.0:
			var a: Actor = world.call("actor_by_id", int(r["id"]))
			if a != null:
				world.call("respawn_actor", a)
		else:
			keep.append(r)
	respawn_queue = keep
	if score.get(Db.TEAM_CRIMINAL, 0) >= limit:
		win(Db.TEAM_CRIMINAL, "лимит фрагов")
	elif score.get(Db.TEAM_POLICE, 0) >= limit:
		win(Db.TEAM_POLICE, "лимит фрагов")


func on_actor_died(victim: Actor, killer: Actor, _headshot: bool) -> void:
	if victim.is_civilian:
		return
	if killer != null and killer != victim and killer.team != victim.team:
		add_score(killer.team, 1)
	elif killer == victim:
		add_score(1 - victim.team, 1)
	var respawn_time := float(mode_data.get("respawn", 3.0))
	respawn_queue.append({"id": victim.a_id, "t": respawn_time})
	Signals.score_changed.emit(0, score.get(0, 0))
	Signals.score_changed.emit(1, score.get(1, 0))


func on_team_counts(_crim: int, _pol: int) -> void:
	pass


func interaction_text(_o: ObjectiveNode, _a: Actor) -> String:
	return ""


func bot_point(actor: Actor) -> Variant:
	# bots push towards the nearest living enemy
	var nearest: Actor = null
	var best := 1e9
	for a in world.call("actors_all"):
		if a.dead or a.team == actor.team or a.is_civilian:
			continue
		var d := a.global_position.distance_to(actor.global_position)
		if d < best:
			best = d
			nearest = a
	if nearest != null:
		return nearest.global_position
	return map.world_size() * 0.5

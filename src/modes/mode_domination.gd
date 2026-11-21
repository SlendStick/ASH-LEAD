extends BaseMode
## DOMINATION -- three capture points on the procedural map. Holding points
## bleeds the enemy's tickets. Civilians wander through the killzones.

var points: Array[Dictionary] = []
var tick_accum := 0.0
var respawn_queue: Array[Dictionary] = []
var limit := 300


func setup_objectives() -> void:
	limit = int(mode_data.get("score_limit", 300))
	var centers: Array = map.points.get("capture", [])
	var letters := ["A", "B", "C"]
	for i in range(mini(centers.size(), 3)):
		var o := spawn_objective(ObjectiveNode.Kind.CAPTURE, centers[i], letters[i], Color("35c9ff"))
		o.radius = 120.0
		points.append({"node": o, "t": Db.TEAM_CRIMINAL, "owner": -1, "capture": 0.0, "pos": centers[i]})
	announce("ЗАХВАТ ТОЧЕК: A / B / C", Color("35c9ff"))


func tick_mode(delta: float) -> void:
	tick_accum += delta
	# capture progress
	for p in points:
		var o: ObjectiveNode = p["node"]
		var crim := 0
		var pol := 0
		for a: Actor in world.call("actors_all"):
			if a.dead or a.is_civilian:
				continue
			if a.global_position.distance_to(o.global_position) < o.radius:
				if a.team == Db.TEAM_CRIMINAL:
					crim += 1
				else:
					pol += 1
		if crim > 0 and pol == 0:
			p["capture"] = minf(1.0, float(p["capture"]) + delta * 0.28 * (1.0 + crim * 0.15))
		elif pol > 0 and crim == 0:
			p["capture"] = maxf(-1.0, float(p["capture"]) - delta * 0.28 * (1.0 + pol * 0.15))
		else:
			p["capture"] = move_toward(float(p["capture"]), 0.0, delta * 0.1)
		o.progress = absf(float(p["capture"]))
		if float(p["capture"]) >= 1.0 and int(p["owner"]) != Db.TEAM_CRIMINAL:
			p["owner"] = Db.TEAM_CRIMINAL
			o.color = Db.TEAM_COLORS[0]
			announce("ТОЧКА %s ЗАХВАЧЕНА НАЁМНИКАМИ" % o.label, Color("ff2b62"))
		elif float(p["capture"]) <= -1.0 and int(p["owner"]) != Db.TEAM_POLICE:
			p["owner"] = Db.TEAM_POLICE
			o.color = Db.TEAM_COLORS[1]
			announce("ТОЧКА %s ЗАХВАЧЕНА ПОЛИЦИЕЙ" % o.label, Color("35c9ff"))
	# ticket bleed once per second
	if tick_accum >= 1.0:
		tick_accum = 0.0
		var crim_pts := 0
		var pol_pts := 0
		for p in points:
			if int(p["owner"]) == Db.TEAM_CRIMINAL:
				crim_pts += 1
			elif int(p["owner"]) == Db.TEAM_POLICE:
				pol_pts += 1
		if crim_pts > pol_pts:
			add_score(Db.TEAM_CRIMINAL, crim_pts)
		elif pol_pts > crim_pts:
			add_score(Db.TEAM_POLICE, pol_pts)
		elif crim_pts == pol_pts and crim_pts > 0:
			add_score(Db.TEAM_CRIMINAL, 1)
			add_score(Db.TEAM_POLICE, 1)
		Signals.objective_changed.emit("ТОЧКИ", "%d : %d" % [score.get(0, 0), score.get(1, 0)], float(crim_pts) / 3.0)
		if int(score.get(Db.TEAM_CRIMINAL, 0)) >= limit:
			win(Db.TEAM_CRIMINAL, "тикеты")
		elif int(score.get(Db.TEAM_POLICE, 0)) >= limit:
			win(Db.TEAM_POLICE, "тикеты")
	# respawns
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


func on_actor_died(victim: Actor, killer: Actor, _headshot: bool) -> void:
	if victim.is_civilian:
		return
	respawn_queue.append({"id": victim.a_id, "t": float(mode_data.get("respawn", 4.0))})
	if killer != null and killer != victim and killer.team != victim.team:
		add_score(killer.team, 2)


func interaction_text(_o: ObjectiveNode, _a: Actor) -> String:
	return ""


func bot_point(actor: Actor) -> Variant:
	# prefer a point we don't own that is nearest
	var best: Variant = null
	var best_score := -1e9
	for p in points:
		var o: ObjectiveNode = p["node"]
		var d: float = o.global_position.distance_to(actor.global_position)
		var s := -d
		if int(p["owner"]) != actor.team:
			s += 400.0
		if s > best_score:
			best_score = s
			best = o.global_position
	return best

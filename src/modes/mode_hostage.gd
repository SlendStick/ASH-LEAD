extends BaseMode
## HOSTAGE -- criminals hold 3 hostages inside a bank/hospital; police must
## breach and rescue. Hostages can be walked, used as human shields, or executed
## (which instantly turns the map loud and costs the criminals the payout).

var hostages: Array[Actor] = []
var rescues_needed := 3
var rescued := 0
var executed := 0
var negotiate_timer := 60.0
var breach_started := false
var held_pos := Vector2.ZERO
var exit_node: ObjectiveNode = null


func setup_objectives() -> void:
	world.set("friendly_fire", false)
	for a in world.call("actors_all"):
		if a.is_civilian and a.get_meta("hostage", false):
			hostages.append(a)
	rescues_needed = mini(3, hostages.size())
	var center := Vector2.ZERO
	for h in hostages:
		center += h.global_position
	if not hostages.is_empty():
		center /= float(hostages.size())
	held_pos = center
	exit_node = spawn_objective(ObjectiveNode.Kind.EXIT, map.points.get("extract", map.world_size() * 0.5), "ЭВАКУАЦИЯ", Color("35c9ff"), Db.TEAM_POLICE)
	announce("ЗАЛОЖНИКИ: наёмники удерживают %d" % hostages.size(), Color("ff2bd6"))
	world.call("raise_alarm", 1, "захват заложников")
	Signals.objective_changed.emit("ЗАЛОЖНИКИ", "Полиция: освободи %d заложников" % rescues_needed, 0.0)


func tick_mode(delta: float) -> void:
	if not breach_started:
		negotiate_timer -= delta
		Signals.objective_changed.emit("ПЕРЕГОВОРЫ", "%s до штурма" % Util.fmt_time(negotiate_timer), 0.0)
		if negotiate_timer <= 0.0:
			breach_started = true
			world.call("raise_alarm", 2, "переговоры провалились")
			announce("ПЕРЕГОВОРЫ ПРОВАЛЕНЫ. ШТУРМ.", Color("1d6bff"))
	# a criminal who grabs a hostage drags them towards their own exit; the mode
	# keeps the escort goal alive so the mechanic has a payoff
	for h in hostages:
		if h.dead:
			continue
		var escort_id := int(h.get_meta("escort_id", 0))
		if escort_id == 0:
			continue
		var captor = world.call("actor_by_id", escort_id)
		if captor == null or captor.dead:
			world.call("release_civilian", null, h)
	# hostages escape when reaching the police exit with a cop nearby
	for h in hostages:
		if h.dead or h.get_meta("rescued", false):
			continue
		if exit_node != null and h.global_position.distance_to(exit_node.global_position) < 90.0:
			var cop_near := false
			for a in world.call("actors_all"):
				if a.team == Db.TEAM_POLICE and not a.dead and a.global_position.distance_to(h.global_position) < 120.0:
					cop_near = true
					break
			if cop_near:
				h.set_meta("rescued", true)
				h.set_meta("hostage_state", "rescued")
				h.visual.queue_redraw()
				rescued += 1
				announce("ЗАЛОЖНИК СПАСЁН (%d/%d)" % [rescued, rescues_needed], Color("2bff9a"))
				Signals.objective_changed.emit("ЗАЛОЖНИКИ", "%d из %d" % [rescued, rescues_needed], float(rescued) / float(rescues_needed))
	if rescued >= rescues_needed:
		win(Db.TEAM_POLICE, "заложники освобождены")
	# time-limit fallback for criminals: keep hostages 6 minutes
	if world.get("elapsed") != null and float(world.get("elapsed")) > 360.0 and executed == 0:
		win(Db.TEAM_CRIMINAL, "заложники удержаны")


func on_actor_died(victim: Actor, killer: Actor, _headshot: bool) -> void:
	if victim.is_civilian and victim.get_meta("hostage", false):
		executed += 1
		world.call("raise_alarm", 2, "заложник убит")
		Signals.match_event.emit("ЗАЛОЖНИК УБИТ", Color("ff1f4b"), "hostage")
		if killer != null and killer.team == Db.TEAM_CRIMINAL:
			killer.money -= 1200
		# criminals lose the payout; police gain leverage
		add_score(Db.TEAM_POLICE, 1)
		if executed >= 2:
			win(Db.TEAM_POLICE, "наёмники казнили заложников")


func on_alarm(level: int) -> void:
	if level >= 2 and not breach_started:
		breach_started = true
		if exit_node != null:
			announce("ШТУРМ НАЧАЛСЯ. ЗАЛОЖНИКИ В ОПАСНОСТИ.", Color("1d6bff"))


func interaction_text(o: ObjectiveNode, _a: Actor) -> String:
	if o.kind == ObjectiveNode.Kind.EXIT:
		return "Вывести заложника"
	return ""


func bot_point(actor: Actor) -> Variant:
	if actor.team == Db.TEAM_POLICE:
		if exit_node != null and actor.has_meta("escorting"):
			return exit_node.global_position
		# nearest living hostage
		var best: Variant = null
		var bd := 1e9
		for h in hostages:
			if h.dead or h.get_meta("rescued", false):
				continue
			var d: float = h.global_position.distance_to(actor.global_position)
			if d < bd:
				bd = d
				best = h.global_position
		if best != null:
			return best
		return exit_node.global_position if exit_node != null else null
	else:
		# criminals hold the hostage room
		return held_pos

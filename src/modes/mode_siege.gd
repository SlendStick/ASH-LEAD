extends BaseMode
## SIEGE -- capture a government building (hospital, warehouse, school, cinema,
## mall). Criminals seize control room by room; police arrive late and retake
## it floor by floor. Floors are logical zones built from room clusters.

var zones: Array[Dictionary] = []
var contested := 0
var hold_seconds := 30.0
var criminals_hold := 0
var zone_hold := 0.0
var current_zone := 0
var police_wave := 0
var wave_timer := 0.0


func setup_objectives() -> void:
	var room_count := map.rooms.size()
	if room_count == 0:
		return
	# group rooms into 2-3 zones (floor-like clusters)
	var zone_count := clampi(int(round(room_count / 4.0)), 2, 3)
	var per := int(ceil(float(room_count) / float(zone_count)))
	for z in range(zone_count):
		var members: Array[int] = []
		for i in range(per):
			var idx := z * per + i
			if idx < room_count:
				members.append(idx)
		if members.is_empty():
			continue
		var rect_sum := Vector2.ZERO
		for m in members:
			var r: Rect2i = map.rooms[m]["rect"]
			rect_sum += Vector2(r.position + r.size / 2)
		var center := rect_sum / float(members.size())
		var world_pos := Vector2(center) * GeneratedMap.TILE
		var o := spawn_objective(ObjectiveNode.Kind.CAPTURE, world_pos, "ЗОНА %d" % (z + 1), Color("ff2b62"))
		o.radius = 190.0
		zones.append({"node": o, "rooms": members, "owner": -1, "progress": 0.0, "pos": world_pos})
		o.progress = 0.0
	announce("ЗАХВАТ ЗДАНИЯ: %d зоны" % zones.size(), Color("ff2b62"))
	world.call("raise_alarm", 1, "проникновение в здание")
	Signals.objective_changed.emit("ЗАХВАТ ЗДАНИЯ", "Захвати все зоны", 0.0)


func tick_mode(delta: float) -> void:
	if zones.is_empty():
		return
	var crim_zones := 0
	var pol_zones := 0
	for i in range(zones.size()):
		var z: Dictionary = zones[i]
		var o: ObjectiveNode = z["node"]
		var players_crim := 0
		var players_pol := 0
		for a: Actor in world.call("actors_all"):
			if a.dead or a.is_civilian:
				continue
			if a.global_position.distance_to(o.global_position) > o.radius:
				continue
			if a.team == Db.TEAM_CRIMINAL:
				players_crim += 1
			else:
				players_pol += 1
		if int(z["owner"]) == Db.TEAM_CRIMINAL:
			crim_zones += 1
			if players_pol > 0 and players_crim == 0:
				z["progress"] = float(z["progress"]) - delta * 0.16
		elif int(z["owner"]) == Db.TEAM_POLICE:
			pol_zones += 1
			if players_crim > 0 and players_pol == 0:
				z["progress"] = float(z["progress"]) - delta * 0.16
		elif int(z["owner"]) < 0:
			if players_crim > 0 and players_pol == 0:
				z["progress"] = minf(1.0, float(z["progress"]) + delta * 0.2)
			elif players_pol > 0 and players_crim == 0:
				z["progress"] = maxf(-1.0, float(z["progress"]) - delta * 0.2)
			if float(z["progress"]) >= 1.0:
				z["owner"] = Db.TEAM_CRIMINAL
				o.color = Db.TEAM_COLORS[0]
				announce("ЗОНА %s ЗАХВАЧЕНА НАЁМНИКАМИ" % o.label, Color("ff2b62"))
			elif float(z["progress"]) <= -1.0:
				z["owner"] = Db.TEAM_POLICE
				o.color = Db.TEAM_COLORS[1]
				announce("ЗОНА %s ВОЗВРАЩЕНА ПОЛИЦИИ" % o.label, Color("35c9ff"))
		if z["owner"] == Db.TEAM_CRIMINAL and float(z["progress"]) < 0.0:
			z["owner"] = -1
			o.color = Color("ff2b62")
			z["progress"] = 0.0
		if z["owner"] == Db.TEAM_POLICE and float(z["progress"]) > 0.0:
			z["owner"] = -1
			o.color = Color("35c9ff")
			z["progress"] = 0.0
		o.progress = absf(float(z["progress"]))
	# full capture + hold timer
	if crim_zone_all(zones):
		zone_hold += delta
		Signals.objective_changed.emit("УДЕРЖАНИЕ", "%s" % Util.fmt_time(hold_seconds - zone_hold), zone_hold / hold_seconds)
		if zone_hold >= hold_seconds:
			win(Db.TEAM_CRIMINAL, "здание захвачено и удержано")
	else:
		zone_hold = 0.0
	if police_all(zones):
		win(Db.TEAM_POLICE, "здание очищено")
	# escalating police waves while criminals hold
	wave_timer += delta
	if int(world.get("alarm_level")) >= 2 and wave_timer > 50.0 and police_wave < 3:
		wave_timer = 0.0
		police_wave += 1
		world.call("summon_police", "подкрепление %d" % police_wave)


func crim_zone_all(z: Array) -> bool:
	for zz in z:
		if int(zz["owner"]) != Db.TEAM_CRIMINAL:
			return false
	return not z.is_empty()


func police_all(z: Array) -> bool:
	for zz in z:
		if int(zz["owner"]) != Db.TEAM_POLICE:
			return false
	return not z.is_empty()


func on_alarm(level: int) -> void:
	if level >= 2:
		announce("ПОЛИЦИЯ ШТУРМУЕТ ЗДАНИЕ", Color("1d6bff"))


func on_actor_died(victim: Actor, killer: Actor, _headshot: bool) -> void:
	if victim.is_civilian:
		world.call("raise_alarm", 1, "гражданский под огнём")
	else:
		world.call("raise_alarm", 2 if killer != null and killer.team == Db.TEAM_POLICE else 1, "перестрелка")


func bot_point(actor: Actor) -> Variant:
	var in_team := 0
	for z in zones:
		if int(z["owner"]) == actor.team:
			in_team += 1
	var best: Variant = null
	var bd := 1e9
	for z2 in zones:
		if int(z2["owner"]) == actor.team:
			continue
		var o: ObjectiveNode = z2["node"]
		var d: float = o.global_position.distance_to(actor.global_position)
		if d < bd:
			bd = d
			best = o.global_position
	return best

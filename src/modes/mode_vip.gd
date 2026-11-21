extends BaseMode
## VIP PROTECTION -- police guard a mayor/judge (bot) while criminals hunt him.
## The VIP follows police, panics under fire, and can be moved by the team that
## grabs him. Killing him is an instant criminal win.

var vip: Actor = null
var timer := 240.0
var phase := 0


func setup_objectives() -> void:
	var candidates: Array = []
	for a in world.call("actors_all"):
		if a.team == Db.TEAM_POLICE and a.is_bot and not a.is_civilian:
			candidates.append(a)
	if candidates.is_empty():
		for a in world.call("actors_all"):
			if a.team == Db.TEAM_POLICE and not a.is_civilian:
				candidates.append(a)
	if not candidates.is_empty():
		vip = candidates[0]
		vip.a_name = "МЭР " + vip.a_name
		vip.max_hp = 150.0
		vip.hp = 150.0
		vip.give_armor("riot")
		vip.ai.set("order", "follow")
		vip.ai.set("order_target", vip.global_position)
		vip.set_meta("is_vip", true)
	# criminals get photos / intel
	announce("ОХРАНА ЛИЦА: мэр в здании. Найди и ликвидируй.", Color("ff1f4b"))
	Signals.objective_changed.emit("ОХРАНА ЛИЦА", "Наёмники: убей мэра. Полиция: удержи до конца операции.", 0.0)


func tick_mode(delta: float) -> void:
	if vip == null or not is_instance_valid(vip) or vip.dead:
		return
	timer -= delta
	Signals.objective_changed.emit("ОХРАНА", "%s" % Util.fmt_time(timer), 1.0 - timer / 240.0)
	if timer <= 0.0:
		win(Db.TEAM_POLICE, "мэр жив")
		return
	# VIP sticks to the nearest cop
	var best_cop: Actor = null
	var bd := 1e9
	for a in world.call("actors_all"):
		if a.team != Db.TEAM_POLICE or a.dead or a.is_civilian or a == vip:
			continue
		var d: float = a.global_position.distance_to(vip.global_position)
		if d < bd:
			bd = d
			best_cop = a
	if best_cop != null and vip.ai != null:
		vip.ai.set("order_target", best_cop.global_position)
	# chase tension: criminals get a ping on the VIP every 20 seconds
	if fmod(timer, 20.0) < delta:
		for a in world.call("actors_all"):
			if a.team == Db.TEAM_CRIMINAL and not a.is_bot:
				Signals.ui_ping.emit(vip.global_position, "vip")
	if timer < 60.0:
		Signals.ui_ping.emit(vip.global_position, "vip")


func on_actor_died(victim: Actor, killer: Actor, _headshot: bool) -> void:
	if victim == vip:
		win(Db.TEAM_CRIMINAL, "мэр ликвидирован")
		GameFlow.add_cash(5000)
		return
	if victim.team == Db.TEAM_POLICE and victim.is_bot:
		Signals.match_event.emit("ОХРАНА МЭРА ПОТЕРЯЛА БОЙЦА", Color("ffb02b"), "vip")


func interaction_text(_o: ObjectiveNode, _a: Actor) -> String:
	return ""


func bot_point(actor: Actor) -> Variant:
	if vip == null or vip.dead:
		return null
	if actor.team == Db.TEAM_CRIMINAL:
		return vip.global_position
	if actor == vip:
		return map.world_size() * 0.5
	return vip.global_position + Vector2(80, 0)

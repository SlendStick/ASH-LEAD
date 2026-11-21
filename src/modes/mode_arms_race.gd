extends BaseMode
## ARMS RACE -- 15 weapons, each kill upgrades you, each death demotes you.
## Knife kills skip a tier. Final tier is the golden knife: backstab wins.

const LADDER := [
	"pm9", "machine_pistol", "vk9", "pp19", "ksg", "deagle45", "ak12",
	"mp5sd", "m4", "saiga12", "scar", "pkm", "vintorez", "svd", "knife",
]
var player_tier: Dictionary = {}
var respawn_queue: Array[Dictionary] = []


func setup_objectives() -> void:
	for a in world.call("actors_all"):
		if a.is_civilian:
			continue
		player_tier[a.a_id] = 0
		_apply_tier(a)
	announce("ГОНКА ВООРУЖЕНИЙ: 15 ступеней", Color("b6ff2b"))


func _apply_tier(a: Actor) -> void:
	var tier := clampi(int(player_tier.get(a.a_id, 0)), 0, LADDER.size() - 1)
	var wid := str(LADDER[tier])
	a.loadout.clear()
	a.add_weapon(wid)
	a.add_weapon("knife")
	a.equip_weapon(wid)
	a.mag = int(Db.WEAPONS[wid].get("mag", 1))
	a.reserve = int(Db.WEAPONS[wid].get("reserve", 100))
	a.visual.weapon_id = wid
	a.visual.queue_redraw()
	if a.is_local_player:
		var w: Dictionary = Db.WEAPONS[wid]
		Signals.notify.emit("Ступень %d/%d: %s" % [tier + 1, LADDER.size(), w.get("name", wid)], "good")
		if tier == LADDER.size() - 1:
			Signals.match_event.emit("ФИНАЛ: ЗОЛОТОЙ НОЖ. ОДИН УДАР.", Color("ffb02b"), "mode")


func tick_mode(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for r in respawn_queue:
		r["t"] = float(r["t"]) - delta
		if float(r["t"]) <= 0.0:
			var a: Actor = world.call("actor_by_id", int(r["id"]))
			if a != null:
				world.call("respawn_actor", a)
				_apply_tier(a)
		else:
			keep.append(r)
	respawn_queue = keep
	if score.get(0, 0) >= 40:
		win(0, "лестница пройдена")
	elif score.get(1, 0) >= 40:
		win(1, "лестница пройдена")


func on_actor_died(victim: Actor, killer: Actor, _headshot: bool) -> void:
	if victim.is_civilian or killer == null or killer == victim:
		return
	var tier := int(player_tier.get(killer.a_id, 0))
	var knife_kill := killer.current_weapon == "knife"
	if tier >= LADDER.size() - 1:
		# golden knife kill ends it
		add_score(killer.team, 40)
		win(killer.team, "золотой нож")
		return
	var step := 2 if knife_kill else 1
	player_tier[killer.a_id] = clampi(tier + step, 0, LADDER.size() - 1)
	_apply_tier(killer)
	add_score(killer.team, 1)
	# victim drops one tier
	var vtier := int(player_tier.get(victim.a_id, 0))
	player_tier[victim.a_id] = maxi(0, vtier - 1)
	respawn_queue.append({"id": victim.a_id, "t": float(mode_data.get("respawn", 1.5))})


func interaction_text(_o: ObjectiveNode, _a: Actor) -> String:
	return ""

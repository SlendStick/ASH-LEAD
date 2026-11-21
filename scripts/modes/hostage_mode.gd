class_name HostageMode
extends GameMode
## «Переговоры»: one side holds a hostage and a limited number of civilians,
## police must free and evacuate people. Harming the hostage is a defeat.

var hostage: Character = null
var hostage_interact = null
var police_spawned: bool = false
var negotiation_points: int = 0
var police_timer: float = 70.0


func _on_setup() -> void:
	match_ref.config["respawn"] = false
	match_ref.config["downed_enabled"] = true
	match_ref.deferred_team = GameTypes.Team.POLICE
	match_ref.police_arrived = false
	police_timer = float(config.get("police_delay", 70.0))
	_pick_hostage()
	match_ref.feed(Localization.t("objective_hostage"))


func _pick_hostage() -> void:
	var candidates: Array = []
	for c in match_ref.characters:
		if c.team == GameTypes.Team.CIVILIAN and c.alive:
			candidates.append(c)
	if candidates.is_empty():
		return
	var chosen: Character = candidates[randi() % candidates.size()]
	# Move the hostage to a room away from the police entry.
	var target_room: Dictionary = {}
	for room in match_ref.map_data.rooms:
		if room["tag"] == "server" or room["tag"] == "storage" or room["tag"] == "archive":
			target_room = room
			break
	if target_room.is_empty() and not match_ref.map_data.rooms.is_empty():
		target_room = match_ref.map_data.rooms[match_ref.map_data.rooms.size() - 1]
	if not target_room.is_empty():
		var tiles: Array = target_room["floor_tiles"]
		if not tiles.is_empty():
			var tile: Vector2i = tiles[randi() % tiles.size()]
			chosen.global_position = match_ref.map_data.tile_center_world(tile.x, tile.y)
	hostage = chosen
	if chosen.controller != null:
		chosen.controller.state = GameTypes.NPCState.STAY
	hostage_interact = Interactable.InteractHostage.new(match_ref, chosen)
	match_ref.register_interactable(hostage_interact)
	add_highlight("hostage", {"pos": chosen.global_position})


func _on_update(delta: float) -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	if not police_spawned:
		police_timer -= delta * (1.0 + match_ref.resonance.value / 130.0)
		if police_timer <= 0.0:
			police_spawned = true
			match_ref.police_arrived = true
			match_ref.spawn_deferred_team(GameTypes.Team.POLICE)
	if hostage == null:
		end(GameTypes.Team.POLICE, "reason_hostage_dead")
		return
	if not hostage.alive:
		end(GameTypes.Team.POLICE, "reason_hostage_dead")
		return
	if hostage_interact != null and hostage_interact.freed:
		for e in match_ref.map_data.evac:
			if hostage.global_position.distance_to(e["pos"]) < float(e["radius"]):
				end(GameTypes.Team.POLICE, "reason_hostage_rescued")
				return
	if match_ref.phase_time >= round_time:
		end(GameTypes.Team.CRIMINALS, "reason_hostage_time")
		return
	if alive_of(GameTypes.Team.CRIMINALS).is_empty():
		end(GameTypes.Team.POLICE, "reason_elimination")
		return
	if police_spawned and alive_of(GameTypes.Team.POLICE).is_empty():
		end(GameTypes.Team.CRIMINALS, "reason_police_down")
		return


func on_hostage_freed(interactable, character: Character) -> void:
	match_ref.record_stat(character, "objectives")
	if hostage != null and hostage.controller != null:
		hostage.controller.command("follow", character)
	add_highlight("objective", {"pos": hostage.global_position if hostage != null else Vector2.ZERO, "type": "hostage_freed"})


## Negotiation lines from the criminal side: abstract effects, no real-world
## procedure involved.
func negotiate(line_id: String) -> void:
	match negotiation_points:
		"calm":
			match_ref.resonance.value = clampf(match_ref.resonance.value - 12.0, 0.0, 100.0)
			match_ref.feed(Localization.t("feed_neg_calm"))
		"demand":
			police_timer += 10.0
			match_ref.feed(Localization.t("feed_neg_demand"))
		"threat":
			match_ref.resonance.value = clampf(match_ref.resonance.value + 14.0, 0.0, 100.0)
			match_ref.feed(Localization.t("feed_neg_threat"))
		_:
			return
	negotiation_points += 1
	match_ref.play_sound("radio_blip", Vector2.INF)


func get_objective_text() -> String:
	if hostage_interact != null and hostage_interact.freed:
		return Localization.t("objective_escort_hostage")
	return Localization.t("objective_hold_hostage")


func get_phase_text() -> String:
	if match_ref.phase == GameTypes.GamePhase.PREP:
		return Localization.t("phase_prep")
	if not police_spawned:
		return Localization.t("phase_police_incoming") + " " + U.format_time(maxf(0.0, police_timer))
	return Localization.t("phase_police_active")

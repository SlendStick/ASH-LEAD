class_name ArchiveMode
extends GameMode
## «Чёрный архив»: deliver a valuable object to the evac zone or intercept it.

var object_item = null
var carrier: Character = null
var drop_pos: Vector2 = Vector2.INF
var recover_progress: float = 0.0
var police_timer: float = 55.0
var police_spawned: bool = false


func _on_setup() -> void:
	match_ref.config["respawn"] = false
	match_ref.config["downed_enabled"] = true
	match_ref.deferred_team = GameTypes.Team.POLICE
	match_ref.police_arrived = false
	police_timer = float(config.get("police_delay", 55.0))
	if not match_ref.map_data.objectives.is_empty():
		object_item = Interactable.InteractLoot.new(match_ref, match_ref.map_data.objectives[0]["pos"], "archive")
		match_ref.register_interactable(object_item)
	match_ref.feed(Localization.t("objective_archive"))


func _on_update(delta: float) -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	if not police_spawned:
		police_timer -= delta * (1.0 + match_ref.resonance.value / 120.0)
		if police_timer <= 0.0:
			police_spawned = true
			match_ref.police_arrived = true
			match_ref.spawn_deferred_team(GameTypes.Team.POLICE)
	if carrier != null and carrier.alive and carrier.carry_object:
		for e in match_ref.map_data.evac:
			if carrier.global_position.distance_to(e["pos"]) < float(e["radius"]):
				match_ref.record_stat(carrier, "objectives")
				end(GameTypes.Team.CRIMINALS, "reason_archive_delivered")
				return
	# Interception: police standing over the dropped object recover it.
	if drop_pos != Vector2.INF:
		var recovering := false
		for c in match_ref.characters:
			if c.team == GameTypes.Team.POLICE and c.alive and c.global_position.distance_to(drop_pos) < 80.0:
				recovering = true
				break
		if recovering:
			recover_progress += delta / 3.0
			if recover_progress >= 1.0:
				end(GameTypes.Team.POLICE, "reason_archive_secured")
				return
		else:
			recover_progress = maxf(0.0, recover_progress - delta * 0.4)
	if match_ref.phase_time >= round_time:
		end(GameTypes.Team.POLICE, "reason_time_up")
		return
	if alive_of(GameTypes.Team.CRIMINALS).is_empty():
		end(GameTypes.Team.POLICE, "reason_elimination")
		return
	if police_spawned and alive_of(GameTypes.Team.POLICE).is_empty():
		end(GameTypes.Team.CRIMINALS, "reason_police_down")
		return


func on_loot_picked(loot, character: Character) -> void:
	carrier = character
	drop_pos = Vector2.INF
	match_ref.record_stat(character, "objectives")
	add_highlight("objective", {"pos": loot.global_position, "type": "archive"})


func on_carrier_down(carrier: Character) -> void:
	if self.carrier == carrier:
		self.carrier = null
		drop_pos = carrier.global_position
		recover_progress = 0.0
		if object_item != null:
			object_item.enabled = false
		var item := Interactable.InteractLoot.new(match_ref, drop_pos, "archive")
		match_ref.register_interactable(item)
		object_item = item
		match_ref.feed(Localization.t("feed_archive_dropped"))


func get_objective_text() -> String:
	if carrier != null:
		return Localization.t("objective_deliver")
	if drop_pos != Vector2.INF:
		return Localization.t("objective_recover")
	return Localization.t("objective_take_archive")


func get_phase_text() -> String:
	if match_ref.phase == GameTypes.GamePhase.PREP:
		return Localization.t("phase_prep")
	if not police_spawned:
		return Localization.t("phase_police_incoming") + " " + U.format_time(maxf(0.0, police_timer))
	return Localization.t("phase_police_active")

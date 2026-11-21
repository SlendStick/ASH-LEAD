class_name HeistMode
extends GameMode
## «Налёт»: criminals find and carry out loot while police arrive after a
## delay. Civilians are present and their evacuation matters.

var arrival_timer: float = 75.0
var loot_items: Array = []
var carrier: Character = null
var police_spawned: bool = false
var escape_timer: float = 0.0


func _on_setup() -> void:
	match_ref.config["respawn"] = false
	match_ref.config["downed_enabled"] = true
	match_ref.deferred_team = GameTypes.Team.POLICE
	match_ref.police_arrived = false
	arrival_timer = float(config.get("police_delay", 75.0))
	for loot in match_ref.map_data.loot:
		var item := Interactable.InteractLoot.new(match_ref, loot["pos"], "loot")
		match_ref.register_interactable(item)
		loot_items.append(item)
	if loot_items.is_empty() and not match_ref.map_data.objectives.is_empty():
		var item := Interactable.InteractLoot.new(match_ref, match_ref.map_data.objectives[0]["pos"], "loot")
		match_ref.register_interactable(item)
		loot_items.append(item)
	match_ref.feed(Localization.t("objective_heist"))


func _on_update(delta: float) -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	# Police arrival: accelerated by resonance (loud actions, panic, alarms).
	if not police_spawned:
		arrival_timer -= delta * (1.0 + match_ref.resonance.value / 110.0)
		if arrival_timer <= 0.0:
			police_spawned = true
			match_ref.police_arrived = true
			match_ref.spawn_deferred_team(GameTypes.Team.POLICE)
			add_highlight("police_arrival", {})
	# Escape check.
	if carrier != null and carrier.alive and carrier.carry_object:
		for e in match_ref.map_data.evac:
			if carrier.global_position.distance_to(e["pos"]) < float(e["radius"]):
				end(GameTypes.Team.CRIMINALS, "reason_escape")
				return
	# Time limit for the whole heist.
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
	match_ref.record_stat(character, "objectives")
	add_highlight("objective", {"pos": loot.global_position, "type": "loot"})
	match_ref.feed(Localization.t("feed_loot_carried"))


func on_carrier_down(carrier: Character) -> void:
	if self.carrier == carrier:
		self.carrier = null
		# The loot drops where the carrier fell.
		var item := Interactable.InteractLoot.new(match_ref, carrier.global_position, "loot")
		match_ref.register_interactable(item)
		loot_items.append(item)
		match_ref.feed(Localization.t("feed_loot_dropped"))


func on_civilian_evacuated(civilian: Character) -> void:
	match_ref.record_stat(civilian, "objectives")
	match_ref.resonance.add_civilian_evacuated()


func get_objective_text() -> String:
	if carrier != null:
		return Localization.t("objective_escape")
	return Localization.t("objective_find_loot")


func get_phase_text() -> String:
	if match_ref.phase == GameTypes.GamePhase.PREP:
		return Localization.t("phase_prep")
	if not police_spawned:
		return Localization.t("phase_police_incoming") + " " + U.format_time(maxf(0.0, arrival_timer))
	return Localization.t("phase_police_active")

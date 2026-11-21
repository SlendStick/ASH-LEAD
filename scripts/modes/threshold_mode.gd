class_name ThresholdMode
extends GameMode
## «Порог»: criminals capture and hold several zones in a large building;
## police arrive after a delay and must stop the advance.

var zones: Array = []
var active_zone: int = 0
var advanced: int = 0
var total_hold: float = 0.0
var hold_target: float = 90.0
var police_timer: float = 60.0
var police_spawned: bool = false


func _on_setup() -> void:
	match_ref.config["respawn"] = false
	match_ref.config["downed_enabled"] = true
	match_ref.deferred_team = GameTypes.Team.POLICE
	match_ref.police_arrived = false
	police_timer = float(config.get("police_delay", 60.0))
	var objectives: Array = match_ref.map_data.objectives
	var count := mini(3, maxi(1, objectives.size()))
	for i in count:
		var obj: Dictionary = objectives[i]
		var zone := Interactable.InteractZone.new(match_ref, obj["pos"], i, float(obj.get("radius", 190.0)))
		zone.set_active(i == 0)
		match_ref.register_interactable(zone)
		zones.append(zone)
	match_ref.feed(Localization.t("objective_threshold"))


func _on_update(delta: float) -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	if not police_spawned:
		police_timer -= delta * (1.0 + match_ref.resonance.value / 120.0)
		if police_timer <= 0.0:
			police_spawned = true
			match_ref.police_arrived = true
			match_ref.spawn_deferred_team(GameTypes.Team.POLICE)
	for zone in zones:
		zone.update_zone(delta)
	var zone = zones[active_zone] if active_zone < zones.size() else null
	if zone != null and zone.owner == GameTypes.Team.CRIMINALS:
		total_hold += delta
		if total_hold >= hold_target:
			end(GameTypes.Team.CRIMINALS, "reason_threshold")
			return
	if active_zone == advanced and zone != null and zone.owner == GameTypes.Team.CRIMINALS:
		advanced += 1
		if active_zone < zones.size() - 1:
			active_zone += 1
			zones[active_zone].set_active(true)
			match_ref.feed(Localization.t("feed_next_zone"))
			match_ref.play_sound("objective", Vector2.INF)
	if match_ref.phase_time >= round_time:
		end(GameTypes.Team.POLICE, "reason_time_up")
		return
	if alive_of(GameTypes.Team.CRIMINALS).is_empty():
		end(GameTypes.Team.POLICE, "reason_elimination")
		return
	if police_spawned and alive_of(GameTypes.Team.POLICE).is_empty():
		end(GameTypes.Team.CRIMINALS, "reason_police_down")
		return


func get_objective_text() -> String:
	return Localization.t("objective_threshold_hold") % U.format_time(maxf(0.0, hold_target - total_hold))


func get_phase_text() -> String:
	if match_ref.phase == GameTypes.GamePhase.PREP:
		return Localization.t("phase_prep")
	if not police_spawned:
		return Localization.t("phase_police_incoming") + " " + U.format_time(maxf(0.0, police_timer))
	return Localization.t("phase_police_active")

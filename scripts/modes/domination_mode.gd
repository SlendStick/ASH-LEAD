class_name DominationMode
extends GameMode
## «Захват точек»: zones activate in turn; holding them scores points.

var zones: Array = []
var active_zone: int = 0
var score_limit: int = 200
var points_per_second: float = 3.0


func _on_setup() -> void:
	match_ref.config["respawn"] = true
	match_ref.config["downed_enabled"] = false
	score_limit = int(config.get("score_limit", 200))
	var objectives: Array = match_ref.map_data.objectives
	var count := mini(3, maxi(1, objectives.size()))
	for i in count:
		var obj: Dictionary = objectives[i]
		var zone := Interactable.InteractZone.new(match_ref, obj["pos"], i, float(obj.get("radius", 200.0)))
		zone.set_active(i == 0)
		match_ref.register_interactable(zone)
		zones.append(zone)
	match_ref.feed(Localization.t("objective_domination"))


func _on_update(delta: float) -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	for zone in zones:
		zone.update_zone(delta)
	var zone = zones[active_zone] if active_zone < zones.size() else null
	if zone != null and zone.zone_owner != GameTypes.Team.NONE:
		scores[zone.zone_owner] = int(scores.get(zone.zone_owner, 0)) + int(points_per_second * delta * 10.0) / 10
		if int(scores.get(zone.zone_owner, 0)) >= score_limit:
			end(zone.zone_owner, "reason_score_limit")
			return
	if zone != null and zone.zone_owner != GameTypes.Team.NONE:
		if active_zone < zones.size() - 1:
			active_zone += 1
			zones[active_zone].set_active(true)
			match_ref.feed(Localization.t("feed_next_zone"))
	if match_ref.phase_time >= round_time:
		end(_leading_team(), "reason_time_up")


func get_objective_text() -> String:
	return Localization.t("objective_domination_score") % [int(scores.get(GameTypes.Team.CRIMINALS, 0)), int(scores.get(GameTypes.Team.POLICE, 0))]


func get_phase_text() -> String:
	return Localization.t("phase_active")

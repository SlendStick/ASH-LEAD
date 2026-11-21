class_name TDMMode
extends GameMode
## «Командный бой насмерть»: fast respawns, score limit, team actions count.

var score_limit: int = 40
var kill_times: Dictionary = {}


func _on_setup() -> void:
	match_ref.config["respawn"] = true
	match_ref.config["downed_enabled"] = false
	score_limit = int(config.get("score_limit", 40))
	match_ref.feed(Localization.t("objective_tdm"))


func _on_update(delta: float) -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	if int(scores.get(GameTypes.Team.CRIMINALS, 0)) >= score_limit:
		end(GameTypes.Team.CRIMINALS, "reason_score_limit")
		return
	if int(scores.get(GameTypes.Team.POLICE, 0)) >= score_limit:
		end(GameTypes.Team.POLICE, "reason_score_limit")
		return
	if match_ref.phase_time >= round_time:
		end(_leading_team(), "reason_time_up")


func on_character_died(victim: Character, killer: Character) -> void:
	super.on_character_died(victim, killer)
	if killer == null or killer == victim:
		return
	if killer.team == victim.team:
		scores[killer.team] = int(scores.get(killer.team, 0)) - 1
		return
	scores[killer.team] = int(scores.get(killer.team, 0)) + 1
	var key := killer.char_name
	var times: Array = kill_times.get(key, [])
	times.append(match_ref.elapsed)
	kill_times[key] = times
	var recent := 0
	for t in times:
		if match_ref.elapsed - float(t) < 6.0:
			recent += 1
	if recent >= 3:
		add_highlight("multikill", {"name": killer.char_name, "count": recent})
		match_ref.feed(Localization.t("feed_multikill") % [killer.char_name, recent])


func get_objective_text() -> String:
	return Localization.t("objective_tdm_score") % [int(scores.get(GameTypes.Team.CRIMINALS, 0)), int(scores.get(GameTypes.Team.POLICE, 0))]


func get_phase_text() -> String:
	return Localization.t("phase_active")

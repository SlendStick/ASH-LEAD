class_name DMMode
extends GameMode
## «Бой насмерть»: free-for-all arcade without teams.

var score_limit: int = 20


func _on_setup() -> void:
	match_ref.config["respawn"] = true
	match_ref.config["downed_enabled"] = false
	match_ref.config["ffa"] = true
	score_limit = int(config.get("score_limit", 20))
	match_ref.feed(Localization.t("objective_dm"))


func _on_update(delta: float) -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	for c in match_ref.characters:
		if c.team == GameTypes.Team.CIVILIAN:
			continue
		if _char_kills(c) >= score_limit:
			end(c.team, "reason_score_limit", c)
			return
	if match_ref.phase_time >= round_time:
		var best: Character = null
		var best_kills := -1
		for c in match_ref.characters:
			if c.team == GameTypes.Team.CIVILIAN:
				continue
			if _char_kills(c) > best_kills:
				best_kills = _char_kills(c)
				best = c
		end(best.team if best != null else GameTypes.Team.NONE, "reason_time_up", best)


func _char_kills(character: Character) -> int:
	return int(match_ref.stats.get(str(character.player_id), {}).get("kills", 0))


func on_character_died(victim: Character, killer: Character) -> void:
	super.on_character_died(victim, killer)
	if killer != null and killer != victim:
		add_highlight("kill", {"killer": killer.char_name, "victim": victim.char_name})


func get_objective_text() -> String:
	var best_name := ""
	var best_kills := 0
	for c in match_ref.characters:
		if c.team == GameTypes.Team.CIVILIAN:
			continue
		var k := _char_kills(c)
		if k > best_kills:
			best_kills = k
			best_name = c.char_name
	return Localization.t("objective_dm_score") % [best_kills, score_limit] if best_name != "" else Localization.t("objective_dm")


func get_phase_text() -> String:
	return Localization.t("phase_active")

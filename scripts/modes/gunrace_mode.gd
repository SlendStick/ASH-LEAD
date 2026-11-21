class_name GunRaceMode
extends GameMode
## «Гонка вооружений»: each elimination moves the weapon tier forward; the
## final tier decides the match.

const TIERS := ["p9", "vec9", "kv14", "ob12", "sv90", "dtas", "knife"]

var tiers: Dictionary = {}
var score_limit: int = 15


func _on_setup() -> void:
	match_ref.config["respawn"] = true
	match_ref.config["downed_enabled"] = false
	match_ref.config["ffa"] = true
	score_limit = int(config.get("score_limit", 15))
	for c in match_ref.characters:
		if c.team == GameTypes.Team.CIVILIAN:
			continue
		tiers[c.char_name] = 0
		_match_give(c, TIERS[0])
	match_ref.feed(Localization.t("objective_gunrace"))


func _match_give(character: Character, weapon_id: String) -> void:
	match_ref.give_weapon(character, weapon_id)


func _on_update(delta: float) -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	if match_ref.phase_time >= round_time:
		var best: Character = null
		var best_kills := -1
		for c in match_ref.characters:
			if c.team == GameTypes.Team.CIVILIAN:
				continue
			var k := int(match_ref.stats.get(str(c.player_id), {}).get("kills", 0))
			if k > best_kills:
				best_kills = k
				best = c
		end(best.team if best != null else GameTypes.Team.NONE, "reason_time_up", best)


func on_character_died(victim: Character, killer: Character) -> void:
	super.on_character_died(victim, killer)
	if killer == null or killer == victim:
		return
	var key := killer.char_name
	var idx: int = tiers.get(key, 0)
	var kills := int(match_ref.stats.get(str(killer.player_id), {}).get("kills", 0))
	var target := clampi(kills, 0, TIERS.size() - 1)
	if target != idx:
		tiers[key] = target
		_match_give(killer, TIERS[target])
		match_ref.feed(Localization.t("feed_gunrace_up") % [killer.char_name, TIERS[target]])
	# The victim falls back to the first tier.
	tiers[victim.char_name] = 0
	_match_give(victim, TIERS[0])
	if target >= TIERS.size() - 1:
		add_highlight("objective", {"type": "gunrace_final", "name": killer.char_name})


func get_objective_text() -> String:
	return Localization.t("objective_gunrace_score") % score_limit


func get_phase_text() -> String:
	return Localization.t("phase_active")

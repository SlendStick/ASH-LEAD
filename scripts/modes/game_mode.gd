class_name GameMode
extends Node
## Base game mode: phases, scoring, win conditions and highlights.

var match_ref: Match
var config: Dictionary = {}
var mode_id: String = "plant"
var mode_data: Dictionary = {}
var category: String = "competitive"
var device_planted: bool = false
var round_number: int = 1
var scores: Dictionary = {GameTypes.Team.CRIMINALS: 0, GameTypes.Team.POLICE: 0}
var round_time: float = 120.0
var rounds_to_win: int = 4
var max_rounds: int = 8
var _highlights: Array = []
var _ended: bool = false


static func create_mode(id: String, match_ref) -> GameMode:
	var script: Variant = null
	match id:
		"plant":
			script = load("res://scripts/modes/plant_mode.gd")
		"heist":
			script = load("res://scripts/modes/heist_mode.gd")
		"hostage":
			script = load("res://scripts/modes/hostage_mode.gd")
		"threshold":
			script = load("res://scripts/modes/threshold_mode.gd")
		"archive":
			script = load("res://scripts/modes/archive_mode.gd")
		"tdm":
			script = load("res://scripts/modes/tdm_mode.gd")
		"dm":
			script = load("res://scripts/modes/dm_mode.gd")
		"gunrace":
			script = load("res://scripts/modes/gunrace_mode.gd")
		"domination":
			script = load("res://scripts/modes/domination_mode.gd")
		_:
			script = load("res://scripts/modes/plant_mode.gd")
	if script == null:
		return null
	var mode = script.new()
	if id == "dm" or id == "gunrace":
		mode.mode_id = id
	elif id == "tdm":
		mode.mode_id = "tdm"
	elif id == "domination":
		mode.mode_id = "domination"
	else:
		mode.mode_id = id
	mode.match_ref = match_ref
	return mode


func setup() -> void:
	config = match_ref.config
	mode_data = Data.mode(mode_id)
	category = String(mode_data.get("category", "competitive"))
	round_time = float(config.get("round_time", mode_data.get("round_time", 120)))
	rounds_to_win = int(config.get("rounds_to_win", mode_data.get("rounds_to_win", 4)))
	max_rounds = maxi(rounds_to_win * 2 - 1, 3)
	highlights_clear()
	match_ref.config["downed_enabled"] = category != "competitive"
	_on_setup()
	_announce_objective()


func _on_setup() -> void:
	pass


func _announce_objective() -> void:
	match_ref.feed(String(mode_data.get("short", "")))


func update(delta: float) -> void:
	match_ref.advance_phase_timer(delta)
	_on_update(delta)


func _on_update(_delta: float) -> void:
	pass


func on_prep() -> void:
	pass


func on_active() -> void:
	pass


func on_post() -> void:
	pass


func get_focus_position() -> Vector2:
	if not match_ref.map_data.objectives.is_empty():
		return match_ref.map_data.objectives[0]["pos"]
	return Vector2.INF


func get_score(team: int) -> int:
	return int(scores.get(team, 0))


func get_highlights() -> Array:
	return _highlights


func add_highlight(type: String, data: Dictionary) -> void:
	_highlights.append({"type": type, "data": data})


func highlights_clear() -> void:
	_highlights.clear()


func end(winner: int, reason_key: String, winner_character: Character = null) -> void:
	if _ended:
		return
	_ended = true
	match_ref.end_match(winner, reason_key, winner_character)


func end_round(winner: int, reason_key: String) -> void:
	scores[winner] = int(scores.get(winner, 0)) + 1
	var rep := _winner_rep(winner)
	if rep != null:
		match_ref.record_stat(rep, "objectives")
	match_ref.feed(Localization.t("feed_round_end") % [GameTypes.team_name(winner), Localization.t(reason_key)])
	if int(scores.get(winner, 0)) >= rounds_to_win or round_number >= max_rounds:
		var best := _leading_team()
		end(best, "reason_rounds")
		return
	round_number += 1
	_reset_round()


func _leading_team() -> int:
	var crim := int(scores.get(GameTypes.Team.CRIMINALS, 0))
	var cop := int(scores.get(GameTypes.Team.POLICE, 0))
	if crim == cop:
		return GameTypes.Team.NONE
	return GameTypes.Team.CRIMINALS if crim > cop else GameTypes.Team.POLICE


func _winner_rep(team: int) -> Character:
	for c in match_ref.characters:
		if c.team == team:
			return c
	return null


func _reset_round() -> void:
	device_planted = false
	_ended = false
	var swap := round_number > max_rounds * 0.5
	for c in match_ref.characters:
		if c.team == GameTypes.Team.CIVILIAN:
			continue
		if swap:
			c.swap_team(GameTypes.Team.POLICE if c.team == GameTypes.Team.CRIMINALS else GameTypes.Team.CRIMINALS)
		_reset_character(c)
	if swap:
		match_ref.feed(Localization.t("feed_side_swap"))
	match_ref.set_phase(GameTypes.GamePhase.PREP)


func _reset_character(character: Character) -> void:
	var tiles: Array = match_ref.map_data.spawn_crim if character.team == GameTypes.Team.CRIMINALS else match_ref.map_data.spawn_cop
	if tiles.is_empty():
		return
	var tile: Vector2i = tiles[randi() % tiles.size()]
	character.global_position = match_ref.map_data.tile_center_world(tile.x, tile.y)
	character.alive = true
	character.downed = false
	character.hp = character.max_hp
	character.armor = character.max_armor
	character.suppression = 0.0
	character.carry_object = false
	character.collision_layer = 2 | 4
	character.collision_mask = 1 | 2 | 4 | 8
	if character.sprite != null:
		character.sprite.modulate = Color.white
	for w in character.weapons:
		w.ammo_in_mag = int(w.data.get("mag", 0))
		w.reserve = int(w.data.get("reserve", 0))
		w.reloading = false
		w.cooldown = 0.0
	character.health_changed.emit(character.hp, character.max_hp)


# ---- shared helpers --------------------------------------------------------

func alive_of(team: int) -> Array:
	var out: Array = []
	for c in match_ref.characters:
		if c.team == team and c.alive and not c.downed:
			out.append(c)
	return out


func all_dead(team: int) -> bool:
	return alive_of(team).is_empty()


func check_elimination() -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	if not alive_of(GameTypes.Team.CRIMINALS).is_empty() and not alive_of(GameTypes.Team.POLICE).is_empty():
		return
	if alive_of(GameTypes.Team.CRIMINALS).is_empty():
		_eliminated(GameTypes.Team.POLICE)
	elif alive_of(GameTypes.Team.POLICE).is_empty():
		_eliminated(GameTypes.Team.CRIMINALS)


func _eliminated(winner: int) -> void:
	# Round-based modes play rounds; arcade modes end the match at once.
	if max_rounds > 1:
		end_round(winner, "reason_elimination")
	else:
		end(winner, "reason_elimination")


func on_character_died(_victim: Character, _killer: Character) -> void:
	# Kills and deaths are recorded by Match.on_character_died.
	pass


func on_civilian_evacuated(_civilian: Character) -> void:
	match_ref.resonance.add_civilian_evacuated()


func on_device_planted(_device, _character: Character) -> void:
	device_planted = true


func on_device_defused(_device, _character: Character) -> void:
	pass


func on_loot_picked(_loot, _character: Character) -> void:
	pass


func on_zone_captured(_zone, _team: int) -> void:
	pass


func on_hostage_freed(_interactable, _character: Character) -> void:
	pass


func on_carrier_down(_carrier: Character) -> void:
	pass


func get_objective_text() -> String:
	return Localization.t("objective_default")


func get_phase_text() -> String:
	return Localization.t("phase_active")

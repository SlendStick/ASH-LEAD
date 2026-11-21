extends Node
## Local player profile and statistics. Cosmetic/progression only: no paid
## advantages, no loot boxes. Stored in user://profile.json.

const PROFILE_PATH := "user://profile.json"

var player_name: String = "Оператор"
var profile: Dictionary = {}


func _ready() -> void:
	load_profile()


func _default_profile() -> Dictionary:
	return {
		"player_name": "Оператор",
		"matches": 0,
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"kills": 0,
		"deaths": 0,
		"assists": 0,
		"civ_saved": 0,
		"civ_hurt": 0,
		"objectives_done": 0,
		"team_actions": 0,
		"favorite_role": "",
		"history": [],
		"unlocked_skins": ["default"],
		"selected_skin": "default",
	}


func add_result(result: Dictionary) -> void:
	profile["matches"] = int(profile.get("matches", 0)) + 1
	var outcome := String(result.get("outcome", "draw"))
	match outcome:
		"win":
			profile["wins"] = int(profile.get("wins", 0)) + 1
		"loss":
			profile["losses"] = int(profile.get("losses", 0)) + 1
		_:
			profile["draws"] = int(profile.get("draws", 0)) + 1
	profile["kills"] = int(profile.get("kills", 0)) + int(result.get("kills", 0))
	profile["deaths"] = int(profile.get("deaths", 0)) + int(result.get("deaths", 0))
	profile["assists"] = int(profile.get("assists", 0)) + int(result.get("assists", 0))
	profile["civ_saved"] = int(profile.get("civ_saved", 0)) + int(result.get("civ_saved", 0))
	profile["civ_hurt"] = int(profile.get("civ_hurt", 0)) + int(result.get("civ_hurt", 0))
	profile["objectives_done"] = int(profile.get("objectives_done", 0)) + int(result.get("objectives", 0))
	profile["team_actions"] = int(profile.get("team_actions", 0)) + int(result.get("team_actions", 0))
	var role := String(result.get("role", ""))
	if not role.is_empty():
		profile["favorite_role"] = role
	var history: Array = profile.get("history", [])
	history.append({
		"mode": result.get("mode", ""),
		"outcome": outcome,
		"map": result.get("map", ""),
		"date": Time.get_datetime_string_from_system(),
	})
	if history.size() > 40:
		history = history.slice(history.size() - 40)
	profile["history"] = history
	save_profile()


func save_profile() -> void:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(profile, "  "))
	f.close()


func load_profile() -> void:
	profile = _default_profile()
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		for key in parsed:
			profile[key] = parsed[key]
	player_name = String(profile.get("player_name", "Оператор"))

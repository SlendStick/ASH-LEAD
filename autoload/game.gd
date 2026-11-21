extends Node
## Global run state shared between menus, lobby, match and results.
## Holds the selected mode/map/seed/team/loadout and the last match result.

var current_mode: String = "plant"
var current_map_id: String = "clinic"
var map_seed: int = 0
var player_team: int = 0
var loadout: Dictionary = {}
var match_config: Dictionary = {}
var match_result: Dictionary = {}
var lobby: Dictionary = {}
var group_members: Array = []
var service_status: String = "offline"
var last_error: String = ""


func _ready() -> void:
	map_seed = int(randi() % 1000000)


func reset_run() -> void:
	match_config = {}
	match_result = {}
	last_error = ""


## Build a default match configuration for a mode/map/seed.
func make_match_config(mode_id: String, map_id: String, seed: int, team_size: int) -> Dictionary:
	return {
		"mode": mode_id,
		"map": map_id,
		"seed": seed,
		"team_size": team_size,
		"bots_fill": true,
		"bot_difficulty": 1,
		"round_time": 120.0,
		"rounds_to_win": 4,
		"police_delay": 75.0,
		"civilians": true,
		"friendly_fire": false,
		"respawn": false,
		"password": "",
	}

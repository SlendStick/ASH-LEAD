class_name FogOfWar
extends Node
## Team-level fog of war. Geometry is revealed by exploration; enemies appear
## on the tactical map only while genuinely detected. The last known position
## fades into an uncertain marker.

const SIGHT_RADIUS := 13.0
const UPDATE_INTERVAL := 0.22
const LAST_SEEN_TIME := 9.0

var explored: Dictionary = {}     # team -> { Vector2i: true }
var visible: Dictionary = {}      # team -> { Vector2i: true }
var detected: Dictionary = {}     # team -> { Character: {"pos": Vector2, "timer": float, "uncertain": bool} }
var _timer := 0.0


func _init() -> void:
	explored = {GameTypes.Team.CRIMINALS: {}, GameTypes.Team.POLICE: {}}
	visible = {GameTypes.Team.CRIMINALS: {}, GameTypes.Team.POLICE: {}}
	detected = {GameTypes.Team.CRIMINALS: {}, GameTypes.Team.POLICE: {}}


func reset() -> void:
	_init()


func update(match_ref, delta: float) -> void:
	_timer += delta
	_decay_detection(match_ref, delta)
	if _timer < UPDATE_INTERVAL:
		return
	_timer = 0.0
	for team in [GameTypes.Team.CRIMINALS, GameTypes.Team.POLICE]:
		visible[team] = {}
	for team in [GameTypes.Team.CRIMINALS, GameTypes.Team.POLICE]:
		for character in match_ref.characters:
			if character.team != team or not character.alive:
				continue
			_reveal_from(match_ref, team, character.global_position)
	_update_detection(match_ref)


func _reveal_from(match_ref, team: int, pos: Vector2) -> void:
	var tile := match_ref.map_data.world_to_tile(pos)
	var radius := int(SIGHT_RADIUS)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var t := tile + Vector2i(dx, dy)
			if not match_ref.map_data.in_bounds(t.x, t.y):
				continue
			if not match_ref.map_data.has_los(pos, match_ref.map_data.tile_center_world(t.x, t.y)):
				continue
			visible[team][t] = true
			explored[team][t] = true


func _update_detection(match_ref) -> void:
	for team in [GameTypes.Team.CRIMINALS, GameTypes.Team.POLICE]:
		var other := GameTypes.Team.POLICE if team == GameTypes.Team.CRIMINALS else GameTypes.Team.CRIMINALS
		var seen_now := {}
		for enemy in match_ref.characters:
			if enemy.team != other or not enemy.alive:
				continue
			var seen := false
			for ally in match_ref.characters:
				if ally.team != team or not ally.alive:
					continue
				if Perception.can_see(ally, enemy, match_ref.map_view):
					seen = true
					break
			if seen:
				seen_now[enemy] = true
				var entry: Dictionary = detected[team].get(enemy, {})
				entry["pos"] = enemy.global_position
				entry["timer"] = LAST_SEEN_TIME
				entry["uncertain"] = false
				detected[team][enemy] = entry
		# Enemies no longer seen stay on the map as fading last-known markers.
		var to_remove: Array = []
		for enemy in detected[team]:
			if seen_now.has(enemy):
				continue
			var entry: Dictionary = detected[team][enemy]
			entry["timer"] = float(entry.get("timer", 0.0)) - UPDATE_INTERVAL
			if float(entry["timer"]) <= 0.0:
				entry["uncertain"] = true
				entry["timer"] = -1.0
				to_remove.append(enemy)
		for enemy in to_remove:
			detected[team].erase(enemy)


func _decay_detection(match_ref, delta: float) -> void:
	for team in detected:
		for enemy in detected[team].keys():
			var entry: Dictionary = detected[team][enemy]
			if entry.get("uncertain", false):
				continue


func is_explored(team: int, tile: Vector2i) -> bool:
	var set_: Dictionary = explored.get(team, {})
	return set_.has(tile)


func is_visible(team: int, tile: Vector2i) -> bool:
	var set_: Dictionary = visible.get(team, {})
	return set_.has(tile)


func is_tile_known(team: int, tile: Vector2i) -> bool:
	return is_visible(team, tile) or is_explored(team, tile)


func get_detected(team: int) -> Dictionary:
	return detected.get(team, {})


## Enemies currently visible to the team (for HUD markers).
func is_enemy_visible(team: int, enemy: Character) -> bool:
	var entry: Dictionary = detected.get(team, {}).get(enemy, {})
	return not entry.is_empty() and not bool(entry.get("uncertain", true))
